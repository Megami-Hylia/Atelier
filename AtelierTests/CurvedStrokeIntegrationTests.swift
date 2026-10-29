import XCTest
import Metal
@testable import Atelier

@MainActor
final class CurvedStrokeIntegrationTests: XCTestCase {
    private func curve(tool: PaintTool = .paint, samples: [PencilSample]) -> PaintStroke {
        var brush = BrushPreset.fallback
        brush.parameters["streamline"] = 0.3
        brush.parameters["wetPull"] = 0.35
        brush.parameters["hueJitter"] = 0.2
        brush.parameters["pressureSize"] = 0.8
        var stroke = PaintStroke(brush: brush, tool: tool, color: SIMD4(0.2,0.6,0.8,1), size: 24, opacity: 0.7,
            samples: samples, seed: 15, distanceDynamicsVersion: 1)
        stroke.curveVersion = 1
        stroke.inputScale = 1.5
        stroke.stabilizationAmount = 0.35
        return stroke
    }

    private func pixels(_ texture: MTLTexture) -> [UInt16] {
        var result = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        result.withUnsafeMutableBytes {
            texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 8,
                from: MTLRegionMake2D(0,0,texture.width,texture.height), mipmapLevel: 0)
        }
        return result
    }

    private func assertSamePixels(_ actual: [UInt16], _ expected: [UInt16],
                                  file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        var maximumError: Float = 0
        for (a,b) in zip(actual,expected) {
            let error = abs(Float(Float16(bitPattern: a))-Float(Float16(bitPattern: b)))
            guard error.isFinite else {
                XCTFail("Curve rendering produced a non-finite pixel.", file: file, line: line)
                return
            }
            maximumError = max(maximumError,error)
        }
        XCTAssertLessThanOrEqual(maximumError,3.0/255,
            "Incremental curve rendering must agree with replay within half-float accumulation tolerance.",
            file: file, line: line)
    }

    func testCurvedInkDiscardsPredictionsAndReplaysLateBakedCorrectionsForEveryTool() throws {
        let samples = PencilSample.demo(width: 384,height: 128,count: 72)
        for tool in PaintTool.allCases {
            let painter = try MetalPainter()
            let replayPainter = try MetalPainter()
            var document = DocumentContents(width: 384,height: 128)
            document.selectedLayerID = document.layers[0].id
            document.layers[0].strokes = [PaintStroke(brush: .fallback,tool: .paint,color: SIMD4(0.8,0.2,0.3,1),
                size: 48,opacity: 1,samples: PencilSample.demo(width: 384,height: 128,count: 36),seed: 5)]
            var live = curve(tool: tool,samples: [])
            for first in stride(from: 0,to: samples.count,by: 12) {
                let end = min(first+12,samples.count)
                live.samples += samples[first..<end]
                var prediction = samples[end-1]
                prediction.x += 20; prediction.y = 15; prediction.time += 0.02
                _ = try painter.render(document,liveStroke: live,finished: false,documentRevision: 0,
                    liveSampleRevision: 0,predictedSamples: [prediction])
                XCTAssertEqual(painter.lastPlannedSampleCount,end-first+(first == 0 ? 36 : 0),
                    "New curve frames must consume only the newly appended samples.")
            }
            XCTAssertTrue(painter.hasBakedSample(strokeID: live.id,index: 3))
            let withoutPrediction = pixels(try painter.render(document,liveStroke: live,finished: false,
                documentRevision: 0,liveSampleRevision: 0))
            XCTAssertEqual(painter.lastPlannedSampleCount,0)
            assertSamePixels(withoutPrediction,pixels(try replayPainter.render(document,liveStroke: live,finished: false)))

            // A late Pencil estimate changes ink that has already entered the retained raster.
            live.samples[3].pressure = 0.08
            live.samples[3].altitude = 0.35
            var consumedAfterCorrection = 0
            for _ in 0..<3 {
                _ = try painter.render(document,liveStroke: live,finished: false,documentRevision: 0,liveSampleRevision: 1)
                XCTAssertLessThanOrEqual(painter.lastPlannedSampleCount,32)
                consumedAfterCorrection += painter.lastPlannedSampleCount
                if !painter.hasPendingLiveSamples { break }
            }
            XCTAssertFalse(painter.hasPendingLiveSamples)
            XCTAssertEqual(consumedAfterCorrection,samples.count,
                "A baked estimate must rebuild the curve once, in bounded frames.")
            let corrected = pixels(try painter.render(document,liveStroke: live,finished: false,
                documentRevision: 0,liveSampleRevision: 1))
            XCTAssertEqual(painter.lastPlannedSampleCount,0)
            assertSamePixels(corrected,pixels(try replayPainter.render(document,liveStroke: live,finished: false)))
        }
    }

    func testOneCurvedGestureKeepsItsMetadataThroughUndoRedoAndPersistence() throws {
        let stroke = curve(samples: PencilSample.demo(width: 384,height: 128,count: 48))
        let document = PaintDocument(width: 384,height: 128)
        document.commit(stroke)
        XCTAssertNil(document.errorMessage)
        XCTAssertEqual(document.selectedLayer.strokes,[stroke])
        document.undo()
        XCTAssertTrue(document.selectedLayer.strokes.isEmpty)
        document.redo()
        XCTAssertEqual(document.selectedLayer.strokes,[stroke])
        XCTAssertFalse(document.canRedo)

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString,isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let url = folder.appendingPathComponent("curved.atelier")
        try document.save(to: url)
        let reopened = PaintDocument()
        try reopened.load(from: url)
        XCTAssertEqual(reopened.contents,document.contents)
        let saved = try XCTUnwrap(reopened.selectedLayer.strokes.first)
        XCTAssertEqual(saved.curveVersion,1)
        XCTAssertEqual(saved.distanceDynamicsVersion,1)
        XCTAssertEqual(saved.inputScale,1.5)
        XCTAssertEqual(saved.stabilizationAmount,0.35)
        XCTAssertEqual(saved.samples,stroke.samples)
        XCTAssertEqual(try StrokePlanner.stamps(for: saved),try StrokePlanner.stamps(for: stroke))
    }

    func testLongContinuousCurveConsumesEachInputOnceWithoutReplanningPrefixes() throws {
        let samples = (0..<8192).map { i in
            PencilSample(x: 28+Float(i)*0.035,y: 64+sin(Float(i)*0.009)*12,
                pressure: 0.5+sin(Float(i)*0.003)*0.3,time: Double(i)/240)
        }
        var stroke = curve(samples: samples)
        stroke.size = 8
        stroke.brush.parameters["spacing"] = 0.3
        var cursor = StrokePlanner.Stream(stroke)
        var actual: [GPUStamp] = []
        var consumed = 0
        for first in stride(from: 0,to: samples.count,by: 32) {
            let end = min(first+32,samples.count)
            let previousCount = cursor.sampleCount
            actual += try cursor.append(samples[first..<end])
            let newCount = cursor.sampleCount-previousCount
            XCTAssertEqual(newCount,end-first)
            consumed += newCount
            XCTAssertEqual(cursor.sampleCount,end)

            // Rendering a predicted tail must leave the retained curve cursor unchanged.
            var provisional = cursor
            var prediction = samples[end-1]
            prediction.x += 2; prediction.y += 3; prediction.time += 0.01
            _ = try provisional.append([prediction][...])
            _ = try provisional.flushEnd()
            XCTAssertEqual(cursor.sampleCount,end)
        }
        actual += try cursor.flushEnd()
        XCTAssertTrue(try cursor.flushEnd().isEmpty)
        XCTAssertEqual(consumed,8192,"Input work must be linear, rather than the sum of all growing prefixes.")
        XCTAssertEqual(cursor.sampleCount,8192)
        XCTAssertEqual(cursor.lastRawSample,samples.last)
        XCTAssertEqual(actual,try StrokePlanner.stamps(for: stroke,finished: false))
    }
}
