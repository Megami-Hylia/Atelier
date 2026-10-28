import SwiftUI

struct AtelierColors: View {
    @Binding var color: Color
    @State private var mode = 0
    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0.05
    @State private var hex = "0D0D0D"
    @AppStorage("colorHistory") private var history = "0D0D0D,FFFFFF,EB5B3F,DFBA6B,4E7689,64724B,8D5891"
    @AppStorage("customPalette") private var palette = "DB6B3F,E8C578,466F79,304D5F,77624B,A34A4A,EEE8DC,2D2D2D"
    var body: some View {
        VStack(spacing: 15) {
            HStack { Text("Colori").font(.title2.bold()); Spacer(); Circle().fill(color).frame(width: 32, height: 32) }
            Picker("Selettore", selection: $mode) {
                Text("Disco").tag(0); Text("Classico").tag(1); Text("Valori").tag(2); Text("Palette").tag(3)
            }.pickerStyle(.segmented)
            if mode == 0 { disc }
            if mode == 1 { square.frame(height: 210); Slider(value: $hue, in: 0...1).tint(Color(hue: hue, saturation: 1, brightness: 1)).onChange(of: hue) { _, _ in apply() } }
            if mode == 2 {
                channel("R", component: 0); channel("G", component: 1); channel("B", component: 2)
                HStack { Text("Hex"); TextField("RRGGBB", text: $hex).textInputAutocapitalization(.characters).onSubmit { select(hex) } }
                Slider(value: $hue, in: 0...1) { Text("Tonalità") }.onChange(of: hue) { _, _ in apply() }
                Slider(value: $saturation, in: 0...1) { Text("Saturazione") }.onChange(of: saturation) { _, _ in apply() }
                Slider(value: $brightness, in: 0...1) { Text("Luminosità") }.onChange(of: brightness) { _, _ in apply() }
            }
            if mode == 3 {
                swatches(palette)
                HStack {
                    Button("Aggiungi colore") { palette = (palette.split(separator: ",").map(String.init) + [currentHex]).suffix(64).joined(separator: ",") }
                    Button("Rimuovi ultimo") { palette = palette.split(separator: ",").dropLast().joined(separator: ",") }
                }.font(.caption)
                Spacer()
            }
            HStack { Text("Cronologia").font(.caption); Spacer(); Button("Memorizza") { remember() }.font(.caption) }
            swatches(history)
        }.padding(18).onAppear { sync() }.onChange(of: color) { _, _ in sync() }.onDisappear { remember() }
    }
    private var disc: some View {
        ZStack {
            Circle().stroke(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center), lineWidth: 25)
                .frame(width: 230, height: 230)
                .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                    let angle = atan2(value.location.y - 115, value.location.x - 115)
                    hue = (Double(angle) / (2 * .pi) + 1).truncatingRemainder(dividingBy: 1); apply()
                })
            square.frame(width: 140, height: 140)
        }.frame(height: 260)
    }
    private var square: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(colors: [.white, Color(hue: hue, saturation: 1, brightness: 1)], startPoint: .leading, endPoint: .trailing)
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                Circle().stroke(.white, lineWidth: 2).background(Circle().stroke(.black, lineWidth: 4)).frame(width: 12, height: 12)
                    .position(x: saturation * geometry.size.width, y: (1 - brightness) * geometry.size.height)
            }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
                saturation = min(1, max(0, value.location.x / geometry.size.width)); brightness = 1 - min(1, max(0, value.location.y / geometry.size.height)); apply()
            })
            .accessibilityLabel("Saturazione e luminosità").accessibilityValue("\(Int(saturation * 100)) e \(Int(brightness * 100)) percento")
        }
    }
    private func swatches(_ text: String) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
            ForEach(Array(text.split(separator: ",").enumerated()), id: \.offset) { _, value in
                Button { select(String(value)) } label: { Rectangle().fill(colorFor(String(value)) ?? .clear).frame(height: 24) }.accessibilityLabel("Colore \(value)")
            }
        }
    }
    private func channel(_ title: String, component: Int) -> some View {
        let binding = Binding<Double>(get: { rgb[component] }, set: { value in
            var values = rgb; values[component] = value; color = Color(red: values[0], green: values[1], blue: values[2])
        })
        return HStack { Text(title).frame(width: 18); Slider(value: binding, in: 0...1); Text("\(Int(rgb[component] * 255))").monospacedDigit().frame(width: 32) }
    }
    private var rgb: [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a); return [Double(r), Double(g), Double(b)]
    }
    private var currentHex: String { rgb.map { String(format: "%02X", Int(($0 * 255).rounded())) }.joined() }
    private func apply() { color = Color(hue: hue, saturation: saturation, brightness: brightness); hex = currentHex }
    private func sync() {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 1
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        hue = Double(h); saturation = Double(s); brightness = Double(b); hex = currentHex
    }
    private func colorFor(_ hex: String) -> Color? {
        let text = hex.replacingOccurrences(of: "#", with: "")
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        return Color(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
    }
    private func select(_ hex: String) { if let color = colorFor(hex) { self.color = color; sync() } }
    private func remember() {
        history = ([currentHex] + history.split(separator: ",").map(String.init).filter { $0 != currentHex }).prefix(16).joined(separator: ",")
    }
}
