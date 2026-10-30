import XCTest
import Metal
@testable import Atelier

@MainActor
final class BrushSettingsTests: XCTestCase {
    private let centerAlpha = 16643
    private func stroke(_ parameters: [String: Double] = [:]) -> PaintStroke {
        var brush = BrushPreset.fallback
        brush.parameters = ["pressureSize": 0, "spacing": 0.15, "wetAttack": 0]
        brush.parameters.merge(parameters) { _, new in new }
        return PaintStroke(brush: brush, tool: .paint, color: SIMD4(0.2,0.5,0.8,1), size: 24, opacity: 1,
            samples: PencilSample.demo(width: 128, height: 64, count: 24), seed: 17,
            distanceDynamicsVersion: 1, curveVersion: 1, inputScale: 1, brushSettingsVersion: 1)
    }
    private func pixels(_ texture: MTLTexture) -> [Float] {
        var bits = [UInt16](repeating: 0, count: texture.width * texture.height * 4)
        bits.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: texture.width * 8,
            from: MTLRegionMake2D(0,0,texture.width,texture.height), mipmapLevel: 0) }
        return bits.map { Float(Float16(bitPattern: $0)) }
    }
    private func render(_ strokes: [PaintStroke]) throws -> [Float] {
        var document = DocumentContents(width: 128, height: 64); document.background = .zero
        document.layers[0].strokes = strokes
        return pixels(try MetalPainter().render(document))
    }
    func testEveryControlAtMinimumMiddleMaximumProducesFiniteStampsAndPersists() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = BrushPreset.fallback
        let archive = BrushArchive(libraries: [BrushLibrary(id: "library", name: "Test")],
            sets: [BrushSet(id: original.setID, libraryID: "library", name: "Test")], brushes: [original], selectedID: original.id)
        let url = folder.appendingPathComponent("brushes.json")
        let store = BrushStore(storageURL: url, catalog: archive)
        for fraction in [0.0, 0.5, 1.0] {
            var saved = original
            for parameter in BrushParameter.all {
                let value = parameter.range.lowerBound + (parameter.range.upperBound-parameter.range.lowerBound)*fraction
                saved.parameters[parameter.id] = parameter.id == "stampCount" ? value.rounded() : value
                var sample = stroke([parameter.id: value])
                let stamps = try StrokePlanner.stamps(for: sample)
                XCTAssertFalse(stamps.isEmpty, parameter.id)
                for stamp in stamps {
                    for vector in [stamp.geometry,stamp.color,stamp.shape,stamp.grain,stamp.texture,stamp.pickup,stamp.rendering,stamp.variation] {
                        XCTAssertTrue((0..<4).allSatisfy { vector[$0].isFinite }, parameter.id)
                    }
                }
                sample.brushSettingsVersion = nil
                XCTAssertNoThrow(try StrokePlanner.stamps(for: sample), parameter.id)
            }
            store.save(saved)
            XCTAssertNil(store.errorMessage)
            let reopened = BrushStore(storageURL: url, catalog: archive)
            XCTAssertEqual(reopened.selectedBrush.parameters, saved.parameters)
        }
    }
    func testDefaultsRangesAndCombinedModesUseTheSameContractAsStudio() {
        var brush = BrushPreset.fallback; brush.parameters = [:]
        let settings = PlannedBrushSettings(brush, corrected: true)
        XCTAssertEqual(settings.pressureSize, 0.6, accuracy: 0.00001)
        XCTAssertEqual(settings.taperSize, 1)
        XCTAssertEqual(settings.grainZoom, 0)
        XCTAssertEqual(settings.dualScale, 1)
        XCTAssertEqual(settings.smudge, 0.5)
        brush.parameters = ["flow": 100, "opacity": -100, "spacing": .nan, "blendMode": 10]
        let clamped = PlannedBrushSettings(brush, corrected: true)
        XCTAssertEqual(clamped.flow, 1); XCTAssertEqual(clamped.opacity, 0)
        XCTAssertEqual(clamped.spacing, 0.08, accuracy: 0.00001); XCTAssertEqual(clamped.blendMode, 10)
    }
    func testPressureOnlyChangesAssignedPropertiesAndAzimuthUsesThePenAngle() throws {
        var low = stroke(["azimuth": 1, "wetAttack": 1, "wetDilution": 0.3, "flow": 0.2])
        low.samples = [PencilSample(x: 20,y: 20,pressure: 0.1,azimuth: 0.7,time: 0)]
        var high = low; high.samples[0].pressure = 1
        let a = try XCTUnwrap(try StrokePlanner.stamps(for: low).first)
        let b = try XCTUnwrap(try StrokePlanner.stamps(for: high).first)
        XCTAssertEqual(a.geometry.z,b.geometry.z); XCTAssertEqual(a.color.w,b.color.w)
        XCTAssertEqual(a.shape.z,b.shape.z); XCTAssertEqual(a.geometry.w,0.7,accuracy: 0.00001)
        for key in ["pressureSize", "pressureFlow", "pressureOpacity"] {
            low.brush.parameters[key] = 1; high.brush.parameters[key] = 1
            let x = try XCTUnwrap(try StrokePlanner.stamps(for: low).first)
            let y = try XCTUnwrap(try StrokePlanner.stamps(for: high).first)
            if key == "pressureSize" { XCTAssertLessThan(x.geometry.z,y.geometry.z) }
            if key == "pressureFlow" { XCTAssertLessThan(x.color.w,y.color.w) }
            if key == "pressureOpacity" { XCTAssertLessThan(x.shape.z,y.shape.z) }
            low.brush.parameters[key] = 0; high.brush.parameters[key] = 0
        }
    }
    func testOpacityCapsEachGestureButFlowAccumulatesAndZeroRemainsZero() throws {
        var line = stroke(["opacity": 0.35, "flow": 0.6, "spacing": 0.02])
        line.samples = (0..<36).map { PencilSample(x: Float(24+($0%2)*80),y: 32,time: Double($0)*0.1) }
        let image = try render([line])
        let alpha = stride(from: 3, to: image.count, by: 4).map { image[$0] }
        XCTAssertLessThanOrEqual(alpha.max() ?? 1, 0.352)
        XCTAssertGreaterThan(alpha.max() ?? 0, 0.34)
        var second = line; second.id = UUID()
        let twice = try render([line,second])
        XCTAssertGreaterThan(twice[centerAlpha],0.5)
        var dot = stroke(["flow": 0.1]); dot.samples = [PencilSample(x: 64,y: 32)]
        let thin = try render([dot]); dot.brush.parameters["flow"] = 0.6
        let dense = try render([dot]); XCTAssertLessThan(thin[centerAlpha],dense[centerAlpha])
        for key in ["flow", "opacity", "maxOpacity", "maxSize"] {
            var disabled = line; disabled.brush.parameters[key] = 0; disabled.brush.parameters["minOpacity"] = 0.8
            let empty = try render([disabled])
            XCTAssertEqual(empty.max(),0,key)
        }
        var nonAccumulating = line; nonAccumulating.brush.parameters["accumulation"] = 0
        let once = try render([nonAccumulating])
        XCTAssertGreaterThan(once[centerAlpha],0)
        XCTAssertLessThan(once[centerAlpha],image[centerAlpha])
    }
    func testChangedSettingsAlterPixelsAndPreviewAndPreserveExistingStrokeSnapshot() throws {
        let original = stroke()
        var radii: [Float] = []
        for size: Float in [4,24,64] {
            var sized = original; sized.size = size; sized.samples = [PencilSample(x: 64,y: 32)]
            radii.append(try XCTUnwrap(try StrokePlanner.stamps(for: sized).first).geometry.z)
        }
        XCTAssertLessThan(radii[0],radii[1]); XCTAssertLessThan(radii[1],radii[2])
        let baseline = try render([original])
        for (key, value) in [("flow",0.03),("opacity",0.3),("spacing",1.5),("roundness",0.1),
            ("jitterLateral",0.8),("pressureSize",1.0),("pressureOpacity",1.0),("sizeJitter",0.9)] {
            var changed = original; changed.brush.parameters[key] = value
            XCTAssertNotEqual(baseline,try render([changed]),key)
        }
        var textured = original; textured.brush.grain = "charcoal"; textured.brush.parameters["grainDepth"] = 1
        let texture = try render([textured]); XCTAssertNotEqual(baseline,texture)
        for (key,value) in [("grainScale",4.0),("grainRotation",0.3),("grainContrast",0.2),("grainMovement",1.0)] {
            var changed = textured; changed.brush.parameters[key] = value
            XCTAssertNotEqual(texture,try render([changed]),key)
        }
        var brush = original.brush
        let preview = try BrushPreviewRenderer.shared.image(brush, lightOnDark: false).pngData()
        brush.parameters["opacity"] = 0.1
        XCTAssertNotEqual(preview,try BrushPreviewRenderer.shared.image(brush, lightOnDark: false).pngData())
        XCTAssertEqual(baseline,try render([original]))
        let document = PaintDocument(width: 128,height: 64); document.commit(original)
        let data = try JSONEncoder().encode(document.contents)
        let decoded = try JSONDecoder().decode(DocumentContents.self,from: data)
        XCTAssertEqual(decoded.layers[0].strokes[0],original)
    }
    func testIncrementalCoverageMatchesReplayAcrossPredictionsAndHistoryLayers() throws {
        for tool in PaintTool.allCases {
            let painter = try MetalPainter()
            var document = DocumentContents(width: 128,height: 64)
            document.selectedLayerID = document.layers[0].id; document.background = .zero
            document.layers[0].strokes = [stroke()]
            document.layers.append(PaintLayer(name: "Other", strokes: [stroke(["opacity":0.2])]))
            var live = stroke(["opacity":0.4,"flow":0.3]); live.tool = tool
            let all = live.samples; live.samples = []
            for start in stride(from: 0,to: all.count,by: 4) {
                live.samples += all[start..<min(start+4,all.count)]
                _ = try painter.render(document,liveStroke: live,finished: false,documentRevision: 0,liveSampleRevision: 0,
                    predictedSamples: [PencilSample(x: 120,y: 10,time: 5)])
            }
            let accumulated = pixels(try painter.render(document,liveStroke: live,finished: false,documentRevision: 0,liveSampleRevision: 0))
            let replay = pixels(try MetalPainter().render(document,liveStroke: live,finished: false))
            for (a,b) in zip(accumulated,replay) { XCTAssertEqual(a,b,accuracy: 0.006) }
            XCTAssertLessThanOrEqual(painter.lastPlannedSampleCount,4)
        }
    }
    func testEveryControlHasAnObservableEffectAtLowMiddleHighWithItsDependenciesEnabled() throws {
        var underpaint = stroke()
        underpaint.color = SIMD4(0.8,0.2,0.1,1)
        underpaint.samples = [PencilSample(x: 10,y: 32,time: 0),PencilSample(x: 118,y: 32,time: 1)]
        underpaint.size = 22
        var base = stroke(["flow":0.18,"opacity":0.7,"pressureSize":0.5,"pressureOpacity":0.3,
            "pressureFlow":0.2,"spacing":0.3,"stampCount":3,"countJitter":0.2,
            "jitterLateral":0.12,"roundness":0.7,"grainDepth":0.4,"rotation":0.3,
            "wetDilution":0.25,"wetPull":0.4,"wetCharge":0.8,"wetAttack":0.3,
            "taperStart":0.3,"taperEnd":0.5,"taperSize":0.5,"taperOpacity":0.3,
            "dualEnabled":1,"dualScale":0.7,"dualOpacity":0.5,"motionFiltering":0.7])
        base.brush.shape = "fleck"; base.brush.grain = "charcoal"
        for i in base.samples.indices {
            base.samples[i].y += i.isMultiple(of: 2) ? 1 : -1
        }
        var records: [[String: Any]] = []
        for parameter in BrushParameter.all {
            var outputs: [Data] = []
            for fraction in [0.0,0.5,1.0] {
                var changed = base
                let value = parameter.range.lowerBound+(parameter.range.upperBound-parameter.range.lowerBound)*fraction
                changed.brush.parameters[parameter.id] = parameter.id == "stampCount" ? value.rounded() : value
                if parameter.id == "smudge" { changed.tool = .smudge }
                if parameter.category == "Preview" {
                    outputs.append(try XCTUnwrap(try BrushPreviewRenderer.shared.image(changed.brush,lightOnDark: false).pngData()))
                } else {
                    let result = try render([underpaint,changed])
                    outputs.append(result.withUnsafeBytes { Data($0) })
                }
            }
            let distinct = Set(outputs).count
            records.append(["id":parameter.id,"minimum":parameter.range.lowerBound,
                "middle":(parameter.range.lowerBound+parameter.range.upperBound)/2,
                "maximum":parameter.range.upperBound,"distinctPixelResults":distinct])
            XCTAssertGreaterThan(distinct,1,"No pixel effect for \(parameter.id) with dependencies enabled")
        }
        let data = try JSONSerialization.data(withJSONObject: records,options: [.prettyPrinted,.sortedKeys])
        let attachment = XCTAttachment(data: data,uniformTypeIdentifier: "public.json")
        attachment.name = "Brush-control-low-middle-high-pixels"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testCombinedBrushSharesOpacityLimitAndPigmentStillChangesAtFullCoverage() throws {
        var combined = stroke(["opacity":0.4,"flow":1])
        combined.samples = [PencilSample(x: 64,y: 32)]
        combined.brush.secondaryBrushes = [combined.brush]
        let image = try render([combined])
        XCTAssertLessThanOrEqual(image[centerAlpha],0.402)
        var held = stroke(["opacity":0.5,"flow":1,"hueJitter":1])
        held.samples = [PencilSample(x: 64,y: 32,pressure: 1,time: 0)]
        let first = try render([held])
        held.samples += [PencilSample(x: 64,y: 32,pressure: 0.3,time: 0.1),
            PencilSample(x: 64,y: 32,pressure: 1,time: 0.2)]
        let varied = try render([held])
        XCTAssertEqual(varied[centerAlpha],first[centerAlpha],accuracy: 0.003)
        XCTAssertNotEqual(varied,first)
    }

    func testLocalStabilizationStillRespondsWhenGlobalStabilizationIsEnabled() {
        let samples = PencilSample.demo(width: 128,height: 64,count: 24)
        func path(_ amount: Double) -> [PencilSample] {
            var brush = BrushPreset.fallback; brush.parameters["stabilization"] = amount
            var curve = StrokeTrajectory(brush: brush,stabilization: 0.5,screenScale: 1,corrected: true)
            var result: [PencilSample] = []
            for sample in samples { result += curve.append(sample) }
            return result + curve.finish()
        }
        XCTAssertNotEqual(path(0),path(0.5)); XCTAssertNotEqual(path(0.5),path(1))
    }

}
