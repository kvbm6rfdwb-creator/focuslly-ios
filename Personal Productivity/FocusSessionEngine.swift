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
    var isPausedByUser: Bool { pausedByUser }

    /// Cumulative minutes added by the user via "Need more time?" during this session.
    private(set) var totalProlongedMinutes: Int = 0

    // MARK: - Break category tracking
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
            self.totalSeconds    = firstBlock.duration
            self.remainingSeconds = firstBlock.duration
            self.blockType       = firstBlock.type
        } else {
            self.totalSeconds    = 1
            self.remainingSeconds = 1
            self.blockType       = .focus
        }

        updateAccent()
        updateProgress()
        subscribeToAppLifecycle()
    }

    deinit {
        notificationObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - App lifecycle
    private func subscribeToAppLifecycle() {
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.sessionState == .running else { return }
            self.lastTickDate = Date()
            self.tick()
        }
        notificationObservers.append(foregroundObserver)

        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            lastTickDate = Date()
            if sessionState == .paused, pausedByUser {
                pausedAt = Date()
            }
        }
        notificationObservers.append(backgroundObserver)
    }

    // MARK: - Control
    func start() {
        guard sessionState == .idle else { return }
        sessionState  = .running
        blockStartDate = Date()
        lastTickDate   = Date()
        startTimer()
        writeWidgetData()
    }

    func pause() {
        guard sessionState == .running else { return }
        pausedByUser  = true
        sessionState  = .paused
        pausedAt      = Date()
        invalidateTimer()
        writePausedWidgetData()
    }

    /// No-op: background/lock screen no longer pauses the timer.
    func systemPause() {}

    func resume() {
        guard sessionState == .paused, let pausedAt, let start = blockStartDate else { return }
        let now = Date()
        if pausedByUser {
            let pauseDuration = now.timeIntervalSince(pausedAt)
            blockStartDate = start.addingTimeInterval(pauseDuration)
            self.pausedAt    = nil
            self.pausedByUser = false
        } else {
            self.pausedAt    = nil
            self.pausedByUser = false
        }
        sessionState  = .running
        lastTickDate  = now
        startTimer()
        writeWidgetData()
    }

    func resumeIfPaused() {
        guard sessionState == .paused else { return }
        resume()
    }

    func extendFocus(minutes: Int) {
        guard blockType == .focus, minutes > 0 else { return }
        let added = minutes * 60
        totalSeconds     += added
        remainingSeconds  = min(totalSeconds, remainingSeconds + added)
        totalProlongedMinutes += minutes
        blockStartDate = blockStartDate.map { $0.addingTimeInterval(-TimeInterval(added)) }
        updateProgress()
        writeWidgetData()
    }

    func startBreakModeNow() {
        let wasFocus = (blockType == .focus)
        blockType = .breakTime
        if wasFocus {
            let elapsed = max(1, totalSeconds - remainingSeconds)
            recordFocusDurationOnEnd(actualSeconds: elapsed)
        }
        continuousFocusSeconds = 0
        let breakDuration = calculateBreakDurationSeconds()
        totalSeconds     = breakDuration
        remainingSeconds = breakDuration
        blockStartDate   = Date()
        lastTickDate     = Date()
        updateAccent()
        updateProgress()
        sessionState = .running
        startTimer()
        writeWidgetData()
    }

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

    func startBreakAfterSummary() {
        guard blockType == .focus else { return }
        blockType = .breakTime
        continuousFocusSeconds = 0
        let breakSeconds = calculateBreakDurationSeconds()
        totalSeconds     = breakSeconds
        remainingSeconds = breakSeconds
        blockStartDate   = Date()
        lastTickDate     = Date()
        updateAccent()
        updateProgress()
        sessionState = .running
        startTimer()
        writeWidgetData()
    }

    func confirmExit(_ exit: FocusSessionExit) {
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
            case .distracted:                log(.distracted)
            case .earlyFinished:             log(.interrupted)
            case .paused:                    log(.paused)
            case .continueNow:               log(.interrupted)
            case .other(let text):           log(.other, custom: text)
            case .completed, .prolonged:     break   // logged in finishFocusAndAwaitBreak()
            }
        }

        switch exit {
        case .paused:                      break
        case .continueNow:                 resume()
        case .distracted:                  finishSession()
        case .earlyFinished:               handleEarlyFinish()
        case .completed, .prolonged:       finishFocusAndAwaitBreak()
        case .other:                       finishSession()
        }
    }

    // MARK: - Timer
    private func startTimer() {
        if timer != nil { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
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

        let elapsed  = Int(Date().timeIntervalSince(blockStartDate))
        let computed = max(0, totalSeconds - elapsed)

        if blockType == .focus, let last = lastTickDate {
            let delta = Int(Date().timeIntervalSince(last))
            if delta > 0 { continuousFocusSeconds += delta }
        }
        lastTickDate     = Date()
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
        finishFocusAndAwaitBreak()
    }

    // MARK: - Finish (distracted / other non-completion exits)
    /// Tears down the timer. Logging is handled by confirmExit() before this is called.
    private func finishSession() {
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

    // MARK: - Break duration + learning
    private(set) var lastFocusDurationSeconds: Int? {
        get { _lastFocusDurationSeconds }
        set { _lastFocusDurationSeconds = newValue }
    }
    private var _lastFocusDurationSeconds: Int? = nil

    private var breakCompletedCallback: (() -> Void)?
    private let learnedFocusKeyPrefix = "learned_focus_duration_v1_"

    func setTaskStore(_ store: TaskStore) { taskStore = store }

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
        var average: Int { count > 0 ? total / count : 0 }
    }

    private func isRecurringTask(_ task: FocusTask) -> Bool { task.recurrenceType != .once }

    private func learnedFocusDuration(for title: String, recurring: Bool) -> Int? {
        let suffix = recurring ? "recurring" : "single"
        let key = learnedFocusKeyPrefix + suffix + "_" + title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = UserDefaults.standard.data(forKey: key),
              let agg  = try? JSONDecoder().decode(FocusDurationAggregate.self, from: data)
        else { return nil }
        return agg.average > 0 ? agg.average : nil
    }

    private func recordLearnedFocusDuration(_ seconds: Int, title: String, recurring: Bool) {
        let suffix = recurring ? "recurring" : "single"
        let key = learnedFocusKeyPrefix + suffix + "_" + title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        var agg = FocusDurationAggregate(total: 0, count: 0)
        if let data    = UserDefaults.standard.data(forKey: key),
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
        recordLearnedFocusDuration(seconds, title: task.title, recurring: isRecurringTask(task))
    }

    private func calculateBreakDurationSeconds() -> Int {
        let recurring = isRecurringTask(task)
        let plannedFocusSeconds = task.focusPlan.blocks
            .filter { $0.type == .focus }
            .reduce(0) { $0 + $1.duration }
        let focusSeconds = _lastFocusDurationSeconds
            ?? learnedFocusDuration(for: task.title, recurring: recurring)
            ?? plannedFocusSeconds
        guard focusSeconds > 0 else { return 1 }
        let baseBreak = max(1, Int((Double(focusSeconds) * (33.0 / 77.0)).rounded()))
        if let category = TaskCategoryStore.shared.category(for: task.id) {
            return max(1, BreakDurationLearningStore.shared.adjustedDuration(
                for: category, baseDuration: baseBreak, fallbackTaskTitle: task.title))
        }
        return max(1, BreakDurationLearningStore.shared.adjustedDuration(
            for: task.title, baseDuration: baseBreak))
    }

    private let liveActivitySessionId = UUID()
    var liveActivitySessionIdPublic: UUID { liveActivitySessionId }

    // MARK: - Widget data
    private func writeWidgetData() {
        guard let blockStart = blockStartDate else { return }
        let endDate = blockStart.addingTimeInterval(TimeInterval(totalSeconds))
        var data = FocusWidgetData(
            blockKind: blockType == .focus ? .focus : .breakTime,
            taskTitle: task.title,
            endDate: endDate,
            startDate: blockStart
        )
        data.isPaused = false
        data.pausedRemainingSeconds = 0
        FocusWidgetData.write(data)
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }

    private func writePausedWidgetData() {
        guard let blockStart = blockStartDate else { return }
        let endDate = blockStart.addingTimeInterval(TimeInterval(totalSeconds))
        var data = FocusWidgetData(
            blockKind: blockType == .focus ? .focus : .breakTime,
            taskTitle: task.title,
            endDate: endDate,
            startDate: blockStart
        )
        data.isPaused = true
        data.pausedRemainingSeconds = remainingSeconds
        FocusWidgetData.write(data)
        WidgetCenter.shared.reloadTimelines(ofKind: "FocusWidget")
    }
}
