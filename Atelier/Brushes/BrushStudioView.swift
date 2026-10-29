import SwiftUI
import UniformTypeIdentifiers
import UIKit
import ImageIO

struct BrushStudioView: View {
    @ObservedObject var store: BrushStore
    @State private var draft: BrushPreset
    @State private var category = "Stroke Path"
    @State private var importSource: AssetSource = .shape
    @State private var importing = false
    @State private var assetError: String?
    @State private var confirmingReset = false
    @State private var newCopy = false
    @StateObject private var pad = PaintDocument(width: 768, height: 512)
    @Environment(\.dismiss) private var dismiss

    private enum AssetSource { case shape, grain }

    init(store: BrushStore, brush: BrushPreset) {
        self.store = store; _draft = State(initialValue: brush)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
            let wide = geometry.size.width >= 950
            let layout = wide ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            layout {
                if wide {
                List(BrushParameter.categories, id: \.self) { title in
                    Button { category = title } label: { Text(title).foregroundStyle(.primary).padding(.vertical, 8) }
                        .listRowBackground(category == title ? Color.accentColor.opacity(0.25) : Color.clear)
                }
                .listStyle(.plain).frame(width: 185)
                } else {
                    Picker("Categoria", selection: $category) {
                        ForEach(BrushParameter.categories, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu).padding(.horizontal).frame(minHeight: 44)
                }
                Divider()
                Form {
                    Section(category) {
                        if category == "Shape" {
                            Picker("Forma", selection: $draft.shape) {
                                ForEach(["round", "soft", "flat", "bristle", "fleck", "chisel"], id: \.self) { Text($0).tag($0) }
                            }
                            Button("Importa sorgente forma") { importSource = .shape; importing = true }
                            if draft.shapeData != nil { Button("Rimuovi sorgente importata") { draft.shapeData = nil } }
                            Text("Bianco deposita colore; nero è trasparente. La sorgente viene convertita in PNG entro 512 × 512 pixel.").font(.caption).foregroundStyle(.secondary)
                        }
                        if category == "Grain" {
                            Picker("Grana", selection: $draft.grain) {
                                ForEach(["none", "paper", "canvas", "charcoal", "wash", "noise"], id: \.self) { Text($0).tag($0) }
                            }
                            Button("Importa sorgente grana") { importSource = .grain; importing = true }
                            if draft.grainData != nil { Button("Rimuovi sorgente importata") { draft.grainData = nil } }
                        }
                        ForEach(BrushParameter.all.filter { $0.category == category }) { parameter in
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(parameter.title)
                                    Spacer()
                                    Text(draft.value(parameter.id, parameter.defaultValue), format: .number.precision(.fractionLength(2))).monospacedDigit().foregroundStyle(.secondary)
                                }
                                if ["flipX", "flipY", "randomRotation", "dualEnabled", "previewWetMix"].contains(parameter.id) {
                                    Toggle("Attivo", isOn: Binding(get: { draft.value(parameter.id) > 0.5 }, set: { draft.parameters[parameter.id] = $0 ? 1 : 0 }))
                                        .accessibilityLabel(parameter.title)
                                } else if parameter.id == "blendMode" {
                                    Picker("Metodo", selection: Binding(get: { Int(draft.value(parameter.id)) }, set: { draft.parameters[parameter.id] = Double($0) })) {
                                        Text("Normal").tag(0); Text("Multiply").tag(1); Text("Screen").tag(2)
                                    }
                                } else {
                                    Slider(value: Binding(get: { draft.value(parameter.id, parameter.defaultValue) }, set: { draft.parameters[parameter.id] = parameter.id == "stampCount" ? $0.rounded() : $0 }), in: parameter.range)
                                        .accessibilityLabel(parameter.title)
                                }
                                Text(parameter.effect).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        if category == "Materials" {
                            Text("Materiali metallic e roughness richiedono il motore 3D, attualmente non implementato. Nessun controllo materiale viene applicato al canvas 2D.")
                        }
                        if category == "About this Brush" {
                            TextField("Autore", text: Binding(get: { draft.author ?? "" }, set: { draft.author = $0 }))
                            TextField("Note", text: Binding(get: { draft.notes ?? "" }, set: { draft.notes = $0 }), axis: .vertical)
                            Text("Seed: \(String(draft.seed))").font(.caption.monospaced()).textSelection(.enabled)
                            Button("Nuovo seed") { draft.seed = UInt64.random(in: 1...UInt64.max) }
                        }
                    }
                    Section("Implementazione Atelier") {
                        Text("Le formule di questo renderer sono indipendenti. Pressione: curva esponenziale. Dual: seconda impronta della stessa sorgente. Wet mix: prelievo dal livello precedente al tratto. Le opzioni ancora mancanti sono inventariate in BRUSH_PARAMETERS.md.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                VStack(spacing: 12) {
                    if let message = store.errorMessage {
                        Text(message).font(.caption).foregroundStyle(.red).textSelection(.enabled)
                    }
                    HStack { Text("Area di prova").font(.headline); Spacer(); Button("Pulisci") { pad.clear() } }
                    CanvasSurface(document: pad, brush: draft, tool: .paint, color: SIMD4<Float>(0.12, 0.2, 0.35, 1), brushSize: 48, opacity: 1)
                        .background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Anteprima libreria").font(.subheadline)
                    BrushPreview(brush: draft).frame(height: 90).background(Color(white: 0.92)).clipShape(RoundedRectangle(cornerRadius: 8))
                    Text("Area di prova e miniatura usano lo stesso renderer Metal del canvas. I tratti già disegnati restano invariati quando modifichi i parametri; i successivi usano la bozza corrente.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding().frame(minWidth: 0, maxWidth: wide ? 440 : .infinity)
                .frame(height: wide ? nil : min(300, geometry.size.height * 0.4))
            }
            }
            .navigationTitle("Laboratorio Pennelli � " + draft.name).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Annulla") { dismiss() } }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Ripristina") { confirmingReset = true }
                    Button("Duplica") { draft.id = UUID().uuidString; draft.name += " copia"; newCopy = true }
                    Button("Fine") {
                        if newCopy { store.insert(draft) } else { store.save(draft) }
                        if store.errorMessage == nil { dismiss() }
                    }.bold()
                }
            }
            .confirmationDialog("Ripristinare la bozza?", isPresented: $confirmingReset, titleVisibility: .visible) {
                Button("Ripristina", role: .destructive) { draft = store.factoryVersion(of: draft) ?? store.brushes.first { $0.id == draft.id } ?? draft }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.png, .jpeg, .tiff]) { result in
                do {
                    let url = try result.get(); let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    guard let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 8_000_000 else { throw BrushArchiveError.invalid("Immagine oltre 8 MB.") }
                    let data = try Data(contentsOf: url)
                    let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 512, kCGImageSourceCreateThumbnailWithTransform: true]
                    guard let source = CGImageSourceCreateWithData(data as CFData, nil), let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { throw BrushArchiveError.invalid("Immagine non decodificabile.") }
                    let image = UIImage(cgImage: thumbnail)
                    let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
                    let target = image.size
                    let normalized = UIGraphicsImageRenderer(size: target, format: format).image { context in
                        UIColor.black.setFill(); context.fill(CGRect(origin: .zero, size: target)); image.draw(in: CGRect(origin: .zero, size: target))
                    }
                    guard let png = normalized.pngData() else { throw BrushArchiveError.invalid("Conversione PNG fallita.") }
                    if importSource == .shape { draft.shapeData = png } else { draft.grainData = png }
                } catch { assetError = error.localizedDescription }
            }
            .alert("Importazione sorgente", isPresented: Binding(get: { assetError != nil }, set: { if !$0 { assetError = nil } })) {
                Button("OK") { assetError = nil }
            } message: { Text(assetError ?? "") }
        }
        .interactiveDismissDisabled()
    }
}
