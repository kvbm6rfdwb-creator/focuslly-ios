import SwiftUI
import Combine

// MARK: - Meal Entry

struct MealEntry: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var type: MealType
    var notes: String = ""

    enum MealType: String, CaseIterable, Codable, Identifiable {
        case breakfast  = "Breakfast"
        case lunch      = "Lunch"
        case snack      = "Snack"
        case dinner     = "Dinner"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .breakfast: return "cup.and.saucer.fill"
            case .lunch:     return "fork.knife"
            case .snack:     return "apple.logo"
            case .dinner:    return "moon.fill"
            }
        }
        var color: Color {
            switch self {
            case .breakfast: return .orange
            case .lunch:     return .brg
            case .snack:     return .yellow
            case .dinner:    return .indigo
            }
        }
    }
}

// MARK: - MealStore

final class MealStore: ObservableObject {
    static let shared = MealStore()

    @Published private(set) var entries: [MealEntry] = []

    private let udKey = "meal_log_v1"

    private init() { load() }

    // MARK: - Public API

    func add(_ entry: MealEntry) {
        entries.append(entry)
        entries.sort { $0.date < $1.date }
        save()
    }

    func delete(_ entry: MealEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func todayEntries() -> [MealEntry] {
        entries.filter { Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    /// Minutes since the last meal today (nil = not eaten yet)
    var minutesSinceLastMeal: Int? {
        guard let last = todayEntries().last else { return nil }
        return max(0, Int(Date().timeIntervalSince(last.date) / 60))
    }

    /// True when the user ate lunch 30–120 min ago — classic post-lunch dip window
    var isInPostLunchDip: Bool {
        let today = todayEntries()
        guard let lunch = today.last(where: { $0.type == .lunch }) else { return false }
        let mins = Int(Date().timeIntervalSince(lunch.date) / 60)
        return mins >= 30 && mins <= 120
    }

    /// True when the user hasn't eaten anything today yet
    var hasNotEatenToday: Bool { todayEntries().isEmpty }

    /// True when it's been more than 4 hours since the last meal
    var isHungry: Bool {
        guard let mins = minutesSinceLastMeal else { return false }
        return mins > 240
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: udKey)
        }
    }

    private func load() {
        // Only keep last 7 days to avoid unbounded growth
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        if let data = UserDefaults.standard.data(forKey: udKey),
           let decoded = try? JSONDecoder().decode([MealEntry].self, from: data) {
            entries = decoded.filter { $0.date > cutoff }
        }
    }
}
