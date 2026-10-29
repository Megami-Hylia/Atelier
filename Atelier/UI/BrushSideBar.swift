import SwiftUI

struct BrushSideBar: View {
    @Binding var size: Float
    @Binding var opacity: Float
    var onRight: Bool
    var canUndo: Bool
    var canRedo: Bool
    var undo: () -> Void
    var redo: () -> Void
    var colors: () -> Void
    @State private var adjusting: String?

    var body: some View {
        GeometryReader { geometry in
            let height = max(240, min(480, geometry.size.height - 40))
            let trackHeight = (height - 132) / 2
            VStack(spacing: 0) {
                track(value: $size, range: 1...256, name: "Dimensione pennello", id: "size", height: trackHeight)
                Button(action: colors) {
                    RoundedRectangle(cornerRadius: 4).stroke(Color(white: 0.55), lineWidth: 1.5)
                        .frame(width: 16, height: 16).frame(width: 44, height: 44)
                }.accessibilityLabel("Apri colori")
                track(value: $opacity, range: 0.01...1, name: "Opacità pennello", id: "opacity", height: trackHeight)
                Button(action: undo) { Image(systemName: "arrow.uturn.backward").frame(width: 44, height: 44) }
                    .disabled(!canUndo).keyboardShortcut("z", modifiers: .command).accessibilityLabel("Annulla")
                Button(action: redo) { Image(systemName: "arrow.uturn.forward").frame(width: 44, height: 44) }
                    .disabled(!canRedo).keyboardShortcut("z", modifiers: [.command, .shift]).accessibilityLabel("Ripeti")
            }
            .font(.system(size: 15, weight: .medium)).foregroundStyle(Color(white: 0.72))
            .buttonStyle(.plain)
            .background {
                RoundedRectangle(cornerRadius: 5).fill(Color(white: 0.075))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color(white: 0.23), lineWidth: 1))
                    .frame(width: 32)
            }
            .frame(width: 44, height: height)
            .position(x: 22, y: geometry.size.height / 2)
        }.frame(width: 44)
    }

    private func track(value: Binding<Float>, range: ClosedRange<Float>, name: String, id: String, height: CGFloat) -> some View {
        let fraction = CGFloat((value.wrappedValue - range.lowerBound) / (range.upperBound - range.lowerBound))
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 2).fill(Color(white: 0.19)).frame(width: 26, height: height - 12).padding(.top, 6)
            RoundedRectangle(cornerRadius: 3).fill(Color(white: adjusting == id ? 0.8 : 0.6))
                .frame(width: 26, height: 14).offset(y: 6 + (1 - fraction) * (height - 26))
        }
        .frame(width: 44, height: height).contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { drag in
                adjusting = id
                let progress = Float(min(1, max(0, 1 - (drag.location.y - 13) / (height - 26))))
                value.wrappedValue = range.lowerBound + progress * (range.upperBound - range.lowerBound)
            }.onEnded { _ in adjusting = nil })
        .overlay(alignment: onRight ? .trailing : .leading) {
            if adjusting == id {
                preview(id: id).offset(x: onRight ? -50 : 50).allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel(name)
        .accessibilityValue(id == "size" ? "\(Int(size)) pixel" : "\(Int(opacity * 100)) per cento")
        .accessibilityAdjustableAction { direction in
            let step = (range.upperBound - range.lowerBound) / 100
            switch direction {
            case .increment: value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
            case .decrement: value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
            @unknown default: break
            }
        }
    }

    private func preview(id: String) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(Color.white.opacity(id == "opacity" ? Double(opacity) : 1))
                    .frame(width: id == "size" ? max(6, 76 * CGFloat(sqrt(size / 256))) : 68,
                           height: id == "size" ? max(6, 76 * CGFloat(sqrt(size / 256))) : 68)
            }.frame(width: 116, height: 104)
            Text(id == "size" ? "Dimensione \(Int(size)) px" : "Opacità pennello \(Int(opacity * 100))%")
                .font(.system(size: 11, weight: .medium)).monospacedDigit().foregroundStyle(Color(red: 0.3, green: 0.57, blue: 1))
                .lineLimit(1).minimumScaleFactor(0.8)
        }.padding(10).frame(width: 140, height: 158)
            .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 9))
    }
}
