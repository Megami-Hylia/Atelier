import Foundation
import Combine
import simd

enum PaintTool: String, Codable, CaseIterable { case paint, smudge, erase }

struct PencilSample: Codable, Equatable {
    var x: Float
    var y: Float
    var pressure: Float = 1
    var altitude: Float = .pi / 2
    var azimuth: Float = 0
    var roll: Float = 0
    var time: Double = 0
    var isPencil: Bool = true

    static func demo(width: Float, height: Float, count: Int = 100) -> [PencilSample] {
        (0..<count).map { i in
            let t = Float(i) / Float(max(1, count - 1))
            return PencilSample(x: width * (0.08 + t * 0.84),
                               y: height * (0.5 + 0.2 * sin(t * .pi * 3)),
                               pressure: 0.15 + 0.85 * sin(t * .pi), altitude: 0.65 + t * 0.7,
                               azimuth: t * .pi, roll: t * .pi / 3, time: Double(t))
        }
    }
}

struct PaintStroke: Codable, Identifiable, Equatable {
    var id = UUID()
    var brush: BrushPreset
    var tool: PaintTool
    var color: SIMD4<Float>
    var size: Float
    var opacity: Float
    var samples: [PencilSample]
    var seed: UInt64
}

struct PaintLayer: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var visible = true
    var locked = false
    var opacity: Float = 1
    var blendMode = 0
    var adjustments: [String: Float]? = nil
    var strokes: [PaintStroke] = []
}

struct DocumentContents: Codable, Equatable {
    var formatVersion = 1
    var id = UUID()
    var name = "Senza titolo"
    var width: Int
    var height: Int
    var dpi = 132
    var colorSpace = "sRGB"
    var background = SIMD4<Float>(1, 1, 1, 1)
    var layers = [PaintLayer(name: "Livello 1")]
    var selectedLayerID: UUID?

    func validate() throws {
        guard formatVersion == 1 else { throw DocumentError.unsupportedVersion }
        guard width >= 64, height >= 64, width <= 4096, height <= 4096,
              width * height * 40 <= 384 * 1024 * 1024, !layers.isEmpty, layers.count <= 32,
              colorSpace == "sRGB", (36...1200).contains(dpi),
              [background.x, background.y, background.z, background.w].allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              Set(layers.map(\.id)).count == layers.count else { throw DocumentError.invalidData }
        guard selectedLayerID == nil || layers.contains(where: { $0.id == selectedLayerID }) else { throw DocumentError.invalidData }
        guard layers.allSatisfy({ layer in
            (layer.adjustments ?? [:]).allSatisfy { key, value in value.isFinite && abs(value) <= 64 } && layer.opacity.isFinite && (0...1).contains(layer.opacity) && (0...2).contains(layer.blendMode) &&
            layer.strokes.allSatisfy { stroke in
                !stroke.samples.isEmpty && stroke.samples.count <= 1_000_000 &&
                stroke.size.isFinite && (0.1...2048).contains(stroke.size) && stroke.opacity.isFinite && (0...1).contains(stroke.opacity) &&
                [stroke.color.x, stroke.color.y, stroke.color.z, stroke.color.w].allSatisfy { $0.isFinite && (0...1).contains($0) } &&
                stroke.brush.parameters.values.allSatisfy(\.isFinite) &&
                stroke.samples.allSatisfy { s in
                    [s.x, s.y, s.pressure, s.altitude, s.azimuth, s.roll].allSatisfy(\.isFinite) && s.time.isFinite &&
                    abs(s.x) <= 32768 && abs(s.y) <= 32768 && (0...1).contains(s.pressure)
                }
            }
        }) else { throw DocumentError.invalidData }
    }
}

enum DocumentError: LocalizedError {
    case unsupportedVersion, invalidData, lockedLayer, memoryBudget, tooLarge, strokeBudget
    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: return "Versione del documento non supportata."
        case .invalidData: return "Il documento contiene dati non validi."
        case .lockedLayer: return "Il livello selezionato è bloccato."
        case .memoryBudget: return "Memoria grafica insufficiente. Riduci le dimensioni del canvas."
        case .tooLarge: return "Il file supera il limite di sicurezza di 128 MB."
        case .strokeBudget: return "Il tratto supera il budget di rendering. Annullalo o riduci dimensione, conteggio o densità delle impronte."
        }
    }
}

@MainActor final class PaintDocument: ObservableObject {
    @Published private(set) var contents: DocumentContents
    @Published private(set) var revision: UInt64 = 0
    @Published var errorMessage: String?
    private var undoStates: [DocumentContents] = []
    private var redoStates: [DocumentContents] = []
    var storageURL: URL?
    var canUndo: Bool { !undoStates.isEmpty }
    var canRedo: Bool { !redoStates.isEmpty }
    var selectedLayer: PaintLayer { contents.layers.first { $0.id == contents.selectedLayerID } ?? contents.layers[0] }

    init(width: Int = 1024, height: Int = 768) {
        contents = DocumentContents(width: min(4096, max(64, width)), height: min(4096, max(64, height)))
        contents.selectedLayerID = contents.layers[0].id
    }

    func change(_ body: (inout DocumentContents) -> Void) {
        let previous = contents
        var candidate = previous
        body(&candidate)
        do { try candidate.validate() } catch { errorMessage = error.localizedDescription; return }
        guard candidate != previous else { return }
        undoStates.append(previous)
        if undoStates.count > 100 { undoStates.removeFirst() }
        redoStates.removeAll()
        contents = candidate
        revision &+= 1
        autosave()
    }

    func commit(_ stroke: PaintStroke) {
        guard !stroke.samples.isEmpty else { return }
        guard !selectedLayer.locked else { errorMessage = DocumentError.lockedLayer.localizedDescription; return }
        do {
            _ = try StrokePlanner.tileBins(StrokePlanner.stamps(for: stroke), width: contents.width, height: contents.height)
        } catch { errorMessage = error.localizedDescription; return }
        let id = selectedLayer.id
        change { value in
            guard let index = value.layers.firstIndex(where: { $0.id == id }) else { return }
            value.layers[index].strokes.append(stroke)
        }
    }

    func undo() {
        guard let state = undoStates.popLast() else { return }
        redoStates.append(contents); contents = state; revision &+= 1; autosave()
    }
    func redo() {
        guard let state = redoStates.popLast() else { return }
        undoStates.append(contents); contents = state; revision &+= 1; autosave()
    }
    func selectLayer(_ id: UUID) {
        guard contents.layers.contains(where: { $0.id == id }) else { return }
        contents.selectedLayerID = id
        revision &+= 1
        autosave()
    }
    func addLayer() {
        guard contents.layers.count < 32 else { errorMessage = "Limite di 32 livelli raggiunto."; return }
        change { c in
            let layer = PaintLayer(name: "Livello \(c.layers.count + 1)")
            c.layers.append(layer); c.selectedLayerID = layer.id
        }
    }
    func duplicateLayer(_ id: UUID) {
        guard contents.layers.count < 32, let source = contents.layers.first(where: { $0.id == id }) else { return }
        change { c in
            var copy = source; copy.id = UUID(); copy.name += " copia"
            c.layers.append(copy); c.selectedLayerID = copy.id
        }
    }
    func deleteLayer(_ id: UUID) {
        guard contents.layers.count > 1 else { return }
        change { c in c.layers.removeAll { $0.id == id }; c.selectedLayerID = c.layers.last?.id }
    }
    func clearLayer() {
        guard !selectedLayer.locked else { return }
        let id = selectedLayer.id
        change { c in c.layers[c.layers.firstIndex(where: { $0.id == id }) ?? 0].strokes.removeAll() }
    }
    func clear() { clearLayer() }
    func refine(strokeID: UUID, sampleIndex: Int, sample: PencilSample) {
        func update(_ value: inout DocumentContents) {
            for layer in value.layers.indices {
                guard let index = value.layers[layer].strokes.firstIndex(where: { $0.id == strokeID }),
                      value.layers[layer].strokes[index].samples.indices.contains(sampleIndex) else { continue }
                value.layers[layer].strokes[index].samples[sampleIndex] = sample
            }
        }
        update(&contents)
        for i in undoStates.indices { update(&undoStates[i]) }
        for i in redoStates.indices { update(&redoStates[i]) }
        revision &+= 1; autosave()
    }

    func save(to url: URL) throws {
        try contents.validate()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(contents)
        guard data.count <= 128 * 1024 * 1024 else { throw DocumentError.tooLarge }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let old = try Data(contentsOf: url)
            try old.write(to: url.appendingPathExtension("recovery"), options: .atomic)
        }
        try data.write(to: url, options: .atomic)
        storageURL = url
    }
    func load(from url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size <= 128 * 1024 * 1024 else { throw DocumentError.tooLarge }
        let loaded = try JSONDecoder().decode(DocumentContents.self, from: Data(contentsOf: url))
        try loaded.validate()
        for layer in loaded.layers { for stroke in layer.strokes {
            _ = try StrokePlanner.tileBins(StrokePlanner.stamps(for: stroke), width: loaded.width, height: loaded.height)
        } }
        contents = loaded; storageURL = url; undoStates = []; redoStates = []; revision &+= 1
    }
    private func autosave() {
        guard let storageURL else { return }
        do { try save(to: storageURL) } catch { errorMessage = "Salvataggio fallito: \(error.localizedDescription)" }
    }
}

@MainActor final class GalleryStore: ObservableObject {
    @Published var urls: [URL] = []
    @Published var errorMessage: String?
    let folder: URL
    init() {
        folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Artworks", isDirectory: true)
        refresh()
    }
    func refresh() {
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            urls = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])
                .filter { $0.pathExtension == "atelier" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch { errorMessage = error.localizedDescription }
    }
    func create(width: Int, height: Int, name: String) throws -> PaintDocument {
        let document = PaintDocument(width: width, height: height)
        document.change { $0.name = name.isEmpty ? "Senza titolo" : name }
        try document.save(to: folder.appendingPathComponent(document.contents.id.uuidString).appendingPathExtension("atelier"))
        refresh(); return document
    }
}
