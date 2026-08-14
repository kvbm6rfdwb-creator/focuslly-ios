import Foundation
import SwiftData
import SwiftUI

enum FocusllyModelContainerState {
    case ready(ModelContainer)
    case unavailable(FocusllyModelContainerError)
}

struct FocusllyModelContainerError: Error, Identifiable, Equatable {
    let id = UUID()
    let message: String
    let recoverySuggestion: String

    static func initializationFailed(_ error: Error) -> FocusllyModelContainerError {
        FocusllyModelContainerError(
            message: "Focuslly could not open its local data store.",
            recoverySuggestion: "Quit and reopen the app. If this persists, export diagnostics before resetting local data. Details: \(error.localizedDescription)"
        )
    }
}

enum FocusllyModelContainerFactory {
    static let configurationName = "FocusllyCoreV1LocalStore"

    static var schema: Schema {
        Schema(FocusllySchemaV1.models)
    }

    static func productionState() -> FocusllyModelContainerState {
        do {
            return .ready(try makeProductionContainer())
        } catch {
            return .unavailable(.initializationFailed(error))
        }
    }

    static func makeProductionContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            configurationName,
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: FocusllySchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }

    static func makeInMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(
            "FocusllyCoreV1InMemoryStore",
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            groupContainer: .none,
            cloudKitDatabase: .none
        )

        return try ModelContainer(
            for: schema,
            migrationPlan: FocusllySchemaMigrationPlan.self,
            configurations: [configuration]
        )
    }
}

struct FocusllyCoreInitializationErrorView: View {
    let error: FocusllyModelContainerError

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Local Data Unavailable")
                .font(.headline)
            Text(error.message)
                .font(.body)
            Text(error.recoverySuggestion)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
