import SwiftUI
import UniformTypeIdentifiers

@main struct AtelierApp: App {
    @StateObject private var brushes = BrushStore()
    @AppStorage("lightInterface") private var light = false
    var body: some Scene {
        WindowGroup { AtelierRoot(brushes: brushes).preferredColorScheme(light ? .light : .dark) }
    }
}

struct AtelierRoot: View {
    @ObservedObject var brushes: BrushStore
    @StateObject private var gallery = GalleryStore()
    @State private var document: PaintDocument?
    @State private var create = false
    @State private var importing = false
    @State private var name = "Senza titolo"
    @State private var width = "2048"
    @State private var height = "1536"
    @State private var error: String?
    var body: some View {
        Group {
            if let document {
                PaintingWorkspace(document: document, brushes: brushes) { self.document = nil; gallery.refresh() }
            } else {
                NavigationStack {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 32)], spacing: 32) {
                            ForEach(gallery.urls, id: \.self) { url in
                                Button { open(url) } label: { ArtworkCard(url: url) }.buttonStyle(.plain)
                                    .contextMenu {
                                        ShareLink(item: url) { Label("Condividi documento", systemImage: "square.and.arrow.up") }
                                        Button("Duplica", systemImage: "doc.on.doc") { duplicate(url) }
                                    }
                            }
                        }.padding(40)
                        if gallery.urls.isEmpty { ContentUnavailableView("La tua galleria", systemImage: "paintpalette", description: Text("Tocca + per creare un canvas e iniziare a dipingere.")) }
                    }
                    .navigationTitle("Atelier")
                    .toolbar {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            Button("Importa", systemImage: "square.and.arrow.down") { importing = true }
                            Button("Nuovo canvas", systemImage: "plus") { create = true }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $create) {
            NavigationStack {
                Form {
                    TextField("Nome", text: $name)
                    TextField("Larghezza in pixel", text: $width).keyboardType(.numberPad)
                    TextField("Altezza in pixel", text: $height).keyboardType(.numberPad)
                    Text("Canvas sRGB, 132 DPI. In questa versione: da 64 a 3172 pixel per lato, entro il budget GPU di 384 MiB.").font(.footnote)
                    Button("Schermo 2048 × 1536") { width = "2048"; height = "1536" }
                    Button("Quadrato 2048 × 2048") { width = "2048"; height = "2048" }
                }.navigationTitle("Nuovo canvas")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Annulla") { create = false } }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Crea") {
                                guard let w = Int(width), let h = Int(height), (64...3172).contains(w), (64...3172).contains(h),
                                      w * h * 40 <= MetalPainter.workingMemoryLimit else { error = "Dimensioni non valide o memoria richiesta oltre il limite."; return }
                                do { document = try gallery.create(width: w, height: h, name: name); create = false }
                                catch { self.error = error.localizedDescription }
                            }
                        }
                    }
            }.frame(minWidth: 450, minHeight: 400)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(importedAs: "org.atelier.document"), .json]) { result in
            switch result {
            case .success(let url): importDocument(url)
            case .failure(let failure): error = failure.localizedDescription
            }
        }
        .onOpenURL { importDocument($0) }
        .alert("Atelier", isPresented: Binding(get: { error != nil || gallery.errorMessage != nil }, set: { if !$0 { error = nil; gallery.errorMessage = nil } })) {
            Button("OK") { error = nil; gallery.errorMessage = nil }
        } message: { Text(error ?? gallery.errorMessage ?? "") }
    }
    private func open(_ url: URL) {
        do { let d = PaintDocument(); try d.load(from: url); document = d } catch { self.error = error.localizedDescription }
    }
    private func importDocument(_ url: URL) {
        do {
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let imported = PaintDocument(); try imported.load(from: url)
            if let current = document, let currentURL = current.storageURL { try current.save(to: currentURL) }
            let destination = gallery.folder.appendingPathComponent(UUID().uuidString).appendingPathExtension("atelier")
            try imported.save(to: destination); document = imported; gallery.refresh()
        } catch { self.error = error.localizedDescription }
    }
    private func duplicate(_ url: URL) {
        do {
            let d = PaintDocument(); try d.load(from: url)
            d.storageURL = nil
            d.change { $0.id = UUID(); $0.name += " copia" }
            try d.save(to: gallery.folder.appendingPathComponent(d.contents.id.uuidString).appendingPathExtension("atelier")); gallery.refresh()
        } catch { self.error = error.localizedDescription }
    }
}

private struct ArtworkCard: View {
    let url: URL
    @State private var image: UIImage?
    @State private var name = "Documento"
    @State private var dimensions = ""
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group { if let image { Image(uiImage: image).resizable().scaledToFit() } else { Color.gray.opacity(0.15) } }
                .frame(height: 190)
            Text(name).font(.headline)
            Text(dimensions).font(.caption).foregroundStyle(.secondary)
        }
        .task {
            do {
                let d = PaintDocument(); try d.load(from: url); name = d.contents.name
                dimensions = "\(d.contents.width) × \(d.contents.height) px"
                image = try MetalPainter().image(d.contents)
            } catch { name = "Documento non leggibile"; dimensions = error.localizedDescription }
        }
    }
}

struct PaintingWorkspace: View {
    @ObservedObject var document: PaintDocument
    @ObservedObject var brushes: BrushStore
    var leave: () -> Void
    @State private var tool = PaintTool.paint
    @State private var color = Color(red: 0.05, green: 0.05, blue: 0.05)
    @State private var size: Float = 32
    @State private var opacity: Float = 1
    @State private var panel: String?
    @State private var exportURL: URL?
    @State private var showingShare = false
    @State private var busy = false
    @AppStorage("leftHanded") private var leftHanded = false
    @AppStorage("fingerPainting") private var fingerPainting = false
    @State private var immersive = false
    @State private var selecting = false

    var body: some View {
        VStack(spacing: 0) {
            if !immersive { toolbar }
            ZStack(alignment: leftHanded ? .trailing : .leading) {
                Color(white: 0.19)
                CanvasSurface(document: document, brush: brushes.selectedBrush, tool: tool, color: rgba(color), brushSize: size, opacity: opacity,
                              fingerPainting: fingerPainting, onToolChange: { tool = $0 }, onPalette: { panel = "color" }, onClipboard: { panel = "clipboard" }, onQuickMenu: { panel = "quick" })
                    .overlay { if selecting { TransformSelectionView(document: document) { selecting = false } } }
                    .aspectRatio(CGFloat(document.contents.width) / CGFloat(document.contents.height), contentMode: .fit)
                    .padding(44)
                if !immersive { sideControls }
                if busy { ProgressView("Rendering…").padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)) }
            }.clipped()
        }
        .background(Color(white: 0.09))
        .overlay(alignment: .bottom) {
            if panel == "clipboard" || panel == "quick" {
                GestureCommandPanel(document: document, quick: panel == "quick") { panel = nil }
                    .padding(.horizontal, 20).padding(.bottom, 30)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if immersive { Button("Mostra interfaccia", systemImage: "arrow.down.right.and.arrow.up.left") { immersive = false }.padding().background(.regularMaterial) }
        }
        .alert("Atelier", isPresented: Binding(get: { document.errorMessage != nil }, set: { if !$0 { document.errorMessage = nil } })) {
            Button("OK") { document.errorMessage = nil }
        } message: { Text(document.errorMessage ?? "") }
        .sheet(isPresented: $showingShare) { if let exportURL { ShareSheet(urls: [exportURL]) } }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            if let url = document.storageURL { do { try document.save(to: url) } catch { document.errorMessage = error.localizedDescription } }
        }
    }
    private var toolbar: some View {
        HStack(spacing: 18) {
            Button("Galleria") {
                do {
                    if let url = document.storageURL { try document.save(to: url) }
                    leave()
                } catch { document.errorMessage = "Impossibile salvare: \(error.localizedDescription). Il documento resta aperto." }
            }.font(.headline)
            Button { panel = "actions" } label: { Image(systemName: "wrench") }.accessibilityLabel("Azioni")
                .popover(isPresented: presented("actions"), arrowEdge: .top) { actions.frame(width: 330) }
            Button { panel = "adjustments" } label: { Image(systemName: "wand.and.stars").foregroundStyle(panel == "adjustments" ? Color.blue : Color.primary) }.accessibilityLabel("Regolazioni")
                .popover(isPresented: presented("adjustments"), arrowEdge: .top) { AdjustmentsPanel(document: document).frame(width: 340, height: 540) }
            Button { selecting.toggle(); panel = nil } label: { Image(systemName: "lasso").foregroundStyle(selecting ? Color.blue : Color.primary) }.accessibilityLabel("Selezione e trasformazione")
            Spacer()
            toolButton(.paint, "paintbrush.pointed.fill", "Pennello")
            toolButton(.smudge, "hand.draw.fill", "Sfumino")
            toolButton(.erase, "eraser.fill", "Gomma")
            Button { panel = "layers" } label: { Image(systemName: "square.on.square.fill") }.accessibilityLabel("Livelli")
                .popover(isPresented: presented("layers"), arrowEdge: .top) { layers.frame(width: 360, height: 540) }
            Button { panel = "color" } label: { Circle().fill(color).overlay(Circle().stroke(.gray)).frame(width: 30, height: 30) }.accessibilityLabel("Colore")
                .popover(isPresented: presented("color"), arrowEdge: .top) { AtelierColors(color: $color).frame(width: 350, height: 650) }
        }.font(.system(size: 20)).buttonStyle(.plain).padding(.horizontal, 16).frame(height: 48).background(Color(uiColor: .systemBackground))
    }
    private func toolButton(_ item: PaintTool, _ icon: String, _ label: String) -> some View {
        Button {
            if tool == item { panel = "brush-\(item.rawValue)" } else { tool = item }
        } label: { Image(systemName: icon).foregroundStyle(tool == item ? Color.blue : Color.primary).frame(width: 30, height: 40) }
            .accessibilityLabel(label)
            .popover(isPresented: presented("brush-\(item.rawValue)"), arrowEdge: .top) { BrushLibraryView(store: brushes).frame(width: 420, height: 650) }
    }
    private func presented(_ value: String) -> Binding<Bool> { Binding(get: { panel == value }, set: { if !$0 && panel == value { panel = nil } }) }
    private var sideControls: some View {
        BrushSideBar(size: $size, opacity: $opacity, onRight: leftHanded,
                     canUndo: document.canUndo, canRedo: document.canRedo,
                     undo: { document.undo() }, redo: { document.redo() }, colors: { panel = "color" })
    }
    private var actions: some View {
        ActionsPanel(document: document, exportPNG: { exportPNG() }, comparison: { contactSheet() }, hideInterface: { panel = nil; immersive = true }).frame(height: 600)
    }
    private var layers: some View { LayerPanel(document: document) }
    private func layerBinding<T>(_ id: UUID, _ keyPath: WritableKeyPath<PaintLayer, T>) -> Binding<T> {
        Binding(get: { (document.contents.layers.first { $0.id == id } ?? document.selectedLayer)[keyPath: keyPath] },
                set: { value in document.change { c in if let index = c.layers.firstIndex(where: { $0.id == id }) { c.layers[index][keyPath: keyPath] = value } } })
    }
    private func exportPNG() {
        do {
            let image = try MetalPainter().image(document.contents)
            guard let data = image.pngData() else { throw RenderError.command("PNG") }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Atelier-\(document.contents.id).png")
            try data.write(to: url, options: .atomic); exportURL = url; panel = nil; showingShare = true
        } catch { document.errorMessage = error.localizedDescription }
    }
    private func contactSheet() {
        busy = true; panel = nil
        Task { @MainActor in
            defer { busy = false }
            do {
                let url = try RendererEvidence.generate(brushes: brushes.brushes)
                exportURL = url; showingShare = true
            } catch { document.errorMessage = error.localizedDescription }
        }
    }
    private func rgba(_ color: Color) -> SIMD4<Float> {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return SIMD4(Float(r), Float(g), Float(b), Float(a))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let urls: [URL]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: urls, applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
