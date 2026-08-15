import Foundation
import SwiftData

@Model
final class Habit {
    // Contract: @Attribute(.unique) on `identifier` means SwiftData will throw
    // (or silently overwrite, depending on version) if a duplicate UUID is inserted.
    // Callers MUST call FocusllyValidation.requireValidIdentifier before insert and
    // MUST fetch-before-insert to guarantee no duplicate exists. Do not rely on
    // SwiftData's constraint enforcement alone — its error handling for unique
    // violations is not guaranteed to be catchable across all OS versions.
    @Attribute(.unique) var identifier: UUID
    var title: String
    var detail: String?
    var createdAt: Date
    var archivedAt: Date?

    /// V1 stores a compact schedule kind plus optional JSON/text detail for future recurrence expansion.
    var scheduleKindRawValue: String
    var scheduleDetail: String?
    var cueText: String?

    // NOTE(reminder-fields): reminderHour and reminderMinute here are V1 scaffolding
    // fields retained for schema compatibility. The canonical source of truth for
    // reminder timing is HabitNotificationPlan.reminderHour / reminderMinute.
    // These Habit-level fields must not be read for scheduling decisions — always
    // read from the associated notificationPlan instead.
    // TODO(reminder-cleanup): Remove these fields in a future VersionedSchema bump
    // once all callsites have been migrated to read from HabitNotificationPlan.
    var reminderHour: Int?
    var reminderMinute: Int?

    var colorHex: String?
    var iconName: String?

    @Relationship(deleteRule: .cascade, inverse: \HabitCheckIn.habit)
    var checkIns: [HabitCheckIn] = []

    @Relationship(deleteRule: .cascade, inverse: \PlannedRestDay.habit)
    var plannedRestDays: [PlannedRestDay] = []

    @Relationship(deleteRule: .cascade, inverse: \HabitNotificationPlan.habit)
    var notificationPlan: HabitNotificationPlan?

    init(
        identifier: UUID = UUID(),
        title: String,
        detail: String? = nil,
        createdAt: Date = Date(),
        archivedAt: Date? = nil,
        scheduleKind: HabitScheduleKind = .daily,
        scheduleDetail: String? = nil,
        cueText: String? = nil,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        colorHex: String? = nil,
        iconName: String? = nil
    ) {
        self.identifier = identifier
        self.title = title
        self.detail = detail
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.scheduleKindRawValue = scheduleKind.rawValue
        self.scheduleDetail = scheduleDetail
        self.cueText = cueText
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.colorHex = colorHex
        self.iconName = iconName
    }
}

@Model
final class HabitCheckIn {
    // Contract: see Habit.identifier for @Attribute(.unique) insert semantics.
    @Attribute(.unique) var identifier: UUID
    var habit: Habit?
    var occurredAt: Date
    var timeZoneIdentifier: String
    var normalizedLocalDay: String
    var outcomeRawValue: String
    var note: String?
    var sourceRawValue: String
    var createdAt: Date

    init(
        identifier: UUID = UUID(),
        habit: Habit?,
        occurredAt: Date,
        timeZoneIdentifier: String,
        normalizedLocalDay: String,
        outcome: HabitCheckInOutcome,
        note: String? = nil,
        source: FocusllyRecordSource,
        createdAt: Date = Date()
    ) {
        self.identifier = identifier
        self.habit = habit
        self.occurredAt = occurredAt
        self.timeZoneIdentifier = timeZoneIdentifier
        self.normalizedLocalDay = normalizedLocalDay
        self.outcomeRawValue = outcome.rawValue
        self.note = note
        self.sourceRawValue = source.rawValue
        self.createdAt = createdAt
    }
}

@Model
final class FocusSessionRecord {
    // Contract: see Habit.identifier for @Attribute(.unique) insert semantics.
    @Attribute(.unique) var identifier: UUID
    var habit: Habit?
    var legacyTaskTitle: String?
    var legacyTaskID: UUID?
    var startedAt: Date
    var endedAt: Date
    var durationSeconds: Int
    var outcomeRawValue: String
    var intention: String?
    var rating: String?
    var exitReasonRawValue: String?
    var createdAt: Date
    var sourceRawValue: String

    init(
        identifier: UUID = UUID(),
        habit: Habit? = nil,
        legacyTaskTitle: String? = nil,
        legacyTaskID: UUID? = nil,
        startedAt: Date,
        endedAt: Date,
        durationSeconds: Int,
        outcome: FocusSessionRecordOutcome,
        intention: String? = nil,
        rating: String? = nil,
        exitReasonRawValue: String? = nil,
        createdAt: Date = Date(),
        source: FocusllyRecordSource
    ) {
        self.identifier = identifier
        self.habit = habit
        self.legacyTaskTitle = legacyTaskTitle
        self.legacyTaskID = legacyTaskID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.outcomeRawValue = outcome.rawValue
        self.intention = intention
        self.rating = rating
        self.exitReasonRawValue = exitReasonRawValue
        self.createdAt = createdAt
        self.sourceRawValue = source.rawValue
    }
}

@Model
final class PlannedRestDay {
    // Contract: see Habit.identifier for @Attribute(.unique) insert semantics.
    @Attribute(.unique) var identifier: UUID
    var habit: Habit?
    var normalizedLocalDay: String
    var createdAt: Date
    var note: String?

    init(
        identifier: UUID = UUID(),
        habit: Habit?,
        normalizedLocalDay: String,
        createdAt: Date = Date(),
        note: String? = nil
    ) {
        self.identifier = identifier
        self.habit = habit
        self.normalizedLocalDay = normalizedLocalDay
        self.createdAt = createdAt
        self.note = note
    }
}

@Model
final class FreezeTokenLedgerEntry {
    // Contract: see Habit.identifier for @Attribute(.unique) insert semantics.
    @Attribute(.unique) var identifier: UUID
    var habit: Habit?
    var eventTypeRawValue: String
    var occurredAt: Date
    var normalizedLocalDay: String?
    var reason: String
    var createdAt: Date

    init(
        identifier: UUID = UUID(),
        habit: Habit?,
        eventType: FreezeTokenLedgerEventType,
        occurredAt: Date,
        normalizedLocalDay: String? = nil,
        reason: String,
        createdAt: Date = Date()
    ) {
        self.identifier = identifier
        self.habit = habit
        self.eventTypeRawValue = eventType.rawValue
        self.occurredAt = occurredAt
        self.normalizedLocalDay = normalizedLocalDay
        self.reason = reason
        self.createdAt = createdAt
    }
}

@Model
final class ReflectionEntry {
    // Contract: see Habit.identifier for @Attribute(.unique) insert semantics.
    @Attribute(.unique) var identifier: UUID
    var periodTypeRawValue: String
    var periodStartLocalDay: String
    var responseText: String
    var createdAt: Date

    init(
        identifier: UUID = UUID(),
        periodType: ReflectionPeriodType,
        periodStartLocalDay: String,
        responseText: String,
        createdAt: Date = Date()
    ) {
        self.identifier = identifier
        self.periodTypeRawValue = periodType.rawValue
        self.periodStartLocalDay = periodStartLocalDay
        self.responseText = responseText
        self.createdAt = createdAt
    }
}

@Model
final class HabitNotificationPlan {
    // Contract: see Habit.identifier for @Attribute(.unique) insert semantics.
    @Attribute(.unique) var identifier: UUID
    var habit: Habit?
    var enabled: Bool
    // Canonical reminder time fields. These are the authoritative source for all
    // notification scheduling decisions. Do NOT read Habit.reminderHour /
    // Habit.reminderMinute for scheduling — those fields are legacy scaffolding.
    var reminderHour: Int?
    var reminderMinute: Int?
    var cadenceStateRawValue: String
    var pausedUntil: Date?
    var updatedAt: Date

    init(
        identifier: UUID = UUID(),
        habit: Habit?,
        enabled: Bool,
        reminderHour: Int? = nil,
        reminderMinute: Int? = nil,
        cadenceState: HabitNotificationCadenceState = .daily,
        pausedUntil: Date? = nil,
        updatedAt: Date = Date()
    ) {
        self.identifier = identifier
        self.habit = habit
        self.enabled = enabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.cadenceStateRawValue = cadenceState.rawValue
        self.pausedUntil = pausedUntil
        self.updatedAt = updatedAt
    }
}

@Model
final class AppMigrationRecord {
    // Uses migrationName (not a UUID) as the unique key because migration records
    // are looked up by name. See SwiftDataMigrationService.existingMigrationRecord.
    @Attribute(.unique) var migrationName: String
    var completedAt: Date
    var sourceVersion: String
    var importedHabitCount: Int
    var importedCheckInCount: Int
    var importedFocusSessionCount: Int
    var failedRecordCount: Int
    var quarantinedRecordCount: Int
    var diagnosticSummary: String

    init(
        migrationName: String,
        completedAt: Date = Date(),
        sourceVersion: String,
        importedHabitCount: Int,
        importedCheckInCount: Int,
        importedFocusSessionCount: Int,
        failedRecordCount: Int,
        quarantinedRecordCount: Int,
        diagnosticSummary: String
    ) {
        self.migrationName = migrationName
        self.completedAt = completedAt
        self.sourceVersion = sourceVersion
        self.importedHabitCount = importedHabitCount
        self.importedCheckInCount = importedCheckInCount
        self.importedFocusSessionCount = importedFocusSessionCount
        self.failedRecordCount = failedRecordCount
        self.quarantinedRecordCount = quarantinedRecordCount
        self.diagnosticSummary = diagnosticSummary
    }
}
