import Foundation

struct FocusSessionLog: Identifiable, Codable {
    let id: UUID
    let taskId: UUID
    let startDate: Date
    let endDate: Date
    let exitReason: FocusExitReason
    let customReason: String?
    let breakMinutes: Int?
    /// Total minutes added via "Need more time?" extensions during this session.
    var prolongedMinutes: Int?

    init(
        taskId: UUID,
        startDate: Date,
        endDate: Date,
        exitReason: FocusExitReason,
        customReason: String? = nil,
        breakMinutes: Int? = nil,
        prolongedMinutes: Int? = nil
    ) {
        self.id = UUID()
        self.taskId = taskId
        self.startDate = startDate
        self.endDate = endDate
        self.exitReason = exitReason
        self.customReason = customReason
        self.breakMinutes = breakMinutes
        self.prolongedMinutes = prolongedMinutes
    }

    // MARK: - Duration

    /// Raw TimeInterval between startDate and endDate.
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    /// Whole minutes of the session duration.
    var durationMinutes: Int { Int(duration) / 60 }

    /// Whole seconds of the session duration.
    var durationSeconds: Int { Int(duration) }

    /// Human-readable duration string (e.g. "25 min", "1h 5m").
    var durationText: String {
        let totalMinutes = durationMinutes
        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
        }
    }
}
