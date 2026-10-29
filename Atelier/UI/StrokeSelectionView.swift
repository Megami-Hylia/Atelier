import SwiftUI

struct StrokeSelectionView: View {
    @ObservedObject var document: PaintDocument
    @Binding var selected: Set<UUID>
    var color: SIMD4<Float>
    var transform: () -> Void
    var close: () -> Void
    @State private var mode = 0
    @State private var removing = false
    @State private var points: [CGPoint] = []
    @State private var tolerance: Double = 0.15
    @AppStorage("savedStrokeSelections") private var saved = "{}"
    private let names = ["Automatico", "Mano libera", "Rettangolo", "Ellisse"]

    var body: some View {
        GeometryReader { geometry in
            let sx = geometry.size.width / CGFloat(document.contents.width)
            let sy = geometry.size.height / CGFloat(document.contents.height)
            ZStack(alignment: .bottom) {
                Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let point = CGPoint(x: value.location.x/sx, y: value.location.y/sy)
                    if points.isEmpty { points = [CGPoint(x: value.startLocation.x/sx,y: value.startLocation.y/sy)] }
                    if mode == 1 { points.append(point) }
                    else { points = [points[0],point] }
                }.onEnded { _ in applySelection(); points = [] })
                ForEach(document.selectedLayer.strokes.filter { selected.contains($0.id) }) { stroke in
                    Path { path in
                        for (index, sample) in stroke.samples.enumerated() {
                            let point = CGPoint(x: CGFloat(sample.x)*sx,y: CGFloat(sample.y)*sy)
                            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }
                    }.stroke(.blue.opacity(0.8),style: StrokeStyle(lineWidth: 2,dash: [4,4])).allowsHitTesting(false)
                }
                selectionPath(scaleX: sx, scaleY: sy).stroke(.blue,style: StrokeStyle(lineWidth: 1.5,dash: [4,4])).allowsHitTesting(false)
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(0..<4) { index in
                            Button { mode = index } label: { Text(names[index]).font(.system(size: 12,weight: .semibold)).padding(.horizontal,12).frame(height: 32).background(mode == index ? PanelStyle.selection : Color(white: 0.18),in: RoundedRectangle(cornerRadius: 6)) }.buttonStyle(.plain)
                        }
                    }
                    if mode == 0 { HStack { Text("Tolleranza colore").font(.caption); Slider(value: $tolerance, in: 0...1).accessibilityLabel("Tolleranza selezione automatica") } }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 22) {
                            command("Aggiungi", "plus.square.fill") { removing = false }.tint(removing ? .white : .blue)
                            command("Rimuovi", "minus.square") { removing = true }.tint(removing ? .blue : .white)
                            command("Inverti", "square.lefthalf.filled") { selected = Set(document.selectedLayer.strokes.map(\.id)).subtracting(selected) }
                            command("Copia e incolla", "doc.on.doc") { document.copySelectedStrokes(selected); if document.errorMessage == nil { document.pasteLayers() } }.disabled(selected.isEmpty)
                            Menu {
                                Button("Salva selezione") { saveSelection() }.disabled(selected.isEmpty)
                                Button("Carica selezione") { loadSelection() }
                            } label: { Label("Salva e carica", systemImage: "heart.fill").labelStyle(.titleAndIcon).font(.caption) }
                            command("Riempimento colore", "drop.fill") { recolor() }.disabled(selected.isEmpty || document.selectedLayer.locked)
                            command("Cancella", "xmark") { selected = [] }
                            command("Trasforma", "arrow.up.left.and.arrow.down.right", action: transform).disabled(selected.isEmpty)
                            command("Fine", "checkmark", action: close)
                        }.padding(6)
                    }
                    Text("Selezione di tratti interi. Automatico confronta il colore; sfumatura e maschera pixel non disponibili.").font(.system(size: 10)).foregroundStyle(.secondary)
                }.padding(12).atelierPanel()
            }
        }
    }
    private func command(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { VStack(spacing: 5) { Image(systemName: icon).font(.system(size: 18)); Text(title).font(.system(size: 10)) }.frame(minWidth: 50,minHeight: 44) }.buttonStyle(.borderless)
    }
    private func selectionPath(scaleX: CGFloat = 1, scaleY: CGFloat = 1) -> Path {
        guard let first = points.first, let last = points.last else { return Path() }
        let rect = CGRect(x: min(first.x,last.x)*scaleX,y: min(first.y,last.y)*scaleY,width: abs(first.x-last.x)*scaleX,height: abs(first.y-last.y)*scaleY)
        return Path { path in
            if mode == 2 { path.addRect(rect) }
            else if mode == 3 { path.addEllipse(in: rect) }
            else if mode == 1 { path.addLines(points.map { CGPoint(x: $0.x*scaleX,y: $0.y*scaleY) }); path.closeSubpath() }
        }
    }
    private func applySelection() {
        let matches: Set<UUID>
        if mode == 0, let point = points.last {
            let nearest = document.selectedLayer.strokes.filter { $0.tool == .paint }.min { a,b in
                distance(a,to: point) < distance(b,to: point)
            }
            guard let nearest, distance(nearest,to: point) <= max(20, CGFloat(nearest.size)) else { return }
            matches = Set(document.selectedLayer.strokes.filter { stroke in
                stroke.tool == .paint && max(abs(stroke.color.x-nearest.color.x),max(abs(stroke.color.y-nearest.color.y),abs(stroke.color.z-nearest.color.z))) <= Float(tolerance)
            }.map(\.id))
        } else {
            let path = selectionPath()
            matches = Set(document.selectedLayer.strokes.filter { stroke in stroke.samples.contains { path.contains(CGPoint(x: CGFloat($0.x),y: CGFloat($0.y))) } }.map(\.id))
        }
        if removing { selected.subtract(matches) } else { selected.formUnion(matches) }
    }
    private func distance(_ stroke: PaintStroke, to point: CGPoint) -> CGFloat {
        stroke.samples.map { hypot(CGFloat($0.x)-point.x,CGFloat($0.y)-point.y) }.min() ?? .greatestFiniteMagnitude
    }
    private func recolor() {
        guard !document.selectedLayer.locked else { return }
        let id = document.selectedLayer.id
        document.change { contents in
            guard let index = contents.layers.firstIndex(where: { $0.id == id }) else { return }
            for i in contents.layers[index].strokes.indices where selected.contains(contents.layers[index].strokes[i].id) { contents.layers[index].strokes[i].color = color }
        }
    }
    private var saveKey: String { document.contents.id.uuidString + ":" + document.selectedLayer.id.uuidString }
    private func saveSelection() {
        var values = (try? JSONDecoder().decode([String:[UUID]].self, from: Data(saved.utf8))) ?? [:]
        values[saveKey] = Array(selected)
        if let data = try? JSONEncoder().encode(values), let text = String(data: data,encoding: .utf8) { saved = text }
    }
    private func loadSelection() {
        let values = (try? JSONDecoder().decode([String:[UUID]].self,from: Data(saved.utf8))) ?? [:]
        selected = Set(values[saveKey] ?? []).intersection(document.selectedLayer.strokes.map(\.id))
    }
}
