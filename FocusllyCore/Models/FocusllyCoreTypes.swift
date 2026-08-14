import Foundation

// MARK: - Domain Enums

enum HabitCheckInOutcome: String, Codable, CaseIterable, Sendable {
    case complete
    case skip
    case plannedRest
    case protectedMiss
}

enum FocusllyRecordSource: String, Codable, CaseIterable, Sendable {
    case app
    case widget
    case liveActivity
    case siri
    case watch
    case migration
}

enum FocusSessionRecordOutcome: String, Codable, CaseIterable, Sendable {
    case completed
    case abandoned
    case interrupted
    case skipped
    case unknown
}

enum FreezeTokenLedgerEventType: String, Codable, CaseIterable, Sendable {
    case earned
    case used
}

enum ReflectionPeriodType: String, Codable, CaseIterable, Sendable {
    case weekly
    case monthly
}

enum HabitNotificationCadenceState: String, Codable, CaseIterable, Sendable {
    case daily
    case weekdays
    case custom
    case paused
    case disabled
}

enum HabitScheduleKind: String, Codable, CaseIterable, Sendable {
    case daily
    case weekdays
    case custom
}

// MARK: - Validation

enum FocusllyRepositoryError: Error, LocalizedError, Equatable {
    case emptyTitle
    case invalidIdentifier
    case invalidDate
    case invalidLocalDay(String)
    case invalidDuration(Int)
    case invalidRawValue(field: String, value: String)
    case duplicateTerminalCheckIn(habitID: UUID, localDay: String)
    case missingHabit
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Title cannot be empty."
        case .invalidIdentifier:
            return "Identifier is invalid."
        case .invalidDate:
            return "Date is invalid."
        case .invalidLocalDay(let value):
            return "Local day key is invalid: \(value)."
        case .invalidDuration(let value):
            return "Duration is invalid: \(value)."
        case .invalidRawValue(let field, let value):
            return "Invalid value for \(field): \(value)."
        case .duplicateTerminalCheckIn(_, let localDay):
            return "A terminal check-in already exists for \(localDay)."
        case .missingHabit:
            return "Habit is missing."
        case .saveFailed(let message):
            return "Save failed: \(message)."
        }
    }
}

// MARK: - Clock / Calendar Abstraction

protocol FocusllyDateProviding: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
    var timeZoneIdentifier: String { get }
    func normalizedLocalDay(for date: Date) -> String
}

struct SystemFocusllyDateProvider: FocusllyDateProviding {
    var now: Date { Date() }
    var calendar: Calendar { Calendar.current }
    var timeZoneIdentifier: String { TimeZone.current.identifier }

    func normalizedLocalDay(for date: Date) -> String {
        FocusllyLocalDay.normalizedLocalDay(for: date, calendar: calendar)
    }
}

enum FocusllyLocalDay {
    private static let formatStyle = Date.FormatStyle()
        .year()
        .month(.twoDigits)
        .day(.twoDigits)

    static func normalizedLocalDay(for date: Date, calendar: Calendar = .current) -> String {
        var localCalendar = calendar
        localCalendar.timeZone = calendar.timeZone
        return date.formatted(formatStyle.calendar(localCalendar))
    }

    static func isValid(_ value: String) -> Bool {
        guard value.count == 10 else { return false }
        let parts = value.split(separator: "-")
        guard parts.count == 3,
              parts[0].count == 4,
              parts[1].count == 2,
              parts[2].count == 2,
              let month = Int(parts[1]),
              let day = Int(parts[2]) else {
            return false
        }
        return (1...12).contains(month) && (1...31).contains(day)
    }
}

enum FocusllyValidation {
    static func cleanedTitle(_ title: String) throws -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw FocusllyRepositoryError.emptyTitle }
        return cleaned
    }

    static func requireValidIdentifier(_ identifier: UUID) throws {
        guard identifier.uuidString.isEmpty == false else { throw FocusllyRepositoryError.invalidIdentifier }
    }

    static func requireValidDate(_ date: Date) throws {
        guard date.timeIntervalSinceReferenceDate.isFinite else { throw FocusllyRepositoryError.invalidDate }
    }

    static func requireValidLocalDay(_ localDay: String) throws {
        guard FocusllyLocalDay.isValid(localDay) else { throw FocusllyRepositoryError.invalidLocalDay(localDay) }
    }

    static func requirePositiveDuration(_ durationSeconds: Int) throws {
        guard durationSeconds > 0 else { throw FocusllyRepositoryError.invalidDuration(durationSeconds) }
    }
}
