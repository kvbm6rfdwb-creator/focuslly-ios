import Foundation

struct WidgetSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

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

    func isValid(referenceDate: Date = Date()) -> Bool {
        schemaVersion == Self.currentSchemaVersion && generatedAt <= referenceDate && expiresAt > referenceDate
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
