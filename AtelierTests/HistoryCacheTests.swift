import XCTest
import Metal
@testable import Atelier

@MainActor
final class HistoryCacheTests: XCTestCase {
    private func pixels(_ texture: MTLTexture) -> [UInt16] {
        var bytes = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 8,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0) }
        return bytes
    }

    private func stroke(index: Int = 0) -> PaintStroke {
        PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(0.8,0.2,0.1,1), size: 16, opacity: 0.7,
            samples: [PencilSample(x: 20,y: Float(20 + index % 80),time: 0),
                      PencilSample(x: 300,y: Float(25 + index % 80),time: 1)], seed: UInt64(index + 1), distanceDynamicsVersion: 1)
    }

    private func document(historyCount: Int = 1) -> DocumentContents {
        var value = DocumentContents(width: 384, height: 128)
        value.layers[0].strokes = (0..<historyCount).map { stroke(index: $0) }
        value.layers.append(PaintLayer(name: "Drawing"))
        value.selectedLayerID = value.layers[1].id
        return value
    }

    func testManyCommittedStrokesAreNotReplayedDuringLiveDrawing() throws {
        let painter = try MetalPainter()
        let value = document(historyCount: 200)
        _ = try painter.render(value, documentRevision: 0)
        XCTAssertGreaterThan(painter.lastStampCount, 0)
        XCTAssertEqual(painter.cachedHistoryLayerCount, 1)
        var live = stroke(index: 5)
        let samples = PencilSample.demo(width: 384,height: 128,count: 32)
        live.samples = []
        for first in stride(from: 0, to: samples.count, by: 4) {
            live.samples.append(contentsOf: samples[first..<min(first+4,samples.count)])
            _ = try painter.render(value, liveStroke: live, finished: false, documentRevision: 0, liveSampleRevision: 0)
            XCTAssertEqual(painter.lastHistoryCacheHitCount, 1)
            XCTAssertLessThanOrEqual(painter.lastPlannedSampleCount, 4,
                "The 200 committed strokes must not enter frame planning again.")
        }
    }

    func testLayerEditsWithoutRevisionAndNewDocumentUUIDInvalidateHistory() throws {
        let painter = try MetalPainter()
        var value = document()
        _ = try painter.render(value)
        _ = try painter.render(value)
        XCTAssertEqual(painter.lastHistoryCacheHitCount, 1)
        XCTAssertEqual(painter.lastStampCount, 0)
        value.layers[0].strokes[0].samples[0].x += 35
        let edited = pixels(try painter.render(value))
        XCTAssertEqual(painter.lastHistoryCacheHitCount, 0)
        XCTAssertGreaterThan(painter.lastStampCount, 0)
        XCTAssertEqual(edited, pixels(try MetalPainter().render(value)))
        _ = try painter.render(value, documentRevision: 7)
        value.id = UUID()
        value.layers[0].strokes[0].color = SIMD4(0.1,0.7,0.4,1)
        let otherDocument = pixels(try painter.render(value, documentRevision: 7))
        XCTAssertEqual(painter.lastHistoryCacheHitCount, 0,
            "Equal revision numbers in different documents do not identify the same layer raster.")
        XCTAssertEqual(otherDocument, pixels(try MetalPainter().render(value)))
    }

    func testHistoryRasterIsCachedBeforeLayerAdjustments() throws {
        let painter = try MetalPainter()
        var value = document()
        let before = pixels(try painter.render(value, documentRevision: 0))
        value.layers[0].adjustments = ["hue": 0.6]
        let adjusted = pixels(try painter.render(value, documentRevision: 1))
        XCTAssertEqual(painter.lastHistoryCacheHitCount, 1)
        XCTAssertEqual(painter.lastStampCount, 0)
        XCTAssertNotEqual(before, adjusted)
        XCTAssertEqual(adjusted, pixels(try MetalPainter().render(value)))
    }

    func testHistoryCacheIsBoundedAndSharesBudgetWithLiveInk() throws {
        let painter = try MetalPainter()
        var value = document()
        for index in 0..<8 {
            var layer = PaintLayer(name: "History \(index)")
            layer.strokes = [stroke(index: index)]
            value.layers.insert(layer, at: 0)
        }
        var live = stroke(); live.samples = PencilSample.demo(width: 384,height: 128,count: 8)
        _ = try painter.render(value, liveStroke: live, finished: false, documentRevision: 0, liveSampleRevision: 0)
        XCTAssertEqual(painter.cachedHistoryLayerCount, 4)
        XCTAssertLessThanOrEqual(painter.cachedHistoryBytes, 32 * 1024 * 1024)
        XCTAssertLessThanOrEqual(painter.workingRasterBytes, MetalPainter.workingMemoryLimit)
        painter.invalidateCache()
        XCTAssertEqual(painter.cachedHistoryBytes, 0)
        XCTAssertEqual(painter.cachedHistoryLayerCount, 0)
    }
}
