import Foundation
import Combine

final class TaskStore: ObservableObject {
    // MARK: - Dependencies
    private let settings: AppSettingsStore

    // MARK: - Tasks
    @Published var tasks: [FocusTask] = [] {
        didSet {
            settings.scheduleTaskStartNotifications(tasks: getTodaysTasks())
        }
    }

    // MARK: - Session logs
    @Published var sessionLogs: [FocusSessionLog] = []

    // MARK: - Active focus session
    @Published var activeFocusTask: FocusTask? = nil

    /// Set by switchFocus() when chaining tasks. FocusTabView shows the
    /// preparation sheet for this task, then calls confirmChainTask() to launch it.
    @Published var pendingChainTask: FocusTask? = nil

    // MARK: - Init
    init(settings: AppSettingsStore) {
        self.settings = settings
        loadTasks()
        loadSessionLogs()
        performDailyCleanupIfNeeded()
        settings.scheduleTaskStartNotifications(tasks: getTodaysTasks())
    }

    // MARK: - Focus control
    func startFocus(task: FocusTask) {
        activeFocusTask = task
    }

    func endFocus() {
        activeFocusTask = nil
    }

    /// Atomically switches from the current task to a new one without ever
    /// setting activeFocusTask to nil. This prevents FocusTabView from
    /// collapsing to idle between sessions.
    /// The actual engine launch is deferred until confirmChainTask() is called
    /// (after the preparation sheet).
    func switchFocus(from old: FocusTask, to next: FocusTask) {
        completeTask(old)
        pendingChainTask = next
        // activeFocusTask stays as `old` until confirmChainTask() fires,
        // keeping FocusTabView in engine-host mode (no idle flash).
    }

    /// Called by FocusTabView after the user confirms the preparation sheet.
    func confirmChainTask(_ task: FocusTask) {
        pendingChainTask = nil
        activeFocusTask = task
    }

    /// Called by FocusTabView if the user dismisses the preparation sheet
    /// without starting (rare edge case — they could tap the back arrow).
    func cancelChainTask() {
        pendingChainTask = nil
        activeFocusTask = nil
    }

    // MARK: - Daily Task Filtering
    /// Returns tasks that should be visible today:
    /// - All unfinished tasks scheduled for today or earlier (overdue)
    /// - Unfinished tasks from previous days (carry forward until end of day)
    func getTodaysTasks() -> [FocusTask] {
        let calendar = Calendar.current
        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart

        return tasks
            .filter { task in
                guard task.status == .pending else { return false }
                let taskDate = task.scheduledTime ?? task.startDate
                return taskDate < tomorrowStart
            }
            .sorted { task1, task2 in
                let time1 = task1.scheduledTime ?? task1.startDate
                let time2 = task2.scheduledTime ?? task2.startDate
                return time1 < time2
            }
    }

    // MARK: - Task CRUD
    func addTask(_ task: FocusTask) {
        tasks.append(task)
        saveTasks()
        settings.scheduleTaskStartNotifications(tasks: getTodaysTasks())
    }

    func addTasks(_ newTasks: [FocusTask]) {
        tasks.append(contentsOf: newTasks)
        saveTasks()
        settings.scheduleTaskStartNotifications(tasks: getTodaysTasks())
    }

    func updateTask(_ task: FocusTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        saveTasks()
        settings.scheduleTaskStartNotifications(tasks: getTodaysTasks())
    }

    /// Shifts the scheduledTime of every task whose ID is in `ids` by `interval`.
    func shiftTasks(ids: [UUID], by interval: TimeInterval) {
        var didChange = false
        for id in ids {
            guard let index = tasks.firstIndex(where: { $0.id == id }) else { continue }
            if let current = tasks[index].scheduledTime {
                tasks[index].scheduledTime = current.addingTimeInterval(interval)
                didChange = true
            }
        }
        if didChange {
            saveTasks()
            settings.scheduleTaskStartNotifications(tasks: getTodaysTasks())
        }
    }

    func completeTask(_ task: FocusTask) {
        var updated = task
        updated.status = .completed
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = updated
        if activeFocusTask?.id == task.id {
            activeFocusTask = nil
        }
        saveTasks()
        settings.scheduleTaskStartNotifications(tasks: getTodaysTasks())
    }

    // MARK: - Delete
    func deleteTask(_ task: FocusTask) {
        tasks.removeAll { $0.id == task.id }
        saveTasks()
        settings.scheduleTaskStartNotifications(tasks: getTodaysTasks())
    }

    // MARK: - Recurrence generation
    /// Generates concrete task instances for the next `daysAhead` days.
    func generateRecurringTasks(from baseTask: FocusTask, daysAhead: Int = 30) -> [FocusTask] {
        guard let startDate = baseTask.scheduledTime else { return [] }

        let calendar = Calendar.current
        var generated: [FocusTask] = []

        for offset in 0..<daysAhead {
            guard let date = calendar.date(byAdding: .day, value: offset, to: startDate) else { continue }

            let weekday = calendar.component(.weekday, from: date)
            let normalizedWeekday = weekday == 1 ? 7 : weekday - 1 // Mon = 1 ... Sun = 7

            let shouldInclude: Bool
            switch baseTask.recurrenceType {
            case .once:     shouldInclude = offset == 0
            case .daily:    shouldInclude = true
            case .weekdays: shouldInclude = normalizedWeekday <= 5
            case .custom:   shouldInclude = baseTask.recurrenceDays?.contains(normalizedWeekday) == true
            }

            guard shouldInclude else { continue }

            let task = FocusTask(
                title: baseTask.title,
                focusPlan: baseTask.focusPlan,
                status: .pending,
                scheduledTime: date,
                recurrenceType: baseTask.recurrenceType,
                recurrenceDays: baseTask.recurrenceDays
            )
            generated.append(task)
        }

        return generated
    }

    // MARK: - Session logging
    func logSession(
        taskId: UUID,
        startDate: Date,
        endDate: Date,
        exitReason: FocusExitReason,
        customReason: String? = nil,
        breakMinutes: Int? = nil,
        prolongedMinutes: Int? = nil
    ) {
        let log = FocusSessionLog(
            taskId: taskId,
            startDate: startDate,
            endDate: endDate,
            exitReason: exitReason,
            customReason: customReason,
            breakMinutes: breakMinutes,
            prolongedMinutes: prolongedMinutes
        )
        sessionLogs.append(log)
        saveSessionLogs()

        // Auto-notify PipelineStore if this was a pipeline-tagged task
        if exitReason == .completed || exitReason == .prolonged,
           let task = tasks.first(where: { $0.id == taskId }),
           task.pipelineCategory != nil {
            PipelineStore.shared.recordTaskCompletion(task: task, durationMinutes: max(1, log.durationMinutes))
        }
    }

    // MARK: - Daily Streak
    /// Counts consecutive days (ending today) that have at least one completed or prolonged session.
    var dailyStreak: Int {
        let calendar = Calendar.current

        let activeDays = Set(
            sessionLogs
                .filter { $0.exitReason == .completed || $0.exitReason == .prolonged }
                .map { calendar.startOfDay(for: $0.startDate) }
        )

        guard !activeDays.isEmpty else { return 0 }

        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())

        var safety = 0
        while activeDays.contains(currentDay) {
            streak += 1
            safety += 1
            if safety > 3660 { break }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = prev
        }

        return streak
    }

    // MARK: - Strict streak helpers (private)
    private func tasksForDay(_ dayStart: Date) -> [FocusTask] {
        let calendar = Calendar.current
        return tasks.filter { task in
            let d = task.scheduledTime ?? task.startDate
            return calendar.isDate(d, inSameDayAs: dayStart)
        }
    }

    private func dayHasDistracted(_ dayStart: Date) -> Bool {
        let calendar = Calendar.current
        return sessionLogs.contains {
            $0.exitReason == .distracted && calendar.isDate($0.startDate, inSameDayAs: dayStart)
        }
    }

    private func completedLogTaskIDsForDay(_ dayStart: Date) -> Set<UUID> {
        let calendar = Calendar.current
        return Set(
            sessionLogs
                .filter {
                    ($0.exitReason == .completed || $0.exitReason == .prolonged)
                    && calendar.isDate($0.startDate, inSameDayAs: dayStart)
                }
                .map { $0.taskId }
        )
    }

    private func dayQualifies(_ dayStart: Date) -> Bool {
        guard !dayHasDistracted(dayStart) else { return false }
        let dayTasks = tasksForDay(dayStart)
        guard !dayTasks.isEmpty else { return false }
        let completedLogIDs = completedLogTaskIDsForDay(dayStart)
        return dayTasks.allSatisfy { task in
            task.status == .completed && completedLogIDs.contains(task.id)
        }
    }

    /// Strict streak: counts only consecutive days where every scheduled task
    /// is completed and there are no distracted sessions.
    /// Days with no tasks are skipped (do not increment, do not break).
    var strictDailyStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())

        var safety = 0
        while true {
            safety += 1
            if safety > 3660 { break }

            let dayTasks = tasksForDay(currentDay)

            if dayTasks.isEmpty {
                guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
                currentDay = prev
                continue
            }

            if dayQualifies(currentDay) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
                currentDay = prev
                continue
            }

            break
        }

        return streak
    }

    // MARK: - Weekly / Monthly Summary
    var focusMinutesThisWeek: Int {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return totalMinutes(in: weekInterval)
    }

    var focusMinutesThisMonth: Int {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: Date()) else { return 0 }
        return totalMinutes(in: monthInterval)
    }

    var bestFocusDay: (date: Date, minutes: Int)? {
        let calendar = Calendar.current
        let grouped = Dictionary(
            grouping: sessionLogs.filter { $0.exitReason == .completed || $0.exitReason == .prolonged }
        ) {
            calendar.startOfDay(for: $0.startDate)
        }
        let dayTotals = grouped.map { date, logs -> (Date, Int) in
            (date, logs.reduce(0) { $0 + $1.durationMinutes })
        }
        return dayTotals.max { $0.1 < $1.1 }
    }

    private func totalMinutes(in interval: DateInterval) -> Int {
        sessionLogs
            .filter {
                ($0.exitReason == .completed || $0.exitReason == .prolonged) &&
                interval.contains($0.startDate)
            }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    // MARK: - Skip / Undo
    @Published var lastSkippedTask: FocusTask? = nil
    @Published var lastSkippedIndex: Int? = nil
    @Published var showUndo: Bool = false

    func skipTask(_ task: FocusTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }

        lastSkippedTask = task
        lastSkippedIndex = index

        var updated = task
        let calendar = Calendar.current
        let baseDate = task.scheduledTime ?? Date()
        updated.scheduledTime = calendar.date(byAdding: .day, value: 1, to: baseDate)

        tasks[index] = updated
        showUndo = true
        saveTasks()
    }

    func undoSkip() {
        guard let task = lastSkippedTask, let index = lastSkippedIndex else { return }
        tasks[index] = task
        lastSkippedTask = nil
        lastSkippedIndex = nil
        showUndo = false
        saveTasks()
    }

    // MARK: - Daily Task Management
    func removeUnfinishedTasksFromPreviousDays() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        tasks.removeAll { task in
            let taskStartOfDay = calendar.startOfDay(for: task.scheduledTime ?? task.startDate)
            return task.status == .pending && taskStartOfDay < todayStart
        }
        saveTasks()
    }

    func performDailyCleanupIfNeeded() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastCleanupKey = "last_task_cleanup_day"

        let lastCleanupInterval = UserDefaults.standard.double(forKey: lastCleanupKey)
        if lastCleanupInterval != 0 {
            let lastCleanupDay = calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: lastCleanupInterval))
            if today == lastCleanupDay { return }
        }

        removeUnfinishedTasksFromPreviousDays()
        UserDefaults.standard.set(Date().timeIntervalSinceReferenceDate, forKey: lastCleanupKey)
    }

    // MARK: - Persistence
    private let tasksKey = "focus_tasks"
    private let logsKey  = "focus_session_logs"

    func deleteAllData() {
        tasks = []
        sessionLogs = []
        UserDefaults.standard.removeObject(forKey: tasksKey)
        UserDefaults.standard.removeObject(forKey: logsKey)
        activeFocusTask = nil
        pendingChainTask = nil
    }

    private func saveTasks() {
        if let data = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(data, forKey: tasksKey)
        }
    }

    private func loadTasks() {
        guard
            let data = UserDefaults.standard.data(forKey: tasksKey),
            let decoded = try? JSONDecoder().decode([FocusTask].self, from: data)
        else { return }
        tasks = decoded
    }

    private func saveSessionLogs() {
        if let data = try? JSONEncoder().encode(sessionLogs) {
            UserDefaults.standard.set(data, forKey: logsKey)
        }
    }

    private func loadSessionLogs() {
        guard
            let data = UserDefaults.standard.data(forKey: logsKey),
            let decoded = try? JSONDecoder().decode([FocusSessionLog].self, from: data)
        else { return }
        sessionLogs = decoded
    }

    // MARK: - Dashboard Stats
    struct DashboardFocusStatsSnapshot {
        let sessionsToday: Int
        let focusedMinutesToday: Int
        let currentStreak: Int
        let last7Days: [(date: Date, focusedMinutes: Int)]
    }

    func focusStatsSnapshot(referenceDate: Date = Date()) -> DashboardFocusStatsSnapshot {
        let sessions = completedSessionsToday(referenceDate: referenceDate)
        let minutes  = focusedMinutesToday(referenceDate: referenceDate)
        let last7    = last7DaysFocusMinutes(referenceDate: referenceDate).map { ($0.date, $0.minutes) }
        return DashboardFocusStatsSnapshot(
            sessionsToday: sessions,
            focusedMinutesToday: minutes,
            currentStreak: strictDailyStreak,
            last7Days: last7
        )
    }

    // MARK: - Dashboard Stats Helpers
    func completedSessionsToday(referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        return sessionLogs.filter {
            ($0.exitReason == .completed || $0.exitReason == .prolonged)
            && calendar.isDate($0.startDate, inSameDayAs: dayStart)
        }.count
    }

    func focusedMinutesToday(referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: referenceDate)
        return sessionLogs
            .filter {
                ($0.exitReason == .completed || $0.exitReason == .prolonged)
                && calendar.isDate($0.startDate, inSameDayAs: dayStart)
            }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    func last7DaysFocusMinutes(referenceDate: Date = Date()) -> [(date: Date, minutes: Int)] {
        let calendar = Calendar.current
        let referenceDay = calendar.startOfDay(for: referenceDate)
        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -(6 - offset), to: referenceDay) ?? referenceDay
            let minutes = sessionLogs
                .filter {
                    ($0.exitReason == .completed || $0.exitReason == .prolonged)
                    && calendar.isDate($0.startDate, inSameDayAs: day)
                }
                .reduce(0) { $0 + $1.durationMinutes }
            return (date: day, minutes: minutes)
        }
    }

    // MARK: - Break Insights (Last 7 Days)
    func breakInsightsForLast7Days(referenceDate: Date = Date()) -> [BreakInsightDecisionEngine.Decision] {
        let calendar = Calendar.current
        let referenceDayStart = calendar.startOfDay(for: referenceDate)
        let todayStart = calendar.startOfDay(for: Date())

        let dayStarts: [Date] = (1...7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: referenceDayStart)
                .map { calendar.startOfDay(for: $0) }
        }

        var decisions: [BreakInsightDecisionEngine.Decision] = []

        for dayStart in dayStarts {
            guard dayStart < todayStart else { continue }

            let tasksForDay = tasksForDay(dayStart)
            guard !tasksForDay.isEmpty else { continue }
            guard !tasksForDay.contains(where: { $0.status != .completed }) else { continue }
            guard !dayHasDistracted(dayStart) else { continue }

            let representativeTask = tasksForDay.max { lhs, rhs in
                let l = lhs.focusPlan.blocks.filter { $0.type == .focus }.reduce(0) { $0 + $1.duration }
                let r = rhs.focusPlan.blocks.filter { $0.type == .focus }.reduce(0) { $0 + $1.duration }
                if l == r {
                    let ld = lhs.scheduledTime ?? lhs.startDate
                    let rd = rhs.scheduledTime ?? rhs.startDate
                    return ld < rd
                }
                return l < r
            }

            guard let representativeTask else { continue }
            decisions.append(BreakInsightDecisionEngine.decide(currentTask: representativeTask))
        }

        return decisions
    }
}
