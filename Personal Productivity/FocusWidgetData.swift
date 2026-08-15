import Foundation
import WidgetKit

// MARK: - Shared widget data
// NOTE: This file must stay in sync with FocusWidgetExtension/FocusWidgetData.swift.
// Any structural change to FocusWidgetData or FocusWidgetInsights must be mirrored
// in both targets. The two copies exist because the widget extension cannot import
// the main app target directly.
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

    // Fix D: @MainActor required — WidgetCenter.shared is not Sendable.
    @MainActor
    static func write(_ data: FocusWidgetData) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    // Fix D: @MainActor — same reasoning as write(_:).
    @MainActor
    static func clear() {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.removeObject(forKey: userDefaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    // Fix G: Evict the stale key immediately on read.
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

// MARK: - Idle-state insights (written by main app, shown when no session is active)
//
// Persistence I/O for this type lives in WidgetInsightsPersistence /
// LiveWidgetInsightsPersistence. Do NOT add static write/read helpers here;
// that pattern was removed so the coordinator can own the full write+reload
// sequence and tests can inject a spy.
struct FocusWidgetInsights: Codable, Equatable {

    // MARK: Task state
    /// Number of tasks not yet marked complete.
    var pendingTaskCount: Int   = 0
    /// Tasks completed since midnight today.
    var completedToday: Int     = 0
    /// Title of the highest-priority pending task (nil when task list is empty).
    var currentTaskTitle: String?
    /// Title of the second-highest-priority pending task.
    var nextTaskTitle: String?

    // MARK: Session state
    /// Total focus minutes accumulated today across all logged sessions.
    var focusMinutesToday: Int  = 0
    /// Consecutive calendar days (ending today) with at least one focus session.
    var weeklyStreakDays: Int    = 0

    // MARK: Metadata
    /// UTC timestamp written by the coordinator at persistence time.
    /// The widget extension rejects snapshots older than `stalenessWindow`.
    var lastUpdated: Date       = Date()

    /// Maximum age before the extension considers this snapshot stale.
    static let stalenessWindow: TimeInterval = 4 * 60 * 60 // 4 hours

    /// UserDefaults key used by both LiveWidgetInsightsPersistence and the extension.
    static let userDefaultsKey = "focusWidgetInsights"
}
