import SwiftUI

// Shared visual language for floating editor panels.
enum PanelStyle {
    static let surface = Color(white: 0.12)
    static let content = Color(white: 0.10)
    static let sidebar = Color(white: 0.15)
    static let selection = Color(red: 0.03, green: 0.43, blue: 1)
    static let title = Font.system(size: 22, weight: .bold)
}

private struct AtelierPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .tint(PanelStyle.selection)
            .environment(\.defaultMinListRowHeight, 44)
            .background(PanelStyle.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .preferredColorScheme(.dark)
            .presentationBackground(PanelStyle.surface)
    }
}

extension View {
    func atelierPanel() -> some View { modifier(AtelierPanelStyle()) }
}
