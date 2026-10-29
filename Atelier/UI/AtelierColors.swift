import SwiftUI

struct AtelierColors: View {
    @Binding var color: Color
    @AppStorage("colorSelectorMode") private var mode = 1
    @State private var previousColor = Color.black
    @State private var hue: Double = 0
    @State private var saturation: Double = 0
    @State private var brightness: Double = 0.05
    @State private var hex = "0D0D0D"
    @AppStorage("colorHistory") private var history = "0D0D0D,FFFFFF,EB5B3F,DFBA6B,4E7689,64724B,8D5891"
    @AppStorage("customPalette") private var palette = "DB6B3F,E8C578,466F79,304D5F,77624B,A34A4A,EEE8DC,2D2D2D"
    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(Color(white: 0.4)).frame(width: 36, height: 3).padding(.top, 4)
            HStack {
                Text("Colori").font(PanelStyle.title)
                Spacer()
                HStack(spacing: 0) {
                    Rectangle().fill(color).frame(width: 38, height: 22).accessibilityLabel("Colore attuale")
                    Button { let old = color; color = previousColor; previousColor = old; sync(); remember() } label: { Rectangle().fill(previousColor).frame(width: 38, height: 22) }.accessibilityLabel("Colore precedente")
                }.clipShape(RoundedRectangle(cornerRadius: 4))
            }.padding(.horizontal, 16).padding(.vertical, 7)
            ScrollView {
                VStack(spacing: mode == 1 ? 0 : 10) {
                    if mode == 0 { disc }
                    if mode == 1 || mode == 2 {
                        square.frame(height: 310).clipped().padding(.bottom, 2)
                        ColorTrack(value: $hue, colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], label: "Tonalità", thumb: Color(hue: hue, saturation: 1, brightness: 1), edited: { apply(); remember() }).onChange(of: hue) { _, _ in apply() }
                        ColorTrack(value: $saturation, colors: [Color(white: brightness), Color(hue: hue, saturation: 1, brightness: brightness)], label: "Saturazione", thumb: Color(hue: hue, saturation: saturation, brightness: brightness), edited: { apply(); remember() }).onChange(of: saturation) { _, _ in apply() }
                        ColorTrack(value: $brightness, colors: [.black, Color(hue: hue, saturation: saturation, brightness: 1)], label: "Luminosità", thumb: Color(white: brightness), edited: { apply(); remember() }).onChange(of: brightness) { _, _ in apply() }
                    }
                    if mode == 2 {
                        sectionTitle("Complementari")
                        HStack(spacing: 0) {
                            ForEach([0.0, 0.5, 1.0 / 3, 2.0 / 3], id: \.self) { offset in
                                let candidate = Color(hue: (hue + offset).truncatingRemainder(dividingBy: 1), saturation: saturation, brightness: brightness)
                                Button { color = candidate; sync(); remember() } label: { Rectangle().fill(candidate).frame(height: 44) }.accessibilityLabel("Armonia con scostamento \(Int(offset * 360)) gradi")
                            }
                        }
                    }
                    if mode == 3 {
                        channel("R", component: 0); channel("G", component: 1); channel("B", component: 2)
                        HStack { Text("Esadecimale"); TextField("RRGGBB", text: $hex).textInputAutocapitalization(.characters).autocorrectionDisabled().onSubmit { select(hex); remember() } }
                    }
                    HStack {
                        Text("Cronologia").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Button("Cancella") { history = "" }.font(.system(size: 12)).foregroundStyle(.secondary)
                    }.padding(.top, 6)
                    swatches(history.split(separator: ",").prefix(10).joined(separator: ","))
                    sectionTitle("Progressione")
                    if mode == 1 { progression } else { swatches(palette) }
                    if mode == 4 {
                        HStack {
                            Button("Aggiungi colore") { palette = (palette.split(separator: ",").map(String.init) + [currentHex]).suffix(64).joined(separator: ",") }
                            Spacer()
                            Button("Rimuovi ultimo") { palette = palette.split(separator: ",").dropLast().joined(separator: ",") }.disabled(palette.isEmpty)
                        }.font(.caption).padding(.vertical, 8)
                    }
                }.padding(.horizontal, 4).padding(.bottom, 2)
            }.scrollIndicators(.hidden)
            HStack(spacing: 0) {
                tab("Disco", "circle", 0)
                tab("Classico", "square.fill", 1)
                tab("Armonia", "point.3.connected.trianglepath.dotted", 2)
                tab("Valori", "slider.horizontal.3", 3)
                tab("Tavolozze", "square.grid.3x3.fill", 4)
            }.padding(.top, 2).padding(.bottom, 2).background(Color(white: 0.085))
        }
        .background(Color(white: 0.105)).foregroundStyle(.white)
        .atelierPanel()
        .onAppear { previousColor = color; sync(); if !(0...4).contains(mode) { mode = 1 } }
        .onChange(of: color) { _, _ in sync() }.onDisappear { remember() }
    }
    private func sectionTitle(_ title: String) -> some View {
        HStack { Text(title).font(.system(size: 11, weight: .medium)); Spacer() }.padding(.horizontal, 5).frame(height: 26)
    }
    private func tab(_ name: String, _ icon: String, _ index: Int) -> some View {
        Button { mode = index } label: {
            VStack(spacing: 2) {
                Image(systemName: icon).font(.system(size: 19)).frame(height: 23)
                Text(name).font(.system(size: 10))
            }.foregroundStyle(mode == index ? Color.blue : Color(white: 0.65)).frame(maxWidth: .infinity).frame(minHeight: 44)
        }.buttonStyle(.plain).accessibilityLabel(name).accessibilityAddTraits(mode == index ? .isSelected : [])
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
                Circle().stroke(.white.opacity(0.9), lineWidth: 1.5).background(Circle().stroke(.black.opacity(0.65), lineWidth: 3)).frame(width: 14, height: 14)
                    .position(x: saturation * geometry.size.width, y: (1 - brightness) * geometry.size.height)
            }.contentShape(Rectangle()).gesture(DragGesture(minimumDistance: 0).onChanged { value in
                saturation = min(1, max(0, value.location.x / geometry.size.width)); brightness = 1 - min(1, max(0, value.location.y / geometry.size.height)); apply()
            }.onEnded { _ in remember() })
            .accessibilityLabel("Saturazione e luminosità").accessibilityValue("\(Int(saturation * 100)) e \(Int(brightness * 100)) percento")
        }
    }
    private var progression: some View {
        let rows = [
            ["12219A","25239D","422299","63218F","842080","A51D76","C51877","E6117E","F20989"],
            ["073CB5","2144B0","4349AA","674CA1","895095","AB518A","C94D88","E04491"],
            ["0393C3","1C91B6","3D8FA9","608B9F","838A9C","A68E9F","C095A7"]
        ]
        return VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(rows[row], id: \.self) { hex in
                        Button { select(hex); remember() } label: {
                            Rectangle().fill(colorFor(hex) ?? .clear).frame(width: 34, height: 33)
                        }.buttonStyle(.plain).accessibilityLabel("Progressione \(hex)")
                    }
                    Spacer(minLength: 0)
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func swatches(_ text: String) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 10), spacing: 1) {
            ForEach(Array(text.split(separator: ",").enumerated()), id: \.offset) { _, value in
                Button { select(String(value)) } label: { Rectangle().fill(colorFor(String(value)) ?? .clear).frame(height: 30) }.accessibilityLabel("Colore \(value)")
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
        if b > 0 && s > 0 { hue = Double(h) }
        if b > 0 { saturation = Double(s) }
        brightness = Double(b); hex = currentHex
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

private struct ColorTrack: View {
    @Binding var value: Double
    let colors: [Color]
    let label: String
    var thumb: Color? = nil
    var edited: () -> Void
    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width - 14)
            ZStack(alignment: .leading) {
                LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing).frame(height: 4).clipShape(Capsule()).padding(.horizontal, 7)
                Circle().fill(thumb ?? colors.last ?? .white).overlay(Circle().stroke(Color(white: 0.8), lineWidth: 1.5)).frame(width: 10, height: 10).padding(.leading, 2).offset(x: min(1, max(0, value)) * width)
            }.frame(height: 30).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { point in value = min(1, max(0, (point.location.x - 7) / width)) }.onEnded { _ in edited() })
        }.frame(height: 30)
        .accessibilityElement().accessibilityLabel(label).accessibilityValue("\(Int(value * 100)) percento")
        .accessibilityAdjustableAction { direction in
            switch direction { case .increment: value = min(1, value + 0.01); case .decrement: value = max(0, value - 0.01); @unknown default: break }
            edited()
        }
    }
}
