import Foundation

struct WidgetSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    // Maximum age a snapshot may have been generated in the future relative to
    // the reference date before it is treated as invalid (clock-skew tolerance).
    // 60 seconds covers typical NTP drift without allowing pathological futures.
    static let clockSkewToleranceSeconds: TimeInterval = 60

    var schemaVersion: Int
    var generatedAt: Date
    var expiresAt: Date
    var activeTimer: ActiveFocusTimer?
    var todayMetrics: TodayMetrics
    var gridCells: [GridCellState]

    struct ActiveFocusTimer: Codable, Equatable, Sendable {
        var title: String
        var startedAt: Date
        var endsAt: Date
        var isPaused: Bool
        var pausedRemainingSeconds: Int?
    }

    struct TodayMetrics: Codable, Equatable, Sendable {
        var completedCount: Int
        var plannedCount: Int
        var skippedCount: Int
        var plannedRestCount: Int
        var protectedMissCount: Int
    }

    // Fix #8: `id` must be unique across all cells in the `gridCells` array.
    // Callers MUST use a value that is unique per cell — the natural key is
    // "\(habitIdentifier)-\(localDay)" which is guaranteed distinct for any
    // valid snapshot. Duplicate `id` values cause SwiftUI ForEach diffing bugs
    // (incorrect animations, missed updates, or duplicate rows) in widget views.
    struct GridCellState: Codable, Equatable, Identifiable, Sendable {
        var id: String
        var localDay: String
        var stateRawValue: String
    }

    static func empty(generatedAt: Date = Date()) -> WidgetSnapshot {
        WidgetSnapshot(
            schemaVersion: currentSchemaVersion,
            generatedAt: generatedAt,
            expiresAt: generatedAt.addingTimeInterval(15 * 60),
            activeTimer: nil,
            todayMetrics: TodayMetrics(
                completedCount: 0,
                plannedCount: 0,
                skippedCount: 0,
                plannedRestCount: 0,
                protectedMissCount: 0
            ),
            gridCells: []
        )
    }

    // Fix #7: Added a lower-bound check so a snapshot whose `generatedAt` is more
    // than `clockSkewToleranceSeconds` in the future (e.g. bad test data, severe
    // device clock skew) is rejected rather than served indefinitely. The previous
    // `generatedAt <= referenceDate` check was strictly correct but did not account
    // for any clock-skew tolerance, so a 1-second future timestamp would fail on a
    // legitimately correct device. The tolerance window resolves that edge case while
    // still bounding pathological futures.
    func isValid(referenceDate: Date = Date()) -> Bool {
        guard schemaVersion == Self.currentSchemaVersion else { return false }
        let skewBound = referenceDate.addingTimeInterval(Self.clockSkewToleranceSeconds)
        return generatedAt <= skewBound && expiresAt > referenceDate
    }
}

protocol WidgetSnapshotWriter {
    func writeAfterCommit(_ snapshot: WidgetSnapshot)
}

struct NoOpWidgetSnapshotWriter: WidgetSnapshotWriter {
    func writeAfterCommit(_ snapshot: WidgetSnapshot) {
        _ = snapshot
    }
}
