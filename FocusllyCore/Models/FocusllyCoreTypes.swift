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
        // Fix #6: The previous assignment `localCalendar.timeZone = calendar.timeZone`
        // was a no-op — it copied the same timezone back onto the copy, so any caller
        // that passed a UTC calendar (e.g. in tests) would format dates in UTC instead
        // of the device's local timezone. Forcing TimeZone.current ensures streak,
        // habit, and session records are always attributed to the correct local day
        // regardless of what calendar the caller provides.
        localCalendar.timeZone = TimeZone.current
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

// MARK: - Nil UUID sentinel

extension UUID {
    /// The all-zeros UUID used as a sentinel / placeholder value in legacy code.
    /// `requireValidIdentifier` rejects this value in addition to any structurally
    /// invalid UUID, because SwiftData will accept it and silently create a record
    /// that is impossible to disambiguate from other sentinel-keyed records.
    static let nilSentinel = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}

enum FocusllyValidation {
    static func cleanedTitle(_ title: String) throws -> String {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { throw FocusllyRepositoryError.emptyTitle }
        return cleaned
    }

    // Fix #7: The previous guard checked `uuidString.isEmpty`, which is structurally
    // impossible — UUID.uuidString always returns a 36-character string. The real risk
    // is callers passing the all-zeros sentinel UUID. Guarding against that prevents
    // SwiftData from inserting ambiguous sentinel-keyed records.
    static func requireValidIdentifier(_ identifier: UUID) throws {
        guard identifier != .nilSentinel else { throw FocusllyRepositoryError.invalidIdentifier }
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
