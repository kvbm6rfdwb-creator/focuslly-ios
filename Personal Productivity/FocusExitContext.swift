import Foundation

struct FocusExitContext: Identifiable {
    let id = UUID()
    let exit: FocusSessionExit
}
