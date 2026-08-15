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
                        // Fix #2: runMigrationIfNeeded is synchronous and only touches
                        // mainContext — no async work needed. Dropping the nonisolated
                        // async wrapper removes the @MainActor / .task{} annotation
                        // mismatch that produced ambiguous concurrency under strict checking.
                        runMigrationIfNeeded(container: container)
                    }

            case .unavailable(let error):
                // Fix #1: coordinator injected here so any sub-view of the error screen
                // that reads coordinator from the environment does not crash.
                FocusllyCoreInitializationErrorView(error: error)
                    .environmentObject(coordinator)
            }
        }
    }

    // Fix #2: @MainActor retained — this func is called from .task{} on the main actor
    // (WindowGroup body is main-actor-isolated). Marking it explicitly keeps the
    // compiler from inferring a nonisolated context if the call site ever changes.
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
