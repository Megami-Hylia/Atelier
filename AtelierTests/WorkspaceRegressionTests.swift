import Testing
import UIKit
@testable import Atelier

@MainActor struct WorkspaceRegressionTests {
    @Test func preferencesSurviveReopenAndRemainIndependent() throws {
        let suite = "AtelierTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = ToolBrushPreferences(defaults: defaults)
        for size in [Float(1), 128, 256] {
            for opacity in [Float(0.01), 0.5, 1] {
                let value = ToolBrushPreferences.Values(size: size, opacity: opacity)
                store.save(value, tool: .paint, brushID: "a")
                #expect(ToolBrushPreferences(defaults: defaults).values(tool: .paint, brushID: "a") == value)
            }
        }
        store.save(.init(size: 24, opacity: 0.2), tool: .erase, brushID: "a")
        store.save(.init(size: 63, opacity: 0.7), tool: .paint, brushID: "b")
        #expect(store.values(tool: .paint, brushID: "a") == .init(size: 256, opacity: 1))
        #expect(store.values(tool: .erase, brushID: "a") == .init(size: 24, opacity: 0.2))
        #expect(store.values(tool: .paint, brushID: "b") == .init(size: 63, opacity: 0.7))
        store.save(.init(size: .nan, opacity: 1), tool: .paint, brushID: "a")
        #expect(store.values(tool: .paint, brushID: "a").size == 256)
        #expect(store.values(tool: .smudge, brushID: "a") == .init())
    }

    @Test func preferencesRecoverFromMalformedStoredValues() throws {
        let suite = "AtelierTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(Data("invalid".utf8), forKey: "atelier.toolBrushPreferences.v1")
        let store = ToolBrushPreferences(defaults: defaults)
        #expect(store.values(tool: .paint, brushID: "a") == .init())
        store.save(.init(size: 12, opacity: 0.3), tool: .paint, brushID: "a")
        #expect(store.values(tool: .paint, brushID: "a").size == 12)
    }

    @Test func navigationPreservesOffCenterAnchorAcrossRotationAndZoom() {
        let bounds = CGRect(x: 0, y: 0, width: 800, height: 600)
        let anchor = CGPoint(x: 145, y: 470)
        let offset = CGPoint(x: anchor.x - bounds.midX, y: anchor.y - bounds.midY)
        var transform = CGAffineTransform(rotationAngle: 0.7).scaledBy(x: 1.8, y: 1.8)
        transform.tx = 38; transform.ty = -90
        let before = offset.applying(transform)
        for delta in [CGAffineTransform(scaleX: 1.3, y: 1.3), CGAffineTransform(rotationAngle: -0.45)] {
            transform = CanvasNavigation.applying(delta, to: transform, anchor: anchor, bounds: bounds)
            let after = offset.applying(transform)
            #expect(abs(before.x - after.x) < 0.00001)
            #expect(abs(before.y - after.y) < 0.00001)
        }
    }

    private var stroke: PaintStroke {
        PaintStroke(brush: .fallback, tool: .paint, color: SIMD4(0, 0, 0, 1), size: 16, opacity: 1,
                    samples: [PencilSample(x: 40, y: 50, time: 0)], seed: 42)
    }

    @Test func strokeCommitsToItsOriginalLayerAfterSelectionChanges() {
        let document = PaintDocument(width: 384, height: 128)
        let original = document.selectedLayer.id
        document.addLayer()
        document.commit(stroke, to: original)
        #expect(document.contents.layers[0].strokes.count == 1)
        #expect(document.selectedLayer.strokes.isEmpty)
        document.undo()
        #expect(document.contents.layers[0].strokes.isEmpty)
        document.redo()
        #expect(document.contents.layers[0].strokes.count == 1)
    }

    @Test func deletedOrLockedStrokeTargetNeverFallsBackToSelectedLayer() {
        let document = PaintDocument(width: 384, height: 128)
        let original = document.selectedLayer.id
        document.addLayer()
        document.change { $0.layers[0].locked = true }
        document.commit(stroke, to: original)
        #expect(document.contents.layers.allSatisfy { $0.strokes.isEmpty })
        #expect(document.errorMessage != nil)
        document.deleteLayer(original)
        document.errorMessage = nil
        document.commit(stroke, to: original)
        #expect(document.selectedLayer.strokes.isEmpty)
        #expect(document.errorMessage != nil)
    }

    @Test func duplicateLayerHasIndependentStrokeIdentityAndRefinement() {
        let document = PaintDocument(width: 384, height: 128)
        let source = stroke
        document.commit(source)
        document.duplicateLayer(document.selectedLayer.id)
        #expect(document.selectedLayer.strokes[0].id != source.id)
        var refined = source.samples[0]; refined.pressure = 0.4
        document.refine(strokeID: source.id, sampleIndex: 0, sample: refined)
        #expect(document.contents.layers[0].strokes[0].samples[0].pressure == 0.4)
        #expect(document.selectedLayer.strokes[0].samples[0].pressure == 1)
    }

    @Test func historyGesturesAcceptOnlyDirectTouchesAndUseTheCanvasDelegate() {
        let canvas = PencilCanvas(frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let taps = (canvas.gestureRecognizers ?? []).compactMap { $0 as? UITapGestureRecognizer }
        #expect(taps.count == 2)
        for tap in taps {
            #expect(tap.allowedTouchTypes == [NSNumber(value: UITouch.TouchType.direct.rawValue)])
            #expect(tap.delegate === canvas)
        }
    }
}
