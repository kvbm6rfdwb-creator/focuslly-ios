import Foundation
import SwiftData

protocol HabitRepository {
    @MainActor func createHabit(_ draft: HabitDraft) throws -> Habit
    @MainActor func fetchHabits(includeArchived: Bool) throws -> [Habit]
    @MainActor func archiveHabit(identifier: UUID, archivedAt: Date) throws
}

protocol CheckInRepository {
    @MainActor func recordCheckIn(_ draft: HabitCheckInDraft) throws -> HabitCheckIn
    @MainActor func terminalCheckIn(habitID: UUID, localDay: String) throws -> HabitCheckIn?
}

protocol FocusSessionRepository {
    @MainActor func recordFocusSession(_ draft: FocusSessionRecordDraft) throws -> FocusSessionRecord
    @MainActor func fetchFocusSessions() throws -> [FocusSessionRecord]
}

struct HabitDraft {
    var identifier: UUID = UUID()
    var title: String
    var detail: String?
    var scheduleKind: HabitScheduleKind = .daily
    var scheduleDetail: String?
    var cueText: String?
    var reminderHour: Int?
    var reminderMinute: Int?
    var colorHex: String?
    var iconName: String?
}

struct HabitCheckInDraft {
    var identifier: UUID = UUID()
    var habitID: UUID
    var occurredAt: Date
    var timeZoneIdentifier: String?
    var normalizedLocalDay: String?
    var outcome: HabitCheckInOutcome
    var note: String?
    var source: FocusllyRecordSource
}

struct FocusSessionRecordDraft {
    var identifier: UUID = UUID()
    var habitID: UUID?
    var legacyTaskTitle: String?
    var legacyTaskID: UUID?
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var outcome: FocusSessionRecordOutcome
    var intention: String?
    var rating: String?
    var exitReasonRawValue: String?
    var source: FocusllyRecordSource
}

@MainActor
final class SwiftDataHabitRepository: HabitRepository {
    private let context: ModelContext
    private let dateProvider: FocusllyDateProviding

    init(context: ModelContext, dateProvider: FocusllyDateProviding = SystemFocusllyDateProvider()) {
        self.context = context
        self.dateProvider = dateProvider
    }

    func createHabit(_ draft: HabitDraft) throws -> Habit {
        try FocusllyValidation.requireValidIdentifier(draft.identifier)
        let title = try FocusllyValidation.cleanedTitle(draft.title)
        try validateReminder(hour: draft.reminderHour, minute: draft.reminderMinute)

        // Fix #4: Fetch-before-insert to surface duplicate UUID as a clean
        // FocusllyRepositoryError rather than an opaque SwiftData unique-constraint
        // violation at context.save(), which is not reliably catchable across OS versions.
        if try fetchHabit(identifier: draft.identifier) != nil {
            throw FocusllyRepositoryError.invalidIdentifier
        }

        let habit = Habit(
            identifier: draft.identifier,
            title: title,
            detail: FocusllyValidation.cleanedOptional(draft.detail),
            createdAt: dateProvider.now,
            scheduleKind: draft.scheduleKind,
            scheduleDetail: FocusllyValidation.cleanedOptional(draft.scheduleDetail),
            cueText: FocusllyValidation.cleanedOptional(draft.cueText),
            reminderHour: draft.reminderHour,
            reminderMinute: draft.reminderMinute,
            colorHex: FocusllyValidation.cleanedOptional(draft.colorHex),
            iconName: FocusllyValidation.cleanedOptional(draft.iconName)
        )

        context.insert(habit)
        try save()
        return habit
    }

    // Fix #2: Sort descriptor pushed to SwiftData/SQLite layer instead of in-memory sort.
    func fetchHabits(includeArchived: Bool = false) throws -> [Habit] {
        var descriptor = FetchDescriptor<Habit>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        if !includeArchived {
            descriptor.predicate = #Predicate { $0.archivedAt == nil }
        }
        return try context.fetch(descriptor)
    }

    func archiveHabit(identifier: UUID, archivedAt: Date) throws {
        try FocusllyValidation.requireValidIdentifier(identifier)
        try FocusllyValidation.requireValidDate(archivedAt)
        guard let habit = try fetchHabit(identifier: identifier) else { return }
        habit.archivedAt = archivedAt
        try save()
    }

    // Fix #1: Predicate-based fetch with fetchLimit 1 replaces full-table scan + Swift filter.
    private func fetchHabit(identifier: UUID) throws -> Habit? {
        var descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.identifier == identifier }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func validateReminder(hour: Int?, minute: Int?) throws {
        if let hour, !(0...23).contains(hour) {
            throw FocusllyRepositoryError.invalidRawValue(field: "reminderHour", value: String(hour))
        }
        if let minute, !(0...59).contains(minute) {
            throw FocusllyRepositoryError.invalidRawValue(field: "reminderMinute", value: String(minute))
        }
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            throw FocusllyRepositoryError.saveFailed(error.localizedDescription)
        }
    }
}

@MainActor
final class SwiftDataCheckInRepository: CheckInRepository {
    private let context: ModelContext
    private let dateProvider: FocusllyDateProviding
    private let widgetSnapshotWriter: WidgetSnapshotWriter

    init(
        context: ModelContext,
        dateProvider: FocusllyDateProviding = SystemFocusllyDateProvider(),
        widgetSnapshotWriter: WidgetSnapshotWriter = NoOpWidgetSnapshotWriter()
    ) {
        self.context = context
        self.dateProvider = dateProvider
        self.widgetSnapshotWriter = widgetSnapshotWriter
    }

    func recordCheckIn(_ draft: HabitCheckInDraft) throws -> HabitCheckIn {
        try FocusllyValidation.requireValidIdentifier(draft.identifier)
        try FocusllyValidation.requireValidIdentifier(draft.habitID)
        try FocusllyValidation.requireValidDate(draft.occurredAt)

        let localDay = draft.normalizedLocalDay ?? dateProvider.normalizedLocalDay(for: draft.occurredAt)
        try FocusllyValidation.requireValidLocalDay(localDay)

        guard let habit = try fetchHabit(identifier: draft.habitID) else {
            throw FocusllyRepositoryError.missingHabit
        }

        if let existing = try terminalCheckIn(habitID: draft.habitID, localDay: localDay) {
            throw FocusllyRepositoryError.duplicateTerminalCheckIn(
                habitID: existing.habit?.identifier ?? draft.habitID,
                localDay: localDay
            )
        }

        let checkIn = HabitCheckIn(
            identifier: draft.identifier,
            habit: habit,
            occurredAt: draft.occurredAt,
            timeZoneIdentifier: draft.timeZoneIdentifier ?? dateProvider.timeZoneIdentifier,
            normalizedLocalDay: localDay,
            outcome: draft.outcome,
            note: FocusllyValidation.cleanedOptional(draft.note),
            source: draft.source,
            createdAt: dateProvider.now
        )

        context.insert(checkIn)
        try save()
        // Fix #5: The snapshot passed here is intentionally .empty() — this repository
        // does not have access to full today-metrics at write time. The widget extension
        // is responsible for rebuilding a complete snapshot on its next timeline reload.
        // Do NOT compute metrics here to avoid a second full-table read on the hot path.
        widgetSnapshotWriter.writeAfterCommit(.empty(generatedAt: dateProvider.now))
        return checkIn
    }

    // Fix #3: Predicate + fetchLimit 1 replaces full HabitCheckIn table scan.
    // SwiftData cannot currently express a compound predicate joining across a
    // relationship (habit.identifier) at the SQL layer, so habitID filtering
    // is done in Swift after a normalizedLocalDay-scoped fetch, which is a
    // significantly smaller result set than the full table.
    func terminalCheckIn(habitID: UUID, localDay: String) throws -> HabitCheckIn? {
        try FocusllyValidation.requireValidIdentifier(habitID)
        try FocusllyValidation.requireValidLocalDay(localDay)
        var descriptor = FetchDescriptor<HabitCheckIn>(
            predicate: #Predicate { $0.normalizedLocalDay == localDay }
        )
        descriptor.fetchLimit = 10
        let candidates = try context.fetch(descriptor)
        return candidates.first { $0.habit?.identifier == habitID }
    }

    // Fix #1: Predicate-based fetch with fetchLimit 1.
    private func fetchHabit(identifier: UUID) throws -> Habit? {
        var descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.identifier == identifier }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            throw FocusllyRepositoryError.saveFailed(error.localizedDescription)
        }
    }
}

@MainActor
final class SwiftDataFocusSessionRepository: FocusSessionRepository {
    private let context: ModelContext
    private let dateProvider: FocusllyDateProviding
    private let widgetSnapshotWriter: WidgetSnapshotWriter

    init(
        context: ModelContext,
        dateProvider: FocusllyDateProviding = SystemFocusllyDateProvider(),
        widgetSnapshotWriter: WidgetSnapshotWriter = NoOpWidgetSnapshotWriter()
    ) {
        self.context = context
        self.dateProvider = dateProvider
        self.widgetSnapshotWriter = widgetSnapshotWriter
    }

    func recordFocusSession(_ draft: FocusSessionRecordDraft) throws -> FocusSessionRecord {
        try FocusllyValidation.requireValidIdentifier(draft.identifier)
        try FocusllyValidation.requireValidDate(draft.startedAt)
        try FocusllyValidation.requireValidDate(draft.endedAt)
        try FocusllyValidation.requirePositiveDuration(draft.durationSeconds)

        let habit = try draft.habitID.flatMap { try fetchHabit(identifier: $0) }
        let record = FocusSessionRecord(
            identifier: draft.identifier,
            habit: habit,
            legacyTaskTitle: FocusllyValidation.cleanedOptional(draft.legacyTaskTitle),
            legacyTaskID: draft.legacyTaskID,
            startedAt: draft.startedAt,
            endedAt: draft.endedAt,
            durationSeconds: draft.durationSeconds,
            outcome: draft.outcome,
            intention: FocusllyValidation.cleanedOptional(draft.intention),
            rating: FocusllyValidation.cleanedOptional(draft.rating),
            exitReasonRawValue: FocusllyValidation.cleanedOptional(draft.exitReasonRawValue),
            createdAt: dateProvider.now,
            source: draft.source
        )

        context.insert(record)
        try save()
        // Fix #5: See SwiftDataCheckInRepository.recordCheckIn — same rationale.
        widgetSnapshotWriter.writeAfterCommit(.empty(generatedAt: dateProvider.now))
        return record
    }

    // Fix #2: Sort descriptor pushed to SwiftData/SQLite layer.
    func fetchFocusSessions() throws -> [FocusSessionRecord] {
        let descriptor = FetchDescriptor<FocusSessionRecord>(
            sortBy: [SortDescriptor(\.startedAt, order: .forward)]
        )
        return try context.fetch(descriptor)
    }

    // Fix #1: Predicate-based fetch with fetchLimit 1.
    private func fetchHabit(identifier: UUID) throws -> Habit? {
        var descriptor = FetchDescriptor<Habit>(
            predicate: #Predicate { $0.identifier == identifier }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            throw FocusllyRepositoryError.saveFailed(error.localizedDescription)
        }
    }
}

// Fix #6: Promoted from private file-scope to internal extension on FocusllyValidation
// so it is accessible to tests and any future repository or service that needs the same
// trimming behaviour without duplicating the logic.
extension FocusllyValidation {
    static func cleanedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
