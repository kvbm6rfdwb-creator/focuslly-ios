import Foundation
import Combine

/// 🔑 Manager koji čuva fokus sesiju i sprječava prekidanje
/// dok korisnik ne završi sve korake (odgovor na pitanje + summary modal)
final class FocusSessionManager: ObservableObject {
    
    @Published var currentTask: FocusTask? = nil
    @Published var isInFocus: Bool = false
    
    // MARK: - KLJUČNO: Ne resetiramo fokus dok korisnik ne završi sve
    func startFocus(task: FocusTask) {
        currentTask = task
        isInFocus = true
    }
    
    /// 🔑 Završi fokus SAMO nakon što korisnik završi sve
    /// (odgovori na pitanje + klikne "Done" na summary)
    func endFocus() {
        currentTask = nil
        isInFocus = false
    }
    
    func pauseFocus() {
        // Fokus ostaje - samo je pauziran
        isInFocus = true
    }
    
    func resumeFocus() {
        isInFocus = true
    }
}
