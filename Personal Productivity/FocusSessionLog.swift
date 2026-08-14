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
    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var durationText: String {
        let totalMinutes = Int(duration) / 60

        if totalMinutes < 60 {
            return "\(totalMinutes) min"
        } else {
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return minutes == 0
                ? "\(hours)h"
                : "\(hours)h \(minutes)m"
        }
    }
}
