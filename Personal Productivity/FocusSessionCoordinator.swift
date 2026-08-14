import Foundation
import Combine

/// 🔑 State machine for Focus coordinator (manages navigation & lifecycle)
enum FocusCoordinatorState {
    case idle                          
    case active                        
    case backgrounded                  
    case awaitingUserDecision          
    case resuming                      
    case ending                        
}

/// Manager koji koordinira fokus sesiju kroz sveprepreke
final class FocusSessionCoordinator: ObservableObject {
    
    @Published private(set) var state: FocusCoordinatorState = .idle
    @Published var shouldShowExitPrompt = false
    @Published var shouldShowFocusView = false
    @Published var focusSessionID = UUID()
    
    private var currentTask: FocusTask?
    
    // MARK: - Transitions
    
    /// Korisnik započinje fokus
    func startFocus(task: FocusTask) {
        DispatchQueue.main.async {
            self.focusSessionID = UUID()   // ⬅️ OVO JE KLJUČNO
            self.currentTask = task
            self.state = .active
            self.shouldShowFocusView = true
            self.shouldShowExitPrompt = false
        }
    }
    
    /// App ide u background tijekom fokusa
    func appDidBackground() {
        guard state == .active else { return }
        DispatchQueue.main.async {
            self.state = .backgrounded
        }
    }
    
    /// App se vraća iz background-a
    func appDidForeground() {
        guard state == .backgrounded else { return }
        DispatchQueue.main.async {
            self.state = .awaitingUserDecision
            self.shouldShowExitPrompt = true
            
            // 🔑 Força UI ažuriranje - ponekad je potreban delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.shouldShowExitPrompt = true
            }
        }
    }
    
    /// Korisnik je dao odluku - nastavlja fokus
    func userContinuesFocus() {
        guard state == .awaitingUserDecision else { return }
        DispatchQueue.main.async {
            self.state = .active
            self.shouldShowExitPrompt = false
        }
    }
    
    /// Korisnik je dao odluku - završava fokus
    func userEndsSession() {
        guard state == .awaitingUserDecision else { return }
        DispatchQueue.main.async {
            self.state = .ending
            self.shouldShowExitPrompt = false
            self.shouldShowFocusView = false
            self.currentTask = nil
        }
    }
    
    /// Korisnik manualno završava fokus (nije iz background-a)
    func manuallyEndSession() {
        DispatchQueue.main.async {
            self.state = .idle
            self.shouldShowFocusView = false
            self.shouldShowExitPrompt = false
            self.currentTask = nil
        }
    }
}
