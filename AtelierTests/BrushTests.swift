import Foundation
import Testing
@testable import Atelier

@MainActor
struct BrushTests {
    private func fixture() -> BrushArchive {
        var brush = BrushPreset.fallback; brush.id = "fixture-brush"; brush.setID = "fixture-set"
        return BrushArchive(libraries: [BrushLibrary(id: "fixture-library", name: "Test")], sets: [BrushSet(id: "fixture-set", libraryID: "fixture-library", name: "Test")], brushes: [brush], selectedID: brush.id)
    }

    @Test func customBrushSurvivesSaveReopenAndJSONRoundTrip() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let path = folder.appendingPathComponent("brushes.json")
        let original = fixture()
        let store = BrushStore(storageURL: path, catalog: original)
        var custom = store.duplicate(store.selectedBrush)
        custom.name = "Custom Ink"
        custom.parameters = Dictionary(uniqueKeysWithValues: BrushParameter.all.map { ($0.id, $0.defaultValue) })
        custom.parameters["spacing"] = 0.72
        custom.parameters["pressureCurve"] = 1.7
        custom.parameters["hueJitter"] = 0.2
        custom.seed = 109
        custom.shapeData = Data([1, 2, 3, 4]); custom.grainData = Data([4, 3, 2, 1])
        custom.notes = "Preserve every field"; store.save(custom)
        #expect(store.errorMessage == nil)
        let reopened = BrushStore(storageURL: path, catalog: original)
        #expect(reopened.brushes.first { $0.id == custom.id } == custom)
        let exported = try reopened.exportData(brush: custom)
        let decoded = try JSONDecoder().decode(BrushArchive.self, from: exported)
        #expect(decoded.brushes == [custom])
        try reopened.importData(exported)
        let imported = try #require(reopened.brushes.last)
        #expect(imported.id != custom.id)
        #expect(imported.parameters == custom.parameters)
        #expect(imported.shapeData == custom.shapeData)
        #expect(imported.seed == custom.seed)
    }

    @Test func importRejectsInvalidReferencesAndParametersWithoutMutation() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: path) }
        let store = BrushStore(storageURL: path, catalog: fixture())
        let before = store.archive
        var invalid = fixture(); invalid.brushes[0].setID = "missing"
        #expect(throws: (any Error).self) { try store.importData(JSONEncoder().encode(invalid)) }
        #expect(store.archive == before)
        invalid = fixture(); invalid.brushes[0].parameters["spacing"] = -10
        #expect(throws: (any Error).self) { try store.importData(JSONEncoder().encode(invalid)) }
        #expect(store.archive == before)
    }

    @Test func movingAndRestoringPresetsKeepsPersonalWork() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: path) }
        let store = BrushStore(storageURL: path, catalog: fixture())
        let personal = store.duplicate(store.selectedBrush)
        let set = store.createSet(name: "Personal", libraryID: "fixture-library")
        store.moveBrush(personal, to: set.id)
        store.renameBrush(personal, to: "Personal renamed")
        store.restoreFactoryPresets()
        #expect(store.brushes.contains { $0.id == personal.id && $0.name == "Personal renamed" && $0.setID == set.id })
        let reopened = BrushStore(storageURL: path, catalog: fixture())
        #expect(reopened.brushes == store.brushes)
        #expect(reopened.sets == store.sets)
    }

    @Test func bundledCatalogContainsDistinctConfigurations() throws {
        let url = try #require(Bundle.main.url(forResource: "BrushCatalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(BrushArchive.self, from: Data(contentsOf: url))
        try BrushStore.validate(catalog)
        #expect(catalog.brushes.count == 192)
        let newSets = catalog.sets.filter { $0.libraryID == "atelier" }
        #expect(newSets.count == 18)
        #expect(newSets.allSatisfy { set in catalog.brushes.filter { $0.setID == set.id }.count == 10 })
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let configurations = try catalog.brushes.map { brush in
            try encoder.encode(brush.parameters).base64EncodedString() + brush.shape + brush.grain
        }
        #expect(Set(configurations).count == 192)
    }
}
