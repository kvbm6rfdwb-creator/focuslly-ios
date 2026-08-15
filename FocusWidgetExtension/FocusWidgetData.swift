import Foundation
import WidgetKit

// MARK: - Shared widget data (widget-side copy — keep in sync with main app's FocusWidgetData.swift)
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
    // reloadTimelines internally dispatches UI work. Callers off the main thread
    // should wrap in Task { @MainActor in ... }.
    @MainActor
    static func write(_ data: FocusWidgetData) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    // Must be called on the main actor: see write(_:) above.
    @MainActor
    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.removeObject(forKey: userDefaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    // Fix #1: When the stored entry is stale (endDate more than 120 s in the past)
    // remove it from UserDefaults immediately so subsequent timeline reloads do not
    // repeatedly decode and discard the same dead payload. Previously the stale key
    // persisted until the main app called clear() explicitly.
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
struct FocusWidgetInsights: Codable {
    var dialsToday: Int        = 0
    var dialTarget: Int        = 55
    var sessionsToday: Int     = 0
    var focusMinutesToday: Int = 0
    var hotLeadsCount: Int     = 0
    var pendingActions: Int    = 0
    var currentStreak: Int     = 0
    /// UTC timestamp of when this snapshot was written. Used by read() to reject stale data.
    var writtenAt: Date        = Date()

    /// Maximum age before insights are considered stale and discarded.
    static let stalenessWindow: TimeInterval = 4 * 60 * 60 // 4 hours

    static let userDefaultsKey = "focusWidgetInsights"

    // Fix #2: Reject insights that are older than stalenessWindow so the widget
    // never silently shows yesterday's dial count or streak as if current.
    static func read() -> FocusWidgetInsights? {
        guard let defaults = UserDefaults(suiteName: FocusWidgetData.appGroupID),
              let data = defaults.data(forKey: userDefaultsKey),
              let decoded = try? JSONDecoder().decode(FocusWidgetInsights.self, from: data)
        else { return nil }
        guard Date().timeIntervalSince(decoded.writtenAt) < stalenessWindow else {
            defaults.removeObject(forKey: userDefaultsKey)
            return nil
        }
        return decoded
    }
}
