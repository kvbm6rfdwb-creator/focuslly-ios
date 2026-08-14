import Foundation

enum FocusExitReason: String, CaseIterable, Identifiable, Codable {

    case completed
    case distracted
    case interrupted
    case paused
    case tired
    case other
    case breakEnded
    case prolonged      // user extended the timer at least once before completing

    var id: String { rawValue }

    // MARK: - UI helpers
    var title: String {
        switch self {
        case .completed:   return "Completed"
        case .distracted:  return "Lost focus"
        case .interrupted: return "Had to do something, continuing"
        case .paused:      return "Just paused"
        case .tired:       return "Too tired"
        case .other:       return "Other reason"
        case .breakEnded:  return "Break ended"
        case .prolonged:   return "Needed more time"
        }
    }

    var icon: String {
        switch self {
        case .completed:   return "checkmark.circle.fill"
        case .distracted:  return "eye.slash.fill"
        case .interrupted: return "arrow.clockwise.circle.fill"
        case .paused:      return "pause.circle.fill"
        case .tired:       return "bed.double.fill"
        case .other:       return "ellipsis.circle"
        case .breakEnded:  return "cup.and.saucer.fill"
        case .prolonged:   return "plus.circle.fill"
        }
    }

    /// Counts as a completed session (streak / stats)
    var countsAsCompletedSession: Bool {
        self == .completed || self == .prolonged
    }
}
