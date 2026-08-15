import Foundation
import SwiftData

protocol MigrationService {
    @MainActor func runInitialLegacyMigrationIfNeeded(sourceVersion: String) throws -> LegacyMigrationReport
}

protocol LegacyDefaultsReading {
    func data(forKey key: String) -> Data?
}

struct LegacyUserDefaultsReader: LegacyDefaultsReading {
    func data(forKey key: String) -> Data? {
        UserDefaults.standard.data(forKey: key)
    }
}

struct LegacyMigrationReport: Codable, Equatable, Sendable {
    var migrationName: String
    var sourceVersion: String
    var alreadyCompleted: Bool
    var decodedLegacyTaskCount: Int
    var decodedLegacySessionLogCount: Int
    var importedHabitCount: Int
    var importedCheckInCount: Int
    var importedFocusSessionCount: Int
    var failedRecordCount: Int
    var quarantinedRecords: [LegacyQuarantinedRecord]
    var deferredAdapters: [String]

    var quarantinedRecordCount: Int { quarantinedRecords.count }

    var safeDiagnosticSummary: String {
        "Decoded tasks: \(decodedLegacyTaskCount), decoded sessions: \(decodedLegacySessionLogCount), imported records: \(importedHabitCount + importedCheckInCount + importedFocusSessionCount), quarantined: \(quarantinedRecordCount), failed: \(failedRecordCount)."
    }
}

struct LegacyQuarantinedRecord: Codable, Equatable, Sendable {
    var sourceKey: String
    var reason: String
}

@MainActor
final class SwiftDataMigrationService: MigrationService {
    static let initialMigrationName = "focuslly_legacy_userdefaults_to_swiftdata_v1_scaffold"

    private let context: ModelContext
    private let legacyReader: LegacyDefaultsReading
    private let dateProvider: FocusllyDateProviding

    init(
        context: ModelContext,
        legacyReader: LegacyDefaultsReading = LegacyUserDefaultsReader(),
        dateProvider: FocusllyDateProviding = SystemFocusllyDateProvider()
    ) {
        self.context = context
        self.legacyReader = legacyReader
        self.dateProvider = dateProvider
    }

    func runInitialLegacyMigrationIfNeeded(sourceVersion: String) throws -> LegacyMigrationReport {
        if try existingMigrationRecord(named: Self.initialMigrationName) != nil {
            return LegacyMigrationReport(
                migrationName: Self.initialMigrationName,
                sourceVersion: sourceVersion,
                alreadyCompleted: true,
                decodedLegacyTaskCount: 0,
                decodedLegacySessionLogCount: 0,
                importedHabitCount: 0,
                importedCheckInCount: 0,
                importedFocusSessionCount: 0,
                failedRecordCount: 0,
                quarantinedRecords: [],
                deferredAdapters: ["Migration already completed; legacy data was not read again."]
            )
        }

        var quarantined: [LegacyQuarantinedRecord] = []
        let decodedTasks = decodeLegacyArray([FocusTask].self, key: "focus_tasks", quarantined: &quarantined)
        let decodedSessionLogs = decodeLegacyArray([FocusSessionLog].self, key: "focus_session_logs", quarantined: &quarantined)

        let report = LegacyMigrationReport(
            migrationName: Self.initialMigrationName,
            sourceVersion: sourceVersion,
            alreadyCompleted: false,
            decodedLegacyTaskCount: decodedTasks?.count ?? 0,
            decodedLegacySessionLogCount: decodedSessionLogs?.count ?? 0,
            importedHabitCount: 0,
            importedCheckInCount: 0,
            importedFocusSessionCount: 0,
            failedRecordCount: quarantined.count,
            quarantinedRecords: quarantined,
            deferredAdapters: [
                "FocusTask adapter deferred: V1 keeps legacyTaskID and legacyTaskTitle fields for lossless FocusSessionRecord import later.",
                "FocusSessionLog adapter deferred: exitReason raw value, intention, rating, and task title joins require an explicit product-approved mapping pass.",
                // TODO(migration-v2): After the full adapter pass is approved and shipped,
                // delete the legacy UserDefaults keys ("focus_tasks", "focus_session_logs")
                // so the device does not retain orphaned plaintext data indefinitely.
                "Legacy UserDefaults data is read-only in this scaffold and is never deleted or overwritten."
            ]
        )

        let record = AppMigrationRecord(
            migrationName: report.migrationName,
            completedAt: dateProvider.now,
            sourceVersion: sourceVersion,
            importedHabitCount: report.importedHabitCount,
            importedCheckInCount: report.importedCheckInCount,
            importedFocusSessionCount: report.importedFocusSessionCount,
            failedRecordCount: report.failedRecordCount,
            quarantinedRecordCount: report.quarantinedRecordCount,
            diagnosticSummary: report.safeDiagnosticSummary
        )
        context.insert(record)
        do {
            try context.save()
        } catch {
            throw FocusllyRepositoryError.saveFailed(error.localizedDescription)
        }
        return report
    }

    // Fix #1: Use a predicate-based FetchDescriptor with fetchLimit 1 instead of
    // fetching every AppMigrationRecord row and filtering in Swift. This keeps the
    // lookup O(1) regardless of how many migration records accumulate over app versions.
    private func existingMigrationRecord(named name: String) throws -> AppMigrationRecord? {
        var descriptor = FetchDescriptor<AppMigrationRecord>(
            predicate: #Predicate { $0.migrationName == name }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    // Fix #2: Include error.localizedDescription in the quarantine reason so the
    // audit trail records what actually failed. Previously the real decode error
    // was silently dropped, making quarantine records useless for post-hoc diagnosis.
    private func decodeLegacyArray<T: Decodable>(
        _ type: T.Type,
        key: String,
        quarantined: inout [LegacyQuarantinedRecord]
    ) -> T? {
        guard let data = legacyReader.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            quarantined.append(
                LegacyQuarantinedRecord(
                    sourceKey: key,
                    reason: "Unable to decode legacy payload as \(T.self): \(error.localizedDescription)"
                )
            )
            return nil
        }
    }
}
