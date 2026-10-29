import SwiftUI

struct TransformSelectionView: View {
    @ObservedObject var document: PaintDocument
    var initialSelection: Set<UUID>? = nil
    var close: () -> Void
    @AppStorage("selectionOverlayOpacity") private var overlayOpacity = 0.25
    @State private var selected = Set<UUID>()
    @State private var marquee: CGRect?
    @State private var moving = true
    @State private var mode = 1
    @State private var snapping = false
    @State private var originals: [PaintStroke] = []
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
                            var dx = value.translation.width / sx, dy = value.translation.height / sy
                            if snapping, let bounds {
                                let targetX = CGFloat(document.contents.width)/2, targetY = CGFloat(document.contents.height)/2
                                if abs(bounds.midX+dx-targetX) < 8/sx { dx = targetX-bounds.midX }
                                if abs(bounds.midY+dy-targetY) < 8/sy { dy = targetY-bounds.midY }
                            }
                            transform { point, _ in CGPoint(x: point.x + dx, y: point.y + dy) }
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
                    ForEach(0..<8) { index in
                        let positions = [CGPoint(x: box.minX,y: box.minY), CGPoint(x: box.midX,y: box.minY), CGPoint(x: box.maxX,y: box.minY), CGPoint(x: box.maxX,y: box.midY), CGPoint(x: box.maxX,y: box.maxY), CGPoint(x: box.midX,y: box.maxY), CGPoint(x: box.minX,y: box.maxY), CGPoint(x: box.minX,y: box.midY)]
                        Circle().fill(.blue).overlay(Circle().stroke(.white, lineWidth: 1)).frame(width: 8, height: 8)
                            .frame(width: 36, height: 36).contentShape(Rectangle()).position(positions[index])
                            .gesture(DragGesture(minimumDistance: 1).onEnded { value in
                                let dx = value.translation.width / sx, dy = value.translation.height / sy
                                let left = index == 0 || index == 6 || index == 7
                                let top = index == 0 || index == 1 || index == 2
                                if mode >= 2 {
                                    transform { point, _ in
                                        let u = min(1, max(0, (point.x-bounds.minX)/max(1,bounds.width)))
                                        let v = min(1, max(0, (point.y-bounds.minY)/max(1,bounds.height)))
                                        let wx = index == 1 || index == 5 ? 1 : left ? 1-u : u
                                        let wy = index == 3 || index == 7 ? 1 : top ? 1-v : v
                                        let weight = mode == 2 ? wx*wy : pow(wx*wy, 2)
                                        return CGPoint(x: point.x+dx*weight, y: point.y+dy*weight)
                                    }
                                } else {
                                    var fx = max(0.05, 1 + (left ? -dx : dx)/max(1,bounds.width))
                                    var fy = max(0.05, 1 + (top ? -dy : dy)/max(1,bounds.height))
                                    if index == 1 || index == 5 { fx = 1 }
                                    if index == 3 || index == 7 { fy = 1 }
                                    if mode == 1 { let f = abs(fx-1) > abs(fy-1) ? fx : fy; fx = f; fy = f }
                                    transform(scale: Float(sqrt(fx*fy))) { point, center in CGPoint(x: center.x+(point.x-center.x)*fx,y: center.y+(point.y-center.y)*fy) }
                                }
                            }).accessibilityLabel("Maniglia trasformazione \(index+1)")
                    }
                    Path { p in p.move(to: CGPoint(x: box.midX,y: box.minY)); p.addLine(to: CGPoint(x: box.midX,y: box.minY-30)) }.stroke(.green,lineWidth: 1).allowsHitTesting(false)
                    Circle().fill(.green).frame(width: 9,height: 9).frame(width: 36,height: 36).contentShape(Rectangle()).position(x: box.midX,y: box.minY-30)
                        .gesture(DragGesture().onEnded { value in
                            var angle = atan2(box.minY-30+value.translation.height-box.midY,value.translation.width) + .pi/2
                            if snapping { angle = (angle/(.pi/4)).rounded() * (.pi/4) }
                            rotate(angle)
                        }).accessibilityLabel("Ruota selezione")

                }
                VStack(spacing: 8) {
                    HStack(spacing: 4) {
                        ForEach(Array(["Forma libera", "Uniforme", "Distorci", "Altera"].enumerated()), id: \.offset) { index, title in
                            Button { mode = index; moving = true } label: {
                                Text(title).font(.system(size: 12,weight: .semibold)).padding(.horizontal,12).frame(height: 32)
                                    .background(mode == index ? PanelStyle.selection : Color(white: 0.18),in: RoundedRectangle(cornerRadius: 6))
                            }.buttonStyle(.plain)
                        }
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 18) {
                            Menu("Seleziona") {
                                Button("Rettangolo") { shape = 0; moving = false }
                                Button("Ellisse") { shape = 1; moving = false }
                                Toggle("Aggiungi", isOn: $additive)
                            }
                            Toggle("Aggancio", isOn: $snapping).fixedSize()
                            Button("Adatta alla tela") {
                                if let bounds { scale(min(CGFloat(document.contents.width)/max(1,bounds.width),CGFloat(document.contents.height)/max(1,bounds.height)))
                                    if let fitted = self.bounds { transform { point, _ in CGPoint(x: point.x+CGFloat(document.contents.width)/2-fitted.midX,y: point.y+CGFloat(document.contents.height)/2-fitted.midY) } }
                                }
                            }
                            Button("Ripristina") {
                                document.change { contents in
                                    guard let index = contents.layers.firstIndex(where: { $0.id == document.selectedLayer.id }) else { return }
                                    for i in contents.layers[index].strokes.indices {
                                        if let original = originals.first(where: { $0.id == contents.layers[index].strokes[i].id }), selected.contains(original.id) { contents.layers[index].strokes[i] = original }
                                    }
                                }
                            }
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
                }.padding(10).atelierPanel()
            }
        }.onAppear { originals = document.selectedLayer.strokes; selected = initialSelection ?? Set(originals.map(\.id)) }
    }
    private func rotate(_ angle: CGFloat) {
        transform(rotation: Float(angle)) { point, center in
            let x = point.x-center.x, y = point.y-center.y
            return CGPoint(x: center.x+x*cos(angle)-y*sin(angle),y: center.y+x*sin(angle)+y*cos(angle))
        }
    }
    private func outline(_ rect: CGRect, ellipse: Bool) -> some View {
        Path { path in if ellipse { path.addEllipse(in: rect) } else { path.addRect(rect) } }
            .stroke(Color.blue.opacity(overlayOpacity), style: StrokeStyle(lineWidth: 1.5, dash: [4,4])).allowsHitTesting(false)
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
