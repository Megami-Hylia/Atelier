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
    private let loader: MTKTextureLoader
    private var textures: [MTLTexture] = []
    private var assetCache: [String: MTLTexture] = [:]
    private(set) var lastStampCount = 0
    static let workingMemoryLimit = 384 * 1024 * 1024

    init() throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue(),
              let library = device.makeDefaultLibrary() else { throw RenderError.unavailable }
        self.device = device; self.queue = queue; loader = MTKTextureLoader(device: device)
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
              width * height * 8 * 4 <= Self.workingMemoryLimit else { throw DocumentError.memoryBudget }
        if textures.count == 4, textures.first?.width == width && textures.first?.height == height { return }
        var allocated: [MTLTexture] = []
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba16Float, width: width, height: height, mipmapped: false)
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .shared
        for _ in 0..<4 {
            guard let texture = device.makeTexture(descriptor: descriptor) else { throw DocumentError.memoryBudget }
            allocated.append(texture)
        }
        textures = allocated
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
        if data == nil, let texture = assetCache[key] { return texture }
        let texture: MTLTexture
        if let data {
            guard let image = UIImage(data: data), image.size.width <= 2048, image.size.height <= 2048,
                  let cgImage = image.cgImage else { throw RenderError.asset(key) }
            texture = try loader.newTexture(cgImage: cgImage, options: [.SRGB: false, .generateMipmaps: false])
        } else {
            guard let url = Bundle.main.url(forResource: key, withExtension: "png") else { throw RenderError.asset(key) }
            texture = try loader.newTexture(URL: url, options: [.SRGB: false, .generateMipmaps: false])
            assetCache[key] = texture
        }
        return texture
    }

    // The CPU bins stamps into 256-pixel tiles; pixels remain in global canvas coordinates.
    // No texture coordinate restarts at tile borders, including pickup and grain.
    private func encode(_ stroke: PaintStroke, finished: Bool, source: MTLTexture, target: MTLTexture, command: MTLCommandBuffer) throws {
        let stamps = try StrokePlanner.stamps(for: stroke, finished: finished)
        lastStampCount += stamps.count
        guard !stamps.isEmpty else { return }
        let tileSize = 256, columns = (source.width + tileSize - 1) / tileSize
        let bins = try StrokePlanner.tileBins(stamps, width: source.width, height: source.height)
        let shape = try asset(stroke.brush, shape: true), grain = try asset(stroke.brush, shape: false)
        for key in bins.keys.sorted() {
            guard let values = bins[key], let encoder = command.makeComputeCommandEncoder() else { throw RenderError.command("tile encoder") }
            let buffer = values.withUnsafeBytes { device.makeBuffer(bytes: $0.baseAddress!, length: $0.count, options: .storageModeShared) }
            guard let buffer else { encoder.endEncoding(); throw DocumentError.memoryBudget }
            let x = (key % columns) * tileSize, y = (key / columns) * tileSize
            var tile = TileInfo(origin: SIMD2(UInt32(x), UInt32(y)),
                                size: SIMD2(UInt32(min(tileSize, source.width - x)), UInt32(min(tileSize, source.height - y))), count: UInt32(values.count))
            encoder.setTexture(source, index: 0); encoder.setTexture(target, index: 1)
            encoder.setTexture(shape, index: 2); encoder.setTexture(grain, index: 3)
            encoder.setBuffer(buffer, offset: 0, index: 0); encoder.setBytes(&tile, length: MemoryLayout<TileInfo>.stride, index: 1)
            dispatch(encoder, pipeline: paintPipeline, width: Int(tile.size.x), height: Int(tile.size.y))
            encoder.endEncoding()
        }
    }

    func render(_ document: DocumentContents, liveStroke: PaintStroke? = nil, finished: Bool = true) throws -> MTLTexture {
        try allocate(width: document.width, height: document.height)
        guard let command = queue.makeCommandBuffer() else { throw RenderError.unavailable }
        var composite = textures[0], nextComposite = textures[1]
        var layer = textures[2], snapshot = textures[3]
        var background = document.background
        background.x = Self.linear(background.x) * background.w
        background.y = Self.linear(background.y) * background.w
        background.z = Self.linear(background.z) * background.w
        try clear(composite, color: background, command: command)
        lastStampCount = 0
        for value in document.layers where value.visible {
            try clear(layer, color: .zero, command: command)
            var strokes = value.strokes
            if value.id == (document.selectedLayerID ?? document.layers.first?.id), let liveStroke { strokes.append(liveStroke) }
            for stroke in strokes {
                guard let blit = command.makeBlitCommandEncoder() else { throw RenderError.command("snapshot") }
                blit.copy(from: layer, sourceSlice: 0, sourceLevel: 0, sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                          sourceSize: MTLSize(width: layer.width, height: layer.height, depth: 1), to: snapshot, destinationSlice: 0,
                          destinationLevel: 0, destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0))
                blit.endEncoding()
                var linearStroke = stroke
                linearStroke.color.x = Self.linear(stroke.color.x); linearStroke.color.y = Self.linear(stroke.color.y); linearStroke.color.z = Self.linear(stroke.color.z)
                try encode(linearStroke, finished: liveStroke?.id != stroke.id || finished, source: snapshot, target: layer, command: command)
            }
            guard let encoder = command.makeComputeCommandEncoder() else { throw RenderError.command("compositing") }
            var options = SIMD2<Float>(value.opacity, Float(value.blendMode))
            encoder.setTexture(composite, index: 0); encoder.setTexture(layer, index: 1); encoder.setTexture(nextComposite, index: 2)
            encoder.setBytes(&options, length: MemoryLayout<SIMD2<Float>>.stride, index: 0)
            dispatch(encoder, pipeline: compositePipeline, width: document.width, height: document.height); encoder.endEncoding()
            swap(&composite, &nextComposite)
        }
        command.commit(); command.waitUntilCompleted()
        if command.status == .error { throw RenderError.command(command.error?.localizedDescription ?? "GPU") }
        return composite
    }

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
