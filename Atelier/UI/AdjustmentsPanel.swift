import SwiftUI

struct AdjustmentsPanel: View {
    @ObservedObject var document: PaintDocument
    @State private var section: String?
    @State private var pending: [String: Float] = [:]
    private let groups: [(String, [(String, String, ClosedRange<Float>, Float)])] = [
        ("Tonalità, saturazione, luminosità", [("hue","Tonalità",-1...1,0),("saturation","Saturazione",0...2,1),("brightness","Luminosità",-0.5...0.5,0)]),
        ("Bilanciamento colore",[("red","Rosso",-0.3...0.3,0),("green","Verde",-0.3...0.3,0),("blue","Blu",-0.3...0.3,0)]),
        ("Curve",[("shadows","Ombre",-0.24...0.24,0),("midtones","Mezzitoni",-0.24...0.24,0),("highlights","Luci",-0.24...0.24,0)]),
        ("Mappa gradiente",[("lowR","Ombre: rosso",0...1,0),("lowG","Ombre: verde",0...1,0),("lowB","Ombre: blu",0...1,0.3),("highR","Luci: rosso",0...1,1),("highG","Luci: verde",0...1,0.3),("highB","Luci: blu",0...1,0.6)]),
        ("Controllo sfocatura",[("blur","Raggio",0...40,0)]),
        ("Sfocatura movimento",[("motion","Raggio",0...40,0),("angle","Direzione",-1...1,0)]),
        ("Sfocatura radiale",[("zoom","Intensità",0...60,0)]),
        ("Nitidezza",[("sharpness","Intensità",0...2,0)]),
        ("Bagliore diffuso",[("bloom","Intensità",0...2,0),("bloomRadius","Raggio",1...40,12)]),
        ("Mezzi toni",[("halftone","Dimensione punti",0...20,0)])
    ]
    var body: some View {
        VStack(spacing: 0) {
            HStack { Text("Regolazioni").font(.title2.bold()); Spacer(); if section != nil { Button("Indietro") { section = nil } } }.padding(16)
            List {
                if let section, let group = groups.first(where: { $0.0 == section }) {
                    Text(section).font(.headline)
                    if section == "Mappa gradiente" { Toggle("Attiva", isOn: Binding(get: { document.selectedLayer.adjustments?["gradient"] == 1 }, set: { set("gradient", $0 ? 1 : 0) })) }
                    ForEach(group.1, id: \.0) { parameter in
                        VStack(alignment: .leading) {
                            HStack { Text(parameter.1); Spacer(); Text(value(parameter.0, parameter.3), format: .number.precision(.fractionLength(2))).monospacedDigit() }
                            Slider(value: Binding(get: { value(parameter.0, parameter.3) }, set: { pending[parameter.0] = $0 }), in: parameter.2, onEditingChanged: { editing in if !editing, let value = pending.removeValue(forKey: parameter.0) { set(parameter.0, value) } }).accessibilityLabel(parameter.1)
                        }.padding(.vertical, 7)
                    }
                    Button("Ripristina questa regolazione") {
                        document.change { contents in
                            guard let index = contents.layers.firstIndex(where: { $0.id == document.selectedLayer.id }) else { return }
                            for parameter in group.1 { contents.layers[index].adjustments?.removeValue(forKey: parameter.0) }
                            if section == "Mappa gradiente" { contents.layers[index].adjustments?.removeValue(forKey: "gradient") }
                        }
                    }
                } else {
                    ForEach(groups, id: \.0) { group in Button(group.0) { section = group.0 }.foregroundStyle(.white).padding(.vertical, 7) }
                }
            }.listStyle(.plain).scrollContentBackground(.hidden)
            Text("Rilascia il cursore per applicare la regolazione.").font(.caption).foregroundStyle(.secondary).padding(.horizontal)
            Text("Livello: " + document.selectedLayer.name).font(.caption).foregroundStyle(.secondary).padding(10)
        }.background(Color(white: 0.12)).foregroundStyle(.white)
    }
    private func value(_ key: String, _ fallback: Float) -> Float { pending[key] ?? document.selectedLayer.adjustments?[key] ?? fallback }
    private func set(_ key: String, _ value: Float) {
        guard !document.selectedLayer.locked else { document.errorMessage = DocumentError.lockedLayer.localizedDescription; return }
        let id = document.selectedLayer.id
        document.change { contents in
            guard let index = contents.layers.firstIndex(where: { $0.id == id }) else { return }
            if contents.layers[index].adjustments == nil { contents.layers[index].adjustments = [:] }
            contents.layers[index].adjustments?[key] = value
        }
    }
}
