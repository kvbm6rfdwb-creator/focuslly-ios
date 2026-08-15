import Foundation
import WidgetKit

// MARK: - Shared widget data (widget-side copy — keep in sync with main app’s FocusWidgetData.swift)
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

    // Must be called on the main actor: WidgetCenter.shared is not Sendable and
    // reloadTimelines internally dispatches UI work.
    @MainActor
    static func write(_ data: FocusWidgetData) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    @MainActor
    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.removeObject(forKey: userDefaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    // Evict stale entry immediately on read.
    static func read() -> FocusWidgetData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(FocusWidgetData.self, from: data)
        else { return nil }
        if decoded.endDate < Date().addingTimeInterval(-120) {
            defaults.removeObject(forKey: userDefaultsKey)
            return nil
        }
        return decoded
    }
}

// MARK: - Idle-state insights
//
// This struct is the widget-extension mirror of the main-app copy.
// Keep fields and static constants in sync with
// Personal Productivity/FocusWidgetData.swift.
// Persistence write path lives in the main app (LiveWidgetInsightsPersistence);
// the extension only reads.
struct FocusWidgetInsights: Codable, Equatable {

    // MARK: Task state
    var pendingTaskCount: Int   = 0
    var completedToday: Int     = 0
    var currentTaskTitle: String?
    var nextTaskTitle: String?

    // MARK: Session state
    var focusMinutesToday: Int  = 0
    var weeklyStreakDays: Int    = 0

    // MARK: Metadata
    /// UTC timestamp written by the coordinator at persistence time.
    var lastUpdated: Date       = Date()

    static let stalenessWindow: TimeInterval = 4 * 60 * 60 // 4 hours
    static let userDefaultsKey = "focusWidgetInsights"

    /// Reads insights from the shared suite, discarding the entry if it is
    /// older than `stalenessWindow` so the widget never shows stale data.
    static func read() -> FocusWidgetInsights? {
        guard let defaults = UserDefaults(suiteName: FocusWidgetData.appGroupID),
              let data    = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(FocusWidgetInsights.self, from: data)
        else { return nil }
        guard Date().timeIntervalSince(decoded.lastUpdated) < stalenessWindow else {
            defaults.removeObject(forKey: userDefaultsKey)
            return nil
        }
        return decoded
    }
}
