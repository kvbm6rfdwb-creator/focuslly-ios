import Foundation
import EventKit
import Combine

final class CalendarSyncStore: ObservableObject {

    static let shared = CalendarSyncStore()

    @Published private(set) var calendars: [EKCalendar] = []
    @Published var selectedCalendarIDs: Set<String> = [] {
        didSet {
            guard selectedCalendarIDs != oldValue else { return }
            UserDefaults.standard.set(Array(selectedCalendarIDs), forKey: udKey)
            storeRevision += 1
        }
    }
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published private(set) var storeRevision: Int = 0
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date? = nil

    private let eventStore = EKEventStore()
    private let udKey = "calendar_sync_selected_ids_v1"

    // MARK: - Helpers

    var calendarInfos: [AppSettingsStore.CalendarInfo] {
        calendars.map { AppSettingsStore.CalendarInfo(id: $0.calendarIdentifier, title: $0.title) }
    }

    var isAuthorized: Bool {
        if #available(iOS 17.0, *) {
            return authorizationStatus == .fullAccess
        } else {
            // .authorized == 3 on iOS 16
            return authorizationStatus.rawValue == 3
        }
    }

    // MARK: - Init

    private init() {
        // Restore persisted selection — bypass didSet to avoid spurious storeRevision bump
        if let saved = UserDefaults.standard.array(forKey: udKey) as? [String] {
            _selectedCalendarIDs = Published(initialValue: Set(saved))
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ekStoreChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )

        let status = EKEventStore.authorizationStatus(for: .event)
        authorizationStatus = status
        if isAuthorized { loadCalendars() }
    }

    // MARK: - Authorization

    func requestAccessIfNeeded(completion: @escaping (Bool) -> Void) {
        if isAuthorized { completion(true); return }

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted { self?.sync() }
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorizationStatus = EKEventStore.authorizationStatus(for: .event)
                    if granted { self?.sync() }
                    completion(granted)
                }
            }
        }
    }

    // MARK: - Sync (called on appear + manually)

    func sync() {
        guard isAuthorized else {
            requestAccessIfNeeded { _ in }
            return
        }
        guard !isSyncing else { return }
        isSyncing = true
        eventStore.reset()
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let fresh = self.eventStore.calendars(for: .event)
            DispatchQueue.main.async {
                self.calendars = fresh
                let validIDs = Set(fresh.map { $0.calendarIdentifier })
                let stale    = self.selectedCalendarIDs.subtracting(validIDs)
                if !stale.isEmpty { self.selectedCalendarIDs.subtract(stale) }
                self.storeRevision += 1
                self.lastSyncDate  = Date()
                self.isSyncing     = false
            }
        }
    }

    // MARK: - Load calendars (light, no reset)

    func loadCalendars() {
        let fresh = eventStore.calendars(for: .event)
        calendars = fresh
        let validIDs = Set(fresh.map { $0.calendarIdentifier })
        let stale    = selectedCalendarIDs.subtracting(validIDs)
        if !stale.isEmpty { selectedCalendarIDs.subtract(stale) }
    }

    // MARK: - EventKit observer

    @objc private func ekStoreChanged() {
        DispatchQueue.main.async { [weak self] in
            self?.sync()
        }
    }

    // MARK: - Fetch timed events

    func events(for date: Date) -> [EKEvent] {
        guard isAuthorized, !selectedCalendarIDs.isEmpty else { return [] }
        let selected = calendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !selected.isEmpty else { return [] }
        guard let (start, end) = dayBounds(for: date) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: selected)
        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Fetch all-day events

    func allDayEvents(for date: Date) -> [EKEvent] {
        guard isAuthorized, !selectedCalendarIDs.isEmpty else { return [] }
        let selected = calendars.filter { selectedCalendarIDs.contains($0.calendarIdentifier) }
        guard !selected.isEmpty else { return [] }
        guard let (start, end) = dayBounds(for: date) else { return [] }
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: selected)
        return eventStore.events(matching: predicate)
            .filter { $0.isAllDay }
            .sorted { ($0.title ?? "") < ($1.title ?? "") }
    }

    // MARK: - Private helpers

    private func dayBounds(for date: Date) -> (Date, Date)? {
        let cal = Calendar.current
        guard
            let start = cal.date(bySettingHour: 0,  minute: 0,  second: 0,  of: date),
            let end   = cal.date(bySettingHour: 23, minute: 59, second: 59, of: date)
        else { return nil }
        return (start, end)
    }

    // MARK: - Legacy stub
    func syncEvents() { sync() }
}
