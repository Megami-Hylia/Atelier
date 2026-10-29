import Foundation
import MetalKit
import UIKit

enum RenderError: LocalizedError {
    case unavailable, shader(String), command(String), asset(String)
    var errorDescription: String? {
        switch self {
        case .unavailable: return "Metal non è disponibile."
        case .shader(let name): return "Shader mancante: \(name)."
        case .command(let message): return "Rendering fallito: \(message)"
        case .asset(let name): return "Risorsa pennello non valida: \(name)."
        }
    }
}

private struct TileInfo {
    var origin: SIMD2<UInt32>
    var size: SIMD2<UInt32>
    var count: UInt32
}

@MainActor final class MetalPainter {
    let device: MTLDevice
    let queue: MTLCommandQueue
    let screenPipeline: MTLRenderPipelineState
    private let paintPipeline: MTLComputePipelineState
    private let clearPipeline: MTLComputePipelineState
    private let compositePipeline: MTLComputePipelineState
    private let adjustments: LayerAdjustments
    private let loader: MTKTextureLoader
    private var textures: [MTLTexture] = []
    private var cachedLayer: PaintLayer?
    private var planCache: [UUID: (PaintStroke, [GPUStamp])] = [:]
    private var planOrder: [UUID] = []
    private var planBytes = 0
    private struct AssetKey: Hashable { var name: String; var data: Data? }
    private var assetCache: [AssetKey: MTLTexture] = [:]
    private var assetOrder: [AssetKey] = []
    private var assetBytes = 0
    private var liveTexture: MTLTexture?
    private var liveStream: StrokePlanner.Stream?
    private var cachedLiveRevision: UInt64?
    private var cachedDocumentRevision: UInt64?
    private var cachedDocumentID: UUID?
    private(set) var lastPlannedSampleCount = 0
    private(set) var hasPendingLiveSamples = false
    private(set) var lastStampCount = 0
    static let workingMemoryLimit = 384 * 1024 * 1024

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { throw RenderError.unavailable }
        self.device = device; self.queue = queue; loader = MTKTextureLoader(device: device)
        adjustments = LayerAdjustments(device: device)
        func compute(_ name: String) throws -> MTLComputePipelineState {
            guard let function = library.makeFunction(name: name) else { throw RenderError.shader(name) }
            return try device.makeComputePipelineState(function: function)
        }
        paintPipeline = try compute("paintTile")
        clearPipeline = try compute("clearTexture")
        compositePipeline = try compute("compositeLayer")
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "canvasVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "canvasFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        screenPipeline = try device.makeRenderPipelineState(descriptor: descriptor)
    }

    private func allocate(width: Int, height: Int) throws {
        guard width > 0, height > 0, width <= 4096, height <= 4096,
              width * height * 8 * 5 <= Self.workingMemoryLimit else { throw DocumentError.memoryBudget }
        if textures.count == 5, textures.first?.width == width && textures.first?.height == height { return }
        var allocated: [MTLTexture] = []
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .shared
        for _ in 0..<5 {
            guard let texture = device.makeTexture(descriptor: descriptor) else { throw DocumentError.memoryBudget }
            allocated.append(texture)
        }
        textures = allocated
        invalidateCache(); liveTexture = nil
    }

    private func dispatch(_ encoder: MTLComputeCommandEncoder, pipeline: MTLComputePipelineState, width: Int, height: Int) {
        encoder.setComputePipelineState(pipeline)
        let w = pipeline.threadExecutionWidth
        encoder.dispatchThreads(MTLSize(width: width, height: height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: w, height: max(1, min(8, pipeline.maxTotalThreadsPerThreadgroup / w)), depth: 1))
    }

    private func clear(_ texture: MTLTexture, color: SIMD4<Float>, command: MTLCommandBuffer) throws {
        guard let encoder = command.makeComputeCommandEncoder() else { throw RenderError.command("clear encoder") }
        var color = color
        encoder.setTexture(texture, index: 0); encoder.setBytes(&color, length: MemoryLayout<SIMD4<Float>>.stride, index: 0)
        dispatch(encoder, pipeline: clearPipeline, width: texture.width, height: texture.height)
        encoder.endEncoding()
    }

    private func asset(_ brush: BrushPreset, shape: Bool) throws -> MTLTexture {
        let data = shape ? brush.shapeData : brush.grainData
        let key = shape ? "BrushShape-\(brush.shape)" : "BrushGrain-\(brush.grain)"
        let identity = AssetKey(name: key, data: data)
        if let texture = assetCache[identity] { return texture }
        let texture: MTLTexture
        if let data {
            guard let image = UIImage(data: data), image.size.width <= 2048, image.size.height <= 2048,
                  let cgImage = image.cgImage else { throw RenderError.asset(key) }
            texture = try loader.newTexture(cgImage: cgImage, options: [.SRGB: false, .generateMipmaps: false])
        } else {
            guard let url = Bundle.main.url(forResource: key, withExtension: "png") else { throw RenderError.asset(key) }
            texture = try loader.newTexture(URL: url, options: [.SRGB: false, .generateMipmaps: false])
        }
        let bytes = texture.width * texture.height * 4
        while assetOrder.count >= 64 || assetBytes + bytes > 32 * 1024 * 1024 {
            guard !assetOrder.isEmpty else { break }
            let oldest = assetOrder.removeFirst()
            if let removed = assetCache.removeValue(forKey: oldest) { assetBytes -= removed.width * removed.height * 4 }
        }
        assetCache[identity] = texture; assetOrder.append(identity); assetBytes += bytes
        return texture
    }

    // The CPU bins stamps into 256-pixel tiles; pixels remain in global canvas coordinates.
    // No texture coordinate restarts at tile borders, including pickup and grain.
    private func encode(_ stroke: PaintStroke, finished: Bool, source: MTLTexture, target: MTLTexture, pickup: MTLTexture? = nil, initialScratch: MTLTexture? = nil, supplied: [GPUStamp]? = nil, command: MTLCommandBuffer) throws {
        if supplied == nil, stroke.distanceDynamicsVersion == 1, let initialScratch {
            var cursor = StrokePlanner.replayStream(for: stroke, finished: finished)
            lastPlannedSampleCount += stroke.samples.count
            for start in stride(from: 0, to: stroke.samples.count, by: 8) {
                let batch = try cursor.append(stroke.samples[start..<min(start+8,stroke.samples.count)])
                if !batch.isEmpty {
                    try copy(target, to: initialScratch, command: command)
                    try encode(stroke, finished: finished, source: initialScratch, target: target, pickup: pickup ?? source, supplied: batch, command: command)
                }
            }
            if stroke.samples.count == 1 {
                let batch = try cursor.dot()
                try copy(target, to: initialScratch, command: command)
                try encode(stroke, finished: finished, source: initialScratch, target: target, pickup: pickup ?? source, supplied: batch, command: command)
            }
            return
        }
        let stamps: [GPUStamp]
        if let supplied { stamps = supplied }
        else if finished, let cached = planCache[stroke.id], cached.0 == stroke {
            stamps = cached.1
        } else {
            lastPlannedSampleCount += stroke.samples.count
            stamps = try StrokePlanner.stamps(for: stroke, finished: finished)
            let bytes = stamps.count * MemoryLayout<GPUStamp>.stride
            if finished, bytes <= 16 * 1024 * 1024 {
                if let previous = planCache.removeValue(forKey: stroke.id) {
                    planBytes -= previous.1.count * MemoryLayout<GPUStamp>.stride
                    planOrder.removeAll { $0 == stroke.id }
                }
                while planBytes + bytes > 16 * 1024 * 1024 || planOrder.count >= 64 {
                    guard !planOrder.isEmpty else { break }
                    let id = planOrder.removeFirst()
                    if let old = planCache.removeValue(forKey: id) { planBytes -= old.1.count * MemoryLayout<GPUStamp>.stride }
                }
                planCache[stroke.id] = (stroke, stamps); planOrder.append(stroke.id); planBytes += bytes
            }
        }
        lastStampCount += stamps.count
        guard !stamps.isEmpty else { return }
        let tileSize = 256, columns = (source.width + tileSize - 1) / tileSize
        let bins = try StrokePlanner.tileBins(stamps, width: source.width, height: source.height)
        let shape = try asset(stroke.brush, shape: true), grain = try asset(stroke.brush, shape: false)
        let secondary = stroke.brush.secondaryBrushes?.first
        let secondaryShape = try secondary.map { try asset($0, shape: true) } ?? shape
        let secondaryGrain = try secondary.map { try asset($0, shape: false) } ?? grain
        for key in bins.keys.sorted() {
            guard let values = bins[key], let encoder = command.makeComputeCommandEncoder() else { throw RenderError.command("tile encoder") }
            let buffer = values.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }
            guard let buffer else { encoder.endEncoding(); throw DocumentError.memoryBudget }
            let tileX = (key % columns) * tileSize, tileY = (key / columns) * tileSize
            var x = min(source.width, tileX + tileSize), y = min(source.height, tileY + tileSize)
            var right = tileX, bottom = tileY
            for stamp in values {
                let extent = stamp.geometry.z * 1.5
                x = min(x, max(tileX, Int(floor(stamp.geometry.x - extent))))
                y = min(y, max(tileY, Int(floor(stamp.geometry.y - extent))))
                right = max(right, min(min(source.width, tileX + tileSize), Int(ceil(stamp.geometry.x + extent))))
                bottom = max(bottom, min(min(source.height, tileY + tileSize), Int(ceil(stamp.geometry.y + extent))))
            }
            guard right > x, bottom > y else { encoder.endEncoding(); continue }
            var tile = TileInfo(origin: SIMD2(UInt32(x), UInt32(y)),
                                size: SIMD2(UInt32(right - x), UInt32(bottom - y)), count: UInt32(values.count))
            encoder.setTexture(source, index: 0); encoder.setTexture(target, index: 1)
            encoder.setTexture(shape, index: 2); encoder.setTexture(grain, index: 3); encoder.setTexture(pickup ?? source, index: 4)
            encoder.setTexture(secondaryShape, index: 5); encoder.setTexture(secondaryGrain, index: 6)
            encoder.setBuffer(buffer, offset: 0, index: 0); encoder.setBytes(&tile, length: MemoryLayout<TileInfo>.stride, index: 1)
            dispatch(encoder, pipeline: paintPipeline, width: Int(tile.size.x), height: Int(tile.size.y))
            encoder.endEncoding()
        }
    }

    private func copy(_ source: MTLTexture, to target: MTLTexture, command: MTLCommandBuffer) throws {
        guard let blit = command.makeBlitCommandEncoder() else { throw RenderError.command("cache copy") }
        blit.copy(from: source, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0,y: 0,z: 0),
                  sourceSize: MTLSize(width: source.width,height: source.height,depth: 1), to: target,
                  destinationSlice: 0, destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0,y: 0,z: 0))
        blit.endEncoding()
    }

    private func encodeLive(_ stroke: PaintStroke, revision: UInt64, stableSampleCount: Int?, predictions: [PencilSample], baseUnchanged: Bool,
                            layer: MTLTexture, command: MTLCommandBuffer) throws -> Bool {
        // An extra accumulation surface is optional; oversized existing documents retain replay support.
        if liveTexture == nil {
            let bytes = layer.width * layer.height * 8
            guard bytes * 6 <= Self.workingMemoryLimit else { return false }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: layer.width, height: layer.height, mipmapped: false)
            descriptor.usage = [.shaderRead, .shaderWrite]; descriptor.storageMode = .shared
            liveTexture = device.makeTexture(descriptor: descriptor)
        }
        guard let liveTexture else { return false }
        let stableCount = min(stroke.samples.count, max(0, stableSampleCount ?? stroke.samples.count))
        let reusable: Bool
        if let stream = liveStream, baseUnchanged, cachedLiveRevision == revision, stream.matches(stroke),
           stream.sampleCount <= stableCount {
            reusable = stream.sampleCount == 0 || stroke.samples[stream.sampleCount - 1] == stream.lastRawSample
        } else { reusable = false }
        if !reusable {
            liveStream = StrokePlanner.Stream(stroke)
            try copy(textures[4], to: liveTexture, command: command)
        }
        guard var stream = liveStream else { return false }
        let count = stream.sampleCount
        // Bound catch-up work per frame instead of allowing input backlog to make each frame slower.
        let end = min(stableCount, count + 32)
        let stamps = try stream.append(stroke.samples[count..<end])
        lastPlannedSampleCount += end - count
        hasPendingLiveSamples = end < stableCount
        // The immutable pre-stroke layer supplies wet pickup, while new stamps accumulate on previous ink.
        try copy(liveTexture, to: layer, command: command)
        try encode(stroke, finished: false, source: layer, target: liveTexture, pickup: textures[4], supplied: stamps, command: command)
        try copy(liveTexture, to: layer, command: command)
        liveStream = stream; cachedLiveRevision = revision
        if !hasPendingLiveSamples {
            var provisional = stream
            // A bounded recent tail can receive Pencil estimation updates without rebuilding old ink.
            var stamps = try provisional.append(stroke.samples[end...])
            lastPlannedSampleCount += stroke.samples.count - end
            stamps += try provisional.append(predictions[...])
            // Neither the recent tail nor predictions enter retained ink/random-generator state.
            try encode(stroke, finished: false, source: liveTexture, target: layer, pickup: textures[4], supplied: stamps, command: command)
        }
        return true
    }

    func render(_ document: DocumentContents, liveStroke: PaintStroke? = nil, finished: Bool = true, waitForCompletion: Bool = true, documentRevision: UInt64? = nil, liveSampleRevision: UInt64? = nil, liveStableSampleCount: Int? = nil, predictedSamples: [PencilSample] = []) throws -> MTLTexture {
        try allocate(width: document.width, height: document.height)
        var submitted = false
        defer { if !submitted { invalidateCache() } }
        guard let command = queue.makeCommandBuffer() else { throw RenderError.unavailable }
        var composite = textures[0], nextComposite = textures[1]
        var layer = textures[2], snapshot = textures[3]
        var background = document.background
        background.x = Self.linear(background.x) * background.w
        background.y = Self.linear(background.y) * background.w
        background.z = Self.linear(background.z) * background.w
        try clear(composite, color: background, command: command)
        lastStampCount = 0; lastPlannedSampleCount = 0; hasPendingLiveSamples = false
        if liveStroke == nil { liveStream = nil; cachedLiveRevision = nil }
        for value in document.layers where value.visible {
            try clear(layer, color: .zero, command: command)
            let selected = value.id == (document.selectedLayerID ?? document.layers.first?.id)
            var cacheIdentity = value
            cacheIdentity.adjustments = nil
            let sameRevision = documentRevision != nil && cachedDocumentRevision == documentRevision && cachedDocumentID == document.id
            let cacheHit = selected && cachedLayer?.id == value.id && (sameRevision || cachedLayer == cacheIdentity)
            if cacheHit { try copy(textures[4], to: layer, command: command) }
            var strokes = cacheHit ? [] : value.strokes
            if selected && !cacheHit, let cachedLayer, !cacheIdentity.strokes.isEmpty {
                var prefix = cacheIdentity
                let appended = prefix.strokes.removeLast()
                if prefix == cachedLayer {
                    try copy(textures[4], to: layer, command: command)
                    strokes = [appended]
                }
            }
            // Preserve committed pixels before adding the provisional live stroke.
            if !cacheHit {
            for stroke in strokes {
                guard let blit = command.makeBlitCommandEncoder() else { throw RenderError.command("snapshot") }
                blit.copy(from: layer, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                          sourceSize: MTLSize(width: layer.width, height: layer.height, depth: 1), to: snapshot, destinationSlice: 0,
                          destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                blit.endEncoding()
                var linearStroke = stroke
                linearStroke.color.x = Self.linear(stroke.color.x); linearStroke.color.y = Self.linear(stroke.color.y); linearStroke.color.z = Self.linear(stroke.color.z)
                try encode(linearStroke, finished: liveStroke?.id != stroke.id || finished, source: snapshot, target: layer, initialScratch: nextComposite, command: command)
            }
                if selected { try copy(layer, to: textures[4], command: command); cachedLayer = cacheIdentity }
            }
            if selected { cachedDocumentRevision = documentRevision; cachedDocumentID = document.id }
            strokes = selected ? liveStroke.map { [$0] } ?? [] : []
            for original in strokes {
                var stroke = original
                stroke.color.x = Self.linear(stroke.color.x); stroke.color.y = Self.linear(stroke.color.y); stroke.color.z = Self.linear(stroke.color.z)
                if !finished, let liveSampleRevision, stroke.distanceDynamicsVersion == 1, stroke.samples.count >= 2,
                   try encodeLive(stroke, revision: liveSampleRevision, stableSampleCount: liveStableSampleCount, predictions: predictedSamples,
                                  baseUnchanged: cacheHit, layer: layer, command: command) { continue }
                liveStream = nil; cachedLiveRevision = nil
                stroke.samples.append(contentsOf: predictedSamples)
                guard let blit = command.makeBlitCommandEncoder() else { throw RenderError.command("snapshot") }
                blit.copy(from: layer, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                          sourceSize: MTLSize(width: layer.width, height: layer.height, depth: 1), to: snapshot, destinationSlice: 0,
                          destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                blit.endEncoding()
                try encode(stroke, finished: finished, source: snapshot, target: layer, initialScratch: nextComposite, command: command)
            }
            var filteredLayer = layer
            if let values = value.adjustments, !values.isEmpty {
                try adjustments.apply(values, source: layer, target: snapshot, command: command)
                filteredLayer = snapshot
            }
            guard let encoder = command.makeComputeCommandEncoder() else { throw RenderError.command("compositing") }
            var options = SIMD2<Float>(value.opacity, Float(value.blendMode))
            encoder.setTexture(composite, index: 0); encoder.setTexture(filteredLayer, index: 1); encoder.setTexture(nextComposite, index: 2)
            encoder.setBytes(&options, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            dispatch(encoder, pipeline: compositePipeline, width: document.width, height: document.height); encoder.endEncoding()
            swap(&composite, &nextComposite)
        }
        if !waitForCompletion {
            command.addCompletedHandler { [weak self] result in
                if result.status == .error { Task { @MainActor [weak self] in self?.invalidateCache() } }
            }
        }
        command.commit(); submitted = true
        if waitForCompletion { command.waitUntilCompleted() }
        if command.status == .error { invalidateCache(); throw RenderError.command(command.error?.localizedDescription ?? "GPU") }
        return composite
    }

    func hasBakedSample(strokeID: UUID, index: Int) -> Bool {
        guard let liveStream else { return false }
        return liveStream.strokeID == strokeID && index < liveStream.sampleCount
    }

    func invalidateCache() { cachedLayer = nil; cachedDocumentRevision = nil; cachedDocumentID = nil; liveStream = nil; cachedLiveRevision = nil; hasPendingLiveSamples = false }

    func image(_ contents: DocumentContents) throws -> UIImage {
        let texture = try render(contents)
        var bytes = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        bytes.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 8, from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0)
        }
        var rgba = [UInt8](repeating: 0, count: bytes.count)
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Float(Float16(bitPattern: bytes[i + 3]))
            for c in 0..<3 {
                let premul = Float(Float16(bitPattern: bytes[i + c]))
                rgba[i + c] = UInt8(max(0, min(255, Self.sRGB(alpha > 0 ? premul / alpha : 0) * alpha * 255)).rounded())
            }
            rgba[i + 3] = UInt8(max(0, min(255, alpha * 255)).rounded())
        }
        let data = Data(rgba) as CFData
        guard let provider = CGDataProvider(data: data),
              let image = CGImage(width: texture.width, height: texture.height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: texture.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                                  decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { throw RenderError.command("PNG") }
        return UIImage(cgImage: image)
    }
    private static func linear(_ v: Float) -> Float { v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
    private static func sRGB(_ v: Float) -> Float { v <= 0.0031308 ? v * 12.92 : 1.055 * pow(v, 1 / 2.4) - 0.055 }
}
