import SwiftUI
import Combine

// MARK: - CategoryColorStore
// Persists user-chosen colours for each TaskCategory to UserDefaults.

final class CategoryColorStore: ObservableObject {

    static let shared = CategoryColorStore()

    private let udKey = "category_custom_colors_v1"

    /// Raw hex strings keyed by TaskCategory.rawValue. Empty string means "use default".
    @Published private(set) var customColors: [String: String] = [:]

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: udKey) as? [String: String] {
            customColors = saved
        }
    }

    // MARK: - Read

    func color(for category: TaskCategory) -> Color {
        guard let hex = customColors[category.rawValue], !hex.isEmpty else {
            return category.defaultColor
        }
        return Color(hex: hex) ?? category.defaultColor
    }

    // MARK: - Write

    func setColor(_ color: Color, for category: TaskCategory) {
        let hex = color.toHex() ?? ""
        customColors[category.rawValue] = hex
        save()
    }

    func resetColor(for category: TaskCategory) {
        customColors.removeValue(forKey: category.rawValue)
        save()
    }

    func resetAll() {
        customColors = [:]
        save()
    }

    private func save() {
        UserDefaults.standard.set(customColors, forKey: udKey)
    }
}

// MARK: - Color hex helpers

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >>  8) & 0xFF) / 255
        let b = Double( value        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else { return nil }
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - TaskCategory default color (separate from customisable .color)

extension TaskCategory {
    var defaultColor: Color {
        switch self {
        case .coreWork:      return .blue
        case .admin:         return .gray
        case .planning:      return .teal
        case .learning:      return .brg
        case .creative:      return .pink
        case .meetings:      return .yellow
        case .maintenance:   return .brown
        case .personalTasks: return .mint
        case .health:        return .red
        case .leisure:       return .cyan
        }
    }
}
