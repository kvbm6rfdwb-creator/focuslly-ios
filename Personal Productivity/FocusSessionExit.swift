import Foundation

/// Engine-level exit decision (NOT user-facing)
enum FocusSessionExit: Equatable {
    case paused
    case continueNow        // short interruption, continuing
    case distracted         // lost focus
    case earlyFinished
    case completed
    case prolonged          // completed after one or more time extensions
    case other(String)
}
