import SwiftUI

struct ActionsPanel: View {
    @ObservedObject var document: PaintDocument
    var exportPNG: () -> Void
    var comparison: () -> Void
    var hideInterface: () -> Void
    @State private var tab = 4
    @AppStorage("lightInterface") private var light = false
    @AppStorage("leftHanded") private var rightInterface = false
    @AppStorage("brushCursor") private var cursor = true
    @AppStorage("fingerPainting") private var fingers = false
    @AppStorage("strokeStabilization") private var stabilization = 0.0
    @AppStorage("pencilPressureExponent") private var pressure = 1.0
    @AppStorage("selectionOverlayOpacity") private var selectionOpacity = 0.25
    private let names = ["Aggiungi", "Tela", "Condividi", "Video", "Pref.", "Aiuto"]
    private let icons = ["plus.square.on.square", "rectangle", "square.and.arrow.up", "play.fill", "switch.2", "questionmark.circle"]
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Azioni").font(PanelStyle.title); Spacer() }.padding(16)
            HStack(spacing: 0) {
                ForEach(0..<names.count, id: \.self) { index in
                    Button { tab = index } label: {
                        VStack(spacing: 6) { Image(systemName: icons[index]).font(.system(size: 19)); Text(names[index]).font(.system(size: 10)) }
                            .foregroundStyle(tab == index ? Color.blue : Color(white: 0.7)).frame(maxWidth: .infinity).frame(minHeight: 48)
                    }.buttonStyle(.plain).accessibilityLabel(names[index])
                }
            }.padding(.horizontal, 8)
            List {
                if tab == 0 {
                    Button("Nuovo livello") { document.addLayer() }
                    Button("Incolla livelli Atelier") { document.pasteLayers() }
                    Button("Copia livello") { document.copyLayers() }
                }
                if tab == 1 {
                    Section("Tela") {
                        Text("\(document.contents.width) × \(document.contents.height) pixel")
                        Text("\(document.contents.dpi) DPI · \(document.contents.colorSpace)")
                        Toggle("Sfondo trasparente", isOn: Binding(get: { document.contents.background.w == 0 }, set: { enabled in document.change { $0.background.w = enabled ? 0 : 1 } }))
                        Button("Rifletti orizzontalmente il livello") { document.flipLayer(horizontal: true) }
                        Button("Rifletti verticalmente il livello") { document.flipLayer(horizontal: false) }
                    }
                }
                if tab == 2 {
                    Button("Immagine PNG", action: exportPNG)
                    if let url = document.storageURL { ShareLink("Documento Atelier", item: url) }
                    Button("Tavola dei pennelli", action: comparison)
                }
                if tab == 3 {
                    Text("Registrazione, replay e esportazione time-lapse non sono ancora implementati.").font(.footnote).foregroundStyle(.secondary)
                }
                if tab == 4 {
                    Section {
                        Toggle("Interfaccia luce", isOn: $light)
                        Toggle("Interfaccia destra", isOn: $rightInterface)
                        Toggle("Cursore pennello", isOn: $cursor)
                    }
                    Section("Controlli gestuali") {
                        Toggle("Disegna con le dita", isOn: $fingers)
                        Text("Due dita: annulla. Tre dita: ripeti. Scorri in basso con tre dita per Copia e Incolla, con quattro per il menu rapido.").font(.caption)
                    }
                    Section("Stabilizzazione tratto") {
                        HStack { Text("Stabilizzazione"); Spacer(); Text("\(Int(stabilization*100))%") }
                        Slider(value: $stabilization, in: 0...1).accessibilityLabel("Stabilizzazione tratto")
                        Text("Bassa: segue la mano. Alta: attenua il tremolio; i movimenti rapidi restano reattivi.").font(.caption)
                    }
                    Section("Curva pressione") {
                        HStack { Text("Risposta Pencil"); Spacer(); Text(pressure, format: .number.precision(.fractionLength(2))) }
                        Slider(value: $pressure, in: 0.2...3).accessibilityLabel("Curva pressione Pencil")
                        Button("Ripristina pressione") { pressure = 1 }
                    }
                    Section("Visibilità selezione") { Slider(value: $selectionOpacity, in: 0.1...1).accessibilityLabel("Opacità contorno selezione") }
                    Button("Nascondi interfaccia", action: hideInterface)
                }
                if tab == 5 {
                    Text("Atelier").font(.headline)
                    Text("Disegno locale e offline. Nessun acquisto o abbonamento.")
                    Text("Le modifiche si salvano nel documento. L’app e la parità funzionale sono ancora incomplete.").font(.footnote)
                }
            }.listStyle(.plain).scrollContentBackground(.hidden)
        }.atelierPanel()
    }
}
