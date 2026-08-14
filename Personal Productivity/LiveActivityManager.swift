import Foundation

final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    func startOrUpdateTimer(sessionId: UUID, title: String, isBreak: Bool, remainingSeconds: Int) {
        _ = sessionId
        _ = title
        _ = isBreak
        _ = remainingSeconds
    }

    func endTimer() {
    }
}
