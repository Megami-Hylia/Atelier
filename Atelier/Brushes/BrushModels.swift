import Foundation
import Combine
import SwiftUI
import ImageIO

struct BrushPreset: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var setID: String
    var shape: String
    var grain: String
    var seed: UInt64
    var parameters: [String: Double]
    var shapeData: Data? = nil
    var grainData: Data? = nil
    var author: String? = "Atelier"
    var notes: String? = nil
    var secondaryBrushes: [BrushPreset]? = nil
    var combineMode: Int? = nil

    func value(_ key: String, _ fallback: Double = 0) -> Double {
        parameters[key] ?? fallback
    }

    static let fallback = BrushPreset(id: "fallback", name: "Round", setID: "basics", shape: "round", grain: "none", seed: 1, parameters: ["spacing": 0.08, "flow": 1, "opacity": 1, "pressureSize": 0.6, "roundness": 1])
}

struct BrushSet: Codable, Identifiable, Equatable {
    var id: String
    var libraryID: String
    var name: String
}

struct BrushLibrary: Codable, Identifiable, Equatable {
    var id: String
    var name: String
}

struct BrushArchive: Codable, Equatable {
    var schemaVersion = 1
    var libraries: [BrushLibrary]
    var sets: [BrushSet]
    var brushes: [BrushPreset]
    var recentIDs: [String] = []
    var selectedID: String? = nil
    var favoriteIDs: [String]? = nil
    var resetPoints: [String: BrushPreset]? = nil
}

enum BrushArchiveError: LocalizedError {
    case invalid(String)
    var errorDescription: String? {
        switch self { case .invalid(let reason): return reason }
    }
}

@MainActor
final class BrushStore: ObservableObject {
    @Published private(set) var libraries: [BrushLibrary] = []
    @Published private(set) var sets: [BrushSet] = []
    @Published private(set) var brushes: [BrushPreset] = []
    @Published private(set) var recentIDs: [String] = []
    @Published private(set) var resetPoints: [String: BrushPreset] = [:]
    @Published private(set) var favoriteIDs: [String] = []
    @Published var selectedID: String = ""
    @Published var selectedLibraryID: String = "atelier"
    @Published var selectedSetID: String = "pencils"
    @Published var errorMessage: String?
    private let storageURL: URL
    private var factory: BrushArchive?
    private var durableArchive: BrushArchive?
    private var recoveryCopyFailed = false

    var selectedBrush: BrushPreset { brushes.first { $0.id == selectedID } ?? brushes.first ?? .fallback }
    var recentBrushes: [BrushPreset] { recentIDs.compactMap { id in brushes.first { $0.id == id } } }

    init(storageURL: URL? = nil, catalog: BrushArchive? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Atelier", isDirectory: true)
        self.storageURL = storageURL ?? base.appendingPathComponent("BrushLibrary.json")
        do {
            let original: BrushArchive
            if let catalog { original = catalog }
            else {
                guard let url = Bundle.main.url(forResource: "BrushCatalog", withExtension: "json") else {
                    throw BrushArchiveError.invalid("Catalogo dei pennelli non trovato nel bundle.")
                }
                original = try JSONDecoder().decode(BrushArchive.self, from: Data(contentsOf: url))
            }
            try Self.validate(original)
            factory = original
            apply(original)
            if FileManager.default.fileExists(atPath: self.storageURL.path) {
                let stored = try JSONDecoder().decode(BrushArchive.self, from: Data(contentsOf: self.storageURL))
                try Self.validate(stored)
                apply(stored)
            }
        } catch {
            // Preserve damaged files; never overwrite recovery evidence with factory defaults.
            if FileManager.default.fileExists(atPath: self.storageURL.path) {
                let backup = self.storageURL.appendingPathExtension("recovery-\(UUID().uuidString)")
                do { try FileManager.default.copyItem(at: self.storageURL, to: backup) }
                catch { recoveryCopyFailed = true }
            }
            errorMessage = "Caricamento pennelli: \(error.localizedDescription). Il file esistente è conservato."
        }
        if !brushes.isEmpty { durableArchive = archive }
    }

    private func apply(_ archive: BrushArchive) {
        libraries = archive.libraries; sets = archive.sets; brushes = archive.brushes
        resetPoints = archive.resetPoints ?? [:]
        favoriteIDs = (archive.favoriteIDs ?? []).filter { id in brushes.contains { $0.id == id } }
        recentIDs = archive.recentIDs.filter { id in brushes.contains { $0.id == id } }
        selectedID = archive.selectedID.flatMap { id in brushes.contains { $0.id == id } ? id : nil } ?? brushes.first?.id ?? ""
        if let set = sets.first(where: { $0.id == selectedBrush.setID }) {
            selectedLibraryID = set.libraryID; selectedSetID = set.id
        }
    }

    var archive: BrushArchive {
        BrushArchive(libraries: libraries, sets: sets, brushes: brushes, recentIDs: recentIDs, selectedID: selectedID, favoriteIDs: favoriteIDs, resetPoints: resetPoints)
    }

    static func validate(_ archive: BrushArchive) throws {
        guard archive.schemaVersion == 1 else { throw BrushArchiveError.invalid("Versione libreria non supportata.") }
        guard archive.brushes.count <= 10_000, archive.sets.count <= 1_000, archive.libraries.count <= 100 else { throw BrushArchiveError.invalid("La libreria supera i limiti di sicurezza.") }
        guard !archive.sets.isEmpty, !archive.libraries.isEmpty else { throw BrushArchiveError.invalid("La libreria deve contenere almeno un set e una raccolta.") }
        guard Set(archive.brushes.map(\.id)).count == archive.brushes.count,
              Set(archive.sets.map(\.id)).count == archive.sets.count,
              Set(archive.libraries.map(\.id)).count == archive.libraries.count else { throw BrushArchiveError.invalid("Identificatori duplicati nella libreria.") }
        let points = archive.resetPoints ?? [:]
        guard points.count <= archive.brushes.count else { throw BrushArchiveError.invalid("Troppi punti di ripristino.") }
        for (id, point) in points {
            guard id == point.id, let current = archive.brushes.first(where: { $0.id == id }) else {
                throw BrushArchiveError.invalid("Punto di ripristino senza pennello valido.")
            }
            var candidate = point; candidate.setID = current.setID
            try validate(BrushArchive(libraries: archive.libraries, sets: archive.sets, brushes: [candidate]))
        }
        let favorites = archive.favoriteIDs ?? []
        guard favorites.count <= archive.brushes.count, Set(favorites).count == favorites.count,
              favorites.allSatisfy({ id in archive.brushes.contains { $0.id == id } }) else {
            throw BrushArchiveError.invalid("Preferiti non validi nella libreria.")
        }
        for set in archive.sets {
            guard archive.libraries.contains(where: { $0.id == set.libraryID }), !set.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw BrushArchiveError.invalid("Set senza raccolta valida o senza nome.") }
        }
        for brush in archive.brushes {
            let components = brush.secondaryBrushes ?? []
            guard components.count <= 1, (0...2).contains(brush.combineMode ?? 0), components.allSatisfy({ ($0.secondaryBrushes ?? []).isEmpty }) else { throw BrushArchiveError.invalid("Un pennello combinato richiede due componenti semplici.") }
            for var component in components {
                component.setID = brush.setID
                try validate(BrushArchive(libraries: archive.libraries, sets: archive.sets, brushes: [component]))
            }
            guard archive.sets.contains(where: { $0.id == brush.setID }), !brush.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  brush.name.count <= 200, brush.parameters.count <= 512,
                  brush.parameters.values.allSatisfy({ $0.isFinite && abs($0) <= 100_000 }),
                  (brush.shapeData?.count ?? 0) <= 8_000_000, (brush.grainData?.count ?? 0) <= 8_000_000 else { throw BrushArchiveError.invalid("Configurazione pennello non valida.") }
            guard ["round", "soft", "flat", "bristle", "fleck", "chisel"].contains(brush.shape),
                  ["none", "paper", "canvas", "charcoal", "wash", "noise"].contains(brush.grain) else { throw BrushArchiveError.invalid("Forma o grana sconosciuta.") }
            for data in [brush.shapeData, brush.grainData].compactMap({ $0 }) {
                guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                      CGImageSourceGetCount(source) == 1,
                      let type = CGImageSourceGetType(source), type as String == "public.png",
                      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                      let width = properties[kCGImagePropertyPixelWidth] as? Int,
                      let height = properties[kCGImagePropertyPixelHeight] as? Int,
                      (1...512).contains(width), (1...512).contains(height) else {
                    throw BrushArchiveError.invalid("Sorgente importata non valida: serve un PNG singolo entro 512 × 512 pixel.")
                }
            }
            for descriptor in BrushParameter.all {
                if let value = brush.parameters[descriptor.id], !descriptor.range.contains(value) {
                    throw BrushArchiveError.invalid("Parametro fuori intervallo: \(descriptor.title).")
                }
            }
            guard brush.value("minSize") <= brush.value("maxSize", 1),
                  brush.value("minOpacity") <= brush.value("maxOpacity", 1) else {
                throw BrushArchiveError.invalid("Il minimo del pennello non può superare il massimo.")
            }
        }
    }

    func persist() {
        do {
            guard !recoveryCopyFailed else { throw BrushArchiveError.invalid("Impossibile conservare una copia di recupero del file precedente. Salvataggio bloccato per proteggerlo.") }
            try Self.validate(archive)
            try FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(archive).write(to: storageURL, options: .atomic)
            durableArchive = archive
            errorMessage = nil
        } catch {
            if let durableArchive { apply(durableArchive) }
            errorMessage = "Salvataggio pennelli annullato: \(error.localizedDescription)"
        }
    }

    func deleteBrushes(_ ids: [String]) {
        let deleting = Set(ids)
        guard brushes.contains(where: { !deleting.contains($0.id) }) else { errorMessage = "Conserva almeno un pennello."; return }
        brushes.removeAll { deleting.contains($0.id) }
        recentIDs.removeAll { deleting.contains($0) }; favoriteIDs.removeAll { deleting.contains($0) }
        resetPoints = resetPoints.filter { !deleting.contains($0.key) }
        if deleting.contains(selectedID) { selectedID = brushes[0].id }
        persist()
    }

    @discardableResult func combine(_ ids: [String]) -> BrushPreset? {
        guard ids.count == 2, ids[0] != ids[1],
              let primary = brushes.first(where: { $0.id == ids[0] }),
              let secondary = brushes.first(where: { $0.id == ids[1] }),
              (primary.secondaryBrushes ?? []).isEmpty, (secondary.secondaryBrushes ?? []).isEmpty else {
            errorMessage = "Seleziona due pennelli semplici per combinarli."; return nil
        }
        var combined = primary
        combined.id = UUID().uuidString; combined.name = primary.name + " + " + secondary.name
        combined.name = String(combined.name.prefix(200))
        combined.secondaryBrushes = [secondary]; combined.combineMode = 0
        insert(combined)
        return errorMessage == nil ? combined : nil
    }

    func saveResetPoint(_ brush: BrushPreset) {
        guard let current = brushes.first(where: { $0.id == brush.id }) else { return }
        resetPoints[brush.id] = current; persist()
    }

    func restoreResetPoint(_ brush: BrushPreset) {
        guard var point = resetPoints[brush.id], let current = brushes.first(where: { $0.id == brush.id }) else { return }
        point.setID = current.setID; save(point)
    }

    func toggleFavorite(_ brush: BrushPreset) {
        guard brushes.contains(where: { $0.id == brush.id }) else { return }
        if favoriteIDs.contains(brush.id) { favoriteIDs.removeAll { $0 == brush.id } }
        else { favoriteIDs.append(brush.id) }
        persist()
    }

    func select(_ brush: BrushPreset) {
        selectedID = brush.id
        recentIDs.removeAll { $0 == brush.id }; recentIDs.insert(brush.id, at: 0)
        recentIDs = Array(recentIDs.prefix(32)); persist()
    }

    func save(_ brush: BrushPreset) {
        guard let index = brushes.firstIndex(where: { $0.id == brush.id }) else { return }
        let previous = brushes[index]; brushes[index] = brush
        do { try Self.validate(archive); persist() }
        catch { brushes[index] = previous; errorMessage = error.localizedDescription }
    }

    func insert(_ brush: BrushPreset) {
        var candidate = archive; candidate.brushes.append(brush)
        do { try Self.validate(candidate); brushes.append(brush); select(brush) }
        catch { errorMessage = error.localizedDescription }
    }

    @discardableResult func createBrush(in setID: String) -> BrushPreset {
        var brush = BrushPreset.fallback
        brush.id = UUID().uuidString; brush.name = "Nuovo pennello"; brush.setID = setID
        brush.seed = UInt64.random(in: 1...UInt64.max)
        brushes.append(brush); select(brush); return brush
    }

    @discardableResult func duplicate(_ brush: BrushPreset) -> BrushPreset {
        var copy = brush; copy.id = UUID().uuidString; copy.name += " copia"
        let index = brushes.firstIndex(where: { $0.id == brush.id }) ?? brushes.count - 1
        brushes.insert(copy, at: min(index + 1, brushes.count)); select(copy); return copy
    }

    func renameBrush(_ brush: BrushPreset, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard var copy = brushes.first(where: { $0.id == brush.id }) else { return }
        copy.name = trimmed; save(copy)
    }

    func deleteBrush(_ brush: BrushPreset) {
        guard brushes.count > 1 else { errorMessage = "Conserva almeno un pennello."; return }
        brushes.removeAll { $0.id == brush.id }; recentIDs.removeAll { $0 == brush.id }; favoriteIDs.removeAll { $0 == brush.id }
        resetPoints.removeValue(forKey: brush.id)
        if selectedID == brush.id { selectedID = brushes[0].id }; persist()
    }

    func moveBrush(_ brush: BrushPreset, to setID: String) {
        guard sets.contains(where: { $0.id == setID }) else { return }
        guard var copy = brushes.first(where: { $0.id == brush.id }) else { return }
        copy.setID = setID; save(copy)
    }

    func moveBrushes(in setID: String, from offsets: IndexSet, to destination: Int) {
        var subset = brushes.filter { $0.setID == setID }
        subset.move(fromOffsets: offsets, toOffset: destination)
        var iterator = subset.makeIterator()
        brushes = brushes.map { $0.setID == setID ? iterator.next()! : $0 }
        persist()
    }

    @discardableResult func createSet(name: String, libraryID: String) -> BrushSet {
        let set = BrushSet(id: UUID().uuidString, libraryID: libraryID, name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Nuovo set" : name)
        sets.append(set); selectedSetID = set.id; persist(); return set
    }

    func renameSet(_ set: BrushSet, to name: String) {
        guard let index = sets.firstIndex(where: { $0.id == set.id }), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        sets[index].name = name; persist()
    }

    func duplicateSet(_ set: BrushSet) {
        let copy = BrushSet(id: UUID().uuidString, libraryID: set.libraryID, name: set.name + " copia")
        let originals = brushes.filter { $0.setID == set.id }
        sets.append(copy)
        for var brush in originals { brush.id = UUID().uuidString; brush.setID = copy.id; brushes.append(brush) }
        selectedSetID = copy.id; persist()
    }

    func deleteSet(_ set: BrushSet) {
        guard sets.count > 1, let destination = sets.first(where: { $0.id != set.id }) else { return }
        for index in brushes.indices where brushes[index].setID == set.id { brushes[index].setID = destination.id }
        sets.removeAll { $0.id == set.id }; selectedSetID = destination.id; selectedLibraryID = destination.libraryID; persist()
    }

    func moveSets(in libraryID: String, from offsets: IndexSet, to destination: Int) {
        var subset = sets.filter { $0.libraryID == libraryID }; subset.move(fromOffsets: offsets, toOffset: destination)
        var iterator = subset.makeIterator(); sets = sets.map { $0.libraryID == libraryID ? iterator.next()! : $0 }; persist()
    }

    func createLibrary(name: String) {
        let library = BrushLibrary(id: UUID().uuidString, name: name.isEmpty ? "Nuova libreria" : name)
        libraries.append(library); selectedLibraryID = library.id
        _ = createSet(name: "Personali", libraryID: library.id)
    }

    func renameLibrary(_ library: BrushLibrary, to name: String) {
        guard let index = libraries.firstIndex(where: { $0.id == library.id }), !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        libraries[index].name = name; persist()
    }

    func deleteLibrary(_ library: BrushLibrary) {
        guard libraries.count > 1, let destination = libraries.first(where: { $0.id != library.id }), let set = sets.first(where: { $0.libraryID == destination.id }) else { return }
        let deleted = Set(sets.filter { $0.libraryID == library.id }.map(\.id))
        for index in brushes.indices where deleted.contains(brushes[index].setID) { brushes[index].setID = set.id }
        sets.removeAll { $0.libraryID == library.id }; libraries.removeAll { $0.id == library.id }
        selectedLibraryID = destination.id; selectedSetID = set.id; persist()
    }

    func reset(_ brush: BrushPreset) {
        guard let original = factory?.brushes.first(where: { $0.id == brush.id }) else { return }
        save(original)
    }

    func factoryVersion(of brush: BrushPreset) -> BrushPreset? { factory?.brushes.first { $0.id == brush.id } }

    func restoreFactoryPresets() {
        guard let original = factory else { return }
        for library in original.libraries where !libraries.contains(where: { $0.id == library.id }) { libraries.append(library) }
        for set in original.sets where !sets.contains(where: { $0.id == set.id }) { sets.append(set) }
        for brush in original.brushes {
            if let index = brushes.firstIndex(where: { $0.id == brush.id }) { brushes[index] = brush }
            else { brushes.append(brush) }
        }
        persist()
    }

    func exportData(brush: BrushPreset? = nil, libraryID: String? = nil, setID: String? = nil) throws -> Data {
        var result = archive
        if let brush {
            result.brushes = [brush]; result.sets = sets.filter { $0.id == brush.setID }
            result.libraries = libraries.filter { library in result.sets.contains { $0.libraryID == library.id } }
        } else if let setID {
            result.sets = sets.filter { $0.id == setID }; result.brushes = brushes.filter { $0.setID == setID }
            result.libraries = libraries.filter { library in result.sets.contains { $0.libraryID == library.id } }
        } else if let libraryID {
            result.libraries = libraries.filter { $0.id == libraryID }; result.sets = sets.filter { $0.libraryID == libraryID }
            result.brushes = brushes.filter { brush in result.sets.contains { $0.id == brush.setID } }
        }
        result.resetPoints = resetPoints.filter { id, _ in result.brushes.contains { $0.id == id } }
        result.favoriteIDs = favoriteIDs.filter { id in result.brushes.contains { $0.id == id } }
        result.recentIDs = []; result.selectedID = result.brushes.first?.id
        try Self.validate(result)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(result)
    }

    func importData(_ data: Data) throws {
        guard data.count <= 32_000_000 else { throw BrushArchiveError.invalid("File troppo grande: limite 32 MB.") }
        let imported = try JSONDecoder().decode(BrushArchive.self, from: data); try Self.validate(imported)
        var libraryMap = [String: String](); var setMap = [String: String](); var combined = archive
        for library in imported.libraries { let id = UUID().uuidString; libraryMap[library.id] = id; combined.libraries.append(BrushLibrary(id: id, name: library.name)) }
        for set in imported.sets { let id = UUID().uuidString; setMap[set.id] = id; combined.sets.append(BrushSet(id: id, libraryID: libraryMap[set.libraryID]!, name: set.name)) }
        for var brush in imported.brushes {
            let point = imported.resetPoints?[brush.id]
            let favorite = (imported.favoriteIDs ?? []).contains(brush.id)
            brush.id = UUID().uuidString; brush.setID = setMap[brush.setID]!; combined.brushes.append(brush)
            if var restored = point { restored.id = brush.id; restored.setID = brush.setID; var points = combined.resetPoints ?? [:]; points[brush.id] = restored; combined.resetPoints = points }
            if favorite { combined.favoriteIDs = (combined.favoriteIDs ?? []) + [brush.id] }
        }
        try Self.validate(combined)
        apply(combined)
        if let id = imported.libraries.first.flatMap({ libraryMap[$0.id] }) { selectedLibraryID = id }
        if let id = imported.sets.first.flatMap({ setMap[$0.id] }) { selectedSetID = id }
        persist()
    }
}
