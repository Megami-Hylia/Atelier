import Foundation

// Resolve and clamp immutable parameters once, outside the per-imprint loop.
struct PlannedBrushSettings {
    let accumulation: Float
    let alphaThreshold: Float
    let azimuth: Float
    let barrelRoll: Float
    let blendMode: Float
    let brightnessJitter: Float
    let countJitter: Float
    let dualEnabled: Float
    let dualOpacity: Float
    let dualRotation: Float
    let dualScale: Float
    let fallOff: Float
    let flipX: Float
    let flipY: Float
    let flow: Float
    let grainBrightness: Float
    let grainContrast: Float
    let grainDepth: Float
    let grainMovement: Float
    let grainRotation: Float
    let grainScale: Float
    let grainZoom: Float
    let hueJitter: Float
    let jitterLateral: Float
    let jitterLinear: Float
    let maxOpacity: Float
    let maxSize: Float
    let minOpacity: Float
    let minSize: Float
    let opacity: Float
    let opacityJitter: Float
    let pressureBleed: Float
    let pressureCurve: Float
    let pressureFlow: Float
    let pressureOpacity: Float
    let pressureRoundness: Float
    let pressureSize: Float
    let randomRotation: Float
    let rotation: Float
    let roundness: Float
    let roundnessJitterX: Float
    let roundnessJitterY: Float
    let saturationJitter: Float
    let scatter: Float
    let sizeJitter: Float
    let smudge: Float
    let spacing: Float
    let spacingJitter: Float
    let speedOpacity: Float
    let speedSize: Float
    let speedSpacing: Float
    let stampCount: Float
    let stampHue: Float
    let strokeHue: Float
    let taperEnd: Float
    let taperOpacity: Float
    let taperSize: Float
    let taperStart: Float
    let tiltGradation: Float
    let tiltOpacity: Float
    let tiltRoundness: Float
    let tiltSize: Float
    let wetAttack: Float
    let wetCharge: Float
    let wetDilution: Float
    let wetGrade: Float
    let wetPull: Float
    init(_ brush: BrushPreset, corrected: Bool = false) {
        func value(_ key: String, _ fallback: Double) -> Float {
            guard corrected, let definition = BrushParameter.all.first(where: { $0.id == key }) else {
                let number = brush.value(key, fallback)
                return number.isFinite ? Float(max(-16, min(16, number))) : Float(fallback)
            }
            let number = brush.value(key, definition.defaultValue)
            let finite = number.isFinite ? number : definition.defaultValue
            let upper = key == "blendMode" ? 10.0 : definition.range.upperBound
            return Float(min(upper, max(definition.range.lowerBound, finite)))
        }
        accumulation = value("accumulation", 1)
        alphaThreshold = value("alphaThreshold", 0)
        azimuth = value("azimuth", 0)
        barrelRoll = value("barrelRoll", 0)
        blendMode = value("blendMode", 0)
        brightnessJitter = value("brightnessJitter", 0)
        countJitter = value("countJitter", 0)
        dualEnabled = value("dualEnabled", 0)
        dualOpacity = value("dualOpacity", 0.5)
        dualRotation = value("dualRotation", 0)
        dualScale = value("dualScale", 0.6)
        fallOff = value("fallOff", 0)
        flipX = value("flipX", 0)
        flipY = value("flipY", 0)
        flow = value("flow", 1)
        grainBrightness = value("grainBrightness", 0)
        grainContrast = value("grainContrast", 1)
        grainDepth = value("grainDepth", 0)
        grainMovement = value("grainMovement", 0)
        grainRotation = value("grainRotation", 0)
        grainScale = value("grainScale", 1)
        grainZoom = value("grainZoom", 1)
        hueJitter = value("hueJitter", 0)
        jitterLateral = value("jitterLateral", 0)
        jitterLinear = value("jitterLinear", 0)
        maxOpacity = value("maxOpacity", 1)
        maxSize = value("maxSize", 1)
        minOpacity = value("minOpacity", 0)
        minSize = value("minSize", 0)
        opacity = value("opacity", 1)
        opacityJitter = value("opacityJitter", 0)
        pressureBleed = value("pressureBleed", 0)
        pressureCurve = value("pressureCurve", 1)
        pressureFlow = value("pressureFlow", 0)
        pressureOpacity = value("pressureOpacity", 0)
        pressureRoundness = value("pressureRoundness", 0)
        pressureSize = value("pressureSize", 0)
        randomRotation = value("randomRotation", 0)
        rotation = value("rotation", 0)
        roundness = value("roundness", 1)
        roundnessJitterX = value("roundnessJitterX", 0)
        roundnessJitterY = value("roundnessJitterY", 0)
        saturationJitter = value("saturationJitter", 0)
        scatter = value("scatter", 0)
        sizeJitter = value("sizeJitter", 0)
        smudge = value("smudge", 0.7)
        spacing = value("spacing", 0.08)
        spacingJitter = value("spacingJitter", 0)
        speedOpacity = value("speedOpacity", 0)
        speedSize = value("speedSize", 0)
        speedSpacing = value("speedSpacing", 0)
        stampCount = value("stampCount", 1)
        stampHue = value("stampHue", 0)
        strokeHue = value("strokeHue", 0)
        taperEnd = value("taperEnd", 0)
        taperOpacity = value("taperOpacity", 0)
        taperSize = value("taperSize", 0)
        taperStart = value("taperStart", 0)
        tiltGradation = value("tiltGradation", 0)
        tiltOpacity = value("tiltOpacity", 0)
        tiltRoundness = value("tiltRoundness", 0)
        tiltSize = value("tiltSize", 0)
        wetAttack = value("wetAttack", 0)
        wetCharge = value("wetCharge", 1)
        wetDilution = value("wetDilution", 0)
        wetGrade = value("wetGrade", 0)
        wetPull = value("wetPull", 0)
    }
}
