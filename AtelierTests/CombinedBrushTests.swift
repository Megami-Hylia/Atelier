import Foundation
import Testing
@testable import Atelier

@MainActor struct CombinedBrushTests {
    @Test func combiningPreservesBothSourcesAndOriginalsAfterReopen() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: path) }
        var first = BrushPreset.fallback; first.id = "first"; first.setID = "set"
        var second = first; second.id = "second"; second.shape = "bristle"; second.grain = "canvas"; second.parameters["spacing"] = 0.2
        let catalog = BrushArchive(libraries: [BrushLibrary(id: "library", name: "Test")], sets: [BrushSet(id: "set", libraryID: "library", name: "Test")], brushes: [first, second])
        let store = BrushStore(storageURL: path, catalog: catalog)
        let combined = try #require(store.combine([first.id, second.id]))
        #expect(store.brushes.prefix(2) == [first, second][...])
        #expect(combined.secondaryBrushes == [second])
        let reopened = BrushStore(storageURL: path, catalog: catalog)
        #expect(reopened.brushes.last == combined)
        #expect(reopened.combine([combined.id, first.id]) == nil)
        let stroke = PaintStroke(brush: combined, tool: .paint, color: SIMD4(0,0,0,1), size: 24, opacity: 1,
            samples: PencilSample.demo(width: 256, height: 90), seed: 4, distanceDynamicsVersion: 1)
        let all = try StrokePlanner.stamps(for: stroke, finished: false)
        #expect(all.contains { $0.variation.y == 0 })
        #expect(all.contains { $0.variation.y == 1 })
        var stream = StrokePlanner.Stream(stroke); var chunked: [GPUStamp] = []
        for start in stride(from: 0, to: stroke.samples.count, by: 8) { chunked += try stream.append(stroke.samples[start..<min(start+8,stroke.samples.count)]) }
        #expect(chunked == all)
    }
}
