import Foundation
import simd

struct StrokeInputSampler {
    private var last: PencilSample?
    mutating func accept(_ sample: PencilSample, screenScale: Float, force: Bool = false) -> Bool {
        guard let last else { self.last = sample; return true }
        let distance = hypot(sample.x-last.x, sample.y-last.y)
        let attributeChange = abs(sample.pressure-last.pressure) > 0.008 || abs(sample.altitude-last.altitude) > 0.008 ||
            abs(StrokeGeometry.angleDelta(last.azimuth, sample.azimuth)) > 0.015 || abs(StrokeGeometry.angleDelta(last.roll, sample.roll)) > 0.015
        // A stationary hold must not keep adding identical points, even with new timestamps.
        guard distance > 0.00001 || attributeChange else { return false }
        let scale = max(0.0001, screenScale)
        let speed = distance * scale / max(0.001, Float(sample.time-last.time))
        let threshold = (0.25 + min(0.10, speed / 10_000)) / scale
        guard force || distance >= threshold || attributeChange else { return false }
        self.last = sample; return true
    }
}

enum StrokeGeometry {
    static func angleDelta(_ a: Float, _ b: Float) -> Float {
        atan2(sin(b-a), cos(b-a))
    }
    static func interpolate(_ a: PencilSample, _ b: PencilSample, t: Float) -> PencilSample {
        if t <= 0 { return a }; if t >= 1 { return b }
        var point = a
        point.x += (b.x-a.x)*t; point.y += (b.y-a.y)*t
        point.pressure += (b.pressure-a.pressure)*t; point.altitude += (b.altitude-a.altitude)*t
        point.azimuth = a.azimuth + angleDelta(a.azimuth,b.azimuth)*t
        point.roll = a.roll + angleDelta(a.roll,b.roll)*t
        point.time = a.time + (b.time-a.time)*Double(t)
        return point
    }
    static func isCorner(_ a: PencilSample, _ b: PencilSample, _ c: PencilSample) -> Bool {
        let incoming = SIMD2(b.x-a.x,b.y-a.y), outgoing = SIMD2(c.x-b.x,c.y-b.y)
        let lengths = simd_length(incoming)*simd_length(outgoing)
        return lengths > 0.000001 && simd_dot(incoming,outgoing)/lengths < 0.85
    }
    static func equivalentTrajectory(_ original: [PencilSample], _ candidate: [PencilSample], brush: BrushPreset,
                                     stabilization: Float, scale: Float, tolerance: Float, corrected: Bool = false) -> Bool {
        if original == candidate { return true }
        struct Cursor {
            var samples: [PencilSample]
            var curve: StrokeTrajectory
            var index = 0, pendingIndex = 0
            var pending: [PencilSample] = []
            var ended = false
            mutating func next() -> PencilSample? {
                while pendingIndex == pending.count {
                    guard !ended else { return nil }
                    pendingIndex = 0
                    if index < samples.count { pending = curve.append(samples[index]); index += 1 }
                    else { pending = curve.finish(); ended = true }
                }
                defer { pendingIndex += 1 }
                return pending[pendingIndex]
            }
        }
        func cursor(_ samples: [PencilSample]) -> Cursor {
            Cursor(samples: samples,curve: StrokeTrajectory(brush: brush,stabilization: stabilization,screenScale: scale, corrected: corrected))
        }
        // Compare as streams so a long pen-up cannot allocate two full flattened trajectories.
        func matches(_ from: [PencilSample], _ to: [PencilSample]) -> Bool {
            var source = cursor(from), target = cursor(to)
            guard var a = target.next() else { return source.next() == nil }
            var b = target.next()
            while let sample = source.next() {
                while let next = b, next.time < sample.time { a = next; b = target.next() }
                let end = b ?? a, dt = end.time-a.time
                let t = dt > 0 ? Float(min(1,max(0,(sample.time-a.time)/dt))) : 0
                let expected = interpolate(a,end,t: t)
                if hypot(sample.x-expected.x,sample.y-expected.y) > tolerance || abs(sample.pressure-expected.pressure) > 0.01 ||
                    abs(sample.altitude-expected.altitude) > 0.01 || abs(angleDelta(sample.azimuth,expected.azimuth)) > 0.02 ||
                    abs(angleDelta(sample.roll,expected.roll)) > 0.02 { return false }
            }
            return true
        }
        return matches(original,candidate) && matches(candidate,original)
    }

    static func simplify(_ samples: [PencilSample], tolerance: Float, pinned: Set<Int> = []) -> (samples: [PencilSample], retainedIndices: [Int]) {
        guard samples.count > 2 else { return (samples,Array(samples.indices)) }
        var keep = pinned.intersection(samples.indices)
        keep.insert(0); keep.insert(samples.count-1)
        for i in 1..<(samples.count-1) where isCorner(samples[i-1],samples[i],samples[i+1]) { keep.insert(i) }
        // Bounded spans prevent quadratic pen-up work for pathological long trajectories.
        for i in stride(from: 256, to: samples.count-1, by: 256) { keep.insert(i) }
        let anchors = keep.sorted()
        var stack = zip(anchors,anchors.dropFirst()).map { ($0.0,$0.1) }
        let epsilon = max(0.0001,tolerance)
        while let (start,end) = stack.popLast() {
            guard end-start > 1 else { continue }
            let a = samples[start], b = samples[end]
            let dx = b.x-a.x, dy = b.y-a.y, lengthSquared = dx*dx+dy*dy
            var worst: Float = 1; var candidate: Int?
            for i in (start+1)..<end {
                let sample = samples[i]
                let t: Float = lengthSquared > 0.000001 ? min(1,max(0,((sample.x-a.x)*dx+(sample.y-a.y)*dy)/lengthSquared)) :
                    Float((sample.time-a.time)/max(0.000001,b.time-a.time))
                let expected = interpolate(a,b,t: min(1,max(0,t)))
                var error = hypot(sample.x-expected.x,sample.y-expected.y)/epsilon
                error = max(error,abs(sample.pressure-expected.pressure)/0.008)
                error = max(error,abs(sample.altitude-expected.altitude)/0.008)
                error = max(error,abs(angleDelta(expected.azimuth,sample.azimuth))/0.015)
                error = max(error,abs(angleDelta(expected.roll,sample.roll))/0.015)
                error = max(error,Float(abs(sample.time-expected.time))/0.002)
                if error > worst { worst = error; candidate = i }
            }
            if let candidate { keep.insert(candidate); stack.append((start,candidate)); stack.append((candidate,end)) }
        }
        let indices = keep.sorted()
        return (indices.map { samples[$0] },indices)
    }
}

// Causal cubic interpolation: one control point of lookahead, flushed provisionally for display.
struct StrokeTrajectory {
    private var window: [PencilSample] = []
    private var preceding: PencilSample?
    private var lastRaw: PencilSample?
    private var beforeRaw: PencilSample?
    private var lastFiltered: PencilSample?
    private let strength: Float
    private let pressureSmoothing: Float
    private let scale: Float
    private var ended = false

    init(brush: BrushPreset, stabilization: Float, screenScale: Float, corrected: Bool = false) {
        let local = Float(brush.value("streamline"))*0.6 + Float(brush.value("stabilization"))*0.35 + Float(brush.value("motionFiltering"))*(1-Float(brush.value("motionExpression"))*0.5)*0.2
        let global = min(1,max(0,stabilization))
        let localAmount = min(1,max(0,local))
        strength = corrected ? 1-(1-global)*(1-localAmount) : min(1,max(0,max(stabilization,local)))
        pressureSmoothing = min(1,max(0,Float(brush.value("pressureSmoothing"))))
        scale = max(0.0001,screenScale)
    }
    mutating func append(_ raw: PencilSample) -> [PencilSample] {
        guard !ended else { return [] }
        var value = raw
        if let lastRaw, let filtered = lastFiltered {
            let corner = beforeRaw.map { before in
                let shortest = min(hypot(lastRaw.x-before.x,lastRaw.y-before.y),hypot(raw.x-lastRaw.x,raw.y-lastRaw.y))*scale
                return shortest >= 0.75+strength*1.25 && StrokeGeometry.isCorner(before,lastRaw,raw)
            } ?? false
            var origin = filtered
            if corner {
                origin.x = lastRaw.x; origin.y = lastRaw.y
                if !window.isEmpty { window[window.count-1].x = lastRaw.x; window[window.count-1].y = lastRaw.y }
            }
            let dt = max(0.001,Float(raw.time-lastRaw.time))
            let speed = hypot(raw.x-lastRaw.x,raw.y-lastRaw.y)*scale/dt
            let cutoff = 35 - 32*strength + speed*0.04
            let gain = strength == 0 || corner ? 1 : 1-exp(-2*Float.pi*cutoff*dt)
            value.x = origin.x+(raw.x-origin.x)*gain; value.y = origin.y+(raw.y-origin.y)*gain
            let pressureGain = pressureSmoothing == 0 ? 1 : 1-exp(-2*Float.pi*(45-39*pressureSmoothing)*dt)
            value.pressure = filtered.pressure+(raw.pressure-filtered.pressure)*pressureGain
        }
        beforeRaw = lastRaw; lastRaw = raw; lastFiltered = value
        window.append(value)
        if window.count == 1 { return [value] }
        guard window.count == 3 else { return [] }
        let output = flatten(preceding,window[0],window[1],window[2])
        preceding = window.removeFirst()
        return output
    }
    mutating func finish() -> [PencilSample] {
        guard !ended else { return [] }
        ended = true
        guard window.count >= 2 else { return [] }
        // Exact pen-up endpoint prevents a stabilized stroke from ending behind the pen.
        if let lastRaw { window[window.count-1].x = lastRaw.x; window[window.count-1].y = lastRaw.y }
        return flatten(preceding,window[0],window[1],nil)
    }
    private func flatten(_ previous: PencilSample?, _ a: PencilSample, _ b: PencilSample, _ next: PencilSample?) -> [PencilSample] {
        let p = SIMD2(a.x,a.y), q = SIMD2(b.x,b.y), chord = q-p
        let distance = simd_length(chord)
        guard distance > 0.00001 else { return [b] }
        func tangent(_ before: PencilSample?, _ center: PencilSample, _ after: PencilSample?, fallback: SIMD2<Float>) -> SIMD2<Float> {
            guard let before, let after else { return fallback }
            if StrokeGeometry.isCorner(before,center,after) { return .zero }
            let vector = SIMD2(after.x-before.x,after.y-before.y)*0.5
            let length = simd_length(vector)
            return vector * min(1,distance*0.5/max(0.00001,length))
        }
        let t0 = tangent(previous,a,b,fallback: chord)
        let t1 = tangent(a,b,next,fallback: chord)
        let lower = simd_min(p,q), upper = simd_max(p,q)
        let c0 = simd_clamp(p+t0/3,lower,upper), c1 = simd_clamp(q-t1/3,lower,upper)
        func point(_ t: Float) -> SIMD2<Float> {
            let u = 1-t
            return p*(u*u*u)+c0*(3*u*u*t)+c1*(3*u*t*t)+q*(t*t*t)
        }
        let tolerance = 0.12/scale
        var stack: [(Float,Float,Int)] = [(0,1,0)]
        var output: [PencilSample] = []
        while let (start,end,depth) = stack.popLast() {
            let pa = point(start), pb = point(end)
            let span = pb-pa, length = max(0.000001,simd_length_squared(span))
            var error: Float = 0
            for fraction in [Float(0.25),0.5,0.75] {
                let value = point(start+(end-start)*fraction)
                let projected = pa+span*min(1,max(0,simd_dot(value-pa,span)/length))
                error = max(error,simd_length(value-projected))
            }
            if error > tolerance && depth < 10 {
                let middle = (start+end)*0.5
                stack.append((middle,end,depth+1)); stack.append((start,middle,depth+1))
            } else {
                var sample = StrokeGeometry.interpolate(a,b,t: end)
                let position = point(end); sample.x = position.x; sample.y = position.y
                output.append(sample)
            }
        }
        return output
    }
}
