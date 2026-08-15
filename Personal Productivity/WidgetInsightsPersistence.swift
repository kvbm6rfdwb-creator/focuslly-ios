import Foundation
import WidgetKit

// MARK: - WidgetInsightsPersistence
//
// Abstracts the two side-effects that FocusWidgetInsightsCoordinator needs:
//   1. Reading / writing FocusWidgetInsights to the shared App Group suite.
//   2. Asking WidgetKit to reload the FocusWidget timeline.
//
// The live implementation uses the real UserDefaults suite and WidgetCenter.
// Tests inject a spy that records calls without touching the file system or
// the widget subsystem.

protocol WidgetInsightsPersistence {
    /// Returns the currently persisted insights, or nil if none exist / decoding fails.
    func readInsights() -> FocusWidgetInsights?

    /// Persists `insights` to the shared suite.
    /// - Returns: `true` if encoding and persistence succeeded, `false` otherwise.
    @discardableResult
    func writeInsights(_ insights: FocusWidgetInsights) -> Bool

    /// Requests a WidgetKit timeline reload for the FocusWidget kind.
    /// Must only be called after a successful `writeInsights`.
    func reloadWidget()
}

// MARK: - Live implementation

/// Production implementation that writes to the App Group UserDefaults suite
/// and calls WidgetCenter. Annotated @MainActor because WidgetCenter.shared
/// is not Sendable; all call sites already run on the main actor under
/// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
@MainActor
struct LiveWidgetInsightsPersistence: WidgetInsightsPersistence {

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func readInsights() -> FocusWidgetInsights? {
        guard
            let suite   = UserDefaults(suiteName: FocusWidgetData.appGroupID),
            let data    = suite.data(forKey: FocusWidgetInsights.userDefaultsKey),
            let decoded = try? decoder.decode(FocusWidgetInsights.self, from: data)
        else { return nil }
        return decoded
    }

    @discardableResult
    func writeInsights(_ insights: FocusWidgetInsights) -> Bool {
        guard
            let suite   = UserDefaults(suiteName: FocusWidgetData.appGroupID),
            let encoded = try? encoder.encode(insights)
        else { return false }
        suite.set(encoded, forKey: FocusWidgetInsights.userDefaultsKey)
        return true
    }

    func reloadWidget() {
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }
}
