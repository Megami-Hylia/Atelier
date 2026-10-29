import SwiftUI

struct TransformSelectionView: View {
    @ObservedObject var document: PaintDocument
    var close: () -> Void
    @State private var selected = Set<UUID>()
    @State private var marquee: CGRect?
    @State private var moving = false
    @State private var delta = CGSize.zero
    @State private var shape = 0
    @State private var additive = false
    private var samples: [PencilSample] { document.selectedLayer.strokes.filter { selected.contains($0.id) }.flatMap(\.samples) }
    private var bounds: CGRect? {
        guard let first = samples.first else { return nil }
        return samples.dropFirst().reduce(CGRect(x: CGFloat(first.x), y: CGFloat(first.y), width: 1, height: 1)) { result, sample in
            result.union(CGRect(x: CGFloat(sample.x), y: CGFloat(sample.y), width: 1, height: 1))
        }.insetBy(dx: -8, dy: -8)
    }
    var body: some View {
        GeometryReader { geometry in
            let sx = geometry.size.width / CGFloat(document.contents.width)
            let sy = geometry.size.height / CGFloat(document.contents.height)
            ZStack(alignment: .bottom) {
                Color.clear.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        if moving { delta = value.translation }
                        else { marquee = CGRect(x: min(value.startLocation.x, value.location.x), y: min(value.startLocation.y, value.location.y), width: abs(value.translation.width), height: abs(value.translation.height)) }
                    }
                    .onEnded { value in
                        if moving {
                            transform { point, _ in CGPoint(x: point.x + value.translation.width / sx, y: point.y + value.translation.height / sy) }
                            delta = .zero
                        } else if let marquee {
                            let box = CGRect(x: marquee.minX / sx, y: marquee.minY / sy, width: marquee.width / sx, height: marquee.height / sy)
                            let matches = document.selectedLayer.strokes.filter { stroke in stroke.samples.contains { sample in
                                let point = CGPoint(x: CGFloat(sample.x), y: CGFloat(sample.y))
                                if shape == 0 { return box.contains(point) }
                                let x = (point.x - box.midX) / max(0.1, box.width / 2), y = (point.y - box.midY) / max(0.1, box.height / 2)
                                return x*x + y*y <= 1
                            } }.map(\.id)
                            if additive { selected.formUnion(matches) } else { selected = Set(matches) }
                            self.marquee = nil
                        }
                    })
                if let marquee { outline(marquee, ellipse: shape == 1) }
                if let bounds {
                    let box = CGRect(x: bounds.minX * sx + delta.width, y: bounds.minY * sy + delta.height, width: bounds.width * sx, height: bounds.height * sy)
                    outline(box, ellipse: false)
                    ForEach(0..<4) { index in
                        Circle().fill(.blue).overlay(Circle().stroke(.white, lineWidth: 1)).frame(width: 10, height: 10)
                            .position(x: index % 2 == 0 ? box.minX : box.maxX, y: index < 2 ? box.minY : box.maxY)
                            .gesture(DragGesture(minimumDistance: 1).onEnded { value in
                                let center = CGPoint(x: box.midX, y: box.midY)
                                let corner = CGPoint(x: index % 2 == 0 ? box.minX : box.maxX, y: index < 2 ? box.minY : box.maxY)
                                let before = hypot(corner.x-center.x, corner.y-center.y)
                                let after = hypot(corner.x+value.translation.width-center.x, corner.y+value.translation.height-center.y)
                                scale(min(10, max(0.1, after / max(1, before))))
                            })
                    }
                }
                VStack(spacing: 8) {
                    HStack {
                        Picker("Selezione", selection: $shape) { Text("Rettangolo").tag(0); Text("Ellisse").tag(1) }.pickerStyle(.segmented)
                        Toggle("Aggiungi", isOn: $additive).fixedSize()
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            Button("Tutto") { selected = Set(document.selectedLayer.strokes.map(\.id)) }
                            Button("Inverti selezione") { selected = Set(document.selectedLayer.strokes.map(\.id)).subtracting(selected) }
                            Toggle("Sposta", isOn: $moving).fixedSize()
                            Button("Riduci") { scale(0.9) }.disabled(selected.isEmpty)
                            Button("Ingrandisci") { scale(1.1) }.disabled(selected.isEmpty)
                            Button("Ruota 90°") { transform(rotation: .pi / 2) { point, center in CGPoint(x: center.x - (point.y-center.y), y: center.y + (point.x-center.x)) } }.disabled(selected.isEmpty)
                            Button("Rifletti H") { transform { point, center in CGPoint(x: 2*center.x-point.x, y: point.y) } }.disabled(selected.isEmpty)
                            Button("Rifletti V") { transform { point, center in CGPoint(x: point.x, y: 2*center.y-point.y) } }.disabled(selected.isEmpty)
                            Button("Annulla operazione") { document.undo() }.disabled(!document.canUndo)
                            Button("Fine", action: close)
                        }.font(.subheadline).padding(8)
                    }
                }.padding(10).background(Color(white: 0.1), in: RoundedRectangle(cornerRadius: 10)).foregroundStyle(.white)
            }
        }
    }
    private func outline(_ rect: CGRect, ellipse: Bool) -> some View {
        Path { path in if ellipse { path.addEllipse(in: rect) } else { path.addRect(rect) } }
            .stroke(.blue, style: StrokeStyle(lineWidth: 1.5, dash: [4,4])).allowsHitTesting(false)
    }
    private func scale(_ factor: CGFloat) {
        transform(scale: Float(factor)) { point, center in CGPoint(x: center.x + (point.x-center.x)*factor, y: center.y + (point.y-center.y)*factor) }
    }
    private func transform(scale: Float = 1, rotation: Float = 0, _ mapping: (CGPoint, CGPoint) -> CGPoint) {
        guard !document.selectedLayer.locked, let bounds else { return }
        let layerID = document.selectedLayer.id
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        document.change { value in
            guard let index = value.layers.firstIndex(where: { $0.id == layerID }) else { return }
            for i in value.layers[index].strokes.indices where selected.contains(value.layers[index].strokes[i].id) {
                value.layers[index].strokes[i].size *= scale
                for j in value.layers[index].strokes[i].samples.indices {
                    let sample = value.layers[index].strokes[i].samples[j]
                    let point = mapping(CGPoint(x: CGFloat(sample.x), y: CGFloat(sample.y)), center)
                    value.layers[index].strokes[i].samples[j].x = Float(point.x)
                    value.layers[index].strokes[i].samples[j].y = Float(point.y)
                    value.layers[index].strokes[i].samples[j].azimuth += rotation
                }
            }
        }
    }
}
