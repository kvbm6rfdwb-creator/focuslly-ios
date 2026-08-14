import Foundation
import WidgetKit

// MARK: - Shared widget data
struct FocusWidgetData: Codable {
    enum BlockKind: String, Codable {
        case focus
        case breakTime
    }

    let blockKind: BlockKind
    let taskTitle: String
    let endDate: Date
    let startDate: Date
    /// True when the user has explicitly paused — widget shows a frozen static time instead of a live countdown.
    var isPaused: Bool = false
    /// Remaining seconds at the moment of pause. Only meaningful when `isPaused` is true.
    var pausedRemainingSeconds: Int = 0

    static let userDefaultsKey = "focusWidgetData"
    static let appGroupID      = "group.com.karlo.personalproductivity.focus"

    static func write(_ data: FocusWidgetData) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.removeObject(forKey: userDefaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    static func read() -> FocusWidgetData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(FocusWidgetData.self, from: data)
        else { return nil }
        if decoded.endDate < Date().addingTimeInterval(-120) { return nil }
        return decoded
    }
}

// MARK: - Idle-state insights (written by main app, shown when no session is active)
struct FocusWidgetInsights: Codable {
    var dialsToday: Int        = 0
    var dialTarget: Int        = 55
    var sessionsToday: Int     = 0
    var focusMinutesToday: Int = 0
    var hotLeadsCount: Int     = 0
    var pendingActions: Int    = 0
    var currentStreak: Int     = 0

    static let userDefaultsKey = "focusWidgetInsights"

    static func write(_ insights: FocusWidgetInsights) {
        guard let defaults = UserDefaults(suiteName: FocusWidgetData.appGroupID) else { return }
        if let encoded = try? JSONEncoder().encode(insights) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    static func read() -> FocusWidgetInsights? {
        guard let defaults = UserDefaults(suiteName: FocusWidgetData.appGroupID),
              let data = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(FocusWidgetInsights.self, from: data)
        else { return nil }
        return decoded
    }
}
