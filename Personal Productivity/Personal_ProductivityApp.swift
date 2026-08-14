import SwiftUI
import SwiftData

@main
struct PersonalProductivityApp: App {
    @StateObject private var coordinator = FocusSessionCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    private let containerState: FocusllyModelContainerState = FocusllyModelContainerFactory.productionState()

    var body: some Scene {
        WindowGroup {
            switch containerState {
            case .ready(let container):
                MainTabView()
                    .environmentObject(coordinator)
                    .modelContainer(container)
                    .task {
                        await runMigrationIfNeeded(container: container)
                    }
            case .unavailable(let error):
                FocusllyCoreInitializationErrorView(error: error)
            }
        }
    }

    @MainActor
    private func runMigrationIfNeeded(container: ModelContainer) {
        let context = container.mainContext
        let service = SwiftDataMigrationService(context: context)
        let sourceVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        do {
            let report = try service.runInitialLegacyMigrationIfNeeded(sourceVersion: sourceVersion)
            if !report.alreadyCompleted {
                print("[Focuslly] Migration completed: \(report.safeDiagnosticSummary)")
            }
        } catch {
            print("[Focuslly] Migration error (non-fatal): \(error.localizedDescription)")
        }
    }
}
