import CoreImage
import Metal

@MainActor final class LayerAdjustments {
    private let context: CIContext
    private let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!
    init(device: MTLDevice) { context = CIContext(mtlDevice: device, options: [.cacheIntermediates: false]) }
    func apply(_ values: [String: Float], source: MTLTexture, target: MTLTexture, command: MTLCommandBuffer) throws {
        guard var image = CIImage(mtlTexture: source, options: [.colorSpace: colorSpace]) else { throw RenderError.command("Regolazioni: texture non disponibile") }
        let extent = image.extent
        func v(_ key: String, _ fallback: Float = 0) -> Float { values[key] ?? fallback }
        if v("hue") != 0 { image = image.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: v("hue") * .pi]) }
        if v("saturation", 1) != 1 || v("brightness") != 0 {
            image = image.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: v("saturation", 1), kCIInputBrightnessKey: v("brightness")])
        }
        if v("red") != 0 || v("green") != 0 || v("blue") != 0 {
            image = image.applyingFilter("CIColorMatrix", parameters: ["inputBiasVector": CIVector(x: CGFloat(v("red")), y: CGFloat(v("green")), z: CGFloat(v("blue")), w: 0)])
        }
        if v("shadows") != 0 || v("midtones") != 0 || v("highlights") != 0 {
            image = image.applyingFilter("CIToneCurve", parameters: ["inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 0.25, y: CGFloat(0.25 + v("shadows"))), "inputPoint2": CIVector(x: 0.5, y: CGFloat(0.5 + v("midtones"))), "inputPoint3": CIVector(x: 0.75, y: CGFloat(0.75 + v("highlights"))), "inputPoint4": CIVector(x: 1, y: 1)])
        }
        if v("gradient") > 0 {
            let gradient = CIFilter(name: "CILinearGradient", parameters: ["inputPoint0": CIVector(x: 0, y: 0), "inputPoint1": CIVector(x: 255, y: 0), "inputColor0": CIColor(red: CGFloat(v("lowR")), green: CGFloat(v("lowG")), blue: CGFloat(v("lowB", 0.3))), "inputColor1": CIColor(red: CGFloat(v("highR", 1)), green: CGFloat(v("highG", 0.3)), blue: CGFloat(v("highB", 0.6)))])?.outputImage?.cropped(to: CGRect(x: 0, y: 0, width: 256, height: 1))
            if let gradient { image = image.applyingFilter("CIColorMap", parameters: ["inputGradientImage": gradient]) }
        }
        if v("blur") > 0 { image = image.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: v("blur")]).cropped(to: extent) }
        if v("motion") > 0 { image = image.clampedToExtent().applyingFilter("CIMotionBlur", parameters: [kCIInputRadiusKey: v("motion"), kCIInputAngleKey: v("angle") * .pi]).cropped(to: extent) }
        if v("zoom") > 0 { image = image.applyingFilter("CIZoomBlur", parameters: [kCIInputCenterKey: CIVector(x: extent.midX, y: extent.midY), kCIInputAmountKey: v("zoom")]).cropped(to: extent) }
        if v("sharpness") > 0 { image = image.applyingFilter("CISharpenLuminance", parameters: [kCIInputSharpnessKey: v("sharpness")]) }
        if v("bloom") > 0 { image = image.clampedToExtent().applyingFilter("CIBloom", parameters: [kCIInputRadiusKey: v("bloomRadius", 12), kCIInputIntensityKey: v("bloom")]).cropped(to: extent) }
        if v("halftone") > 0 { image = image.applyingFilter("CIDotScreen", parameters: [kCIInputWidthKey: v("halftone"), kCIInputSharpnessKey: 0.7]).cropped(to: extent) }
        context.render(image, to: target, commandBuffer: command, bounds: extent, colorSpace: colorSpace)
    }
}
