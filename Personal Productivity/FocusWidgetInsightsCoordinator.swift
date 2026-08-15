import Foundation

// MARK: - FocusWidgetInsightsCoordinator
//
// Owns the single responsibility of converting live app state into a
// FocusWidgetInsights snapshot and persisting it via WidgetInsightsPersistence.
//
// *** Wiring rule ***
// One instance is created at app startup (see AppComposition) and injected
// into both TaskStore and PipelineStore. No other code creates this type.

@MainActor
final class FocusWidgetInsightsCoordinator {

    // MARK: Dependencies

    private let persistence: WidgetInsightsPersistence

    // MARK: Init

    /// Designated initialiser.
    /// - Parameter persistence: The persistence back-end to use.
    ///   Pass `LiveWidgetInsightsPersistence()` in production;
    ///   pass a spy/stub in tests.
    init(persistence: WidgetInsightsPersistence) {
        self.persistence = persistence
    }

    // MARK: Public API

    /// Rebuilds the widget snapshot from the current task and session state,
    /// writes it to the shared suite, then requests a WidgetKit reload.
    ///
    /// Safe to call on every TaskStore / PipelineStore mutation — the method
    /// is cheap (pure transform + one UserDefaults write) and debouncing is
    /// left to callers if needed.
    ///
    /// - Parameters:
    ///   - tasks:    Current tasks from TaskStore.
    ///   - sessions: Current focus session logs from PipelineStore.
    func update(tasks: [FocusTask], sessions: [FocusSessionLog]) {
        let snapshot = buildSnapshot(tasks: tasks, sessions: sessions)
        guard persistence.writeInsights(snapshot) else { return }
        persistence.reloadWidget()
    }

    /// Returns the last-persisted snapshot, or `nil` if none exists.
    func currentInsights() -> FocusWidgetInsights? {
        persistence.readInsights()
    }

    // MARK: Private — snapshot building

    private func buildSnapshot(
        tasks: [FocusTask],
        sessions: [FocusSessionLog]
    ) -> FocusWidgetInsights {
        let now        = Date()
        let calendar   = Calendar.current
        let todayStart = calendar.startOfDay(for: now)

        // ── Task counts ──────────────────────────────────────────────────
        let pendingTasks    = tasks.filter { !$0.isCompleted }
        let completedToday  = tasks.filter {
            $0.isCompleted &&
            ($0.completedAt.map { $0 >= todayStart } ?? false)
        }

        // ── Focus minutes today ──────────────────────────────────────────
        let focusMinutesToday = sessions
            .filter { $0.date >= todayStart }
            .reduce(0) { $0 + $1.durationMinutes }

        // ── Current / next task ──────────────────────────────────────────
        let currentTask = pendingTasks
            .sorted { ($0.priority?.rawValue ?? 0) > ($1.priority?.rawValue ?? 0) }
            .first

        let nextTask = pendingTasks
            .filter { $0.id != currentTask?.id }
            .sorted { ($0.priority?.rawValue ?? 0) > ($1.priority?.rawValue ?? 0) }
            .first

        // ── Weekly streak ────────────────────────────────────────────────
        let streak = computeStreak(sessions: sessions, calendar: calendar, now: now)

        return FocusWidgetInsights(
            pendingTaskCount:   pendingTasks.count,
            completedToday:     completedToday.count,
            focusMinutesToday:  focusMinutesToday,
            currentTaskTitle:   currentTask?.title,
            nextTaskTitle:      nextTask?.title,
            weeklyStreakDays:   streak,
            lastUpdated:        now
        )
    }

    /// Returns how many consecutive calendar days (ending today) had at
    /// least one completed focus session.
    private func computeStreak(
        sessions: [FocusSessionLog],
        calendar: Calendar,
        now: Date
    ) -> Int {
        guard !sessions.isEmpty else { return 0 }

        let activeDays = Set(
            sessions.map { calendar.startOfDay(for: $0.date) }
        )

        var streak = 0
        var cursor = calendar.startOfDay(for: now)

        while activeDays.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor)
            else { break }
            cursor = previous
        }

        return streak
    }
}
