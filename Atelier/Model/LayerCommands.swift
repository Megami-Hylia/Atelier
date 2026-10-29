import UIKit

@MainActor extension PaintDocument {
    private static var clipboardType: String { "org.atelier.layers" }
    var canMergeSelected: Bool {
        guard let index = contents.layers.firstIndex(where: { $0.id == selectedLayer.id }), index > 0 else { return false }
        return [contents.layers[index - 1], contents.layers[index]].allSatisfy { layer in
            (layer.adjustments?.isEmpty ?? true) && !layer.locked && layer.visible && layer.opacity == 1 && layer.blendMode == 0 && layer.strokes.allSatisfy {
                $0.tool == .paint && $0.brush.value("blendMode") == 0 && $0.brush.value("wetPull") == 0 && $0.brush.value("wetDilution") == 0 && $0.brush.value("pressureBleed") == 0
            }
        }
    }
    func mergeSelectedDown() {
        guard canMergeSelected else { return }
        let id = selectedLayer.id
        change { value in
            guard let index = value.layers.firstIndex(where: { $0.id == id }), index > 0 else { return }
            value.layers[index - 1].strokes.append(contentsOf: value.layers[index].strokes)
            value.selectedLayerID = value.layers[index - 1].id
            value.layers.remove(at: index)
        }
    }
    func copyLayers(all: Bool = false, cut: Bool = false) {
        guard !cut || !selectedLayer.locked else { errorMessage = DocumentError.lockedLayer.localizedDescription; return }
        do {
            var value = contents
            if !all { value.layers = [selectedLayer]; value.selectedLayerID = selectedLayer.id; value.background = .zero }
            let data = try JSONEncoder().encode(value)
            guard data.count <= 32 * 1024 * 1024 else { throw DocumentError.tooLarge }
            var item: [String: Any] = [Self.clipboardType: data]
            if let png = try MetalPainter().image(value).pngData() { item["public.png"] = png }
            UIPasteboard.general.setItems([item])
            errorMessage = nil
            if cut { clearLayer() }
        } catch { errorMessage = error.localizedDescription }
    }
    func copySelectedStrokes(_ ids: Set<UUID>) {
        var value = contents, layer = selectedLayer
        layer.strokes = layer.strokes.filter { ids.contains($0.id) }
        guard !layer.strokes.isEmpty else { errorMessage = "Nessun tratto selezionato."; return }
        value.layers = [layer]; value.selectedLayerID = layer.id; value.background = .zero
        do {
            let data = try JSONEncoder().encode(value)
            guard data.count <= 32 * 1024 * 1024 else { throw DocumentError.tooLarge }
            var item: [String: Any] = [Self.clipboardType: data]
            if let png = try MetalPainter().image(value).pngData() { item["public.png"] = png }
            UIPasteboard.general.setItems([item]); errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }

    func pasteLayers() {
        do {
            guard let data = UIPasteboard.general.data(forPasteboardType: Self.clipboardType) else {
                errorMessage = "Gli appunti non contengono livelli Atelier. L'importazione di immagini esterne non è ancora supportata."; return
            }
            guard data.count <= 32 * 1024 * 1024 else { throw DocumentError.tooLarge }
            let imported = try JSONDecoder().decode(DocumentContents.self, from: data)
            try imported.validate()
            guard imported.width == contents.width, imported.height == contents.height,
                  contents.layers.count + imported.layers.count <= 32 else { throw DocumentError.invalidData }
            for layer in imported.layers { for stroke in layer.strokes {
                _ = try StrokePlanner.tileBins(StrokePlanner.stamps(for: stroke), width: contents.width, height: contents.height)
            } }
            change { value in
                for var layer in imported.layers {
                    layer.id = UUID(); layer.name += " copia"
                    for i in layer.strokes.indices { layer.strokes[i].id = UUID() }
                    value.layers.append(layer); value.selectedLayerID = layer.id
                }
            }
        } catch { errorMessage = error.localizedDescription }
    }
    func flipLayer(horizontal: Bool) {
        guard !selectedLayer.locked else { errorMessage = DocumentError.lockedLayer.localizedDescription; return }
        let id = selectedLayer.id
        change { value in
            guard let index = value.layers.firstIndex(where: { $0.id == id }) else { return }
            for s in value.layers[index].strokes.indices {
                for p in value.layers[index].strokes[s].samples.indices {
                    if horizontal {
                        value.layers[index].strokes[s].samples[p].x = Float(value.width) - value.layers[index].strokes[s].samples[p].x
                        value.layers[index].strokes[s].samples[p].azimuth = .pi - value.layers[index].strokes[s].samples[p].azimuth
                    } else {
                        value.layers[index].strokes[s].samples[p].y = Float(value.height) - value.layers[index].strokes[s].samples[p].y
                        value.layers[index].strokes[s].samples[p].azimuth *= -1
                    }
                }
            }
        }
    }
}
