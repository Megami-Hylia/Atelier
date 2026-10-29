import Foundation
import Testing
@testable import Atelier

@MainActor
struct StrokeGeometryTests {
    private func sample(_ x: Float, _ y: Float, _ time: Double, pressure: Float = 0.5) -> PencilSample {
        PencilSample(x: x, y: y, pressure: pressure, time: time)
    }

    private func trajectory(_ samples: [PencilSample], amount: Float = 0, scale: Float = 1) -> [PencilSample] {
        var curve = StrokeTrajectory(brush: .fallback, stabilization: amount, screenScale: scale)
        var result: [PencilSample] = []
        for point in samples { result += curve.append(point) }
        result += curve.finish()
        return result
    }

    private func segmentDistance(_ point: PencilSample, _ a: PencilSample, _ b: PencilSample) -> Float {
        let dx = b.x-a.x, dy = b.y-a.y
        let square = dx*dx+dy*dy
        let t = square > 0 ? min(1,max(0,((point.x-a.x)*dx+(point.y-a.y)*dy)/square)) : 0
        return hypot(point.x-a.x-t*dx,point.y-a.y-t*dy)
    }

    @Test func duplicateGeometryIsDiscardedButStationaryPressureAndTiltRemain() {
        var sampler = StrokeInputSampler()
        let first = sample(10,20,0,pressure: 0.2)
        let initialAccepted = sampler.accept(first,screenScale: 1)
        #expect(initialAccepted)
        let duplicateAccepted = sampler.accept(first,screenScale: 1)
        #expect(!duplicateAccepted)
        var stationary = first; stationary.time = 3
        let stationaryAccepted = sampler.accept(stationary,screenScale: 1)
        #expect(!stationaryAccepted, "Holding still must not accumulate identical points.")
        stationary.pressure = 0.9
        let pressureAccepted = sampler.accept(stationary,screenScale: 1)
        #expect(pressureAccepted)
        stationary.altitude = 0.4; stationary.time += 0.001
        let tiltAccepted = sampler.accept(stationary,screenScale: 1)
        #expect(tiltAccepted)
        stationary.azimuth = 0.3; stationary.time += 0.001
        let azimuthAccepted = sampler.accept(stationary,screenScale: 1)
        #expect(azimuthAccepted)
        stationary.roll = 0.3; stationary.time += 0.001
        let rollAccepted = sampler.accept(stationary,screenScale: 1)
        #expect(rollAccepted)
    }

    @Test func nearDuplicateFilteringAndPenUpPreserveTheExactEndpoint() {
        var sampler = StrokeInputSampler()
        let first = sample(0,0,0)
        let initialAccepted = sampler.accept(first,screenScale: 1)
        #expect(initialAccepted)
        let near = sample(0.000001,0,0.001)
        let nearAccepted = sampler.accept(near,screenScale: 1)
        #expect(!nearAccepted)
        let final = sample(0.0001,0,0.002)
        let endpointAccepted = sampler.accept(final,screenScale: 1,force: true)
        #expect(endpointAccepted)
    }

    @Test func acquisitionHasTheSameDisplayedDensityAcrossZoomLevels() {
        var counts: [Int] = []
        for scale in [Float(0.25),1,8] {
            var sampler = StrokeInputSampler(); var kept = 0
            for i in 0...1000 {
                let point = sample(Float(i)*0.01/scale,0,Double(i)/240)
                if sampler.accept(point,screenScale: scale,force: i == 1000) { kept += 1 }
            }
            counts.append(kept)
        }
        #expect((counts.max() ?? 0)-(counts.min() ?? 0) <= 2)
        #expect((counts.max() ?? 1001) < 100, "Subpixel duplicates should be greatly reduced.")
        #expect((counts.min() ?? 0) > 2, "Sampling must not collapse all detail into endpoints.")
    }

    @Test func simplificationBoundsGeometryErrorAndRetainsPinnedSamples() {
        let raw = (0...1000).map { i in sample(Float(i)*0.1,64+sin(Float(i)*0.3)*0.04,Double(i)/240) }
        let result = StrokeGeometry.simplify(raw,tolerance: 0.2,pinned: [123,500,876,-1,1001])
        #expect(result.retainedIndices.first == 0)
        #expect(result.retainedIndices.last == 1000)
        #expect(Set([123,500,876]).isSubset(of: Set(result.retainedIndices)))
        #expect(result.samples.count < raw.count/10)
        #expect(result.samples == result.retainedIndices.map { raw[$0] })
        #expect(zip(result.retainedIndices,result.retainedIndices.dropFirst()).allSatisfy { $0 < $1 })
        for point in raw {
            let error = zip(result.samples,result.samples.dropFirst()).map { segmentDistance(point,$0,$1) }.min() ?? .infinity
            #expect(error <= 0.2001)
        }
    }

    @Test func simplificationPreservesPressureAndTiltPeaksWithoutPinnedIndices() {
        let raw = (0...100).map { i -> PencilSample in
            var point = sample(Float(i),0,Double(i)/240,pressure: i == 50 ? 0.95 : 0.2)
            point.altitude = i == 70 ? 0.3 : 1.3
            return point
        }
        let result = StrokeGeometry.simplify(raw,tolerance: 0.3)
        #expect(result.retainedIndices.contains(50))
        #expect(result.retainedIndices.contains(70))
        #expect(result.samples.contains { $0.pressure == 0.95 })
        #expect(result.samples.contains { $0.altitude == 0.3 })
    }

    @Test func tapsShortAndFastStrokesRemainFiniteAndEndAtThePenUpPoint() {
        var dot = StrokeTrajectory(brush: .fallback,stabilization: 0,screenScale: 1)
        let point = sample(12,24,0)
        let dotStart = dot.append(point), dotEnd = dot.finish(), repeatedEnd = dot.finish()
        #expect(dotStart == [point])
        #expect(dotEnd.isEmpty)
        #expect(repeatedEnd.isEmpty)
        for raw in [
            [sample(0,0,0),sample(0.001,0.002,0.001)],
            [sample(0,0,0),sample(2000,1000,0.001)],
            [sample(1,1,0),sample(1,1,0,pressure: 0.9)]
        ] {
            let output = trajectory(raw)
            #expect(output.first?.x == raw.first?.x)
            #expect(output.first?.y == raw.first?.y)
            #expect(output.last?.x == raw.last?.x)
            #expect(output.last?.y == raw.last?.y)
            #expect(output.allSatisfy { [$0.x,$0.y,$0.pressure,$0.altitude,$0.azimuth,$0.roll].allSatisfy(\.isFinite) && $0.time.isFinite })
        }
    }

    @Test func interpolationPreservesRightAnglesAndSmallClosedDetails() {
        let corner = [sample(0,0,0),sample(10,0,1),sample(10,10,2),sample(20,10,3)]
        let output = trajectory(corner)
        #expect(output.contains { hypot($0.x-10,$0.y) <= 0.001 })
        #expect(output.contains { hypot($0.x-10,$0.y-10) <= 0.001 })
        for point in output {
            let error = zip(corner,corner.dropFirst()).map { segmentDistance(point,$0,$1) }.min() ?? .infinity
            #expect(error <= 0.35)
        }
        let loop = [sample(0,0,0),sample(2,0,1),sample(2,2,2),sample(0,2,3),sample(0,0,4)]
        let loopOutput = trajectory(loop)
        #expect(loopOutput.contains { $0.x >= 1.9 && $0.y >= 1.9 })
        #expect(loopOutput.last?.x == 0 && loopOutput.last?.y == 0)
    }

    @Test func attributesStayContinuousAndAnglesTakeTheShortestPath() {
        var a = sample(0,0,0,pressure: 0.1); a.azimuth = .pi-0.05; a.roll = .pi-0.05; a.altitude = 1.5
        var b = sample(10,1,1,pressure: 0.5); b.azimuth = -.pi+0.05; b.roll = -.pi+0.05; b.altitude = 0.8
        var c = sample(20,0,2,pressure: 0.9); c.azimuth = -.pi+0.15; c.roll = -.pi+0.15; c.altitude = 0.4
        let output = trajectory([a,b,c],scale: 8)
        #expect(output.allSatisfy { $0.pressure >= 0.0999 && $0.pressure <= 0.9001 })
        #expect(output.allSatisfy { abs($0.azimuth) > 2.8 && abs($0.roll) > 2.8 })
        #expect(zip(output,output.dropFirst()).allSatisfy { $1.time >= $0.time && $1.pressure >= $0.pressure-0.0001 })
        #expect(abs((output.last?.pressure ?? 0)-c.pressure) < 0.0001)
        #expect(abs((output.last?.altitude ?? 0)-c.altitude) < 0.0001)
    }

    @Test func highStabilizationReducesSmallJitterRatherThanOnlyAddingLag() {
        let raw = (0..<256).map { i in sample(Float(i),64+sin(Float(i)*0.4)*0.4,Double(i)/240) }
        func rms(_ points: [PencilSample]) -> Float {
            let middle = points.filter { $0.time > 0.15 && $0.time < 0.8 }
            return sqrt(middle.reduce(Float(0)) { $0+($1.y-64)*($1.y-64) }/Float(max(1,middle.count)))
        }
        let low = rms(trajectory(raw,amount: 0))
        let high = rms(trajectory(raw,amount: 0.95))
        #expect(high < low*0.95)
    }

    @Test func motionExpressionPreservesMoreSmallHandMovementWhenMotionFilteringIsActive() {
        // Subpixel legs stay below the corner-reset threshold for both settings.
        let raw = (0..<256).map { i in sample(Float(i)*0.25,64+sin(Float(i)*0.4)*0.1,Double(i)/240) }
        func filtered(expression: Double) -> [PencilSample] {
            var brush = BrushPreset.fallback
            brush.parameters["streamline"] = 0
            brush.parameters["stabilization"] = 0
            brush.parameters["motionFiltering"] = 1
            brush.parameters["motionExpression"] = expression
            var curve = StrokeTrajectory(brush: brush,stabilization: 0,screenScale: 1)
            var output: [PencilSample] = []
            for point in raw { output += curve.append(point) }
            output += curve.finish()
            return output
        }
        func errorFromRaw(_ output: [PencilSample]) -> Float {
            let middle = output.filter { $0.time > 40.0/240 && $0.time < 200.0/240 }
            return middle.reduce(Float(0)) { total,point in
                let rawY = 64+sin(Float(point.time*240)*0.4)*0.1
                return total+abs(point.y-rawY)
            }/Float(max(1,middle.count))
        }
        let restrained = filtered(expression: 0)
        let expressive = filtered(expression: 1)
        #expect(errorFromRaw(expressive) < errorFromRaw(restrained)*0.98)
        for output in [restrained,expressive] {
            #expect(output.first == raw.first)
            #expect(output.last?.x == raw.last?.x)
            #expect(output.last?.y == raw.last?.y)
        }
    }

    @Test func provisionalClonesCannotChangePersistentTrajectoryOrDuplicateTheTail() {
        let raw = (0..<100).map { i in sample(Float(i),sin(Float(i)*0.08)*4,Double(i)/240) }
        var curve = StrokeTrajectory(brush: .fallback,stabilization: 0.5,screenScale: 1)
        var output: [PencilSample] = []
        for point in raw.prefix(50) { output += curve.append(point) }
        var predicted = curve
        _ = predicted.append(sample(1000,1000,10)); _ = predicted.finish()
        for point in raw.dropFirst(50) { output += curve.append(point) }
        output += curve.finish()
        #expect(curve.finish().isEmpty)
        #expect(output == trajectory(raw,amount: 0.5))
    }

    @Test func curvePlannerPacketsAndFinalFlushMatchWholeReplayIncludingCombinedBrushes() throws {
        var primary = BrushPreset.fallback
        primary.parameters["streamline"] = 0.1
        primary.parameters["pressureSize"] = 0.8
        primary.parameters["hueJitter"] = 0.2
        var secondary = primary
        secondary.id = "geometry-secondary"; secondary.shape = "bristle"; secondary.grain = "canvas"
        secondary.parameters["streamline"] = 0.9
        secondary.parameters["spacing"] = 0.2
        secondary.parameters["pressureSmoothing"] = 0.7
        let raw = (0..<120).map { i -> PencilSample in
            var point = sample(Float(i)*1.7,sin(Float(i)*0.1)*8,1_000_000+Double(i)/240,
                pressure: 0.2+0.7*pow(sin(Float(i)/119*Float.pi),2))
            point.altitude = 0.5+Float(i)/240
            return point
        }
        for combined in [false,true] {
            var brush = primary
            if combined { brush.secondaryBrushes = [secondary]; brush.combineMode = 8 }
            var stroke = PaintStroke(brush: brush,tool: .paint,color: SIMD4(0.2,0.5,0.7,1),size: 24,opacity: 0.8,
                samples: raw,seed: 73,distanceDynamicsVersion: 1)
            stroke.curveVersion = 1; stroke.inputScale = 2; stroke.stabilizationAmount = 0.2
            let expected = try StrokePlanner.stamps(for: stroke,finished: false)
            #expect(!expected.isEmpty)
            if combined { #expect(expected.contains { $0.variation.y == 1 }) }
            for packet in [1,2,7,32,64] {
                var stream = StrokePlanner.Stream(stroke)
                var actual: [GPUStamp] = []
                for first in stride(from: 0,to: raw.count,by: packet) {
                    actual += try stream.append(raw[first..<min(first+packet,raw.count)])
                }
                actual += try stream.flushEnd()
                #expect(actual == expected,"Packet boundaries must not change a curved brush or component ordering.")
                let repeatedEnd = try stream.flushEnd()
                #expect(repeatedEnd.isEmpty)
                #expect(stream.sampleCount == raw.count)
            }
        }
    }

    @Test func stationaryPressurePeakProducesAnImprintWithThePeakWidth() throws {
        var brush = BrushPreset.fallback
        brush.parameters["pressureSize"] = 1
        brush.parameters["pressureCurve"] = 1
        let raw = [sample(32,32,0,pressure: 0.2),sample(32,32,0.01,pressure: 0.9),sample(32,32,0.02,pressure: 0.2)]
        var stroke = PaintStroke(brush: brush,tool: .paint,color: SIMD4(0,0,0,1),size: 32,opacity: 1,
            samples: raw,seed: 9,distanceDynamicsVersion: 1)
        stroke.curveVersion = 1; stroke.inputScale = 1; stroke.stabilizationAmount = 0
        let stamps = try StrokePlanner.stamps(for: stroke,finished: false)
        #expect(stamps.count >= 2)
        #expect((stamps.map { $0.geometry.z }.max() ?? 0) >= 14)
        #expect((stamps.map { $0.geometry.z }.min() ?? 100) <= 3.21)
        #expect(stamps.allSatisfy { $0.geometry.x == 32 && $0.geometry.y == 32 })
    }

    @Test func plannerDoesNotSpinAzimuthOrRollAcrossTheAngleWrap() throws {
        var brush = BrushPreset.fallback
        brush.parameters["azimuth"] = 1; brush.parameters["barrelRoll"] = 1
        brush.parameters["pressureSize"] = 0; brush.parameters["spacing"] = 0.1
        var a = sample(0,0,0); a.azimuth = .pi-0.05; a.roll = .pi-0.05
        var b = sample(10,0,1); b.azimuth = -.pi+0.05; b.roll = -.pi+0.05
        var c = sample(20,0,2); c.azimuth = -.pi+0.15; c.roll = -.pi+0.15
        var stroke = PaintStroke(brush: brush,tool: .paint,color: SIMD4(0,0,0,1),size: 4,opacity: 1,
            samples: [a,b,c],seed: 2,distanceDynamicsVersion: 1)
        stroke.curveVersion = 1; stroke.inputScale = 1; stroke.stabilizationAmount = 0
        let stamps = try StrokePlanner.stamps(for: stroke,finished: false)
        let angularTravel = zip(stamps,stamps.dropFirst()).reduce(Float(0)) { sum,pair in
            sum+abs(StrokeGeometry.angleDelta(pair.0.geometry.w,pair.1.geometry.w))
        }
        #expect(stamps.count > 4)
        #expect(angularTravel < 1,"An orientation wrap must not introduce full rotations.")
    }

    @Test func emptyAndSinglePointSimplificationAreSafe() {
        #expect(StrokeGeometry.simplify([],tolerance: 0.2).samples.isEmpty)
        let point = sample(3,7,0)
        let result = StrokeGeometry.simplify([point],tolerance: 0.2)
        #expect(result.samples == [point])
        #expect(result.retainedIndices == [0])
    }
}
