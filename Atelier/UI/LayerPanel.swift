import SwiftUI

struct LayerPanel: View {
    @ObservedObject var document: PaintDocument
    @State private var optionsID: UUID?
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Livelli").font(.title2.bold()); Spacer(); Button { document.addLayer() } label: { Image(systemName: "plus").font(.title2) }.accessibilityLabel("Nuovo livello") }.padding(18)
            List {
                ForEach(Array(document.contents.layers.reversed())) { layer in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 4).fill(Color(white: 0.24)).frame(width: 58, height: 58)
                            .overlay(Image(systemName: layer.locked ? "lock.fill" : "paintbrush.pointed").foregroundStyle(.white.opacity(0.6)))
                        Text(layer.name).font(.system(size: 16, weight: .semibold)).lineLimit(2)
                        Spacer(minLength: 4)
                        Text(["N", "M", "S"][min(2, max(0, layer.blendMode))]).font(.caption.bold())
                        Button { binding(layer.id, \.visible).wrappedValue.toggle() } label: {
                            Image(systemName: layer.visible ? "checkmark.square.fill" : "square").frame(width: 32, height: 44)
                        }.buttonStyle(.plain).accessibilityLabel(layer.visible ? "Nascondi livello" : "Mostra livello")
                    }
                    .foregroundStyle(.white).padding(.vertical, 5).contentShape(Rectangle())
                    .onTapGesture { document.selectLayer(layer.id); optionsID = layer.id }
                    .listRowBackground(document.selectedLayer.id == layer.id ? Color.blue : Color(white: 0.13))
                    .listRowSeparatorTint(Color(white: 0.18))
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Elimina", role: .destructive) { document.deleteLayer(layer.id) }.disabled(document.contents.layers.count <= 1)
                        Button("Duplica") { document.duplicateLayer(layer.id) }.tint(Color(white: 0.28))
                        Button(layer.locked ? "Sblocca" : "Blocca") { binding(layer.id, \.locked).wrappedValue.toggle() }.tint(Color(white: 0.22))
                    }
                    .popover(isPresented: Binding(get: { optionsID == layer.id }, set: { if !$0 { optionsID = nil } }), arrowEdge: .trailing) {
                        layerOptions(layer).frame(width: 260, height: 390)
                    }
                }
                HStack {
                    Rectangle().fill(Color(red: Double(document.contents.background.x), green: Double(document.contents.background.y), blue: Double(document.contents.background.z))).frame(width: 58, height: 48)
                    Text("Colore di sfondo").font(.subheadline.bold()); Spacer()
                    Button { document.change { $0.background.w = $0.background.w == 0 ? 1 : 0 } } label: { Image(systemName: document.contents.background.w > 0 ? "checkmark.square.fill" : "square") }.buttonStyle(.plain).accessibilityLabel("Visibilità sfondo")
                }.listRowBackground(Color(white: 0.1))
            }.listStyle(.plain).scrollContentBackground(.hidden)
        }.background(Color(white: 0.11))
    }
    private func layerOptions(_ layer: PaintLayer) -> some View {
        Form {
            TextField("Rinomina", text: binding(layer.id, \.name))
            Slider(value: binding(layer.id, \.opacity), in: 0...1) { Text("Opacità") }
            Picker("Fusione", selection: binding(layer.id, \.blendMode)) { Text("Normale").tag(0); Text("Moltiplica").tag(1); Text("Scolora").tag(2) }
            Button("Copia") { document.copyLayers(); optionsID = nil }
            Button(layer.locked ? "Sblocca" : "Blocca") { binding(layer.id, \.locked).wrappedValue.toggle() }
            Button("Duplica") { document.duplicateLayer(layer.id); optionsID = nil }
            Button("Unisci sotto") { document.mergeSelectedDown(); optionsID = nil }.disabled(!document.canMergeSelected)
            Button("Cancella contenuto", role: .destructive) { document.clearLayer(); optionsID = nil }.disabled(layer.locked)
            Button("Elimina livello", role: .destructive) { document.deleteLayer(layer.id); optionsID = nil }.disabled(document.contents.layers.count <= 1)
        }
    }
    private func binding<T>(_ id: UUID, _ key: WritableKeyPath<PaintLayer, T>) -> Binding<T> {
        Binding(get: { (document.contents.layers.first { $0.id == id } ?? document.selectedLayer)[keyPath: key] }, set: { newValue in
            document.change { value in if let index = value.layers.firstIndex(where: { $0.id == id }) { value.layers[index][keyPath: key] = newValue } }
        })
    }
}

struct GestureCommandPanel: View {
    @ObservedObject var document: PaintDocument
    var quick: Bool
    var close: () -> Void
    var body: some View {
        VStack(spacing: 14) {
            HStack { Text(quick ? "Menu rapido" : "Copia e Incolla").font(.headline); Spacer(); Button(action: close) { Image(systemName: "xmark.circle.fill") }.accessibilityLabel("Chiudi") }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 18) { commands }
                ScrollView(.horizontal) { HStack(spacing: 18) { commands } }
            }
        }.padding(16).frame(maxWidth: 620).background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 12)).foregroundStyle(.white)
    }
    @ViewBuilder private var commands: some View {
        if quick {
            command("Nuovo livello", "plus.square") { document.addLayer() }
            command("Rifletti verticale", "arrow.up.and.down.righttriangle.up.righttriangle.down") { document.flipLayer(horizontal: false) }
            command("Rifletti orizzontale", "arrow.left.and.right.righttriangle.left.righttriangle.right") { document.flipLayer(horizontal: true) }
            command("Cancella livello", "eraser") { document.clearLayer() }
            command("Copia", "doc.on.doc") { document.copyLayers() }
            command("Unisci sotto", "square.3.layers.3d") { document.mergeSelectedDown() }.disabled(!document.canMergeSelected)
        } else {
            command("Taglia", "scissors") { document.copyLayers(cut: true) }
            command("Copia", "doc.on.doc") { document.copyLayers() }
            command("Copia tutto", "square.on.square") { document.copyLayers(all: true) }
            command("Duplica", "plus.square.on.square") { document.duplicateLayer(document.selectedLayer.id) }
            command("Taglia e incolla", "rectangle.split.2x1") { document.copyLayers(cut: true); if document.errorMessage == nil { document.pasteLayers() } }
            command("Incolla", "doc.on.clipboard") { document.pasteLayers() }
        }
    }
    private func command(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button { action(); close() } label: { VStack(spacing: 8) { Image(systemName: symbol).font(.title3); Text(title).font(.caption2).multilineTextAlignment(.center) }.frame(width: 76, height: 56) }.buttonStyle(.plain)
    }
}
