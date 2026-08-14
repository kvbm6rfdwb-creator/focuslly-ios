import Foundation
import Combine
import UserNotifications
import EventKit
import SwiftUI

final class AppSettingsStore: ObservableObject {

    static let shared = AppSettingsStore()

    struct SetTimePreset: Codable, Identifiable, Hashable {
        let id: UUID
        var minutes: Int

        init(id: UUID = UUID(), minutes: Int) {
            self.id = id
            self.minutes = minutes
        }

        var label: String {
            "\(minutes)m"
        }
    }

    struct QuickStartTaskPreset: Codable, Identifiable, Hashable {
        let id: UUID
        var title: String
        var icon: String
        var colorHex: String
        var defaultMinutes: Int
        var description: String
        var pipelineCategoryRaw: String?

        init(
            id: UUID = UUID(),
            title: String,
            icon: String,
            colorHex: String,
            defaultMinutes: Int,
            description: String,
            pipelineCategoryRaw: String?
        ) {
            self.id = id
            self.title = title
            self.icon = icon
            self.colorHex = colorHex
            self.defaultMinutes = defaultMinutes
            self.description = description
            self.pipelineCategoryRaw = pipelineCategoryRaw
        }

        var color: Color {
            Color(hex: colorHex) ?? .orange
        }
    }

    // MARK: - Keys
    private enum Keys {
        static let hapticsEnabled            = "settings_haptics_enabled"
        static let soundsEnabled             = "settings_sounds_enabled"
        static let dailyFocusGoalWeekday     = "settings_daily_focus_goal_weekday"
        static let dailyFocusGoalWeekend     = "settings_daily_focus_goal_weekend"
        static let setTimePresets            = "settings_set_time_presets_v1"
        static let quickStartTaskPresets     = "settings_quick_start_task_presets_v1"
        static let taskNamePresets           = "settings_task_name_presets_v1"
        static let intentionPresets          = "settings_intention_presets_v1"
    }

    // MARK: - Published settings

    @Published var hapticsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(hapticsEnabled, forKey: Keys.hapticsEnabled)
        }
    }

    @Published var soundsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundsEnabled, forKey: Keys.soundsEnabled)
        }
    }

    // Daily focus goals (minutes). Defaults: 600 min (10h) weekday, 480 min (8h) weekend.
    @Published var dailyFocusGoalWeekday: Int {
        didSet { UserDefaults.standard.set(dailyFocusGoalWeekday, forKey: Keys.dailyFocusGoalWeekday) }
    }
    @Published var dailyFocusGoalWeekend: Int {
        didSet { UserDefaults.standard.set(dailyFocusGoalWeekend, forKey: Keys.dailyFocusGoalWeekend) }
    }

    /// Returns today's goal in minutes based on whether it's a weekday or weekend.
    var dailyFocusGoalToday: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return (weekday == 1 || weekday == 7) ? dailyFocusGoalWeekend : dailyFocusGoalWeekday
    }

    // MARK: - Notification Preferences
    @Published var notificationsReminders: Bool {
        didSet {
            UserDefaults.standard.set(notificationsReminders, forKey: "settings_notifications_reminders")
            // Don't touch task notifications here — TaskStore owns them.
            // Just cancel all pending task notifications when the toggle is turned off.
            if !notificationsReminders {
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    // Remove all task and follow-up notifications; keep only insight IDs.
                    let toRemove = requests
                        .filter { !["weeklyInsight", "monthlyInsight"].contains($0.identifier) }
                        .map { $0.identifier }
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toRemove)
                }
            }
        }
    }
    @Published var notificationsDailySummary: Bool {
        didSet {
            UserDefaults.standard.set(notificationsDailySummary, forKey: "settings_notifications_daily_summary")
            updateInsightNotifications()
        }
    }
    @Published var notificationsFocusStart: Bool {
        didSet {
            UserDefaults.standard.set(notificationsFocusStart, forKey: "settings_notifications_focus_start")
        }
    }
    @Published var notificationsFollowUp: Bool {
        didSet {
            UserDefaults.standard.set(notificationsFollowUp, forKey: "settings_notifications_follow_up")
            if notificationsFollowUp {
                PipelineStore.shared.scheduleFollowUpNotifications()
            } else {
                // Remove all pending follow-up notifications immediately.
                UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                    let ids = requests
                        .filter { $0.identifier.hasPrefix("followup_") }
                        .map { $0.identifier }
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
                }
            }
        }
    }

    // MARK: - Task Reminder Timing
    @Published var taskReminderMinutesBefore: Int {
        didSet {
            UserDefaults.standard.set(taskReminderMinutesBefore, forKey: "settings_task_reminder_minutes_before")
            // TaskStore will reschedule with the new offset next time tasks change.
            // We can't reschedule here because we don't hold a reference to TaskStore.
        }
    }

    // MARK: - Focus Presets
    @Published var setTimePresets: [SetTimePreset] {
        didSet { persistSetTimePresets() }
    }

    @Published var quickStartTaskPresets: [QuickStartTaskPreset] {
        didSet { persistQuickStartTaskPresets() }
    }

    @Published var taskNamePresets: [String] {
        didSet {
            let safe = taskNamePresets.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if let data = try? JSONEncoder().encode(safe) {
                UserDefaults.standard.set(data, forKey: Keys.taskNamePresets)
            }
            if safe != taskNamePresets { taskNamePresets = safe }
        }
    }

    @Published var intentionPresets: [String] {
        didSet {
            let safe = intentionPresets.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if let data = try? JSONEncoder().encode(safe) {
                UserDefaults.standard.set(data, forKey: Keys.intentionPresets)
            }
            if safe != intentionPresets { intentionPresets = safe }
        }
    }

    // MARK: - Accessibility
    enum FontSize: String, CaseIterable, Identifiable {
        case small, medium, large, extraLarge
        var id: String { rawValue }
    }
    @Published var fontSize: FontSize {
        didSet { UserDefaults.standard.set(fontSize.rawValue, forKey: "settings_font_size") }
    }
    @Published var highContrast: Bool {
        didSet { UserDefaults.standard.set(highContrast, forKey: "settings_high_contrast") }
    }
    @Published var reduceMotion: Bool {
        didSet { UserDefaults.standard.set(reduceMotion, forKey: "settings_reduce_motion") }
    }
    @Published var voiceOverSupport: Bool {
        didSet { UserDefaults.standard.set(voiceOverSupport, forKey: "settings_voiceover_support") }
    }

    // MARK: - Training Settings

    /// Days per week the user wants to train (1–7)
    @Published var trainingDaysPerWeek: Int {
        didSet { UserDefaults.standard.set(trainingDaysPerWeek, forKey: "settings_training_days_per_week") }
    }

    /// Which weekdays training is planned (1=Sun … 7=Sat, matching Calendar.component(.weekday))
    @Published var trainingWeekdays: Set<Int> {
        didSet { UserDefaults.standard.set(Array(trainingWeekdays), forKey: "settings_training_weekdays") }
    }

    /// What counts as completing a training session for streak purposes
    enum TrainingStreakMode: String, CaseIterable, Identifiable {
        case anyPhysicalTask = "Any physical task"
        case quickStartOnly  = "Quick Start sessions only"
        case manualLog       = "Manual log only"
        var id: String { rawValue }
    }
    @Published var trainingStreakMode: TrainingStreakMode {
        didSet { UserDefaults.standard.set(trainingStreakMode.rawValue, forKey: "settings_training_streak_mode") }
    }

    /// Minimum session length (minutes) that counts toward the streak
    @Published var trainingMinSessionMinutes: Int {
        didSet { UserDefaults.standard.set(trainingMinSessionMinutes, forKey: "settings_training_min_session_minutes") }
    }

    // MARK: - Calendar Sync
    struct CalendarInfo: Hashable, Identifiable {
        let id: String
        let title: String
    }
    @Published var availableCalendars: [CalendarInfo]? = nil
    @Published var syncedCalendarIDs: Set<String> {
        didSet {
            // Persist directly to the shared key
            UserDefaults.standard.set(Array(syncedCalendarIDs), forKey: "calendar_sync_selected_ids_v1")
            // Keep CalendarSyncStore in sync — it will bump storeRevision → CalendarView reloads
            calendarSyncStore.selectedCalendarIDs = syncedCalendarIDs
        }
    }

    // MARK: - Reset Confirmation
    @Published var showResetConfirmation: Bool = false

    // MARK: - Calendar Sync Integration
    private var calendarSyncStore = CalendarSyncStore.shared

    // MARK: - Init
    init() {
        self.hapticsEnabled = UserDefaults.standard.object(forKey: Keys.hapticsEnabled) as? Bool ?? true
        self.soundsEnabled = UserDefaults.standard.object(forKey: Keys.soundsEnabled) as? Bool ?? true
        self.dailyFocusGoalWeekday = UserDefaults.standard.object(forKey: Keys.dailyFocusGoalWeekday) as? Int ?? 600
        self.dailyFocusGoalWeekend = UserDefaults.standard.object(forKey: Keys.dailyFocusGoalWeekend) as? Int ?? 480
        self.notificationsReminders = UserDefaults.standard.object(forKey: "settings_notifications_reminders") as? Bool ?? true
        self.notificationsDailySummary = UserDefaults.standard.object(forKey: "settings_notifications_daily_summary") as? Bool ?? true
        self.notificationsFocusStart = UserDefaults.standard.object(forKey: "settings_notifications_focus_start") as? Bool ?? true
        self.notificationsFollowUp = UserDefaults.standard.object(forKey: "settings_notifications_follow_up") as? Bool ?? true
        self.taskReminderMinutesBefore = UserDefaults.standard.object(forKey: "settings_task_reminder_minutes_before") as? Int ?? 10
        self.fontSize = FontSize(rawValue: UserDefaults.standard.string(forKey: "settings_font_size") ?? "medium") ?? .medium
        self.highContrast = UserDefaults.standard.object(forKey: "settings_high_contrast") as? Bool ?? false
        self.reduceMotion = UserDefaults.standard.object(forKey: "settings_reduce_motion") as? Bool ?? false
        self.voiceOverSupport = UserDefaults.standard.object(forKey: "settings_voiceover_support") as? Bool ?? false
        self.trainingDaysPerWeek = UserDefaults.standard.object(forKey: "settings_training_days_per_week") as? Int ?? 3
        if let days = UserDefaults.standard.array(forKey: "settings_training_weekdays") as? [Int] {
            self.trainingWeekdays = Set(days)
        } else {
            self.trainingWeekdays = [2, 4, 6] // Mon, Wed, Fri
        }
        self.trainingStreakMode = TrainingStreakMode(rawValue: UserDefaults.standard.string(forKey: "settings_training_streak_mode") ?? "") ?? .anyPhysicalTask
        self.trainingMinSessionMinutes = UserDefaults.standard.object(forKey: "settings_training_min_session_minutes") as? Int ?? 20
        self.setTimePresets = Self.loadSetTimePresets()
        self.quickStartTaskPresets = Self.loadQuickStartTaskPresets()
        self.taskNamePresets = Self.loadStringList(key: Keys.taskNamePresets, defaults: Self.defaultTaskNamePresets)
        self.intentionPresets = Self.loadStringList(key: Keys.intentionPresets, defaults: Self.defaultIntentionPresets)
        // Read from the same key CalendarSyncStore persists to — single source of truth
        if let ids = UserDefaults.standard.array(forKey: "calendar_sync_selected_ids_v1") as? [String] {
            self.syncedCalendarIDs = Set(ids)
        } else if let ids = UserDefaults.standard.array(forKey: "settings_synced_calendar_ids") as? [String] {
            // Migrate from old key
            self.syncedCalendarIDs = Set(ids)
            UserDefaults.standard.set(ids, forKey: "calendar_sync_selected_ids_v1")
        } else {
            self.syncedCalendarIDs = []
        }
        setupCalendarSync()
        purgeStaleLegacyNotifications()
    }

    // MARK: - Notification Logic
    func updateInsightNotifications() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                    if granted { self.scheduleInsightNotifications() }
                }
            } else if settings.authorizationStatus == .authorized {
                self.scheduleInsightNotifications()
            }
        }
    }

    private func scheduleInsightNotifications() {
        if notificationsDailySummary {
            scheduleWeeklyInsightNotification()
            scheduleMonthlyInsightNotification()
        } else {
            cancelNotification(identifier: "weeklyInsight")
            cancelNotification(identifier: "monthlyInsight")
        }
    }

    private func scheduleWeeklyInsightNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Weekly Progress"
        content.body = "Check your productivity progress for this week!"
        content.sound = .default
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // Sunday
        dateComponents.hour = 20
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weeklyInsight", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func scheduleMonthlyInsightNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Monthly Progress"
        content.body = "Check your productivity progress for this month!"
        content.sound = .default
        var dateComponents = DateComponents()
        dateComponents.day = 1
        dateComponents.hour = 20
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "monthlyInsight", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Task Start Notification Scheduling
    func scheduleTaskStartNotifications(tasks: [FocusTask]) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: tasks.map { $0.id.uuidString })
        guard notificationsReminders else { return }
        for task in tasks {
            guard let scheduled = task.scheduledTime else { continue }
            let reminderDate = scheduled.addingTimeInterval(TimeInterval(-taskReminderMinutesBefore * 60))
            if reminderDate > Date() {
                let content = UNMutableNotificationContent()
                content.title = "Upcoming Task: \(task.title)"
                content.body = taskReminderMinutesBefore == 1
                    ? "Starting in 1 minute — get ready!"
                    : "Starts in \(taskReminderMinutesBefore) minutes."
                content.sound = .default
                let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate), repeats: false)
                let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
                UNUserNotificationCenter.current().add(request)
            }
        }
    }

    // MARK: - Accessibility Application
    func applyAccessibilitySettings() {
        // Font size: Use environment or custom modifier in views
        // High contrast: Use environment or custom modifier in views
        // Reduce motion: Use environment or custom modifier in views
        // VoiceOver: Use environment or custom modifier in views
        // This method can be called from main views to update UI
    }

    // MARK: - Reset All
    func resetAll() {
        hapticsEnabled = true
        soundsEnabled = true
        notificationsReminders = true
        notificationsDailySummary = true
        notificationsFocusStart = true
        notificationsFollowUp = true
        taskReminderMinutesBefore = 10
        fontSize = .medium
        highContrast = false
        reduceMotion = false
        voiceOverSupport = false
        syncedCalendarIDs = []
        dailyFocusGoalWeekday = 600
        dailyFocusGoalWeekend = 480
        trainingDaysPerWeek = 3
        trainingWeekdays = [2, 4, 6]
        trainingStreakMode = .anyPhysicalTask
        trainingMinSessionMinutes = 20
        setTimePresets = Self.defaultSetTimePresets
        quickStartTaskPresets = Self.defaultQuickStartTaskPresets
        taskNamePresets = Self.defaultTaskNamePresets
        intentionPresets = Self.defaultIntentionPresets
    }

    // MARK: - Calendar Sync Setup
    private func setupCalendarSync() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .fullAccess || status == .writeOnly {
            // Sync calendars list, but NEVER overwrite saved selectedCalendarIDs
            calendarSyncStore.sync()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.availableCalendars = self.calendarSyncStore.calendarInfos
            }
        } else if status == .notDetermined {
            calendarSyncStore.requestAccessIfNeeded { granted in
                if granted {
                    self.availableCalendars = self.calendarSyncStore.calendarInfos
                } else {
                    self.availableCalendars = nil
                }
            }
        }
    }

    /// Called from the Settings sync button — forces a full EventKit refresh.
    func forceCalendarSync() {
        calendarSyncStore.sync()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.availableCalendars = self.calendarSyncStore.calendarInfos
        }
    }

    /// Removes any randomly-fired legacy notifications scheduled by the old
    /// `scheduleAllNotifications` path and any orphaned requests that aren't
    /// task UUIDs, known insight IDs, or follow-up notifications.
    private func purgeStaleLegacyNotifications() {
        let knownInsightIds: Set<String> = ["weeklyInsight", "monthlyInsight"]
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let toRemove = requests
                .filter { req in
                    // Keep known insight notifications.
                    guard !knownInsightIds.contains(req.identifier) else { return false }
                    // Keep task notifications (UUID-based identifiers).
                    if UUID(uuidString: req.identifier) != nil { return false }
                    // Keep follow-up notifications scheduled by PipelineStore.
                    if req.identifier.hasPrefix("followup_") { return false }
                    // Anything else is stale/legacy — remove it.
                    return true
                }
                .map { $0.identifier }
            if !toRemove.isEmpty {
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: toRemove)
            }
        }
    }

    // MARK: - Preset Persistence
    private static let defaultSetTimePresets: [SetTimePreset] = [
        .init(minutes: 15), .init(minutes: 25), .init(minutes: 30), .init(minutes: 45), .init(minutes: 60), .init(minutes: 90)
    ]

    private static let defaultQuickStartTaskPresets: [QuickStartTaskPreset] = [
        .init(title: "Follow-Ups", icon: "arrow.uturn.right", colorHex: "34C759", defaultMinutes: 30, description: "Warm leads & callbacks", pipelineCategoryRaw: "followUps"),
        .init(title: "Send Offers", icon: "doc.text.fill", colorHex: "007AFF", defaultMinutes: 60, description: "Prepare & send proposals", pipelineCategoryRaw: "sendOffers"),
        .init(title: "Add New Listing", icon: "house.fill", colorHex: "FF9500", defaultMinutes: 90, description: "List a new property", pipelineCategoryRaw: "addListing"),
        .init(title: "Answer Inquiries", icon: "message.fill", colorHex: "30B0C7", defaultMinutes: 20, description: "Reply to incoming requests", pipelineCategoryRaw: "answerInquiries"),
        .init(title: "Meeting", icon: "person.2.fill", colorHex: "AF52DE", defaultMinutes: 90, description: "Client or team meeting", pipelineCategoryRaw: "meeting"),
        .init(title: "Physical Training", icon: "figure.run", colorHex: "FF3B30", defaultMinutes: 60, description: "Gym, run or sport session", pipelineCategoryRaw: "physicalTraining"),
        .init(title: "Reading", icon: "book.fill", colorHex: "5856D6", defaultMinutes: 45, description: "Books, articles, learning", pipelineCategoryRaw: "reading")
    ]

    static let defaultTaskNamePresets: [String] = [
        "Cold calls", "Follow-up calls", "Answer inquiries",
        "Send offers", "Showings", "CMA prep",
        "Add listing", "Admin", "Reading",
        "Physical training", "Team meeting"
    ]

    static let defaultIntentionPresets: [String] = [
        "Offer sent", "Call done", "Showing done",
        "Listing added", "Answered inquiries", "Read a book"
    ]

    private static func loadStringList(key: String, defaults: [String]) -> [String] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([String].self, from: data),
            !decoded.isEmpty
        else { return defaults }
        return decoded
    }

    private static func loadSetTimePresets() -> [SetTimePreset] {
        guard
            let data = UserDefaults.standard.data(forKey: Keys.setTimePresets),
            let decoded = try? JSONDecoder().decode([SetTimePreset].self, from: data),
            !decoded.isEmpty
        else {
            return defaultSetTimePresets
        }
        return decoded
    }

    private static func loadQuickStartTaskPresets() -> [QuickStartTaskPreset] {
        guard
            let data = UserDefaults.standard.data(forKey: Keys.quickStartTaskPresets),
            let decoded = try? JSONDecoder().decode([QuickStartTaskPreset].self, from: data),
            !decoded.isEmpty
        else {
            return defaultQuickStartTaskPresets
        }
        return decoded
    }

    private func persistSetTimePresets() {
        let safe = setTimePresets
            .map { SetTimePreset(id: $0.id, minutes: max(5, min(240, $0.minutes))) }
            .sorted { $0.minutes < $1.minutes }
        guard let data = try? JSONEncoder().encode(safe) else { return }
        UserDefaults.standard.set(data, forKey: Keys.setTimePresets)
        if safe != setTimePresets {
            setTimePresets = safe
        }
    }

    private func persistQuickStartTaskPresets() {
        let safe = quickStartTaskPresets
            .map {
                QuickStartTaskPreset(
                    id: $0.id,
                    title: $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Quick Task" : $0.title.trimmingCharacters(in: .whitespacesAndNewlines),
                    icon: $0.icon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "bolt.fill" : $0.icon,
                    colorHex: $0.colorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "FF9500" : $0.colorHex,
                    defaultMinutes: max(5, min(240, $0.defaultMinutes)),
                    description: $0.description,
                    pipelineCategoryRaw: $0.pipelineCategoryRaw
                )
            }
        guard let data = try? JSONEncoder().encode(safe) else { return }
        UserDefaults.standard.set(data, forKey: Keys.quickStartTaskPresets)
        if safe != quickStartTaskPresets {
            quickStartTaskPresets = safe
        }
    }
}
