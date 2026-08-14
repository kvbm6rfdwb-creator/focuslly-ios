import Foundation
import SwiftUI
import Combine
import UIKit
import WidgetKit

// MARK: - Session State
enum FocusSessionState: Equatable {
    case idle
    case running
    case paused
    case finished
}

// MARK: - Focus Session Engine
final class FocusSessionEngine: ObservableObject {
    // MARK: - Published (UI)
    @Published private(set) var task: FocusTask
    @Published private(set) var sessionState: FocusSessionState = .idle
    @Published private(set) var blockType: FocusBlockType = .focus

    @Published private(set) var remainingSeconds: Int
    @Published private(set) var totalSeconds: Int
    @Published private(set) var ringProgress: Double = 0
    @Published private(set) var accentColor: Color = .orange

    // MARK: - Time bookkeeping
    // blockStartDate is the wall-clock anchor. remainingSeconds is always derived from it.
    // When the user pauses, pausedAt captures the moment; when they resume, blockStartDate
    // is shifted forward by the pause duration so the derivation stays correct.
    private(set) var blockStartDate: Date?
    private var pausedAt: Date?
    private var lastTickDate: Date?
    private weak var taskStore: TaskStore?

    // User-initiated pause vs everything else
    private var pausedByUser = false

    /// `true` when the user explicitly tapped Pause (not a system/background event).
    /// FocusView reads this to decide whether to auto-resume on foreground.
    var isPausedByUser: Bool { pausedByUser }

    /// Cumulative minutes added by the user via "Need more time?" during this session.
    private(set) var totalProlongedMinutes: Int = 0

    // MARK: - Break category tracking (for meditation rotation)
    private(set) var lastBreakCategory: BreakSuggestionEngine.BreakCategory? = nil
    private(set) var continuousFocusSeconds: Int = 0

    // MARK: - Timer + lifecycle observers
    private var timer: Timer?
    private var notificationObservers: [NSObjectProtocol] = []

    // MARK: - Init
    init(task: FocusTask, taskStore: TaskStore? = nil) {
        self.task = task
        self.taskStore = taskStore

        if let firstBlock = task.focusPlan.blocks.first {
            self.totalSeconds = firstBlock.duration
            self.remainingSeconds = firstBlock.duration
            self.blockType = firstBlock.type
        } else {
            self.totalSeconds = 1
            self.remainingSeconds = 1
            self.blockType = .focus
        }

        updateAccent()
        updateProgress()
        subscribeToAppLifecycle()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - App lifecycle — keep the timer running through background/lock
    private func subscribeToAppLifecycle() {
        // When the app comes back to the foreground after being backgrounded or the
        // device is unlocked, fire an immediate catch-up tick so remainingSeconds
        // snaps to the correct wall-clock value without waiting for the next 0.25 s pulse.
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            // Fire a catch-up tick on the main queue so we immediately reflect
            // any time that elapsed while backgrounded / locked.
            DispatchQueue.main.async { [weak self] in
                guard let self, self.sessionState == .running else { return }
                self.lastTickDate = Date()
                self.tick()
            }
        }
        notificationObservers.append(foregroundObserver)

        // When backgrounding: update lastTickDate so the next tick knows how long
        // we were away. The timer itself may be suspended by iOS but the wall-clock
        // reference is intact, so the first tick after returning catches up fully.
        // If the session is paused by the user, also advance pausedAt to "now" so
        // that background time is not absorbed into the pause window — the timer
        // stays frozen at the same remaining value when the user returns.
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            lastTickDate = Date()
            // Advance the pause anchor so background duration is NOT counted as pause time.
            // When resume() shifts blockStartDate by (now - pausedAt), this ensures the
            // shift only reflects actual in-app pause time, not background time.
            if sessionState == .paused, pausedByUser {
                pausedAt = Date()
            }
        }
        notificationObservers.append(backgroundObserver)
    }

    // MARK: - Control
    func start() {
        guard sessionState == .idle else { return }
        sessionState = .running
        blockStartDate = Date()
        lastTickDate = Date()
        startTimer()
        writeWidgetData()
    }

    /// User-initiated pause only. Background/lock screen never pauses the timer.
    func pause() {
        guard sessionState == .running else { return }
        pausedByUser = true
        sessionState = .paused
        pausedAt = Date()
        invalidateTimer()
        writePausedWidgetData()
    }

    /// Legacy name kept for callers. No longer used for system events.
    func systemPause() {
        // No-op: background/lock screen no longer pauses the timer.
        // Time is tracked via wall-clock (blockStartDate anchor + lastTickDate).
    }

    func resume() {
        guard sessionState == .paused, let pausedAt, let start = blockStartDate else { return }
        let now = Date()

        if pausedByUser {
            // Shift the anchor forward by the pause duration so elapsed time is unchanged.
            let pauseDuration = now.timeIntervalSince(pausedAt)
            blockStartDate = start.addingTimeInterval(pauseDuration)
            self.pausedAt = nil
            self.pausedByUser = false
        } else {
            // Defensive path (should not occur with new design).
            self.pausedAt = nil
            self.pausedByUser = false
        }

        sessionState = .running
        lastTickDate = now
        startTimer()
        writeWidgetData()   // rewrite with updated anchor so live countdown is accurate
    }

    func resumeIfPaused() {
        guard sessionState == .paused else { return }
        resume()
    }

    /// Adds `minutes` to the current focus block. Only valid while focus is running or paused.
    /// Records the extension so the session log can mark the outcome as `.prolonged`.
    func extendFocus(minutes: Int) {
        guard blockType == .focus, minutes > 0 else { return }
        let added = minutes * 60
        totalSeconds    += added
        remainingSeconds = min(totalSeconds, remainingSeconds + added)
        totalProlongedMinutes += minutes
        // Shift the wall-clock anchor forward so the derived tick stays correct.
        blockStartDate = blockStartDate.map { $0.addingTimeInterval(-TimeInterval(added)) }
        updateProgress()
        writeWidgetData()
    }

    func startBreakModeNow() {
        // Used by Lost Focus summary CTA. This does not change focus-mode exit logic.
        let wasFocus = (blockType == .focus) // CHANGED: capture before mutating blockType
        blockType = .breakTime

        // Use actual elapsed focus time if we were currently in focus.
        if wasFocus {
            let elapsed = max(1, totalSeconds - remainingSeconds)
            recordFocusDurationOnEnd(actualSeconds: elapsed)
        }

        let breakDuration = calculateBreakDurationSeconds()

        totalSeconds = breakDuration
        remainingSeconds = breakDuration

        blockStartDate = Date()
        lastTickDate = Date()

        updateAccent()
        updateProgress()

        sessionState = .running
        startTimer()
        writeWidgetData()
    }

    // NEW: Called when focus ends (natural or user-completed) to show focus summary before starting break.
    private func finishFocusAndAwaitBreak() {
        if blockType == .focus {
            SoundManager.focusComplete()

            let elapsed = max(1, totalSeconds - remainingSeconds)
            recordFocusDurationOnEnd(actualSeconds: elapsed)

            if let store = taskStore {
                let reason: FocusExitReason = totalProlongedMinutes > 0 ? .prolonged : .completed
                store.logSession(
                    taskId: task.id,
                    startDate: blockStartDate ?? Date(),
                    endDate: Date(),
                    exitReason: reason,
                    prolongedMinutes: totalProlongedMinutes > 0 ? totalProlongedMinutes : nil
                )
            }
        }

        FocusWidgetData.clear()
        invalidateTimer()
        sessionState = .finished
    }

    // NEW: Called by UI after focus summary is dismissed.
    func startBreakAfterSummary() {
        guard blockType == .focus else { return }

        blockType = .breakTime
        let breakSeconds = calculateBreakDurationSeconds()
        totalSeconds = breakSeconds
        remainingSeconds = breakSeconds

        blockStartDate = Date()
        lastTickDate = Date()

        updateAccent()
        updateProgress()

        sessionState = .running
        startTimer()
        writeWidgetData()
    }

    /// POZIVA SE ISKLJUČIVO NAKON ODLUKE USERA
    func confirmExit(_ exit: FocusSessionExit) {
        // ✅ Log non-completed outcomes for AI/trends (without changing flow).
        // Only log for focus blocks; breaks are logged when the break timer reaches zero.
        if blockType == .focus, let store = taskStore {
            let now = Date()

            func log(_ reason: FocusExitReason, custom: String? = nil) {
                store.logSession(
                    taskId: task.id,
                    startDate: blockStartDate ?? now,
                    endDate: now,
                    exitReason: reason,
                    customReason: custom
                )
            }

            switch exit {
            case .distracted:
                log(.distracted)

            case .earlyFinished:
                log(.interrupted)

            case .paused:
                log(.paused)

            case .continueNow:
                log(.interrupted)

            case .other(let text):
                log(.other, custom: text)

            case .completed, .prolonged:
                // Logged in finishFocusAndAwaitBreak() with correct .prolonged reason.
                break
            }
        }

        switch exit {

        case .paused:
            break

        case .continueNow:
            resume()

        case .distracted:
            finishSession()

        case .earlyFinished:
            handleEarlyFinish()

        case .completed, .prolonged:
            // User completed focus (with or without extensions): show focus summary first.
            finishFocusAndAwaitBreak()

        case .other:
            finishSession()
        }
    }

    // MARK: - Timer
    private func startTimer() {
        if timer != nil { return }

        timer = Timer.scheduledTimer(
            withTimeInterval: 0.25,
            repeats: true
        ) { [weak self] _ in
            self?.tick()
        }
    }

    private func invalidateTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Tick
    private func tick() {
        guard sessionState == .running else { return }
        guard let blockStartDate else { return }

        // Derive remaining time from wall-clock anchor — immune to timer suspension,
        // background, lock screen, or any gap between ticks.
        let elapsed = Int(Date().timeIntervalSince(blockStartDate))
        let computed = max(0, totalSeconds - elapsed)

        // Track continuous focus time using the real elapsed delta
        if blockType == .focus, let last = lastTickDate {
            let delta = Int(Date().timeIntervalSince(last))
            if delta > 0 { continuousFocusSeconds += delta }
        }
        lastTickDate = Date()

        remainingSeconds = computed
        updateProgress()

        if computed == 0 {
            if blockType == .focus {
                finishFocusAndAwaitBreak()
                return
            }

            if blockType == .breakTime {
                if let store = taskStore {
                    store.logSession(
                        taskId: task.id,
                        startDate: self.blockStartDate ?? Date(),
                        endDate: Date(),
                        exitReason: .breakEnded
                    )
                }
                continuousFocusSeconds = 0
                FocusWidgetData.clear()
                SoundManager.breakComplete()
                breakCompletedCallback?()
                invalidateTimer()
                sessionState = .finished
                return
            }

            finishSession()
        }
    }

    // MARK: - Early finish
    private func handleEarlyFinish() {
        // Early finish must show focus summary first, then break starts after summary.
        finishFocusAndAwaitBreak()
    }

    // MARK: - Finish (distracted / other non-completion exits)
    private func finishSession() {
        if let store = taskStore, blockType == .focus {
            store.logSession(
                taskId: task.id,
                startDate: blockStartDate ?? Date(),
                endDate: Date(),
                exitReason: .completed
            )
            // Do NOT call completeTask here — distracted/other exits are not completions.
        }

        FocusWidgetData.clear()
        invalidateTimer()
        sessionState = .finished
    }

    // MARK: - UI helpers
    private func updateProgress() {
        ringProgress = totalSeconds > 0
        ? Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
        : 0
    }

    private func updateAccent() {
        accentColor = blockType == .focus ? .orange : .brg
    }

    // MARK: - Focus Statistics
    static func focusedMinutesToday() -> Int {
        guard let store = TaskStoreLocator.shared.store else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let logs = store.sessionLogs.filter { log in
            (log.exitReason == .completed || log.exitReason == .prolonged)
            && calendar.isDate(log.startDate, inSameDayAs: today)
        }
        let totalSeconds = logs.reduce(0) { $0 + Int($1.duration) }
        return totalSeconds / 60
    }

    static func currentFocusStreak() -> Int {
        guard let store = TaskStoreLocator.shared.store else { return 0 }
        let calendar = Calendar.current
        let completedDays = Set(
            store.sessionLogs
                .filter { $0.exitReason == .completed || $0.exitReason == .prolonged }
                .map { calendar.startOfDay(for: $0.startDate) }
        )
        guard !completedDays.isEmpty else { return 0 }
        var streak = 0
        var currentDay = calendar.startOfDay(for: Date())
        var safety = 0
        while completedDays.contains(currentDay) {
            streak += 1
            safety += 1
            if safety > 3660 { break }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = prev
        }
        return streak
    }

    // MARK: - Break duration + learning
    private(set) var lastFocusDurationSeconds: Int? {
        get { _lastFocusDurationSeconds }
        set { _lastFocusDurationSeconds = newValue }
    }
    private var _lastFocusDurationSeconds: Int? = nil

    private var breakCompletedCallback: (() -> Void)?
    private let learnedFocusKeyPrefix = "learned_focus_duration_v1_"

    // MARK: - Dependency injection (called from onAppear after environment is ready)
    func setTaskStore(_ store: TaskStore) {
        taskStore = store
    }

    /// Call this right after BreakSuggestionEngine.decide() so the next break
    /// can avoid repeating the same category — both within this engine instance
    /// and across tasks (persisted via BreakCategoryMemory).
    func recordBreakCategory(_ category: BreakSuggestionEngine.BreakCategory) {
        lastBreakCategory = category
        BreakCategoryMemory.record(category)
    }

    func setBreakCompletedCallback(_ callback: @escaping () -> Void) {
        breakCompletedCallback = callback
    }

    private struct FocusDurationAggregate: Codable {
        var total: Int
        var count: Int

        var average: Int {
            guard count > 0 else { return 0 }
            return total / count
        }
    }

    private func isRecurringTask(_ task: FocusTask) -> Bool {
        task.recurrenceType != .once
    }

    private func learnedFocusDuration(for title: String, recurring: Bool) -> Int? {
        let suffix = recurring ? "recurring" : "single"
        let key = learnedFocusKeyPrefix + suffix + "_" + title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = UserDefaults.standard.data(forKey: key),
              let agg = try? JSONDecoder().decode(FocusDurationAggregate.self, from: data)
        else { return nil }
        return agg.average > 0 ? agg.average : nil
    }

    private func recordLearnedFocusDuration(_ seconds: Int, title: String, recurring: Bool) {
        let suffix = recurring ? "recurring" : "single"
        let key = learnedFocusKeyPrefix + suffix + "_" + title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        var agg = FocusDurationAggregate(total: 0, count: 0)
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(FocusDurationAggregate.self, from: data) {
            agg = decoded
        }

        agg.total += seconds
        agg.count += 1

        if let data = try? JSONEncoder().encode(agg) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func recordFocusDurationOnEnd(actualSeconds: Int) {
        let seconds = max(1, actualSeconds)
        _lastFocusDurationSeconds = seconds

        let recurring = isRecurringTask(task)
        recordLearnedFocusDuration(seconds, title: task.title, recurring: recurring)
    }

    private func calculateBreakDurationSeconds() -> Int {
        let recurring = isRecurringTask(task)

        let plannedFocusSeconds = task.focusPlan.blocks
            .filter { $0.type == .focus }
            .reduce(0) { $0 + $1.duration }

        let focusSeconds = _lastFocusDurationSeconds
        ?? learnedFocusDuration(for: task.title, recurring: recurring)
        ?? plannedFocusSeconds

        guard focusSeconds > 0 else {
            return 1
        }

        let baseBreak = max(1, Int((Double(focusSeconds) * (33.0 / 77.0)).rounded()))

        // Apply user feedback learning (Too short +10%, Just right 0%, Too long -10%).
        if let category = TaskCategoryStore.shared.category(for: task.id) {
            let adjusted = BreakDurationLearningStore.shared.adjustedDuration(
                for: category,
                baseDuration: baseBreak,
                fallbackTaskTitle: task.title
            )
            return max(1, adjusted)
        }

        let adjusted = BreakDurationLearningStore.shared.adjustedDuration(for: task.title, baseDuration: baseBreak)
        return max(1, adjusted)
    }

    private let liveActivitySessionId = UUID()
    var liveActivitySessionIdPublic: UUID { liveActivitySessionId }

    // MARK: - Widget data

    private func writeWidgetData() {
        guard let blockStart = blockStartDate else { return }
        let endDate = blockStart.addingTimeInterval(TimeInterval(totalSeconds))
        var widgetData = FocusWidgetData(
            blockKind: blockType == .focus ? .focus : .breakTime,
            taskTitle: task.title,
            endDate: endDate,
            startDate: blockStart
        )
        widgetData.isPaused = false
        widgetData.pausedRemainingSeconds = 0
        FocusWidgetData.write(widgetData)
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    /// Writes a paused snapshot so the widget shows a frozen static countdown.
    private func writePausedWidgetData() {
        guard let blockStart = blockStartDate else { return }
        let endDate = blockStart.addingTimeInterval(TimeInterval(totalSeconds))
        var widgetData = FocusWidgetData(
            blockKind: blockType == .focus ? .focus : .breakTime,
            taskTitle: task.title,
            endDate: endDate,
            startDate: blockStart
        )
        widgetData.isPaused = true
        widgetData.pausedRemainingSeconds = remainingSeconds
        FocusWidgetData.write(widgetData)
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    private func clearWidgetData() {
        FocusWidgetData.clear()
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

}
