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
struct GPUStamp: Equatable {
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
    static func tileBins(_ stamps: [GPUStamp], width: Int, height: Int) throws -> [Int: [GPUStamp]] {
        let tileSize = 256, columns = (width + tileSize - 1) / tileSize
        var bins: [Int: [GPUStamp]] = [:]
        var entryCount = 0
        for stamp in stamps {
            let extent = stamp.geometry.z * 1.5
            let x0 = max(0, Int(floor((stamp.geometry.x - extent) / Float(tileSize))))
            let y0 = max(0, Int(floor((stamp.geometry.y - extent) / Float(tileSize))))
            let x1 = min(columns - 1, Int(floor((stamp.geometry.x + extent) / Float(tileSize))))
            let y1 = min((height - 1) / tileSize, Int(floor((stamp.geometry.y + extent) / Float(tileSize))))
            guard x1 >= x0, y1 >= y0 else { continue }
            entryCount += (x1 - x0 + 1) * (y1 - y0 + 1)
            guard entryCount <= 262_144 else { throw DocumentError.strokeBudget }
            for y in y0...y1 { for x in x0...x1 { bins[y * columns + x, default: []].append(stamp) } }
        }
        return bins
    }

    static func stamps(for stroke: PaintStroke, finished: Bool = true) throws -> [GPUStamp] {
        // Saved strokes retain the original total-length-relative dynamics.
        guard stroke.distanceDynamicsVersion == 1 else { return try legacyStamps(for: stroke, finished: finished) }
        var stream = Stream(stroke, finalDistance: finished ? pathLength(stroke) : nil)
        var stamps = try stream.append(stroke.samples[...])
        stamps += try stream.flushEnd()
        return stroke.samples.count == 1 && stroke.curveVersion != 1 ? try stream.dot() : stamps
    }

    static func replayStream(for stroke: PaintStroke, finished: Bool = true) -> Stream {
        Stream(stroke, finalDistance: finished ? pathLength(stroke) : nil)
    }

    static func validateForRendering(_ stroke: PaintStroke, width: Int, height: Int) throws {
        guard stroke.distanceDynamicsVersion == 1 else {
            _ = try tileBins(stamps(for: stroke), width: width, height: height); return
        }
        var cursor = replayStream(for: stroke)
        for start in stride(from: 0, to: stroke.samples.count, by: 8) {
            let batch = try cursor.append(stroke.samples[start..<min(start+8, stroke.samples.count)])
            _ = try tileBins(batch, width: width, height: height)
        }
        _ = try tileBins(cursor.flushEnd(), width: width, height: height)
        if stroke.samples.count == 1 && stroke.curveVersion != 1 { _ = try tileBins(cursor.dot(), width: width, height: height) }
    }

    private static func pathLength(_ stroke: PaintStroke) -> Float {
        if stroke.curveVersion == 1 {
            var curve = StrokeTrajectory(brush: stroke.brush, stabilization: stroke.stabilizationAmount ?? 0, screenScale: stroke.inputScale ?? 1)
            var previous: PencilSample?; var distance: Float = 0
            func consume(_ samples: [PencilSample]) {
                for sample in samples {
                    if let previous { distance += hypot(sample.x-previous.x,sample.y-previous.y) }
                    previous = sample
                }
            }
            for sample in stroke.samples { consume(curve.append(sample)) }
            consume(curve.finish()); return distance
        }
        var previous: PencilSample?
        var distance: Float = 0
        for raw in stroke.samples {
            let value = smooth(raw, after: previous, brush: stroke.brush)
            if let previous { distance += hypot(value.x - previous.x, value.y - previous.y) }
            previous = value
        }
        return distance
    }

    private static func smooth(_ raw: PencilSample, after previous: PencilSample?, brush: BrushPreset) -> PencilSample {
        guard let previous else { return raw }
        func p(_ key: String) -> Float { Float(brush.value(key)) }
        let smoothing = min(0.98, p("streamline") * 0.6 + p("stabilization") * 0.35 + p("motionFiltering") * (1 - p("motionExpression") * 0.5) * 0.2)
        let dt = max(0.001, Float(raw.time - previous.time))
        let gain = max(0.02, 1 - smoothing * exp(-dt * 30))
        var value = raw
        value.x = previous.x + (raw.x - previous.x) * gain
        value.y = previous.y + (raw.y - previous.y) * gain
        value.pressure = previous.pressure + (raw.pressure - previous.pressure) * (1 - p("pressureSmoothing") * 0.95)
        return value
    }

    // The cursor retains constant-size state, never the growing sample array.
    struct Stream {
        private var secondary: [Stream] = []
        private var trajectory: StrokeTrajectory?
        private var lastStampPoint: SIMD2<Float>?
        private let settings: PlannedBrushSettings
        private let hsv: SIMD3<Float>
        private var context: PaintStroke
        private var rng: SeededGenerator
        private var initialRotation: Float = 0
        private var strokeHue: Float = 0
        private let finalDistance: Float?
        private var previous: PencilSample?
        private var distance: Float = 0
        private var nextDistance: Float = 0
        private var firstInputTime: Double?
        private var stampCount = 0
        var strokeID: UUID { context.id }
        private(set) var sampleCount = 0
        private(set) var lastRawSample: PencilSample?

        init(_ stroke: PaintStroke, finalDistance: Float? = nil) {
            settings = PlannedBrushSettings(stroke.brush, corrected: stroke.brushSettingsVersion == 1)
            hsv = StrokePlanner.rgbToHSV(SIMD3(stroke.color.x, stroke.color.y, stroke.color.z))
            context = stroke; context.samples = []
            rng = SeededGenerator(seed: stroke.seed ^ stroke.brush.seed)
            self.finalDistance = finalDistance
            trajectory = stroke.curveVersion == 1 ? StrokeTrajectory(brush: stroke.brush, stabilization: stroke.stabilizationAmount ?? 0, screenScale: stroke.inputScale ?? 1) : nil
            initialRotation = settings.randomRotation > 0 ? rng.unit() * .pi * 2 : 0
            strokeHue = rng.signed() * settings.strokeHue * 0.5
            if var brush = stroke.brush.secondaryBrushes?.first {
                brush.parameters["blendMode"] = Double(stroke.brush.combineMode ?? 0)
                var component = stroke; component.brush = brush
                let componentDistance = finalDistance == nil ? nil : StrokePlanner.pathLength(component)
                component.samples = []
                secondary = [Stream(component, finalDistance: componentDistance)]
            }
        }

        func matches(_ stroke: PaintStroke) -> Bool {
            context.id == stroke.id && context.brush == stroke.brush && context.tool == stroke.tool &&
            context.color == stroke.color && context.size == stroke.size && context.opacity == stroke.opacity && context.seed == stroke.seed && context.distanceDynamicsVersion == stroke.distanceDynamicsVersion && context.curveVersion == stroke.curveVersion && context.inputScale == stroke.inputScale && context.stabilizationAmount == stroke.stabilizationAmount && context.brushSettingsVersion == stroke.brushSettingsVersion
        }

        mutating func append(_ samples: ArraySlice<PencilSample>) throws -> [GPUStamp] {
            var result: [GPUStamp] = []
            for raw in samples {
                if firstInputTime == nil { firstInputTime = raw.time }
                if trajectory != nil {
                    for value in trajectory!.append(raw) { result += try consume(value) }
                } else { result += try consume(StrokePlanner.smooth(raw, after: previous, brush: context.brush)) }
                lastRawSample = raw; sampleCount += 1
            }
            if !secondary.isEmpty {
                let extra = try secondary[0].append(samples).map { stamp -> GPUStamp in var value = stamp; value.variation.y = 1; return value }
                result += extra
                sortComponents(&result)
                guard result.count <= 100_000 else { throw DocumentError.strokeBudget }
            }
            return result
        }

        private mutating func consume(_ value: PencilSample) throws -> [GPUStamp] {
            var result: [GPUStamp] = []
            if let a = previous {
                let length = hypot(value.x-a.x,value.y-a.y)
                let segmentLength = max(0.001,length), end = distance+length
                if context.curveVersion != 1 || length > 0.00001 {
                    while nextDistance <= end {
                        let t = min(1,max(0,(nextDistance-distance)/segmentLength))
                        result += try makeStamps(a: a,b: value,t: t,segmentLength: segmentLength)
                    }
                } else if abs(value.pressure-a.pressure) > 0.008 || abs(value.altitude-a.altitude) > 0.008 ||
                    abs(StrokeGeometry.angleDelta(a.azimuth,value.azimuth)) > 0.015 || abs(StrokeGeometry.angleDelta(a.roll,value.roll)) > 0.015 {
                    // Pressure/tilt can change while the tip stays still. Deposit that change
                    // without consuming the arc-length phase of the next moving segment.
                    let phase = nextDistance
                    nextDistance = distance
                    result += try makeStamps(a: a,b: value,t: 1,segmentLength: segmentLength)
                    nextDistance = phase
                }
                distance = end
            }
            previous = value
            return result
        }

        mutating func flushEnd() throws -> [GPUStamp] {
            guard trajectory != nil else { return [] }
            var result: [GPUStamp] = []
            for value in trajectory!.finish() { result += try consume(value) }
            if stampCount == 0, let previous { result += try makeStamps(a: previous,b: previous,t: 0,segmentLength: 0.001) }
            if !secondary.isEmpty {
                result += try secondary[0].flushEnd().map { stamp -> GPUStamp in var value = stamp; value.variation.y = 1; return value }
                sortComponents(&result)
            }
            return result
        }

        private func sortComponents(_ stamps: inout [GPUStamp]) {
            // Components may have different stabilization and therefore different path lengths.
            // Input-relative time keeps their order identical across live/replay packet sizes.
            let component = context.curveVersion == 1 ? 3 : 2
            stamps.sort {
                $0.variation[component] == $1.variation[component] ? $0.variation.y < $1.variation.y : $0.variation[component] < $1.variation[component]
            }
        }

        mutating func dot() throws -> [GPUStamp] {
            guard let previous else { return [] }
            var result = try makeStamps(a: previous, b: previous, t: 0, segmentLength: 0.001)
            if !secondary.isEmpty { result += try secondary[0].dot().map { stamp -> GPUStamp in var value = stamp; value.variation.y = 1; return value } }
            return result
        }

        private mutating func makeStamps(a: PencilSample, b: PencilSample, t: Float, segmentLength: Float) throws -> [GPUStamp] {
            var stamps: [GPUStamp] = []
            let point = SIMD2<Float>(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t)
            let pressure = pow(max(0, a.pressure + (b.pressure - a.pressure) * t), max(0.2, settings.pressureCurve))
            let tilt = 1 - min(1, max(0, (a.altitude + (b.altitude - a.altitude) * t) / (.pi / 2)))
            let speed = min(1, segmentLength / max(0.001, Float(b.time - a.time)) / 1800)
            let direction = atan2(b.y - a.y, b.x - a.x)
            let along = SIMD2<Float>(cos(direction), sin(direction))
            let across = SIMD2<Float>(-along.y, along.x)
            let normalizedDistance = nextDistance / max(1, context.size * 10)
            let startTaper = settings.taperStart > 0 ? min(1, normalizedDistance / max(0.001, settings.taperStart * 0.5)) : 1
            let endProgress = finalDistance.map { nextDistance / max(1, $0) } ?? 0
            let endTaper = finalDistance != nil && settings.taperEnd > 0 ? min(1, (1 - endProgress) / max(0.001, settings.taperEnd * 0.5)) : 1
            let taper = max(0.015, min(startTaper, endTaper))
            let sizePressure = 1 - settings.pressureSize + settings.pressureSize * pressure
            let speedSize = max(0.02, 1 + settings.speedSize * speed)
            let diameter = max(0.1, min(2048, context.size * sizePressure * speedSize * (1 + tilt * settings.tiltSize * 3) *
                                   (1 - settings.sizeJitter * rng.unit()) * (1 - settings.taperSize + settings.taperSize * taper)))
            let radius = max(0.05, min(context.size * max(0.01, settings.maxSize), max(context.size * min(settings.minSize, settings.maxSize), diameter)) / 2)
            let previousPoint = context.curveVersion == 1 ? lastStampPoint ?? point : SIMD2<Float>(a.x,a.y)
            let count = max(1, min(16, Int(settings.stampCount * (1 - settings.countJitter * rng.unit()))))
            for _ in 0..<count {
                let offset = across * (rng.signed() * settings.jitterLateral * radius * 2) + along * (rng.signed() * settings.jitterLinear * radius * 2)
                var angle = direction * settings.rotation + initialRotation + rng.signed() * settings.scatter * .pi
                if context.brushSettingsVersion != 1 { angle += direction * settings.azimuth * 0.25 }
                if a.isPencil {
                    angle += (a.azimuth + (context.curveVersion == 1 ? StrokeGeometry.angleDelta(a.azimuth,b.azimuth) : b.azimuth-a.azimuth) * t) * settings.azimuth
                    angle += (a.roll + (context.curveVersion == 1 ? StrokeGeometry.angleDelta(a.roll,b.roll) : b.roll-a.roll) * t) * settings.barrelRoll
                }
                let rx = max(0.02, (1 - settings.roundnessJitterX * rng.unit()) * (1 - settings.pressureRoundness * (1 - pressure) * 0.9))
                let ry = max(0.02, settings.roundness * (1 - settings.roundnessJitterY * rng.unit()) * (1 - settings.tiltRoundness * tilt * 0.95))
                var alpha = context.opacity * context.color.w * settings.opacity * settings.flow
                alpha *= (1 - settings.pressureOpacity + settings.pressureOpacity * pressure)
                alpha *= (1 - settings.pressureFlow + settings.pressureFlow * pressure)
                alpha *= max(0, 1 + settings.speedOpacity * speed) * (1 - settings.opacityJitter * rng.unit())
                alpha *= (1 - settings.tiltOpacity * tilt) * (1 - settings.taperOpacity + settings.taperOpacity * taper)
                alpha *= exp(-settings.fallOff * normalizedDistance * 10) * (context.brushSettingsVersion == 1 ? 1 : (0.15 + settings.accumulation * 0.85))
                let charge = settings.wetCharge
                alpha *= max(0.01, 1 - settings.wetDilution * 0.9) * (context.brushSettingsVersion == 1 ? charge : (0.05 + 0.95 * charge)) * max(0.01, 1 - (1 - charge) * normalizedDistance * 0.95)
                if context.brushSettingsVersion != 1 || settings.wetDilution > 0 || settings.wetPull > 0 || charge < 1 {
                    alpha *= 1 + settings.wetAttack * pressure
                }
                let maximum = settings.maxOpacity
                let pressureOpacity = 1 - settings.pressureOpacity + settings.pressureOpacity * pressure
                let response = settings.opacity * pressureOpacity
                let opacityLimit = context.brushSettingsVersion == 1 ? context.opacity * context.color.w *
                    (response > 0 ? min(maximum, max(min(settings.minOpacity, maximum), response)) : 0) : 0
                if context.brushSettingsVersion == 1 {
                    // Flow deposits pigment; opacity limits the coverage of the whole gesture.
                    let base = context.opacity * context.color.w * response
                    alpha = base > 0 ? alpha / base : 0
                    if settings.maxSize == 0 { alpha = 0 }
                } else { alpha = min(maximum, max(settings.minOpacity, alpha)) }
                let hue = hsv.x + rng.signed() * (settings.hueJitter + settings.stampHue) * 0.5 + strokeHue
                let rgb = StrokePlanner.hsvToRGB(SIMD3<Float>(hue, min(1, max(0, hsv.y + rng.signed() * settings.saturationJitter)),
                                               min(1, max(0, hsv.z + rng.signed() * settings.brightnessJitter))))
                var stamp = GPUStamp(
                    geometry: SIMD4(point.x + offset.x, point.y + offset.y, radius, angle),
                    color: SIMD4(rgb.x, rgb.y, rgb.z, max(0, min(1, alpha))),
                    shape: SIMD4(rx * (settings.flipX > 0.5 ? -1 : 1), ry * (settings.flipY > 0.5 ? -1 : 1), opacityLimit, context.brushSettingsVersion == 1 ? 1 : 0),
                    grain: SIMD4(max(0.1, settings.grainScale), min(1, settings.grainDepth), settings.grainContrast, settings.grainBrightness),
                    texture: SIMD4(settings.grainMovement, settings.grainZoom, settings.grainRotation * .pi, settings.tiltGradation * tilt),
                    pickup: SIMD4(point.x - previousPoint.x, point.y - previousPoint.y,
                                  min(1, settings.wetDilution + settings.pressureBleed * (1 - pressure)),
                                  context.tool == .smudge ? (context.brushSettingsVersion == 1 ? settings.smudge : max(0.02, settings.smudge)) : settings.wetPull),
                    rendering: SIMD4(settings.blendMode, context.tool == .paint ? 0 : context.tool == .smudge ? 1 : 2, settings.alphaThreshold, settings.wetGrade),
                    variation: SIMD4(rng.unit(), 0, nextDistance,
                                     context.curveVersion == 1 ? Float((a.time-(firstInputTime ?? a.time))+(b.time-a.time)*Double(t)) : 0))
                if context.brushSettingsVersion == 1 { stamp.variation.x = settings.accumulation }
                stamps.append(stamp)
                if settings.dualEnabled > 0.5 {
                    stamp.geometry.z *= max(0.1, settings.dualScale)
                    stamp.geometry.w += settings.dualRotation * .pi
                    stamp.color.w *= settings.dualOpacity
                    stamps.append(stamp)
                }
            }
            lastStampPoint = point
            stampCount += stamps.count
            guard stamps.count <= 100_000 else { throw DocumentError.strokeBudget }
            let jitter = 1 + rng.signed() * settings.spacingJitter * 0.95
            nextDistance += max(0.15, radius * 2 * max(0.01, settings.spacing) * jitter * (1 + settings.speedSpacing * speed))
            return stamps
        }
    }

    private static func legacyStamps(for stroke: PaintStroke, finished: Bool = true) throws -> [GPUStamp] {
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
