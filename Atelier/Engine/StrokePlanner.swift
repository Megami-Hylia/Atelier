import Foundation
import simd

struct SeededGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 1 : seed }
    mutating func unit() -> Float {
        state ^= state >> 12; state ^= state << 25; state ^= state >> 27
        return Float((state &* 2685821657736338717) >> 40) / Float(1 << 24)
    }
    mutating func signed() -> Float { unit() * 2 - 1 }
}

// All SIMD4 fields have the same alignment as the Metal Stamp structure.
struct GPUStamp {
    var geometry: SIMD4<Float>
    var color: SIMD4<Float>
    var shape: SIMD4<Float>
    var grain: SIMD4<Float>
    var texture: SIMD4<Float>
    var pickup: SIMD4<Float>
    var rendering: SIMD4<Float>
    var variation: SIMD4<Float>
}

enum StrokePlanner {
    static func stamps(for stroke: PaintStroke, finished: Bool = true) throws -> [GPUStamp] {
        guard !stroke.samples.isEmpty else { return [] }
        let brush = stroke.brush
        func p(_ key: String, _ fallback: Double = 0) -> Float {
            let v = brush.value(key, fallback)
            return v.isFinite ? Float(max(-16, min(16, v))) : Float(fallback)
        }
        var rng = SeededGenerator(seed: stroke.seed ^ brush.seed)
        var samples = stroke.samples
        var previous = samples[0]
        let smoothing = min(0.98, p("streamline") * 0.6 + p("stabilization") * 0.35 + p("motionFiltering") * (1 - p("motionExpression") * 0.5) * 0.2)
        for i in samples.indices.dropFirst() {
            let value = samples[i]
            let dt = max(0.001, Float(value.time - previous.time))
            let gain = max(0.02, 1 - smoothing * exp(-dt * 30))
            samples[i].x = previous.x + (value.x - previous.x) * gain
            samples[i].y = previous.y + (value.y - previous.y) * gain
            samples[i].pressure = previous.pressure + (value.pressure - previous.pressure) * (1 - p("pressureSmoothing") * 0.95)
            previous = samples[i]
        }
        var lengths: [Float] = [0]
        for i in samples.indices.dropFirst() {
            lengths.append(lengths[i - 1] + hypot(samples[i].x - samples[i - 1].x, samples[i].y - samples[i - 1].y))
        }
        let total = max(1, lengths.last ?? 1)
        var stamps: [GPUStamp] = []
        var nextDistance: Float = 0
        var segment = 1
        let initialRotation = p("randomRotation") > 0 ? rng.unit() * .pi * 2 : 0
        let strokeHue = rng.signed() * p("strokeHue") * 0.5
        while nextDistance <= total && stamps.count < 100_000 {
            while segment < samples.count - 1 && lengths[segment] < nextDistance { segment += 1 }
            let a = samples[max(0, min(samples.count - 1, segment - 1))]
            let b = samples[min(samples.count - 1, segment)]
            let startDistance = lengths[max(0, segment - 1)]
            let segmentLength = max(0.001, lengths[min(lengths.count - 1, segment)] - startDistance)
            let t = min(1, max(0, (nextDistance - startDistance) / segmentLength))
            let point = SIMD2<Float>(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
            let pressure = pow(max(0, a.pressure + (b.pressure - a.pressure) * t), max(0.2, p("pressureCurve", 1)))
            let tilt = 1 - min(1, max(0, (a.altitude + (b.altitude - a.altitude) * t) / (.pi / 2)))
            let speed = min(1, segmentLength / max(0.001, Float(b.time - a.time)) / 1800)
            let direction = atan2(b.y - a.y, b.x - a.x)
            let along = SIMD2<Float>(cos(direction), sin(direction))
            let across = SIMD2<Float>(-along.y, along.x)
            let normalizedDistance = nextDistance / total
            let startTaper = p("taperStart") > 0 ? min(1, normalizedDistance / max(0.001, p("taperStart") * 0.5)) : 1
            let endTaper = finished && p("taperEnd") > 0 ? min(1, (1 - normalizedDistance) / max(0.001, p("taperEnd") * 0.5)) : 1
            let taper = max(0.015, min(startTaper, endTaper))
            let sizePressure = 1 - p("pressureSize") + p("pressureSize") * pressure
            let speedSize = max(0.02, 1 + p("speedSize") * speed)
            let diameter = max(0.1, min(2048, stroke.size * sizePressure * speedSize * (1 + tilt * p("tiltSize") * 3) *
                                   (1 - p("sizeJitter") * rng.unit()) * (1 - p("taperSize") + p("taperSize") * taper)))
            let radius = max(0.05, min(stroke.size * max(0.01, p("maxSize", 1)), max(stroke.size * p("minSize"), diameter)) / 2)
            let count = max(1, min(16, Int(p("stampCount", 1) * (1 - p("countJitter") * rng.unit()))))
            for _ in 0..<count {
                let offset = across * (rng.signed() * p("jitterLateral") * radius * 2) + along * (rng.signed() * p("jitterLinear") * radius * 2)
                var angle = direction * p("rotation") + initialRotation + rng.signed() * p("scatter") * .pi
                angle += direction * p("azimuth") * 0.25
                if a.isPencil {
                    angle += (a.azimuth + (b.azimuth - a.azimuth) * t) * p("azimuth")
                    angle += (a.roll + (b.roll - a.roll) * t) * p("barrelRoll")
                }
                let rx = max(0.02, (1 - p("roundnessJitterX") * rng.unit()) * (1 - p("pressureRoundness") * (1 - pressure) * 0.9))
                let ry = max(0.02, p("roundness", 1) * (1 - p("roundnessJitterY") * rng.unit()) * (1 - p("tiltRoundness") * tilt * 0.95))
                var alpha = stroke.opacity * stroke.color.w * p("opacity", 1) * p("flow", 1)
                alpha *= (1 - p("pressureOpacity") + p("pressureOpacity") * pressure)
                alpha *= (1 - p("pressureFlow") + p("pressureFlow") * pressure)
                alpha *= max(0, 1 + p("speedOpacity") * speed) * (1 - p("opacityJitter") * rng.unit())
                alpha *= (1 - p("tiltOpacity") * tilt) * (1 - p("taperOpacity") + p("taperOpacity") * taper)
                alpha *= exp(-p("fallOff") * normalizedDistance * 10) * (0.15 + p("accumulation", 1) * 0.85)
                let charge = p("wetCharge", 1)
                alpha *= max(0.01, 1 - p("wetDilution") * 0.9) * (0.05 + 0.95 * charge) * max(0.01, 1 - (1 - charge) * normalizedDistance * 0.95)
                alpha *= 1 + p("wetAttack") * pressure
                alpha = min(p("maxOpacity", 1), max(p("minOpacity"), alpha))
                let hsv = rgbToHSV(SIMD3<Float>(stroke.color.x, stroke.color.y, stroke.color.z))
                let hue = hsv.x + rng.signed() * (p("hueJitter") + p("stampHue")) * 0.5 + strokeHue
                let rgb = hsvToRGB(SIMD3<Float>(hue, min(1, max(0, hsv.y + rng.signed() * p("saturationJitter"))),
                                               min(1, max(0, hsv.z + rng.signed() * p("brightnessJitter")))))
                let previousPoint = segment > 0 ? SIMD2<Float>(a.x, a.y) : point
                var stamp = GPUStamp(
                    geometry: SIMD4(point.x + offset.x, point.y + offset.y, radius, angle),
                    color: SIMD4(rgb.x, rgb.y, rgb.z, max(0, min(1, alpha))),
                    shape: SIMD4(rx * (p("flipX") > 0.5 ? -1 : 1), ry * (p("flipY") > 0.5 ? -1 : 1), 0, 0),
                    grain: SIMD4(max(0.1, p("grainScale", 1)), min(1, p("grainDepth")), p("grainContrast", 1), p("grainBrightness")),
                    texture: SIMD4(p("grainMovement"), p("grainZoom", 1), p("grainRotation") * .pi, p("tiltGradation") * tilt),
                    pickup: SIMD4(point.x - previousPoint.x, point.y - previousPoint.y,
                                  min(1, p("wetDilution") + p("pressureBleed") * (1 - pressure)),
                                  stroke.tool == .smudge ? max(0.02, p("smudge", 0.7)) : p("wetPull")),
                    rendering: SIMD4(p("blendMode"), stroke.tool == .paint ? 0 : stroke.tool == .smudge ? 1 : 2, p("alphaThreshold"), p("wetGrade")),
                    variation: SIMD4(rng.unit(), 0, 0, 0))
                stamps.append(stamp)
                if p("dualEnabled") > 0.5 {
                    stamp.geometry.z *= max(0.1, p("dualScale", 0.6))
                    stamp.geometry.w += p("dualRotation") * .pi
                    stamp.color.w *= p("dualOpacity", 0.5)
                    stamps.append(stamp)
                }
            }
            let jitter = 1 + rng.signed() * p("spacingJitter") * 0.95
            nextDistance += max(0.15, radius * 2 * max(0.01, p("spacing", 0.08)) * jitter * (1 + p("speedSpacing") * speed))
            if samples.count == 1 { break }
        }
        guard nextDistance > total || samples.count == 1 else { throw DocumentError.strokeBudget }
        return stamps
    }

    private static func rgbToHSV(_ c: SIMD3<Float>) -> SIMD3<Float> {
        let maxC = max(c.x, max(c.y, c.z)), minC = min(c.x, min(c.y, c.z)), d = maxC - minC
        var h: Float = 0
        if d > 0.00001 {
            if maxC == c.x { h = (c.y - c.z) / d }
            else if maxC == c.y { h = (c.z - c.x) / d + 2 }
            else { h = (c.x - c.y) / d + 4 }
            h /= 6
        }
        return SIMD3(h, maxC > 0 ? d / maxC : 0, maxC)
    }
    private static func hsvToRGB(_ hsv: SIMD3<Float>) -> SIMD3<Float> {
        let h = (hsv.x - floor(hsv.x)) * 6, f = h - floor(h)
        let p = hsv.z * (1 - hsv.y), q = hsv.z * (1 - hsv.y * f), t = hsv.z * (1 - hsv.y * (1 - f))
        switch Int(h) % 6 {
        case 0: return SIMD3(hsv.z, t, p)
        case 1: return SIMD3(q, hsv.z, p)
        case 2: return SIMD3(p, hsv.z, t)
        case 3: return SIMD3(p, q, hsv.z)
        case 4: return SIMD3(t, p, hsv.z)
        default: return SIMD3(hsv.z, p, q)
        }
    }
}
