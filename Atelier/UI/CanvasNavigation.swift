import UIKit

enum CanvasNavigation {
    /// Apply a local scale/rotation while keeping the touched point fixed in the parent.
    static func applying(_ delta: CGAffineTransform, to transform: CGAffineTransform,
                         anchor: CGPoint, bounds: CGRect) -> CGAffineTransform {
        let offset = CGPoint(x: anchor.x - bounds.midX, y: anchor.y - bounds.midY)
        let before = offset.applying(transform)
        var result = transform
        // Postmultiply the linear part; translation is solved from the anchor constraint.
        result = result.scaledBy(x: hypot(delta.a, delta.b), y: hypot(delta.c, delta.d))
        result = result.rotated(by: atan2(delta.b, delta.a))
        let after = offset.applying(result)
        result.tx += before.x - after.x
        result.ty += before.y - after.y
        return result
    }
}
