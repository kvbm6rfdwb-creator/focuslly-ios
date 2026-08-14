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

        let habit = Habit(
            identifier: draft.identifier,
            title: title,
            detail: cleanedOptional(draft.detail),
            createdAt: dateProvider.now,
            scheduleKind: draft.scheduleKind,
            scheduleDetail: cleanedOptional(draft.scheduleDetail),
            cueText: cleanedOptional(draft.cueText),
            reminderHour: draft.reminderHour,
            reminderMinute: draft.reminderMinute,
            colorHex: cleanedOptional(draft.colorHex),
            iconName: cleanedOptional(draft.iconName)
        )

        context.insert(habit)
        try save()
        return habit
    }

    func fetchHabits(includeArchived: Bool = false) throws -> [Habit] {
        let all = try context.fetch(FetchDescriptor<Habit>())
        return all
            .filter { includeArchived || $0.archivedAt == nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    func archiveHabit(identifier: UUID, archivedAt: Date) throws {
        try FocusllyValidation.requireValidIdentifier(identifier)
        try FocusllyValidation.requireValidDate(archivedAt)
        guard let habit = try fetchHabit(identifier: identifier) else { return }
        habit.archivedAt = archivedAt
        try save()
    }

    private func fetchHabit(identifier: UUID) throws -> Habit? {
        try context.fetch(FetchDescriptor<Habit>()).first { $0.identifier == identifier }
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
            throw FocusllyRepositoryError.duplicateTerminalCheckIn(habitID: existing.habit?.identifier ?? draft.habitID, localDay: localDay)
        }

        let checkIn = HabitCheckIn(
            identifier: draft.identifier,
            habit: habit,
            occurredAt: draft.occurredAt,
            timeZoneIdentifier: draft.timeZoneIdentifier ?? dateProvider.timeZoneIdentifier,
            normalizedLocalDay: localDay,
            outcome: draft.outcome,
            note: cleanedOptional(draft.note),
            source: draft.source,
            createdAt: dateProvider.now
        )

        context.insert(checkIn)
        try save()
        widgetSnapshotWriter.writeAfterCommit(.empty(generatedAt: dateProvider.now))
        return checkIn
    }

    func terminalCheckIn(habitID: UUID, localDay: String) throws -> HabitCheckIn? {
        try FocusllyValidation.requireValidIdentifier(habitID)
        try FocusllyValidation.requireValidLocalDay(localDay)
        return try context.fetch(FetchDescriptor<HabitCheckIn>()).first {
            $0.habit?.identifier == habitID && $0.normalizedLocalDay == localDay
        }
    }

    private func fetchHabit(identifier: UUID) throws -> Habit? {
        try context.fetch(FetchDescriptor<Habit>()).first { $0.identifier == identifier }
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
            legacyTaskTitle: cleanedOptional(draft.legacyTaskTitle),
            legacyTaskID: draft.legacyTaskID,
            startedAt: draft.startedAt,
            endedAt: draft.endedAt,
            durationSeconds: draft.durationSeconds,
            outcome: draft.outcome,
            intention: cleanedOptional(draft.intention),
            rating: cleanedOptional(draft.rating),
            exitReasonRawValue: cleanedOptional(draft.exitReasonRawValue),
            createdAt: dateProvider.now,
            source: draft.source
        )

        context.insert(record)
        try save()
        widgetSnapshotWriter.writeAfterCommit(.empty(generatedAt: dateProvider.now))
        return record
    }

    func fetchFocusSessions() throws -> [FocusSessionRecord] {
        try context.fetch(FetchDescriptor<FocusSessionRecord>()).sorted { $0.startedAt < $1.startedAt }
    }

    private func fetchHabit(identifier: UUID) throws -> Habit? {
        try context.fetch(FetchDescriptor<Habit>()).first { $0.identifier == identifier }
    }

    private func save() throws {
        do {
            try context.save()
        } catch {
            throw FocusllyRepositoryError.saveFailed(error.localizedDescription)
        }
    }
}

private func cleanedOptional(_ value: String?) -> String? {
    guard let value else { return nil }
    let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return cleaned.isEmpty ? nil : cleaned
}
