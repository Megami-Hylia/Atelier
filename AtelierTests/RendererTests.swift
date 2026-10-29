import XCTest
import UIKit
import CryptoKit
import Metal
@testable import Atelier

@MainActor final class RendererTests: XCTestCase {
    private func stroke(_ brush: BrushPreset = .fallback, tool: PaintTool = .paint) -> PaintStroke {
        PaintStroke(brush: brush, tool: tool, color: SIMD4(0.2, 0.35, 0.7, 1), size: 32, opacity: 1,
                    samples: PencilSample.demo(width: 384, height: 128), seed: 42)
    }
    private func imageData(_ painter: MetalPainter, _ strokes: [PaintStroke]) throws -> Data {
        var contents = DocumentContents(width: 384, height: 128)
        contents.layers[0].strokes = strokes
        return try XCTUnwrap(try painter.image(contents).pngData())
    }
    func testCommittedLayerCacheSkipsReplayAndInvalidatesOnEdit() throws {
        let painter = try MetalPainter()
        var content = DocumentContents(width: 384, height: 128)
        content.layers[0].strokes = [stroke()]
        let first = try painter.image(content).pngData()
        XCTAssertGreaterThan(painter.lastStampCount, 0)
        XCTAssertEqual(first, try painter.image(content).pngData())
        XCTAssertEqual(painter.lastStampCount, 0)
        content.layers[0].strokes[0].samples[0].x += 50
        let edited = try painter.image(content).pngData()
        XCTAssertGreaterThan(painter.lastStampCount, 0)
        XCTAssertEqual(edited, try MetalPainter().image(content).pngData())
    }

    func testDeterministicReplayAndSpacingAffectPixels() throws {
        let painter = try MetalPainter()
        let original = stroke()
        XCTAssertEqual(try imageData(painter, [original]), try imageData(painter, [original]))
        var spaced = original; spaced.brush.parameters["spacing"] = 1.4
        XCTAssertNotEqual(try imageData(painter, [original]), try imageData(painter, [spaced]))
        var textured = original; textured.brush.grain = "charcoal"; textured.brush.parameters["grainDepth"] = 1
        XCTAssertNotEqual(try imageData(painter, [original]), try imageData(painter, [textured]))
        var tapered = original; tapered.brush.parameters["taperStart"] = 0.8; tapered.brush.parameters["taperSize"] = 1
        XCTAssertNotEqual(try imageData(painter, [original]), try imageData(painter, [tapered]))
        var pressure = original; pressure.brush.parameters["pressureSize"] = 1; pressure.brush.parameters["pressureCurve"] = 3
        XCTAssertNotEqual(try imageData(painter, [original]), try imageData(painter, [pressure]))
        var chromatic = original; chromatic.brush.parameters["hueJitter"] = 1
        XCTAssertNotEqual(try imageData(painter, [original]), try imageData(painter, [chromatic]))
    }
    func testUndoRedoReopenPreservePixelsAndParameters() throws {
        let document = PaintDocument(width: 384, height: 128)
        let painter = try MetalPainter()
        document.commit(stroke()); let before = try painter.image(document.contents).pngData()
        document.undo(); XCTAssertTrue(document.contents.layers[0].strokes.isEmpty)
        document.redo(); XCTAssertEqual(before, try painter.image(document.contents).pngData())
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let url = directory.appendingPathComponent("test.atelier")
        defer { try? FileManager.default.removeItem(at: directory) }
        try document.save(to: url)
        let reopened = PaintDocument(); try reopened.load(from: url)
        XCTAssertEqual(document.contents, reopened.contents)
        XCTAssertEqual(before, try painter.image(reopened.contents).pngData())
    }
    func testEraserChangesAlphaAndSmudgeMovesExistingPigment() throws {
        let painter = try MetalPainter()
        var contents = DocumentContents(width: 384, height: 128); contents.background = .zero
        var paint = stroke(); paint.samples = [PencilSample(x: 100, y: 64, time: 0)]; paint.size = 40
        contents.layers[0].strokes = [paint]
        let texture = try painter.render(contents)
        let paintedAlpha = alpha(texture, x: 100, y: 64)
        XCTAssertGreaterThan(paintedAlpha, 0.9)
        XCTAssertLessThan(alpha(texture, x: 180, y: 64), 0.01)
        var erase = paint; erase.tool = .erase; contents.layers[0].strokes.append(erase)
        let erased = try painter.render(contents)
        XCTAssertLessThan(alpha(erased, x: 100, y: 64), paintedAlpha * 0.5)
        var smudge = stroke(tool: .smudge)
        smudge.samples = [PencilSample(x: 100, y: 64, time: 0), PencilSample(x: 200, y: 64, time: 1)]
        smudge.brush.parameters["smudge"] = 1; smudge.size = 40
        contents.layers[0].strokes = [paint, smudge]
        let dragged = try painter.render(contents)
        XCTAssertGreaterThan(alpha(dragged, x: 180, y: 64), 0.1, "Smudge must transport existing pigment to previously transparent pixels.")
    }
    private func alpha(_ texture: MTLTexture, x: Int, y: Int) -> Float {
        var pixel = [UInt16](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: 8, from: MTLRegionMake2D(x, y, 1, 1), mipmapLevel: 0) }
        return Float(Float16(bitPattern: pixel[3]))
    }
    func testOpaqueStrokeHasNoTransparentTileSeam() throws {
        // A long opaque stroke must cross x=256 without opening a transparent seam.
        let painter = try MetalPainter()
        var content = DocumentContents(width: 512, height: 128); content.background = .zero
        var brush = BrushPreset.fallback; brush.parameters["spacing"] = 0.03; brush.parameters["pressureSize"] = 0
        let samples = [PencilSample(x: 10,y: 64,time: 0), PencilSample(x: 502,y: 64,time: 1)]
        content.layers[0].strokes = [PaintStroke(brush: brush, tool: .paint, color: SIMD4(0,0,0,1), size: 32, opacity: 1, samples: samples, seed: 1)]
        let texture = try painter.render(content)
        var pixels = [UInt16](repeating: 0, count: 3 * 4)
        pixels.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: 24, from: MTLRegionMake2D(255, 64, 3, 1), mipmapLevel: 0) }
        XCTAssertGreaterThan(Float(Float16(bitPattern: pixels[3])), 0.95)
        XCTAssertGreaterThan(Float(Float16(bitPattern: pixels[7])), 0.95)
        XCTAssertGreaterThan(Float(Float16(bitPattern: pixels[11])), 0.95)
    }
    func testCatalogComparisonFromActualMetalRenderer() throws {
        let store = BrushStore()
        XCTAssertNil(store.errorMessage)
        XCTAssertGreaterThanOrEqual(store.brushes.count, 192)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("RendererEvidence")
        let url = try RendererEvidence.generate(brushes: store.brushes, folder: directory)
        let attachment = XCTAttachment(contentsOfFile: url); attachment.name = "Actual-Metal-192-Preset-Comparison"; attachment.lifetime = .keepAlways; add(attachment)
        let manifest = directory.appendingPathComponent("manifest.json")
        let metadata = XCTAttachment(contentsOfFile: manifest); metadata.lifetime = .keepAlways; add(metadata)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        let presets = try XCTUnwrap(json["presets"] as? [[String: Any]])
        let hashes = presets.compactMap { $0["sha256"] as? String }
        XCTAssertEqual(hashes.count, store.brushes.count)
        XCTAssertEqual(Set(hashes).count, hashes.count, "Every catalog preset should produce distinct pixels for this synthetic trajectory.")
    }
    func testInvalidDocumentCannotReplaceCurrentState() throws {
        let document = PaintDocument()
        let previous = document.contents
        document.change { $0.width = Int.max }
        XCTAssertEqual(document.contents, previous)
        XCTAssertNotNil(document.errorMessage)
        document.errorMessage = nil
        document.change { $0.selectedLayerID = UUID() }
        XCTAssertEqual(document.contents, previous)
        XCTAssertNotNil(document.errorMessage)
        document.errorMessage = nil
        document.change { $0.width = 4096; $0.height = 4096 }
        XCTAssertEqual(document.contents, previous)
        XCTAssertNotNil(document.errorMessage)
    }
    func testOverBudgetStrokeIsRejectedInsteadOfSilentlyTruncated() throws {
        var tooLong = stroke(); tooLong.size = 1; tooLong.brush.parameters["spacing"] = 0.01
        tooLong.samples = [PencilSample(x: -32768, y: 64, time: 0), PencilSample(x: 32768, y: 64, time: 1)]
        XCTAssertThrowsError(try StrokePlanner.stamps(for: tooLong))
        let document = PaintDocument(width: 384, height: 128)
        let previous = document.contents
        document.commit(tooLong)
        XCTAssertEqual(document.contents, previous)
        XCTAssertNotNil(document.errorMessage)
    }
    func testDuplicatingDocumentPreservesOriginalFile() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let source = folder.appendingPathComponent("original.atelier"), destination = folder.appendingPathComponent("copy.atelier")
        let original = PaintDocument(); try original.save(to: source)
        let bytes = try Data(contentsOf: source)
        let copy = PaintDocument(); try copy.load(from: source); copy.storageURL = nil
        copy.change { $0.id = UUID(); $0.name += " copia" }; try copy.save(to: destination)
        XCTAssertEqual(bytes, try Data(contentsOf: source))
        XCTAssertNotEqual(original.contents.id, copy.contents.id)
    }
}
