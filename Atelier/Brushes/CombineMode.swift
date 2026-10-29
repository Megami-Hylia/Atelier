import Foundation

enum CombineMode: Int, CaseIterable, Identifiable {
    // Preserve IDs from existing Atelier archives.
    case normal = 0, multiply = 1, screen = 2, darken = 3, colourBurn = 4, linearBurn = 5
    case lighten = 6, colourDodge = 7, overlay = 8, hardMix = 9, difference = 10
    var id: Int { rawValue }
    static let menuOrder: [CombineMode] = [.multiply, .darken, .colourBurn, .linearBurn, .normal, .lighten, .colourDodge, .overlay, .hardMix, .difference, .screen]
    var title: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .screen: return "Screen"
        case .darken: return "Darken"
        case .colourBurn: return "Colour Burn"
        case .linearBurn: return "Linear Burn"
        case .lighten: return "Lighten"
        case .colourDodge: return "Colour Dodge"
        case .overlay: return "Overlay"
        case .hardMix: return "Hard Mix"
        case .difference: return "Difference"
        }
    }
}
