import XCTest
import SwiftUI
@testable import Atelier

@MainActor
final class BrushLibraryVisualTests: XCTestCase {
    func testLibraryProducesReviewableNativeSnapshot() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = BrushStore(storageURL: folder.appendingPathComponent("library.json"))
        XCTAssertNil(store.errorMessage)
        let controller = UIHostingController(rootView: BrushLibraryView(store: store))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 420, height: 650))
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
        XCTAssertNotNil(image.cgImage)
        let attachment = XCTAttachment(image: image)
        attachment.name = "Brush-Library-420x650"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
