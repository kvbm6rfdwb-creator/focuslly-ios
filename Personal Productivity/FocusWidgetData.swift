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
    // FocusSessionEngine call sites must dispatch to the main actor; see writeWidgetData().
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

    // Fix G: Evict the stale key immediately on read instead of silently discarding
    // so subsequent timeline reloads do not repeatedly decode the same dead payload.
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
struct FocusWidgetInsights: Codable {
    var dialsToday: Int        = 0
    var dialTarget: Int        = 55
    var sessionsToday: Int     = 0
    var focusMinutesToday: Int = 0
    var hotLeadsCount: Int     = 0
    var pendingActions: Int    = 0
    var currentStreak: Int     = 0
    /// UTC timestamp written at the moment this snapshot is persisted.
    /// The widget extension rejects snapshots older than stalenessWindow.
    var writtenAt: Date        = Date()

    /// Maximum age before insights are considered stale and discarded by the extension.
    static let stalenessWindow: TimeInterval = 4 * 60 * 60 // 4 hours

    static let userDefaultsKey = "focusWidgetInsights"

    // Fix C + A: @MainActor annotation added; this write path was previously
    // unannotated and never called. TaskStore.logSession() and DashboardViewModel
    // should call this after any data change that affects the idle widget panel.
    @MainActor
    static func write(_ insights: FocusWidgetInsights) {
        guard let defaults = UserDefaults(suiteName: FocusWidgetData.appGroupID) else { return }
        if let encoded = try? JSONEncoder().encode(insights) {
            defaults.set(encoded, forKey: userDefaultsKey)
        }
        // Fix E (insights path): reloadTimelines is owned here; callers must NOT
        // call reloadTimelines themselves after invoking this method.
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
