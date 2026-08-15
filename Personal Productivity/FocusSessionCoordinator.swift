import Foundation
import Combine

// MARK: - Coordinator state
/// Models the navigation / lifecycle state of the active focus session.
enum FocusCoordinatorState {
    case idle
    case active
    case backgrounded
    case awaitingUserDecision
    case ending
}

// MARK: - FocusSessionCoordinator
/// Drives top-level focus-session navigation (start → background → decision → end).
/// Does NOT own timer logic — that lives in FocusSessionEngine.
final class FocusSessionCoordinator: ObservableObject {

    @Published private(set) var state: FocusCoordinatorState = .idle
    @Published var shouldShowExitPrompt = false
    @Published var shouldShowFocusView  = false
    @Published var focusSessionID       = UUID()

    private var currentTask: FocusTask?

    // MARK: - Transitions

    func startFocus(task: FocusTask) {
        focusSessionID       = UUID()
        currentTask          = task
        state                = .active
        shouldShowFocusView  = true
        shouldShowExitPrompt = false
    }

    func appDidBackground() {
        guard state == .active else { return }
        state = .backgrounded
    }

    func appDidForeground() {
        guard state == .backgrounded else { return }
        state                = .awaitingUserDecision
        shouldShowExitPrompt = true
    }

    func userContinuesFocus() {
        guard state == .awaitingUserDecision else { return }
        state                = .active
        shouldShowExitPrompt = false
    }

    func userEndsSession() {
        guard state == .awaitingUserDecision else { return }
        state                = .ending
        shouldShowExitPrompt = false
        shouldShowFocusView  = false
        currentTask          = nil
    }

    func manuallyEndSession() {
        state                = .idle
        shouldShowFocusView  = false
        shouldShowExitPrompt = false
        currentTask          = nil
    }
}
