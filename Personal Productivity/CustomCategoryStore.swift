import Foundation
import SwiftUI
import Combine

// MARK: - CustomCategory

/// A fully user-defined category (not one of the built-in TaskCategory enum cases).
struct CustomCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var icon: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, icon: String, colorHex: String) {
        self.id = id
        self.name = name
        self.icon = icon
        self.colorHex = colorHex
    }

    var color: Color {
        Color(hex: colorHex) ?? .orange
    }
}

// MARK: - CustomCategoryStore

final class CustomCategoryStore: ObservableObject {

    static let shared = CustomCategoryStore()

    private let customKey  = "custom_categories_v1"
    private let hiddenKey  = "builtin_hidden_categories_v1"

    /// User-added custom categories.
    @Published private(set) var customCategories: [CustomCategory] = []

    /// rawValues of built-in TaskCategory cases the user has hidden/removed.
    @Published private(set) var hiddenBuiltins: Set<String> = []

    private init() {
        if let data = UserDefaults.standard.data(forKey: customKey),
           let decoded = try? JSONDecoder().decode([CustomCategory].self, from: data) {
            customCategories = decoded
        }
        if let arr = UserDefaults.standard.array(forKey: hiddenKey) as? [String] {
            hiddenBuiltins = Set(arr)
        }
    }

    // MARK: - Custom categories

    func addCustomCategory(_ cat: CustomCategory) {
        customCategories.append(cat)
        saveCustom()
    }

    func updateCustomCategory(_ cat: CustomCategory) {
        if let idx = customCategories.firstIndex(where: { $0.id == cat.id }) {
            customCategories[idx] = cat
            saveCustom()
        }
    }

    func removeCustomCategory(id: UUID) {
        customCategories.removeAll { $0.id == id }
        saveCustom()
    }

    // MARK: - Built-in visibility

    func hide(builtin category: TaskCategory) {
        hiddenBuiltins.insert(category.rawValue)
        saveHidden()
    }

    func show(builtin category: TaskCategory) {
        hiddenBuiltins.remove(category.rawValue)
        saveHidden()
    }

    func isHidden(_ category: TaskCategory) -> Bool {
        hiddenBuiltins.contains(category.rawValue)
    }

    /// All built-in categories that are not hidden.
    var visibleBuiltins: [TaskCategory] {
        TaskCategory.allCases.filter { !isHidden($0) }
    }

    // MARK: - Persistence

    private func saveCustom() {
        if let data = try? JSONEncoder().encode(customCategories) {
            UserDefaults.standard.set(data, forKey: customKey)
        }
        objectWillChange.send()
    }

    private func saveHidden() {
        UserDefaults.standard.set(Array(hiddenBuiltins), forKey: hiddenKey)
        objectWillChange.send()
    }
}
