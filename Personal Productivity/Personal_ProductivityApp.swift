import SwiftUI

@main
struct PersonalProductivityApp: App {
    @StateObject private var coordinator = FocusSessionCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(coordinator)
                .onAppear {
                    TaskStoreLocator.shared.store = nil // Not needed, or set in MainTabView if needed
                    HapticManager.settings = nil // Not needed, or set in MainTabView if needed
                    SoundManager.settings = nil // Not needed, or set in MainTabView if needed
                }
                .onChange(of: scenePhase) { _, phase in
                    // If you need to perform daily cleanup, do it via Notification or Coordinator
                }
        }
    }
}
