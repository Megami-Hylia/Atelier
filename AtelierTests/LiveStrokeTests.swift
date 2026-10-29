import Foundation
import Testing
@testable import Atelier

@MainActor
struct LiveStrokeTests {
    @Test func chunkedPlanningMatchesWholePlanningForEveryBundledBrush() throws {
        let url = try #require(Bundle.main.url(forResource: "BrushCatalog", withExtension: "json"))
        let catalog = try JSONDecoder().decode(BrushArchive.self, from: Data(contentsOf: url))
        for brush in catalog.brushes {
            let stroke = PaintStroke(brush: brush, tool: .paint, color: SIMD4(0.2, 0.4, 0.7, 1), size: 32, opacity: 0.8,
                samples: PencilSample.demo(width: 384, height: 128, count: 97), seed: 58, distanceDynamicsVersion: 1)
            var cursor = StrokePlanner.Stream(stroke)
            var actual: [GPUStamp] = []
            for first in stride(from: 0, to: stroke.samples.count, by: 7) {
                actual += try cursor.append(stroke.samples[first..<min(first + 7, stroke.samples.count)])
            }
            #expect(actual == (try StrokePlanner.stamps(for: stroke, finished: false)), "Chunk boundaries changed a brush trajectory.")
            #expect(cursor.sampleCount == stroke.samples.count)
        }
    }

    @Test func longStrokeConsumesEachSampleOnceAndPredictionsDoNotAdvanceCursor() throws {
        var brush = BrushPreset.fallback
        brush.parameters["stampCount"] = 8; brush.parameters["dualEnabled"] = 1
        brush.parameters["scatter"] = 0.2; brush.parameters["hueJitter"] = 0.5
        brush.parameters["taperStart"] = 0.4; brush.parameters["fallOff"] = 0.1
        let samples = (0..<8192).map { i in PencilSample(x: Float(i) * 0.15, y: 64 + sin(Float(i) * 0.01) * 5, pressure: 0.8, time: Double(i) / 240) }
        let stroke = PaintStroke(brush: brush, tool: .paint, color: SIMD4(0.3, 0.5, 0.2, 1), size: 48, opacity: 1,
            samples: samples, seed: 89, distanceDynamicsVersion: 1)
        var cursor = StrokePlanner.Stream(stroke)
        var stamps: [GPUStamp] = []
        for first in stride(from: 0, to: samples.count, by: 32) {
            let countBefore = cursor.sampleCount
            stamps += try cursor.append(samples[first..<min(first + 32, samples.count)])
            #expect(cursor.sampleCount - countBefore <= 32)
            var predicted = cursor
            _ = try predicted.append([PencilSample(x: Float(first + 32) * 0.15 + 1, y: 64, time: Double(first + 40) / 240)][...])
            #expect(cursor.sampleCount == min(first + 32, samples.count))
        }
        #expect(stamps == (try StrokePlanner.stamps(for: stroke, finished: false)))
        // Sample work is 8192, not the sum of every growing prefix (~1 million).
        #expect(cursor.sampleCount == 8192)
    }

    @Test func legacyStrokesRoundTripWithoutChangingDynamicsVersion() throws {
        let stroke = PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(0, 0, 0, 1), size: 12, opacity: 1,
            samples: PencilSample.demo(width: 120, height: 64, count: 20), seed: 3)
        let decoded = try JSONDecoder().decode(PaintStroke.self, from: JSONEncoder().encode(stroke))
        #expect(decoded.distanceDynamicsVersion == nil)
        #expect(try StrokePlanner.stamps(for: stroke) == StrokePlanner.stamps(for: decoded))
    }
}
