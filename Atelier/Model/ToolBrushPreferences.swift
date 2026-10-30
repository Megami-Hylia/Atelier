import Foundation

/// Workspace controls belong to a tool and preset; brush engine parameters remain in BrushStore.
struct ToolBrushPreferences {
    struct Values: Codable, Equatable {
        var size: Float = 32
        var opacity: Float = 1

        var isValid: Bool {
            size.isFinite && (1...256).contains(size) && opacity.isFinite && (0.01...1).contains(opacity)
        }
    }

    private let defaults: UserDefaults
    private let key = "atelier.toolBrushPreferences.v1"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func values(tool: PaintTool, brushID: String) -> Values {
        guard let data = defaults.data(forKey: key),
              let saved = try? JSONDecoder().decode([String: [String: Values]].self, from: data),
              let value = saved[tool.rawValue]?[brushID], value.isValid else { return Values() }
        return value
    }

    func save(_ value: Values, tool: PaintTool, brushID: String) {
        guard value.isValid else { return }
        var saved = defaults.data(forKey: key).flatMap {
            try? JSONDecoder().decode([String: [String: Values]].self, from: $0)
        } ?? [:]
        saved[tool.rawValue, default: [:]][brushID] = value
        // Values are finite scalars, so this encoding cannot fail for supported inputs.
        if let data = try? JSONEncoder().encode(saved) { defaults.set(data, forKey: key) }
    }
}
