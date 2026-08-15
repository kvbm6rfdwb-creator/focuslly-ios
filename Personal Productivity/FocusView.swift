import SwiftUI

struct FocusView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var coordinator: FocusSessionCoordinator
    @EnvironmentObject var taskStore: TaskStore

    @ObservedObject var engine: FocusSessionEngine
    @State private var showExitSheet = false
    @State private var showSummary = false
    @State private var lastExitReason: FocusSessionExit?
    @State private var isChainingNextTask = false

    @State private var showBreakStopSheet = false
    @State private var breakStopMessage: String?

    @State private var breakInsightDecision: BreakInsightDecisionEngine.Decision? = nil
    @State private var breakInsightUserChoseRecommendation: Bool? = nil

    @State private var lostFocusDecision: LostFocusDecisionEngine.Decision? = nil

    @State private var showBreakFeedbackSheet = false
    @State private var pendingBreakFeedback = false
    @State private var showExtendSheet = false

    // Break suggestion state
    @State private var breakSuggestionDecision: BreakSuggestionEngine.Decision? = nil
    @State private var hasShownBreakSuggestion = false

    let onExit: (FocusSessionExit) -> Void

    init(engine: FocusSessionEngine, onExit: @escaping (FocusSessionExit) -> Void) {
        self._engine = ObservedObject(wrappedValue: engine)
        self.onExit = onExit
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if engine.blockType == .breakTime {
                breakModeLayout
            } else {
                focusModeLayout
            }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
            engine.setBreakCompletedCallback {
                DispatchQueue.main.async { pendingBreakFeedback = true }
            }
            if engine.sessionState == .idle { engine.start() }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                coordinator.appDidBackground()
                engine.systemPause()
            case .active:
                coordinator.appDidForeground()
                // Only auto-resume if the pause was caused by a system event
                // (e.g. lock screen). If the user tapped Pause themselves, respect
                // that decision and leave the timer paused when they return.
                if engine.sessionState == .paused && !engine.isPausedByUser {
                    engine.resumeIfPaused()
                }
            default: break
            }
        }
        .sheet(isPresented: $showExitSheet) {
            ExitFocusReasonSheet { decision in
                lastExitReason = decision
                if decision == .distracted {
                    lostFocusDecision = LostFocusDecisionEngine.decide(task: engine.task)
                } else {
                    lostFocusDecision = nil
                }
                engine.confirmExit(decision)
                switch decision {
                case .continueNow, .paused:
                    showExitSheet = false
                    coordinator.userContinuesFocus()
                case .distracted, .completed, .prolonged, .other:
                    showExitSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { showSummary = true }
                case .earlyFinished:
                    showExitSheet = false
                }
            }
            .interactiveDismissDisabled(true)
            .onDisappear { coordinator.shouldShowExitPrompt = false }
        }
        .sheet(isPresented: $showBreakStopSheet) {
            BreakStopReasonSheet(
                message: $breakStopMessage,
                onHadToTalkToClient: {
                    engine.resume()
                    breakStopMessage = nil
                    showBreakStopSheet = false
                },
                onStillHaveFocus: {
                    let analysis = BreakStopAI.analyze(task: engine.task, engine: engine)
                    breakStopMessage = analysis.message
                    breakInsightDecision = BreakInsightDecisionEngine.decide(currentTask: engine.task)
                    breakInsightUserChoseRecommendation = nil
                    lastExitReason = .paused
                    showBreakStopSheet = false
                    showSummary = true
                }
            )
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showSummary) { summarySheet }
        .onChange(of: engine.sessionState) { _, state in
            guard state == .finished else { return }
            if isChainingNextTask { isChainingNextTask = false; return }
            if engine.blockType == .breakTime && lastExitReason != .paused { return }
            if engine.blockType != .breakTime && lastExitReason != .paused {
                breakInsightDecision = BreakInsightDecisionEngine.decide(currentTask: engine.task)
                breakInsightUserChoseRecommendation = nil
            }
            // Auto-determine outcome: prolonged if extensions were used, otherwise completed
            lastExitReason = engine.totalProlongedMinutes > 0 ? .prolonged : .completed
            showSummary = true
        }
        .sheet(isPresented: $showBreakFeedbackSheet) {
            BreakFeedbackSheet(
                title: breakFeedbackPromptTitle(engine: engine),
                onSelect: { feedback in
                    BreakDurationLearningStore.shared.record(feedback, taskTitle: engine.task.title)
                    showBreakFeedbackSheet = false
                    finishSessionAfterFeedback(nextTask: nil)
                }
            )
            .presentationDetents([.height(190)])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled(true)
        }
        .sheet(isPresented: $showExtendSheet) {
            ExtendFocusSheet { minutes in
                engine.extendFocus(minutes: minutes)
                showExtendSheet = false
            }
            .presentationDetents([.height(260)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: pendingBreakFeedback) { _, pending in
            guard pending else { return }
            pendingBreakFeedback = false
            showSummary = false; showExitSheet = false; showBreakStopSheet = false
            showBreakFeedbackSheet = true
        }
        .onChange(of: engine.blockType) { _, newBlockType in
            if newBlockType == .breakTime && !hasShownBreakSuggestion && engine.sessionState == .running {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    // Use persisted memory first (covers cross-task deduplication),
                    // fall back to the in-engine value for within-session chaining.
                    let previousCategory = BreakCategoryMemory.lastCategoryToday
                                        ?? engine.lastBreakCategory
                    breakSuggestionDecision = BreakSuggestionEngine.decide(
                        completedTask: engine.task,
                        engine: engine,
                        breakDuration: engine.totalSeconds,
                        taskStore: taskStore,
                        previousBreakCategory: previousCategory,
                        continuousWorkMinutes: engine.continuousFocusSeconds / 60
                    )
                    if let decision = breakSuggestionDecision {
                        engine.recordBreakCategory(decision.category)
                    }
                    hasShownBreakSuggestion = true
                }
            }
        }
        .onChange(of: engine.task.id) { _, _ in
            showExitSheet = false; showSummary = false; lastExitReason = nil
            showBreakStopSheet = false; breakStopMessage = nil
            breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil
            lostFocusDecision = nil; showBreakFeedbackSheet = false
            pendingBreakFeedback = false
            showExtendSheet = false
            breakSuggestionDecision = nil
            hasShownBreakSuggestion = false
        }
    }

    // MARK: - Focus mode layout

    private var focusModeLayout: some View {
        VStack(spacing: 32) {
            header(engine: engine)
            Spacer()
            timerRing(engine: engine)
            if let next = nextPendingTask { nextTaskStrip(next) }
            Spacer()
            controls(engine: engine)
            Spacer()
        }
        .padding()
    }

    // MARK: - Break mode layout
    // Fixed header: tick ring + timer + pause/stop buttons
    // Scrollable body: break suggestion card
    private var breakModeLayout: some View {
        VStack(spacing: 0) {
            // ── Ring + controls ───────────────────────────────────
            HStack(spacing: 18) {
                ZStack {
                    AdaptiveTickRingView(
                        totalSeconds: engine.totalSeconds,
                        elapsedSeconds: engine.totalSeconds - engine.remainingSeconds,
                        accentColor: engine.accentColor,
                        baseTickLength: 3.5,
                        maxTickGrowth: 7,
                        baseTickWidth: 1.2,
                        maxTickWidth: 2.2
                    )
                    VStack(spacing: 2) {
                        Text("BREAK")
                            .font(.system(size: 9, weight: .heavy))
                            .tracking(1.4)
                            .foregroundStyle(.white.opacity(0.4))
                        Text(timeString(engine: engine))
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 140, height: 140)

                VStack(alignment: .leading, spacing: 10) {
                    Text(engine.task.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(2)

                    HStack(spacing: 10) {
                        Button {
                            engine.sessionState == .running ? engine.pause() : engine.resume()
                        } label: {
                            Label(
                                engine.sessionState == .running ? "Pause" : "Resume",
                                systemImage: engine.sessionState == .running ? "pause.fill" : "play.fill"
                            )
                            .font(.system(size: 13, weight: .semibold))
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(engine.accentColor)
                        .animation(nil, value: engine.sessionState)

                        Button {
                            engine.pause()
                            breakStopMessage = nil
                            showBreakStopSheet = true
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Hairline separator — same surface, just a hint of division
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)
                .padding(.horizontal, 20)

            // ── Suggestion scrolls below ──────────────────────
            ScrollView(.vertical, showsIndicators: false) {
                if let decision = breakSuggestionDecision {
                    BreakSuggestionCard(decision: decision, accentColor: engine.accentColor)
                        .padding(.top, 16)
                        .padding(.bottom, 100)
                }
            }
        }
        .background(Color.black.ignoresSafeArea())
    }

    // MARK: - Shared sub-views

    private func nextTaskStrip(_ task: FocusTask) -> some View {
        let mins = task.focusPlan.blocks
            .filter { $0.type == .focus }
            .reduce(0) { $0 + $1.duration } / 60
        return HStack(spacing: 10) {
            Image(systemName: "arrow.right.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.brg)
            Text("Up next")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text(task.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
            Spacer()
            Text("\(mins)m")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.07))
        .clipShape(Capsule())
        .padding(.horizontal, 24)
    }

    // MARK: - Reusable primitives

    private func header(engine: FocusSessionEngine) -> some View {
        VStack(spacing: 8) {
            Text(engine.blockType == .focus ? "FOCUS MODE" : "BREAK MODE")
                .font(.system(size: 15, weight: .medium))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.8))
            Text(engine.task.title)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    private func timerRing(engine: FocusSessionEngine) -> some View {
        ZStack {
            AdaptiveTickRingView(
                totalSeconds: engine.totalSeconds,
                elapsedSeconds: engine.totalSeconds - engine.remainingSeconds,
                accentColor: engine.accentColor
            )
            Text(timeString(engine: engine))
                .font(.system(size: 64, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .frame(width: 300, height: 300)
    }

    private func controls(engine: FocusSessionEngine) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                Button {
                    engine.sessionState == .running ? engine.pause() : engine.resume()
                } label: {
                    Label(
                        engine.sessionState == .running ? "Pause" : "Resume",
                        systemImage: engine.sessionState == .running ? "pause.fill" : "play.fill"
                    )
                    .frame(minWidth: 140)
                }
                .buttonStyle(.borderedProminent)
                .tint(engine.accentColor)
                .animation(nil, value: engine.sessionState)

                Button {
                    engine.pause()
                    if engine.blockType == .breakTime {
                        breakStopMessage = nil
                        showBreakStopSheet = true
                    } else {
                        showExitSheet = true
                    }
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(minWidth: 120)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }

            // "Need more time?" — only shown during a focus block
            if engine.blockType == .focus {
                Button {
                    showExtendSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Need more time?")
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.45))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func timeString(engine: FocusSessionEngine) -> String {
        String(format: "%02d:%02d", engine.remainingSeconds / 60, engine.remainingSeconds % 60)
    }

    // MARK: - Summary sheet

    private var summarySheet: some View {
        Group {
            if let reason = lastExitReason, reason == .distracted {
                FocusSessionSummary(
                    task: engine.task, exitReason: .distracted,
                    duration: TimeInterval(engine.totalSeconds - engine.remainingSeconds),
                    onDismiss: {},
                    aiInsightOverride: lostFocusDecision?.message, aiInsightDecision: nil,
                    primaryActionTitle: "Finish",
                    onPrimaryAction: {
                        showSummary = false; lostFocusDecision = nil
                        DispatchQueue.main.async { onExit(.distracted); dismiss() }
                    },
                    secondaryActionTitle: "Start Break Mode",
                    onSecondaryAction: {
                        showSummary = false; engine.startBreakModeNow(); lostFocusDecision = nil
                    },
                    recommendedPrimary: lostFocusDecision?.recommendation == .finish,
                    recommendedSecondary: lostFocusDecision?.recommendation == .startBreak
                )
                .environmentObject(taskStore)

            } else if lastExitReason == .paused && engine.blockType == .breakTime {
                // Early break stop: user chose to stop break before it finished.
                // Log break insight choice if a decision was active.
                FocusSessionSummary(
                    task: engine.task, exitReason: .paused,
                    duration: TimeInterval(engine.totalSeconds - engine.remainingSeconds),
                    onDismiss: { showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil },
                    aiInsightOverride: breakInsightDecision?.message, aiInsightDecision: breakInsightDecision,
                    primaryActionTitle: "Continue Break",
                    onPrimaryAction: {
                        if let decision = breakInsightDecision {
                            let followed = decision.recommendation == .continueBreak
                            logBreakInsightChoice(decision: decision, followedRecommendation: followed)
                        }
                        logBreakAction("continue_break")
                        showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil
                        hasShownBreakSuggestion = false; lastExitReason = nil
                        DispatchQueue.main.async { engine.resume() }
                    },
                    secondaryActionTitle: "Next Task",
                    onSecondaryAction: {
                        if let decision = breakInsightDecision {
                            let followed = decision.recommendation == .nextTask
                            logBreakInsightChoice(decision: decision, followedRecommendation: followed)
                        }
                        logBreakAction("next_task_from_early_break")
                        breakNextOrFinishFromEarlyBreak()
                    },
                    tertiaryActionTitle: "Finish",
                    onTertiaryAction: {
                        logBreakAction("finish_from_early_break")
                        showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil
                        hasShownBreakSuggestion = false; lastExitReason = nil
                        taskStore.completeTask(engine.task); taskStore.endFocus()
                        DispatchQueue.main.async { onExit(.completed); dismiss() }
                    },
                    recommendedPrimary: false, recommendedSecondary: false
                )
                .environmentObject(taskStore)

            } else if engine.blockType == .breakTime && engine.sessionState == .finished {
                // Break completed naturally: log insight choice for Finish / Next Task.
                FocusSessionSummary(
                    task: engine.task, exitReason: .completed,
                    duration: TimeInterval(engine.totalSeconds - engine.remainingSeconds),
                    onDismiss: { showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil },
                    aiInsightOverride: breakInsightDecision?.message, aiInsightDecision: breakInsightDecision,
                    primaryActionTitle: "Finish",
                    onPrimaryAction: {
                        if let decision = breakInsightDecision {
                            let followed = decision.recommendation == .finish
                            logBreakInsightChoice(decision: decision, followedRecommendation: followed)
                        }
                        logBreakAction("finish")
                        showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil
                        hasShownBreakSuggestion = false; lastExitReason = nil
                        taskStore.completeTask(engine.task); taskStore.endFocus()
                        DispatchQueue.main.async { onExit(.completed); dismiss() }
                    },
                    secondaryActionTitle: nextPendingTask != nil ? "Next Task" : nil,
                    onSecondaryAction: nextPendingTask != nil ? {
                        if let decision = breakInsightDecision {
                            let followed = decision.recommendation == .nextTask
                            logBreakInsightChoice(decision: decision, followedRecommendation: followed)
                        }
                        logBreakAction("next_task_from_finished_break")
                        breakNextOrFinishFromFinishedBreak()
                    } : nil,
                    recommendedPrimary: false, recommendedSecondary: false
                )
                .environmentObject(taskStore)

            } else {
                FocusSessionSummary(
                    task: engine.task, exitReason: lastExitReason ?? .completed,
                    duration: TimeInterval(engine.totalSeconds - engine.remainingSeconds),
                    onDismiss: { showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil },
                    aiInsightOverride: breakInsightDecision?.message, aiInsightDecision: breakInsightDecision,
                    primaryActionTitle: "Start Break",
                    onPrimaryAction: {
                        showSummary = false
                        breakInsightDecision = nil
                        breakInsightUserChoseRecommendation = nil
                        engine.startBreakAfterSummary()
                    },
                    secondaryActionTitle: nil, onSecondaryAction: nil,
                    recommendedPrimary: false, recommendedSecondary: false
                )
                .environmentObject(taskStore)
            }
        }
    }

    // MARK: - Helpers

    private var nextPendingTask: FocusTask? {
        let now = Date()
        let excludedID = taskStore.activeFocusTask?.id ?? engine.task.id
        return taskStore.tasks
            .filter { $0.status == .pending && $0.id != excludedID }
            .sorted {
                let l = $0.scheduledTime ?? $0.startDate
                let r = $1.scheduledTime ?? $1.startDate
                let lF = l >= now; let rF = r >= now
                if lF != rF { return lF }
                return l < r
            }
            .first
    }

    private func breakFeedbackPromptTitle(engine: FocusSessionEngine) -> String {
        engine.blockType == .focus ? "Did you have enough time?" : "How was that break?"
    }

    private func logBreakAction(_ action: String) {
        let key = "break_flow_action_logs_v1"
        var existing = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        existing.append(["timestamp": Date().timeIntervalSince1970, "action": action, "taskId": engine.task.id.uuidString])
        UserDefaults.standard.set(existing, forKey: key)
    }

    private func logBreakInsightChoice(decision: BreakInsightDecisionEngine.Decision, followedRecommendation: Bool) {
        let key = "break_insight_choice_logs_v1"
        var existing = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        existing.append(["timestamp": Date().timeIntervalSince1970, "recommendation": decision.recommendation.rawValue, "confidence": decision.confidence, "followed": followedRecommendation])
        UserDefaults.standard.set(existing, forKey: key)
    }

    private func breakNextOrFinishFromEarlyBreak() {
        guard let next = nextPendingTask else { return }
        isChainingNextTask = true
        showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil
        hasShownBreakSuggestion = false; lastExitReason = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            taskStore.switchFocus(from: engine.task, to: next)
            coordinator.startFocus(task: next)
        }
    }

    private func breakNextOrFinishFromFinishedBreak() {
        if let next = nextPendingTask {
            isChainingNextTask = true
            showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil
            hasShownBreakSuggestion = false; lastExitReason = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                taskStore.switchFocus(from: engine.task, to: next)
                coordinator.startFocus(task: next)
            }
        } else {
            showSummary = false; breakInsightDecision = nil; breakInsightUserChoseRecommendation = nil
            hasShownBreakSuggestion = false; lastExitReason = nil
            taskStore.completeTask(engine.task); taskStore.endFocus()
            DispatchQueue.main.async { onExit(.completed); dismiss() }
        }
    }

    private func finishSessionAfterFeedback(nextTask: FocusTask?) {
        if let next = nextTask {
            isChainingNextTask = true
            showSummary = false; breakInsightDecision = nil
            hasShownBreakSuggestion = false; lastExitReason = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                taskStore.switchFocus(from: engine.task, to: next)
                coordinator.startFocus(task: next)
            }
        } else {
            taskStore.completeTask(engine.task); taskStore.endFocus()
            DispatchQueue.main.async { onExit(.completed); dismiss() }
        }
    }

    // MARK: - Nested types

    private struct BreakStopReasonSheet: View {
        @Binding var message: String?
        let onHadToTalkToClient: () -> Void
        let onStillHaveFocus: () -> Void

        var body: some View {
            VStack(spacing: 16) {
                Capsule().fill(Color.secondary.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 8)
                Text("Why did you stop break mode?").font(.title3.weight(.semibold))
                VStack(spacing: 12) {
                    Button(action: onHadToTalkToClient) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.2.fill").font(.system(size: 20)).foregroundStyle(Color.brgBright).frame(width: 28)
                            Text("I had to talk to a client").font(.body.weight(.medium)).foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                    Button(action: onStillHaveFocus) {
                        HStack(spacing: 16) {
                            Image(systemName: "bolt.fill").font(.system(size: 20)).foregroundStyle(Color.brgBright).frame(width: 28)
                            Text("I still have focus for the next task").font(.body.weight(.medium)).foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial))
                    }
                    .buttonStyle(.plain)
                }
                if let message { Text(message).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4) }
                Spacer(minLength: 12)
            }
            .padding()
            .background(.ultraThinMaterial)
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
        }
    }

    private enum BreakStopAI {
        struct Result { let approvedStop: Bool; let message: String }
        static func analyze(task: FocusTask, engine: FocusSessionEngine) -> Result {
            let totalFocusSec = task.focusPlan.blocks.filter { $0.type == .focus }.reduce(0) { $0 + $1.duration }
            let totalBreakSec = task.focusPlan.blocks.filter { $0.type == .breakTime }.reduce(0) { $0 + $1.duration }
            let hard = totalFocusSec >= 60 * 60
            if hard && totalBreakSec < 15 * 60 {
                return .init(approvedStop: false, message: "AI suggests continuing the break a bit longer to protect focus endurance.")
            }
            return .init(approvedStop: true, message: "AI approves stopping the break. You still have focus — moving to the next task.")
        }
    }
}

// MARK: - Break feedback sheet

private struct BreakFeedbackSheet: View {
    let title: String
    let onSelect: (BreakDurationLearningStore.Feedback) -> Void

    private let options: [(label: String, icon: String, color: Color, feedback: BreakDurationLearningStore.Feedback)] = [
        ("Too short", "clock.badge.exclamationmark.fill", .blue,   .tooShort),
        ("Just right", "checkmark.circle.fill",           .green,  .justRight),
        ("Too long",   "tortoise.fill",                   .orange, .tooLong)
    ]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            .padding(.top, 20)
            HStack(spacing: 10) {
                ForEach(options, id: \.label) { opt in
                    Button { onSelect(opt.feedback) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: opt.icon).font(.system(size: 22)).foregroundStyle(opt.color)
                            Text(opt.label).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(opt.color.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }
}

// MARK: - Extend Focus Sheet

private struct ExtendFocusSheet: View {
    let onExtend: (Int) -> Void

    private let options: [(minutes: Int, label: String, icon: String)] = [
        (5,  "+5 min",  "plus.circle"),
        (10, "+10 min", "plus.circle.fill"),
        (15, "+15 min", "arrow.up.circle.fill"),
        (20, "+20 min", "clock.arrow.2.circlepath"),
        (30, "+30 min", "timer"),
    ]

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 40, height: 5)
                .padding(.top, 10)

            VStack(spacing: 4) {
                Text("Need more time?")
                    .font(.system(size: 17, weight: .semibold))
                Text("Add extra focus time to finish the task")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                ForEach(options, id: \.minutes) { opt in
                    Button { onExtend(opt.minutes) } label: {
                        VStack(spacing: 6) {
                            Image(systemName: opt.icon)
                                .font(.system(size: 20))
                                .foregroundStyle(.orange)
                            Text(opt.label)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }
}
