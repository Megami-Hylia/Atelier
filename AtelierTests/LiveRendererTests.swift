import XCTest
import Metal
@testable import Atelier

@MainActor
final class LiveRendererTests: XCTestCase {
    private func pixels(_ texture: MTLTexture) -> [UInt16] {
        var bytes = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        bytes.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 8,
            from: MTLRegionMake2D(0, 0, texture.width, texture.height), mipmapLevel: 0) }
        return bytes
    }

    func testIncrementalInkMatchesReplayAndDiscardsPredictionsForPaintEraseAndSmudge() throws {
        for tool in PaintTool.allCases {
            let painter = try MetalPainter()
            var document = DocumentContents(width: 384, height: 128)
            document.selectedLayerID = document.layers[0].id
            let underpaint = PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(0.8, 0.2, 0.3, 1), size: 48, opacity: 1,
                samples: PencilSample.demo(width: 384, height: 128, count: 60), seed: 5)
            document.layers[0].strokes = [underpaint]
            var brush = BrushPreset.fallback
            brush.parameters["wetPull"] = 0.4; brush.parameters["hueJitter"] = 0.3
            let all = PencilSample.demo(width: 384, height: 128, count: 80)
            var live = PaintStroke(brush: brush, tool: tool, color: SIMD4(0.2, 0.6, 0.8, 1), size: 24, opacity: 0.7,
                samples: [], seed: 15, distanceDynamicsVersion: 1)
            for first in stride(from: 0, to: all.count, by: 8) {
                live.samples += all[first..<min(first + 8, all.count)]
                _ = try painter.render(document, liveStroke: live, finished: false, documentRevision: 0, liveSampleRevision: 0,
                    predictedSamples: [PencilSample(x: 200, y: 80, time: 10)])
                XCTAssertLessThanOrEqual(painter.lastPlannedSampleCount, first == 0 ? 68 : 8)
            }
            let incremental = pixels(try painter.render(document, liveStroke: live, finished: false,
                documentRevision: 0, liveSampleRevision: 0))
            XCTAssertEqual(painter.lastPlannedSampleCount, 0)
            let replay = pixels(try MetalPainter().render(document, liveStroke: live, finished: false))
            for (a, b) in zip(incremental, replay) {
                XCTAssertLessThanOrEqual(abs(Float(Float16(bitPattern: a)) - Float(Float16(bitPattern: b))), 3.0 / 255,
                    "Incremental half-float rounding must not visibly alter replay.")
            }
            live.samples[3].pressure = 0.1
            var replanned = 0
            for _ in 0..<4 {
                _ = try painter.render(document, liveStroke: live, finished: false, documentRevision: 0, liveSampleRevision: 1)
                XCTAssertLessThanOrEqual(painter.lastPlannedSampleCount, 32)
                replanned += painter.lastPlannedSampleCount
                if !painter.hasPendingLiveSamples { break }
            }
            XCTAssertEqual(replanned, live.samples.count, "Estimated-property corrections must invalidate stale ink.")
        }
    }

    func testInputBurstIsDrainedInBoundedFramesWithoutRevisitingPrefixes() throws {
        let painter = try MetalPainter()
        var document = DocumentContents(width: 384, height: 128)
        document.selectedLayerID = document.layers[0].id
        let live = PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(0.3, 0.2, 0.8, 1), size: 24, opacity: 1,
            samples: PencilSample.demo(width: 384, height: 128, count: 256), seed: 2, distanceDynamicsVersion: 1)
        var processed = 0
        for _ in 0..<10 {
            _ = try painter.render(document, liveStroke: live, finished: false, documentRevision: 0, liveSampleRevision: 0)
            XCTAssertLessThanOrEqual(painter.lastPlannedSampleCount, 32)
            processed += painter.lastPlannedSampleCount
            if !painter.hasPendingLiveSamples { break }
        }
        XCTAssertFalse(painter.hasPendingLiveSamples)
        XCTAssertEqual(processed, 256)
    }

    func testRecentPencilCorrectionsOnlyReplanTheProvisionalTail() throws {
        let painter = try MetalPainter()
        var document = DocumentContents(width: 384, height: 128)
        document.selectedLayerID = document.layers[0].id
        var live = PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(0.3, 0.2, 0.8, 1), size: 24, opacity: 1,
            samples: PencilSample.demo(width: 384, height: 128, count: 80), seed: 2, distanceDynamicsVersion: 1)
        for _ in 0..<2 {
            _ = try painter.render(document, liveStroke: live, finished: false, documentRevision: 0,
                liveSampleRevision: 0, liveStableSampleCount: 48)
        }
        XCTAssertTrue(painter.hasBakedSample(strokeID: live.id, index: 3))
        XCTAssertFalse(painter.hasBakedSample(strokeID: live.id, index: 70))
        live.samples[70].pressure = 0.2
        _ = try painter.render(document, liveStroke: live, finished: false, documentRevision: 0,
            liveSampleRevision: 0, liveStableSampleCount: 48)
        XCTAssertEqual(painter.lastPlannedSampleCount, 32, "Only the bounded provisional tail needs replanning.")
    }

    func testAppendingFinishedStrokeDoesNotReplayCommittedHistory() throws {
        let painter = try MetalPainter()
        var document = DocumentContents(width: 384, height: 128)
        document.selectedLayerID = document.layers[0].id
        let stroke = PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(0.2, 0.4, 0.7, 1), size: 20, opacity: 1,
            samples: PencilSample.demo(width: 384, height: 128, count: 40), seed: 1, distanceDynamicsVersion: 1)
        document.layers[0].strokes = [stroke]
        _ = try painter.render(document)
        var next = stroke; next.id = UUID(); next.seed = 8
        document.layers[0].strokes.append(next)
        let cached = pixels(try painter.render(document))
        XCTAssertEqual(painter.lastStampCount, try StrokePlanner.stamps(for: next).count)
        XCTAssertEqual(cached, pixels(try MetalPainter().render(document)))
    }

    func testExplicitSaveCannotBeOverwrittenByAnOlderQueuedAutosave() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("document.atelier")
        let document = PaintDocument(width: 384, height: 128)
        try document.save(to: url)
        document.change { $0.name = "Old queued snapshot" }
        document.change { $0.name = "Latest explicit snapshot" }
        try document.save(to: url)
        try await Task.sleep(for: .milliseconds(700))
        let reopened = PaintDocument(); try reopened.load(from: url)
        XCTAssertEqual(reopened.contents, document.contents)
        XCTAssertEqual(reopened.contents.name, "Latest explicit snapshot")
    }
}
