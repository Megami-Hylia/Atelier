import XCTest
import UIKit
@testable import Atelier

@MainActor final class LayerCommandTests: XCTestCase {
    func testCopyPasteAndCutPreserveStrokeData() throws {
        let previous = UIPasteboard.general.items
        defer { UIPasteboard.general.items = previous }
        let document = PaintDocument(width: 384, height: 128)
        let stroke = PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(1,0,0,1), size: 16, opacity: 1,
                                 samples: [PencilSample(x: 40,y: 50,time: 0)], seed: 42)
        document.commit(stroke)
        document.copyLayers()
        document.pasteLayers()
        XCTAssertNil(document.errorMessage)
        XCTAssertEqual(document.contents.layers.count, 2)
        XCTAssertEqual(document.selectedLayer.strokes[0].samples, stroke.samples)
        XCTAssertNotEqual(document.selectedLayer.strokes[0].id, stroke.id)
        document.copyLayers(cut: true)
        XCTAssertTrue(document.selectedLayer.strokes.isEmpty)
        document.undo()
        XCTAssertEqual(document.selectedLayer.strokes.count, 1)
    }
    func testFlipIsUndoableAndMergeRejectsLockedLayers() throws {
        let document = PaintDocument(width: 384, height: 128)
        document.commit(PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(1,0,0,1), size: 16, opacity: 1,
                                    samples: [PencilSample(x: 40,y: 50,time: 0)], seed: 42))
        document.flipLayer(horizontal: true)
        XCTAssertEqual(document.selectedLayer.strokes[0].samples[0].x, 344)
        document.undo()
        XCTAssertEqual(document.selectedLayer.strokes[0].samples[0].x, 40)
        document.addLayer()
        XCTAssertTrue(document.canMergeSelected)
        document.change { $0.layers[0].locked = true }
        XCTAssertFalse(document.canMergeSelected)
        document.mergeSelectedDown()
        XCTAssertEqual(document.contents.layers.count, 2)
    }
}
