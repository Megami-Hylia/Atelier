import XCTest
import SwiftUI
import UIKit
@testable import Atelier

@MainActor
final class ColorPopupVisualTests: XCTestCase {
    func testColorPopupProducesReviewableNativeSnapshot() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BrushStore(storageURL: folder.appendingPathComponent("library.json"))
        XCTAssertNil(store.errorMessage)
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: "colorSelectorMode")
        defaults.set(1, forKey: "colorSelectorMode")
        defer { if let previous { defaults.set(previous, forKey: "colorSelectorMode") } else { defaults.removeObject(forKey: "colorSelectorMode") } }
        let controller = UIHostingController(rootView: AtelierColors(color: .constant(.blue)))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 350, height: 700)
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.view.frame = window.bounds
        controller.view.setNeedsLayout(); controller.view.layoutIfNeeded()
        try await Task.sleep(for: .seconds(2))
        controller.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        let cgImage = try XCTUnwrap(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        try pixels.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: cgImage.width, height: cgImage.height,
                bitsPerComponent: 8, bytesPerRow: cgImage.width * 4, space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        let visiblePixels = stride(from: 0, to: pixels.count, by: 4).filter { max(pixels[$0], max(pixels[$0+1], pixels[$0+2])) > 80 }.count
        XCTAssertGreaterThan(visiblePixels, cgImage.width * cgImage.height / 100, "A blank screenshot is not visual evidence.")
        let attachment = XCTAttachment(image: image)
        attachment.name = "Color-Popup-350x700"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
