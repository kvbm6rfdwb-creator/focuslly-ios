import Foundation
import Combine

// MARK: - CategoryNameStore
// Persists user-chosen display names and icon overrides for each TaskCategory.

final class CategoryNameStore: ObservableObject {

    static let shared = CategoryNameStore()

    private let udKey     = "category_custom_names_v1"
    private let iconUDKey = "category_custom_icons_v1"

    /// Custom names keyed by TaskCategory.rawValue. Absent / empty = use built-in title.
    @Published private(set) var customNames: [String: String] = [:]

    /// Custom SF Symbol names keyed by TaskCategory.rawValue. Absent / empty = use built-in icon.
    @Published private(set) var customIcons: [String: String] = [:]

    private init() {
        if let saved = UserDefaults.standard.dictionary(forKey: udKey) as? [String: String] {
            customNames = saved
        }
        if let saved = UserDefaults.standard.dictionary(forKey: iconUDKey) as? [String: String] {
            customIcons = saved
        }
    }

    // MARK: - Name Read/Write

    func name(for category: TaskCategory) -> String {
        let custom = customNames[category.rawValue] ?? ""
        return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? category.title
            : custom
    }

    func hasCustomName(for category: TaskCategory) -> Bool {
        let v = customNames[category.rawValue] ?? ""
        return !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setName(_ name: String, for category: TaskCategory) {
        customNames[category.rawValue] = name.trimmingCharacters(in: .whitespacesAndNewlines)
        saveNames()
        objectWillChange.send()
    }

    func resetName(for category: TaskCategory) {
        customNames.removeValue(forKey: category.rawValue)
        saveNames()
        objectWillChange.send()
    }

    func resetAll() {
        customNames = [:]
        customIcons = [:]
        saveNames()
        saveIcons()
        objectWillChange.send()
    }

    // MARK: - Icon Read/Write

    func icon(for category: TaskCategory) -> String {
        let custom = customIcons[category.rawValue] ?? ""
        return custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? category.icon
            : custom
    }

    func hasCustomIcon(for category: TaskCategory) -> Bool {
        let v = customIcons[category.rawValue] ?? ""
        return !v.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func setIcon(_ icon: String, for category: TaskCategory) {
        customIcons[category.rawValue] = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        saveIcons()
        objectWillChange.send()
    }

    func resetIcon(for category: TaskCategory) {
        customIcons.removeValue(forKey: category.rawValue)
        saveIcons()
        objectWillChange.send()
    }

    // MARK: - Persistence

    private func saveNames() {
        UserDefaults.standard.set(customNames, forKey: udKey)
    }

    private func saveIcons() {
        UserDefaults.standard.set(customIcons, forKey: iconUDKey)
    }
}
