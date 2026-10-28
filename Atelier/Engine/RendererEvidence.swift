import UIKit
import CryptoKit

@MainActor enum RendererEvidence {
    static func generate(brushes: [BrushPreset], folder: URL? = nil) throws -> URL {
        let directory = folder ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Verification-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let painter = try MetalPainter()
        let width = 400, height = 128, columns = 4
        let rows = (brushes.count + columns - 1) / columns
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width * columns, height: height * max(1, rows)), format: format)
        var failure: Error?
        var records: [[String: Any]] = []
        let sheet = renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: width * columns, height: height * max(1, rows)))
            for (index, brush) in brushes.enumerated() {
                do {
                    var document = DocumentContents(width: width, height: 96)
                    document.layers[0].strokes = [PaintStroke(brush: brush, tool: .paint, color: SIMD4(0.16, 0.35, 0.65, 1), size: 32,
                                                            opacity: 1, samples: PencilSample.demo(width: Float(width), height: 96), seed: 42)]
                    let image = try painter.image(document)
                    guard let data = image.pngData() else { throw RenderError.command("evidence PNG") }
                    let x = (index % columns) * width, y = (index / columns) * height
                    image.draw(in: CGRect(x: x, y: y + 26, width: width, height: 96))
                    let title = "\(brush.setID) / \(brush.name)"
                    (title as NSString).draw(at: CGPoint(x: x + 8, y: y + 5), withAttributes: [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.black])
                    let safeID = String(index) + ".png"
                    try data.write(to: directory.appendingPathComponent(safeID), options: .atomic)
                    records.append(["id": brush.id, "name": brush.name, "set": brush.setID, "seed": 42,
                                    "sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), "file": safeID])
                } catch { failure = error; break }
            }
        }
        if let failure { throw failure }
        let url = directory.appendingPathComponent("brush-comparison.png")
        guard let png = sheet.pngData() else { throw RenderError.command("comparison PNG") }
        try png.write(to: url, options: .atomic)
        let manifest: [String: Any] = ["renderer": "Atelier MetalPainter", "input": "PencilSample.demo count100 size32 sRGB color.16,.35,.65 seed42", "hardware": UIDevice.current.model, "system": UIDevice.current.systemVersion, "syntheticInput": true, "presets": records]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: directory.appendingPathComponent("manifest.json"), options: .atomic)
        return url
    }
}
