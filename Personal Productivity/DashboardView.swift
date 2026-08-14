import SwiftUI

struct DashboardView: View {

    // MARK: - Dependencies
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var coordinator: FocusSessionCoordinator
    @EnvironmentObject var settings: AppSettingsStore
    @StateObject private var viewModel: DashboardViewModel
    @StateObject private var pipeline = PipelineStore.shared
    @Binding var focusTabSelector: MainTabView.Tab

    @State private var appeared = false
    @State private var showAddTask = false
    @State private var testSheet = false
    @State private var editingTask: FocusTask? = nil
    @State private var taskToDelete: FocusTask? = nil
    @State private var taskToMarkDone: FocusTask? = nil
    @State private var showSettings = false
    @State private var showMealLog = false
    @State private var showInsights = false
    @State private var preparingTask: FocusTask? = nil
    @State private var upNextAnimatedIn = false
    @State private var upNextShimmerPhase = false
    @State private var pressedTaskID: UUID? = nil
    @State private var shouldRunFirstLaunchShimmer = false
    @State private var shimmerActive = false

    // Motivation message is driven by the engine's @Published property
    @ObservedObject private var motivationEngine = MotivationMessageEngine.shared

    // MARK: - Init
    init(
        taskStore: TaskStore,
        focusTabSelector: Binding<MainTabView.Tab>
    ) {
        self._focusTabSelector = focusTabSelector
        _viewModel = StateObject(
            wrappedValue: DashboardViewModel(taskStore: taskStore)
        )
    }
    // MARK: - Derived
    private var activeTasks: [FocusTask] {
        // getTodaysTasks() already filters status == .pending only,
        // so completed tasks are automatically excluded.
        taskStore.getTodaysTasks()
            .sorted { task1, task2 in
                if task1.isActive && task1.pausedAt != nil { return true }
                if task2.isActive && task2.pausedAt != nil { return false }
                let time1 = task1.scheduledTime ?? task1.startDate
                let time2 = task2.scheduledTime ?? task2.startDate
                return time1 < time2
            }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        headerSection

                        morningContextCard

                        if let activeTask = taskStore.activeFocusTask {
                            nowFocusingSection(task: activeTask)
                        }

                        nudgeCard
                        primaryActionSection
                        dailyGlanceSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                .frame(maxWidth: .infinity)

                // MARK: - UNDO BAR
                if taskStore.showUndo {
                    HStack {
                        Text("Task skipped")
                            .font(.subheadline)
                        Spacer()
                        Button("Undo") {
                            HapticManager.impact()
                            taskStore.undoSkip()
                        }
                        .font(.subheadline.bold())
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                            .environmentObject(taskStore)
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.headline)
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(greetingText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddTask = true } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
                }
            }
            .sheet(isPresented: $showInsights) {
                InsightsView(settings: settings)
                    .environmentObject(taskStore)
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskView(onSave: { newTask in
                    taskStore.addTask(newTask)
                })
                .environmentObject(taskStore)
            }
            // MARK: - EDIT SHEET
            .sheet(item: $editingTask) { task in
                EditTaskView(task: task)
                    .environmentObject(taskStore)
            }
            // MARK: - PREPARATION SHEET
            .sheet(item: $preparingTask, onDismiss: {
                // If the user dismissed the sheet without starting, return to dashboard
                if taskStore.activeFocusTask == nil {
                    withAnimation { focusTabSelector = .dashboard }
                }
            }) { task in
                SessionPreparationSheet(task: task) { intention in
                    taskStore.startFocus(task: task)
                    coordinator.startFocus(task: task)
                    if let intention, !intention.isEmpty {
                        SessionIntentionStore.shared.set(intention, for: task.id)
                    }
                }
            }
            // MARK: - DELETE ALERT ✅ FIXED
            .alert("Delete task?", isPresented: Binding(
                get: { taskToDelete != nil },
                set: { if !$0 { taskToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let task = taskToDelete {
                        taskStore.deleteTask(task)
                    }
                    taskToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    taskToDelete = nil
                }
            }
            // MARK: - MARK DONE ALERT
            .alert("Mark as done?", isPresented: Binding(
                get: { taskToMarkDone != nil },
                set: { if !$0 { taskToMarkDone = nil } }
            )) {
                Button("Mark as Done") {
                    if let task = taskToMarkDone {
                        HapticManager.success()
                        taskStore.completeTask(task)
                    }
                    taskToMarkDone = nil
                }
                Button("Cancel", role: .cancel) {
                    taskToMarkDone = nil
                }
            } message: {
                if let task = taskToMarkDone {
                    Text("\"\(task.title)\" will be marked as completed.")
                }
            }
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) {
                    appeared = true
                }
                refreshMessage()

                // Re-trigger Up Next entrance every appearance.
                upNextAnimatedIn = false
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.55, dampingFraction: 0.86)) {
                        upNextAnimatedIn = true
                    }
                }

                // Shimmer only once per app install (first open).
                let shimmerKey = "upnext_first_launch_shimmer_seen_v1"
                let hasSeenShimmer = UserDefaults.standard.bool(forKey: shimmerKey)
                shouldRunFirstLaunchShimmer = !hasSeenShimmer

                if shouldRunFirstLaunchShimmer {
                    upNextShimmerPhase = false
                    shimmerActive = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                        withAnimation(.easeInOut(duration: 1.0)) {
                            upNextShimmerPhase = true
                            shimmerActive = true
                        }
                    }
                    UserDefaults.standard.set(true, forKey: shimmerKey)
                } else {
                    upNextShimmerPhase = true
                    shimmerActive = false
                }
            }
            .onChange(of: taskStore.activeFocusTask?.id) { refreshMessage() }
        }
    }

    // MARK: - MORNING BRIEFING SLOTS

    enum BriefingSlot: String, CaseIterable, Identifiable {
        // Focus
        case focus          = "focus"
        case sessionsDone   = "sessions"
        case streak         = "streak"
        case weekCompletion = "week"
        case tasksToday     = "tasks"
        case overdueCount   = "overdue"
        case focusThisWeek  = "focusWeek"
        case focusThisMonth = "focusMonth"
        case upcomingTasks  = "upcoming"
        // Pipeline daily
        case dials            = "dials"
        case dialsTarget      = "dialsTarget"
        case connectedCalls   = "connected"
        case meaningfulConvos = "meaningful"
        case apptAskRate      = "apptAskRate"
        case newContactsToday = "newContacts"
        case cmaToday         = "cmaToday"
        // Pipeline weekly
        case weeklyDials        = "weeklyDials"
        case weeklyMeaningful   = "weeklyMeaningful"
        case weeklyAppointments = "weeklyAppointments"
        case weeklyNewContacts  = "weeklyNewContacts"
        case weeklyContent      = "weeklyContent"
        case weeklyTraining     = "weeklyTraining"
        case openHouseContacts  = "openHouseContacts"
        // Pipeline health
        case openDeals = "openDeals"
        case csatScore = "csatScore"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .focus:                return "Focus today"
            case .sessionsDone:         return "Sessions done"
            case .streak:               return "Streak"
            case .weekCompletion:       return "Today's completion"
            case .tasksToday:           return "Tasks due today"
            case .overdueCount:         return "Overdue tasks"
            case .focusThisWeek:        return "Focus this week"
            case .focusThisMonth:       return "Focus this month"
            case .upcomingTasks:        return "Upcoming tasks (7d)"
            case .dials:                return "Dials today"
            case .dialsTarget:          return "Dials remaining"
            case .connectedCalls:       return "Connected calls today"
            case .meaningfulConvos:     return "Meaningful convos today"
            case .apptAskRate:          return "Appt ask rate today"
            case .newContactsToday:     return "New contacts today"
            case .cmaToday:             return "CMAs today"
            case .weeklyDials:          return "Dials this week"
            case .weeklyMeaningful:     return "Meaningful convos (wk)"
            case .weeklyAppointments:   return "Appointments set (wk)"
            case .weeklyNewContacts:    return "New contacts (wk)"
            case .weeklyContent:        return "Content pieces (wk)"
            case .weeklyTraining:       return "Training (wk)"
            case .openHouseContacts:    return "Open house contacts (wk)"
            case .openDeals:            return "Open deals"
            case .csatScore:            return "CSAT score"
            }
        }

        var icon: String {
            switch self {
            case .focus:                return "bolt.fill"
            case .sessionsDone:         return "checkmark.circle.fill"
            case .streak:               return "flame.fill"
            case .weekCompletion:       return "percent"
            case .tasksToday:           return "checklist"
            case .overdueCount:         return "exclamationmark.circle.fill"
            case .focusThisWeek:        return "clock.fill"
            case .focusThisMonth:       return "calendar.badge.clock"
            case .upcomingTasks:        return "calendar.badge.plus"
            case .dials:                return "phone.fill"
            case .dialsTarget:          return "phone.arrow.up.right"
            case .connectedCalls:       return "phone.connection.fill"
            case .meaningfulConvos:     return "bubble.left.fill"
            case .apptAskRate:          return "calendar.badge.checkmark"
            case .newContactsToday:     return "person.badge.plus"
            case .cmaToday:             return "doc.text.fill"
            case .weeklyDials:          return "chart.bar.fill"
            case .weeklyMeaningful:     return "bubble.left.and.bubble.right.fill"
            case .weeklyAppointments:   return "calendar.circle.fill"
            case .weeklyNewContacts:    return "person.2.fill"
            case .weeklyContent:        return "square.and.pencil"
            case .weeklyTraining:       return "book.fill"
            case .openHouseContacts:    return "house.fill"
            case .openDeals:            return "briefcase.fill"
            case .csatScore:            return "star.fill"
            }
        }

        var color: Color {
            switch self {
            case .focus:                return .brg
            case .sessionsDone:         return .brg
            case .streak:               return .brg
            case .weekCompletion:       return .brg
            case .tasksToday:           return .brg
            case .overdueCount:         return .red
            case .focusThisWeek:        return .brg
            case .focusThisMonth:       return .brg
            case .upcomingTasks:        return .brg
            case .dials:                return .brg
            case .dialsTarget:          return .red
            case .connectedCalls:       return .brg
            case .meaningfulConvos:     return .brg
            case .apptAskRate:          return .brg
            case .newContactsToday:     return .brg
            case .cmaToday:             return .brg
            case .weeklyDials:          return .brg
            case .weeklyMeaningful:     return .brg
            case .weeklyAppointments:   return .brg
            case .weeklyNewContacts:    return .brg
            case .weeklyContent:        return .brg
            case .weeklyTraining:       return .brg
            case .openHouseContacts:    return .brg
            case .openDeals:            return .brg
            case .csatScore:            return .brg
            }
        }
    }

    // Persisted slot choices (3 slots)
    @State private var briefingSlots: [BriefingSlot] = {
        guard let raw = UserDefaults.standard.array(forKey: "briefing_slots_v1") as? [String] else {
            return [.focus, .dials, .tasksToday]
        }
        let decoded = raw.compactMap(BriefingSlot.init(rawValue:))
        guard decoded.count == 3 else { return [.focus, .dials, .tasksToday] }
        return decoded
    }()

    @State private var editingSlotIndex: BriefingSlotEdit? = nil

    struct BriefingSlotEdit: Identifiable {
        let id: Int   // the slot index (0, 1, or 2)
    }

    private func saveBriefingSlots() {
        UserDefaults.standard.set(briefingSlots.map(\.rawValue), forKey: "briefing_slots_v1")
    }

    // MARK: - Briefing slot value

    private func briefingValue(for slot: BriefingSlot) -> (title: String, subtitle: String, color: Color) {
        func hLabel(_ mins: Int) -> String {
            if mins < 60 { return "\(mins)m" }
            let h = mins / 60; let m = mins % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }

        switch slot {

        // ── Focus ──────────────────────────────────────────────────────────
        case .focus:
            let done = viewModel.focusMinutesToday
            let goal = settings.dailyFocusGoalToday
            let color: Color = done >= goal ? .brg : .brg
            return ("\(hLabel(done)) / \(hLabel(goal))", "focused today", color)

        case .sessionsDone:
            return ("\(viewModel.completedToday)", "sessions done", .brg)

        case .streak:
            let s = taskStore.strictDailyStreak
            return ("\(s)d", s > 0 ? "day streak 🔥" : "no streak yet", .brg)

        case .weekCompletion:
            let pct = Int(viewModel.completionRateThisWeek * 100)
            let color: Color = pct >= 80 ? .brg : pct >= 50 ? .brg : .red
            return ("\(pct)%", "today's completion", color)

        case .tasksToday:
            let n = activeTasks.count
            return (n == 0 ? "All done" : "\(n)", n == 0 ? "tasks due" : "tasks due today", n == 0 ? .brg : Color(uiColor: .secondaryLabel))

        case .overdueCount:
            let n = viewModel.overdueCount
            return (n == 0 ? "None" : "\(n)", "overdue tasks", n == 0 ? .brg : .red)

        case .focusThisWeek:
            let mins = viewModel.focusMinutesThisWeek
            return (hLabel(mins), "focus this week", .brg)

        case .focusThisMonth:
            let mins = viewModel.focusMinutesThisMonth
            return (hLabel(mins), "focus this month", .brg)

        case .upcomingTasks:
            let n = viewModel.upcomingTasks.count
            return (n == 0 ? "Clear" : "\(n)", "upcoming (7 days)", n == 0 ? .brg : Color(uiColor: .secondaryLabel))

        // ── Pipeline: daily ────────────────────────────────────────────────
        case .dials:
            let d = pipeline.dialsToday
            return ("\(d)", "dials today", d >= pipeline.dailyDialTarget ? .brg : .brg)

        case .dialsTarget:
            let r = pipeline.remainingDialsToday()
            return (r == 0 ? "Done!" : "\(r)", "dials remaining", r == 0 ? .brg : r <= 10 ? Color(uiColor: .secondaryLabel) : .red)

        case .connectedCalls:
            let n = pipeline.connectedCallsToday
            return ("\(n)", "connected today", n > 0 ? .brg : Color(uiColor: .secondaryLabel))

        case .meaningfulConvos:
            let n = pipeline.meaningfulConversationsToday
            return ("\(n)", "meaningful today", n > 0 ? .brg : Color(uiColor: .secondaryLabel))

        case .apptAskRate:
            let rate = pipeline.appointmentAskRateToday
            let pct = Int(rate * 100)
            return ("\(pct)%", "appt ask rate", pct >= 80 ? .brg : pct >= 50 ? Color(uiColor: .secondaryLabel) : .red)

        case .newContactsToday:
            let n = pipeline.newContactsToday
            return ("\(n)", "new contacts today", n > 0 ? .brg : Color(uiColor: .secondaryLabel))

        case .cmaToday:
            let n = pipeline.cmaCreatedToday
            return ("\(n)", "CMAs created", n > 0 ? .brg : Color(uiColor: .secondaryLabel))

        // ── Pipeline: weekly ───────────────────────────────────────────────
        case .weeklyDials:
            let d = pipeline.dialsThisWeek
            let color: Color = d >= pipeline.weeklyDialTarget ? .brg : Color(uiColor: .secondaryLabel)
            return ("\(d)", "dials this week", color)

        case .weeklyMeaningful:
            return ("\(pipeline.meaningfulConversationsThisWeek)", "meaningful (wk)", .brg)

        case .weeklyAppointments:
            return ("\(pipeline.appointmentsSetThisWeek)", "appts set (wk)", .brg)

        case .weeklyNewContacts:
            return ("\(pipeline.newContactsThisWeek)", "new contacts (wk)", .brg)

        case .weeklyContent:
            let n = pipeline.contentPiecesThisWeek
            return ("\(n)", "content pieces (wk)", n > 0 ? .brg : Color(uiColor: .secondaryLabel))

        case .weeklyTraining:
            let mins = pipeline.trainingMinutesThisWeek
            return (hLabel(mins), "training (wk)", mins > 0 ? .brg : Color(uiColor: .secondaryLabel))

        case .openHouseContacts:
            let n = pipeline.openHouseContactsThisWeekend
            return ("\(n)", "open house contacts", n > 0 ? .brg : Color(uiColor: .secondaryLabel))

        // ── Pipeline: health ───────────────────────────────────────────────
        case .openDeals:
            let n = pipeline.deals.filter { $0.stage != .closed && $0.stage != .lost }.count
            return ("\(n)", "open deals", n > 0 ? .brg : Color(uiColor: .secondaryLabel))

        case .csatScore:
            if let score = pipeline.csatScoreLast20 {
                let pct = Int(score * 20)
                return ("\(pct)%", "CSAT (last 20)", pct >= 80 ? .brg : pct >= 60 ? Color(uiColor: .secondaryLabel) : .red)
            } else {
                return ("—", "CSAT (no data)", Color(uiColor: .secondaryLabel))
            }
        }
    }

    // MARK: - MORNING BRIEFING CARD
    @ViewBuilder
    private var morningContextCard: some View {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "sun.horizon.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("Morning briefing")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Hold chip to change")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(.tertiary)
                }

                // 3 editable chips
                HStack(spacing: 10) {
                    ForEach(briefingSlots.indices, id: \.self) { idx in
                        let slot   = briefingSlots[idx]
                        let val    = briefingValue(for: slot)
                        briefingChip(
                            icon:     slot.icon,
                            color:    val.color,
                            title:    val.title,
                            subtitle: val.subtitle
                        )
                        .onLongPressGesture(minimumDuration: 0.4) {
                            HapticManager.impact()
                            editingSlotIndex = BriefingSlotEdit(id: idx)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 8)
            .sheet(item: $editingSlotIndex) { edit in
                BriefingSlotPickerSheet(
                    currentSlot: briefingSlots[edit.id],
                    usedSlots: Set(briefingSlots),
                    onSelect: { newSlot in
                        briefingSlots[edit.id] = newSlot
                        saveBriefingSlots()
                    }
                )
            }
        }
    }

    private func briefingChip(icon: String, color: Color, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - NUDGE CARD
    private enum NudgeUrgency {
        case critical   // red    — streak/day ending
        case action     // yellow — something needs doing now
        case positive   // green  — goal hit / celebration
    }

    private struct NudgeItem {
        let icon: String
        let urgency: NudgeUrgency
        let message: String
        let destination: MainTabView.Tab?
        let priority: Int

        var color: Color {
            switch urgency {
            case .critical: return .red
            case .action:   return Color(red: 0.95, green: 0.78, blue: 0.0) // warm yellow
            case .positive: return .brg
            }
        }
    }

    /// Evaluates every tracked data dimension and returns the single highest-priority
    /// recommendation for the user right now. Always returns a value.
    private var currentNudge: NudgeItem {
        let cal        = Calendar.current
        let now        = Date()
        let hour       = cal.component(.hour, from: now)
        let weekday    = cal.component(.weekday, from: now) // 1=Sun … 7=Sat
        let isWeekday  = weekday >= 2 && weekday <= 6
        let isWorkHour = hour >= 8 && hour < 19

        // ── Focus metrics ─────────────────────────────────────────────────────
        let sessions   = viewModel.sessionsToday
        let focusMins  = viewModel.focusMinutesToday
        let focusGoal  = settings.dailyFocusGoalToday  // minutes
        let streak     = taskStore.strictDailyStreak
        let overdue    = viewModel.overdueCount

        // Next pending task for today (most time-relevant)
        let nextTask   = taskStore.getTodaysTasks().first

        // Distracted sessions today (exit reason == .distracted)
        let distractedToday = taskStore.sessionLogs.filter {
            $0.exitReason == .distracted && cal.isDateInToday($0.startDate)
        }.count

        // ── Pipeline metrics ─────────────────────────────────────────────────
        let hasPipeline  = !pipeline.callLogs.isEmpty

        // Dial pace: linear ramp from 0 at 8:00 to 55 at 18:00
        let dialTarget   = 55
        let dials        = pipeline.dialsToday
        let minuteOfDay  = hour * 60 + cal.component(.minute, from: now)
        let paceProgress = isWorkHour ? min(1.0, Double(max(0, minuteOfDay - 480)) / Double(600)) : 0.0
        let dialPace     = Int((paceProgress * Double(dialTarget)).rounded())
        let dialsShort   = max(0, dialPace - dials)

        // Meaningful conversations & appointment ask rate today
        let connected    = pipeline.connectedCallsToday
        let apptAsks     = pipeline.appointmentAsksToday
        let missedAsks   = connected > 0 ? (connected - apptAsks) : 0

        // Hot / warm leads from today's calls that have a follow-up next step
        let followUpsDue = pipeline.callLogs.filter {
            cal.isDateInToday($0.date) &&
            ($0.nextStep == .followUpCall || $0.nextStep == .retryCall || $0.nextStep == .appointment) &&
            $0.generatedTaskID == nil
        }

        // Warm/hot leads in the call log (any time) whose deals are still at "Lead" stage
        let stalledLeads = pipeline.deals.filter {
            ($0.stage == .lead || $0.stage == .contacted) &&
            !cal.isDate($0.updatedAt, inSameDayAs: now) &&
            cal.dateComponents([.day], from: $0.updatedAt, to: now).day ?? 0 >= 2
        }

        // Deals close to closing
        let nearCloseDeals = pipeline.deals.filter {
            $0.stage == .proposal || $0.stage == .listing || $0.stage == .offer
        }

        let hotSheetDone   = pipeline.hotSheetReviewedToday
        let bigFour        = pipeline.bigFourToday
        let openDeals      = pipeline.deals.filter { $0.stage != .closed && $0.stage != .lost }.count
        let trainingMins   = pipeline.trainingLogs.filter { cal.isDateInToday($0.date) }.reduce(0) { $0 + $1.durationMinutes }
        let contentThisWeek = pipeline.contentPiecesThisWeek

        // ── Helper: minutes → label ───────────────────────────────────────────
        func minsLabel(_ m: Int) -> String {
            let h = m / 60; let r = m % 60
            if h > 0 { return r > 0 ? "\(h)h \(r)m" : "\(h)h" }
            return "\(r)m"
        }

        var candidates: [NudgeItem] = []

        // ═══════════════════════════════════════════════════════════════════
        // CRITICAL 100+ — streak or day-ending events
        // ═══════════════════════════════════════════════════════════════════

        if hour >= 21 && sessions == 0 && streak > 0 {
            candidates.append(.init(
                icon: "flame.fill", urgency: .critical,
                message: "Your \(streak)-day streak ends at midnight if you don't complete a session. Start now.",
                destination: .focus, priority: 130))
        }

        if hour >= 18 && sessions == 0 {
            let t = nextTask.map { " — \($0.title) is waiting" } ?? ""
            candidates.append(.init(
                icon: "exclamationmark.triangle.fill", urgency: .critical,
                message: "No focus sessions today\(t). Start one before the day ends.",
                destination: .focus, priority: 115))
        }

        // ═══════════════════════════════════════════════════════════════════
        // HIGH 70–99 — significant gaps in core daily KPIs
        // ═══════════════════════════════════════════════════════════════════

        // 0 calls logged on a workday during work hours
        if hasPipeline && isWeekday && isWorkHour && dials == 0 {
            let dealCtx = openDeals > 0 ? " You have \(openDeals) open deal\(openDeals == 1 ? "" : "s") to advance." : ""
            candidates.append(.init(
                icon: "phone.arrow.up.right", urgency: .action,
                message: "0 calls logged today.\(dealCtx) Open Tracker and start prospecting.",
                destination: .pipeline, priority: 95))
        }

        // Hot sheet not done in the morning
        if hasPipeline && isWeekday && hour >= 7 && hour < 11 && !hotSheetDone {
            candidates.append(.init(
                icon: "doc.text.magnifyingglass", urgency: .action,
                message: "Hot sheet not reviewed yet. Do it before your first call — it sets your priorities.",
                destination: .pipeline, priority: 88))
        }

        // Connected calls where appointment was never asked
        if hasPipeline && isWorkHour && missedAsks >= 2 {
            candidates.append(.init(
                icon: "questionmark.bubble.fill", urgency: .critical,
                message: "You connected \(connected) times today but only asked for an appointment \(apptAsks) time\(apptAsks == 1 ? "" : "s"). Ask on every connected call.",
                destination: .pipeline, priority: 83))
        }

        // No focus sessions yet during work hours
        if sessions == 0 && isWorkHour {
            let ctx = nextTask.map { " \"\($0.title)\" is your first task." } ?? ""
            candidates.append(.init(
                icon: "bolt.fill", urgency: .action,
                message: hour < 12
                    ? "No focus sessions yet.\(ctx) Morning is your sharpest window."
                    : "No focus sessions yet today.\(ctx) Start one now.",
                destination: .focus, priority: 80))
        }

        // ═══════════════════════════════════════════════════════════════════
        // MEDIUM 40–69 — real gaps with specific data to act on
        // ═══════════════════════════════════════════════════════════════════

        // Follow-ups generated today not yet turned into tasks
        if !followUpsDue.isEmpty {
            let names = followUpsDue.prefix(2).map { $0.contactName.isEmpty ? "a contact" : $0.contactName }.joined(separator: ", ")
            let more  = followUpsDue.count > 2 ? " +\(followUpsDue.count - 2) more" : ""
            candidates.append(.init(
                icon: "arrow.turn.down.right", urgency: .action,
                message: "\(followUpsDue.count) follow-up\(followUpsDue.count == 1 ? "" : "s") from today's calls need a task: \(names)\(more).",
                destination: .pipeline, priority: 68))
        }

        // Overdue tasks — show first task name
        if overdue > 0 {
            let first = taskStore.tasks
                .filter { $0.status == .pending }
                .filter { ($0.scheduledTime ?? $0.startDate) < cal.startOfDay(for: now) }
                .sorted { ($0.scheduledTime ?? $0.startDate) < ($1.scheduledTime ?? $1.startDate) }
                .first
            let taskName = first.map { " \"\($0.title)\" is \(Int(now.timeIntervalSince($0.scheduledTime ?? $0.startDate) / 3600))h overdue." } ?? ""
            candidates.append(.init(
                icon: "exclamationmark.circle.fill", urgency: .action,
                message: "\(overdue) overdue task\(overdue == 1 ? "" : "s").\(taskName) Clear it now.",
                destination: .focus, priority: 65))
        }

        // Focus goal gap in the afternoon — concrete remaining time
        if hour >= 13 && focusMins < focusGoal / 2 {
            let rem = focusGoal - focusMins
            candidates.append(.init(
                icon: "clock.fill", urgency: .action,
                message: "Only \(minsLabel(focusMins)) focused so far. \(minsLabel(rem)) left to hit today's goal of \(minsLabel(focusGoal)).",
                destination: .focus, priority: 60))
        }

        // Big Four not passed — name the exact missing item
        if hasPipeline && isWeekday && isWorkHour && !bigFour.passesRule {
            var missing: [String] = []
            if bigFour.setAppointment == 0  { missing.append("set an appointment") }
            if bigFour.signedSomething == 0 { missing.append("sign something") }
            if bigFour.soldSomething == 0   { missing.append("close a sale") }
            let detail = missing.first ?? "complete the checklist"
            candidates.append(.init(
                icon: "checklist", urgency: .action,
                message: "Big Four not done today. Next: \(detail) in Tracker.",
                destination: .pipeline, priority: 55))
        }

        // Stalled leads — name the contact and days since last touch
        if hasPipeline && !stalledLeads.isEmpty {
            let lead = stalledLeads.sorted { $0.updatedAt < $1.updatedAt }.first!
            let days = cal.dateComponents([.day], from: lead.updatedAt, to: now).day ?? 0
            let name = lead.contactName.isEmpty ? "a lead" : lead.contactName
            candidates.append(.init(
                icon: "person.fill.questionmark", urgency: .action,
                message: "\(stalledLeads.count) lead\(stalledLeads.count == 1 ? "" : "s") not touched in 2+ days. \(name) hasn't heard from you in \(days)d.",
                destination: .pipeline, priority: 52))
        }

        // Near-close deals need attention
        if hasPipeline && !nearCloseDeals.isEmpty {
            let deal = nearCloseDeals.first!
            let name = deal.contactName.isEmpty ? "a deal" : deal.contactName
            let stageLabel = deal.stage.rawValue.lowercased()
            candidates.append(.init(
                icon: "briefcase.fill", urgency: .action,
                message: "\(nearCloseDeals.count) deal\(nearCloseDeals.count == 1 ? "" : "s") near closing. \(name) is at \(stageLabel) — follow up today.",
                destination: .pipeline, priority: 50))
        }

        // No content this week (midweek or later)
        if hasPipeline && isWeekday && contentThisWeek == 0 && weekday >= 4 {
            candidates.append(.init(
                icon: "camera.fill", urgency: .action,
                message: "No content posted this week and it's already \(["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][weekday]). Post one piece today.",
                destination: .pipeline, priority: 44))
        }

        // ═══════════════════════════════════════════════════════════════════
        // LOW 10–39 — positive or forward-looking
        // ═══════════════════════════════════════════════════════════════════

        // Multiple distracted sessions today — pattern worth flagging
        if distractedToday >= 2 {
            candidates.append(.init(
                icon: "eye.slash.fill", urgency: .action,
                message: "\(distractedToday) sessions ended early today. Try a shorter \(nextTask.map { _ in "block on \"\(nextTask!.title)\"" } ?? "focus block") to rebuild momentum.",
                destination: .focus, priority: 38))
        }

        // Within striking distance of focus goal
        if focusMins > 0 && focusMins >= (focusGoal * 2) / 3 && focusMins < focusGoal {
            let rem = focusGoal - focusMins
            candidates.append(.init(
                icon: "bolt.fill", urgency: .action,
                message: "\(minsLabel(focusMins)) done — only \(minsLabel(rem)) left to hit your \(minsLabel(focusGoal)) goal today.",
                destination: .focus, priority: 28))
        }

        // Training shortfall (weekly target 120 min)
        if hasPipeline && isWeekday && trainingMins == 0 && hour >= 13 {
            let weeklyTotal = pipeline.trainingMinutesThisWeek
            if weeklyTotal < 60 {
                candidates.append(.init(
                    icon: "book.fill", urgency: .action,
                    message: "Only \(weeklyTotal)m of training this week (120m target). Log 15–20m today.",
                    destination: .pipeline, priority: 25))
            }
        }

        // Goal achieved — specific and celebratory
        if focusMins >= focusGoal {
            let extra    = focusMins - focusGoal
            let extraCtx = extra >= 15 ? " (+\(minsLabel(extra)) over goal)" : ""
            let streakCtx = streak > 1 ? " \(streak)-day streak 🔥" : ""
            candidates.append(.init(
                icon: "checkmark.seal.fill", urgency: .positive,
                message: "Focus goal hit: \(minsLabel(focusMins))\(extraCtx).\(streakCtx) Great work today.",
                destination: nil, priority: 22))
        }

        // Early morning warm-up
        if hour < 9 {
            let taskCtx = nextTask.map { "First task: \"\($0.title)\"." } ?? ""
            candidates.append(.init(
                icon: "sunrise.fill", urgency: .action,
                message: "Good morning.\(taskCtx) Plan your sessions and review the hot sheet.",
                destination: .focus, priority: 14))
        }

        // ═══════════════════════════════════════════════════════════════════
        // GUARANTEED FALLBACK — precise summary of today
        // ═══════════════════════════════════════════════════════════════════
        let callCtx = hasPipeline ? ", \(dials) call\(dials == 1 ? "" : "s")" : ""
        let convCtx = hasPipeline && connected > 0 ? " (\(connected) connected)" : ""
        candidates.append(.init(
            icon: "checkmark.circle.fill", urgency: .positive,
            message: "\(sessions) session\(sessions == 1 ? "" : "s") · \(minsLabel(focusMins)) focused\(callCtx)\(convCtx) today. What's next?",
            destination: .focus, priority: 5))

        return candidates.max(by: { $0.priority < $1.priority })!
    }

    @ViewBuilder
    private var nudgeCard: some View {
        let nudge = currentNudge
        HStack(spacing: 12) {
            Image(systemName: nudge.icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(nudge.color)
                .frame(width: 28, height: 28)
                .background(nudge.color.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(nudge.message)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if let tab = nudge.destination {
                Spacer()
                Button {
                    HapticManager.impact()
                    withAnimation { focusTabSelector = tab }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(7)
                        .background(Color(uiColor: .tertiarySystemFill), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
    private var headerSection: some View {
        HStack(alignment: .center, spacing: 16) {
            // Left: message + date
            VStack(alignment: .leading, spacing: 6) {
                // Date chip
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                // Motivation message — updated live by MotivationMessageEngine
                let fullMsg = motivationEngine.currentMessage
                let parts   = fullMsg.components(separatedBy: "\n")
                let quote   = parts.first ?? fullMsg
                let attribution = parts.count > 1 ? parts.dropFirst().joined(separator: " ") : nil

                VStack(alignment: .leading, spacing: 3) {
                    Text(quote.isEmpty ? " " : quote)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let attr = attribution, !attr.isEmpty {
                        Text(attr)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .animation(.easeInOut(duration: 0.6), value: motivationEngine.currentMessage)
            }

            Spacer()

            // Right: progress ring
            let total = max(taskStore.getTodaysTasks().count + viewModel.completedToday, 1)
            let done  = viewModel.completedToday
            let prog  = Double(done) / Double(total)

            ZStack {
                Circle()
                    .stroke(Color.brg.opacity(0.15), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: prog)
                    .stroke(
                        LinearGradient(
                            colors: [Color.brg, Color.brgBright],
                            startPoint: .top, endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: prog)
                VStack(spacing: 0) {
                    Text("\(done)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.brgBright)
                    Text("done")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning" }
        if h < 17 { return "Good afternoon" }
        return "Good evening"
    }

    // Builds a context snapshot from live store + viewModel + pipeline data
    private var engineContext: MotivationMessageEngine.Context {
        let h        = Calendar.current.component(.hour, from: Date())
        let pipeline = PipelineStore.shared
        let cal      = Calendar.current

        let offersToday   = pipeline.saleLogs.filter {
            cal.isDateInToday($0.date) && $0.type == .offerSent
        }.count
        let listingsToday = pipeline.saleLogs.filter {
            cal.isDateInToday($0.date) && $0.type == .listingSigned
        }.count
        let hotLeads = pipeline.contactMetadata.filter {
            $0.tag == .hotLead
        }.count

        return MotivationMessageEngine.Context(
            hour:                  h,
            streak:                taskStore.strictDailyStreak,
            focusMinsToday:        viewModel.focusMinutesToday,
            sessionsToday:         viewModel.completedToday,
            tasksRemaining:        activeTasks.count,
            totalTasksToday:       taskStore.getTodaysTasks().count,
            weeklyMins:            viewModel.focusMinutesThisWeek,
            isInFocusSession:      taskStore.activeFocusTask != nil,
            dialsToday:            pipeline.dialsToday,
            dialTarget:            pipeline.dailyDialTarget,
            dialsThisWeek:         pipeline.dialsThisWeek,
            weeklyDialTarget:      pipeline.weeklyDialTarget,
            hotLeadsCount:         hotLeads,
            meetingsToday:         pipeline.meetingsToday,
            offersToday:           offersToday,
            listingsToday:         listingsToday,
            newContactsToday:      pipeline.newContactsToday,
            appointmentsThisWeek:  pipeline.appointmentsSetThisWeek
        )
    }

    private func refreshMessage() {
        // Calling message() kicks off an AI request if the block/context changed.
        // The engine publishes the result to currentMessage which the view observes.
        _ = MotivationMessageEngine.shared.message(context: engineContext)
    }

    // MARK: - NOW FOCUSING
    private func nowFocusingSection(task: FocusTask) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.brg.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.brgBright)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Now focusing")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(task.title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "waveform")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.variableColor.iterative)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.06)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.accentColor.opacity(0.20), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    // MARK: - PRIMARY ACTION
    private var primaryActionSection: some View {
        let visibleTasks = Array(activeTasks.prefix(4))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Up next")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text(visibleTasks.isEmpty ? "No pending tasks" : "Your next high-impact moves")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text("\(activeTasks.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.brg)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06), in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.14), lineWidth: 0.8)
                    )
            }

            if visibleTasks.isEmpty {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.brg.opacity(0.25), Color.brg.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                        Image(systemName: "sparkles")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(Color.brg)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("All caught up!")
                            .font(.headline)
                        Text("Great work today. Add a new task to keep momentum.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                )
                .shadow(color: Color.black.opacity(0.22), radius: 12, x: 0, y: 7)
            } else {
                ForEach(Array(visibleTasks.enumerated()), id: \.element.id) { index, task in
                    taskRowCard(task: task, index: index, total: activeTasks.count)
                        .scaleEffect(pressedTaskID == task.id ? 0.98 : 1)
                        .opacity(upNextAnimatedIn ? 1 : 0)
                        .offset(y: upNextAnimatedIn ? 0 : 10)
                        .animation(
                            .spring(response: 0.52, dampingFraction: 0.84).delay(0.04 * Double(index)),
                            value: upNextAnimatedIn
                        )
                        .animation(.easeOut(duration: 0.16), value: pressedTaskID)
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    // MARK: - TASK ROW CARD
    private func taskRowCard(task: FocusTask, index: Int, total: Int) -> some View {
        let mins = Int(task.focusPlan.blocks.first?.duration ?? 0) / 60
        let isHero = index == 0
        let scheduledTime: String? = {
            guard let t = task.scheduledTime else { return nil }
            let f = DateFormatter(); f.timeStyle = .short
            return f.string(from: t)
        }()

        let titleFont: Font = isHero
            ? .system(size: 17, weight: .bold, design: .rounded)
            : .system(size: 15, weight: .semibold)

        return HStack(spacing: isHero ? 16 : 12) {
            ZStack {
                RoundedRectangle(cornerRadius: isHero ? 12 : 10, style: .continuous)
                    .fill(
                        isHero
                        ? LinearGradient(
                            colors: [Color.brg, Color.brgBright.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: isHero ? 42 : 34, height: isHero ? 42 : 34)
                Text("\(index + 1)")
                    .font(.system(size: isHero ? 16 : 13, weight: .bold, design: .rounded))
                    .foregroundStyle(isHero ? .white : Color.brg)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(titleFont)
                    .foregroundStyle(.primary)
                    .lineLimit(isHero ? 2 : 1)

                HStack(spacing: 8) {
                    Label("\(mins)m", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let t = scheduledTime {
                        Text("•")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(t)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Play button as Button for reliable tap
            Button(action: {
                print("Play button tapped for task: \(task.title)")
                pressedTaskID = nil
                HapticManager.impact()
                SoundManager.tap()
                preparingTask = task
                withAnimation { focusTabSelector = .focus }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: isHero ? 12 : 10, style: .continuous)
                        .fill(
                            isHero
                            ? LinearGradient(
                                colors: [Color.brg, Color.brgBright.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: isHero ? 38 : 34, height: isHero ? 38 : 34)
                    Image(systemName: "play.fill")
                        .font(.system(size: isHero ? 14 : 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Start \(task.title)")
        }
        .padding(.horizontal, isHero ? 16 : 14)
        .padding(.vertical, isHero ? 15 : 11)
        .background(
            RoundedRectangle(cornerRadius: isHero ? 20 : 16, style: .continuous)
                .fill(
                    isHero
                    ? LinearGradient(
                        colors: [Color.white.opacity(0.12), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    : LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: isHero ? 20 : 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(isHero ? 0.16 : 0.10), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .center
                    )
                )
                .padding(1)
                .allowsHitTesting(false)
        }
        .overlay {
            // Shimmer effect for hero card on first app open
            if isHero && shouldRunFirstLaunchShimmer {
                GeometryReader { geo in
                    let w = geo.size.width
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.clear, Color.white.opacity(0.22), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: w * 0.28)
                        .rotationEffect(.degrees(13))
                        .offset(x: shimmerActive ? w + 44 : -w * 0.50)
                        .blendMode(.screen)
                }
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .allowsHitTesting(false)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: isHero ? 20 : 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: isHero ? 20 : 16, style: .continuous)
                .stroke(
                    isHero ? Color.white.opacity(0.20) : Color.white.opacity(0.12),
                    lineWidth: 0.8
                )
        )
        .shadow(
            color: isHero ? Color.black.opacity(0.30) : Color.black.opacity(0.18),
            radius: isHero ? 14 : 8,
            x: 0,
            y: isHero ? 8 : 5
        )
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in pressedTaskID = task.id }
                .onEnded { _ in pressedTaskID = nil }
        )
        .onTapGesture {
            if !isHero {
                pressedTaskID = nil
                HapticManager.impact()
                SoundManager.tap()
                preparingTask = task
                withAnimation { focusTabSelector = .focus }
            }
        }
        .contextMenu {
            Button { HapticManager.impact(); editingTask = task } label: { Label("Edit", systemImage: "pencil") }
            Button { HapticManager.impact(); taskStore.skipTask(task) } label: { Label("Skip", systemImage: "forward.fill") }
            Button { HapticManager.impact(); taskToMarkDone = task } label: { Label("Mark as Done", systemImage: "checkmark.circle.fill") }
            Button(role: .destructive) { HapticManager.impact(); taskToDelete = task } label: { Label("Delete", systemImage: "trash") }
        }
    }

    // MARK: - DAILY GLANCE
    private var dailyGlanceSection: some View {
        VStack(spacing: 14) {
            // ── Training counter (subtle) ─────────────────────
            trainingCheckRow

            // ── Meal tracker ──────────────────────────────────
            mealLogCard

            // 7-day streak strip
            streakWeekRow
                .padding(18)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            // ── Quick Insights card ───────────────────────────────
            quickInsightsCard
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
    }

    // Training row — gamified checkmark with 72h-grace weekly streak
    private var trainingCheckRow: some View {
        let done      = pipeline.trainedToday
        let streak    = pipeline.trainingStreak
        let weekCount = pipeline.weeklyWorkoutCount
        let goalMet   = pipeline.weeklyWorkoutGoalMet
        let hours     = pipeline.hoursSinceLastWorkout
        let graceLeft: Double? = hours.map { max(0.0, 72.0 - $0) }
        let urgent    = graceLeft.map { $0 < 18 && $0 > 0 } ?? false

        return TrainingCheckRowContent(
            done: done, streak: streak, weekCount: weekCount,
            goalMet: goalMet, graceLeft: graceLeft, urgent: urgent
        ) {
            HapticManager.impact()
            var u = pipeline.bigFourToday
            u.completedTraining = done ? 0 : 1
            pipeline.saveBigFour(u)
        }
    }
    // MARK: - Meal Log Card
    private var mealLogCard: some View {
        let store = MealStore.shared
        let today = store.todayEntries()
        let isHungry = store.isHungry
        let isDip = store.isInPostLunchDip
        let hasNone = store.hasNotEatenToday

        let cardColor: Color = isHungry ? .orange : isDip ? .indigo : Color.brg
        let icon = isHungry ? "fork.knife.circle.fill" : isDip ? "moon.fill" : hasNone ? "fork.knife" : "checkmark.circle.fill"
        let statusText: String = {
            if isHungry { return "You may be hungry — log a meal" }
            if isDip { return "Post-lunch dip — break adjusted" }
            if hasNone { return "No meals logged yet today" }
            if let last = today.last {
                let mins = Int(Date().timeIntervalSince(last.date) / 60)
                let timeStr = mins < 60 ? "\(mins)m ago" : "\(mins/60)h ago"
                return "Last meal \(timeStr) · \(today.count) logged today"
            }
            return "Track meals to improve break suggestions"
        }()

        return Button { showMealLog = true } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(cardColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Meals Today")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(statusText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Meal type dots
                if !today.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(today.prefix(4)) { entry in
                            Circle()
                                .fill(entry.type.color)
                                .frame(width: 7, height: 7)
                        }
                    }
                }

                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(cardColor.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isHungry ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showMealLog) { MealLogView() }
    }

    // MARK: - Quick Insights card
    private var quickInsightsCard: some View {
        let trendColor: Color = weekTrendPositive ? Color.brgBright : .red
        let curr  = viewModel.focusMinutesThisWeek
        let prev  = viewModel.prevWeekMinutes
        let top   = Double(max(curr, prev, 1))
        let currW = min(1.0, Double(curr) / top)
        let prevW = min(1.0, Double(prev) / top)

        return VStack(alignment: .leading, spacing: 0) {

            // ── Header ───────────────────────────────────────────────
            HStack(alignment: .center) {
                Text("Quick Insights")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                Button { showInsights = true } label: {
                    HStack(spacing: 5) {
                        Text("Full report")
                            .font(.system(size: 12, weight: .semibold))
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.brg)
                            .shadow(color: Color.brg.opacity(0.4), radius: 6, x: 0, y: 3)
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
                .buttonStyle(InsightReportButtonStyle())
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 16)

            // ── Divider ──────────────────────────────────────────────
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.5))
                .frame(height: 0.5)

            // ── Hero zone ────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 16) {

                // Delta + inline label + badge
                HStack(alignment: .center, spacing: 10) {
                    // Number
                    Text(weekTrendShortLabel)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(trendColor)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .layoutPriority(1)

                    Spacer()

                    // Badge + label stacked
                    VStack(alignment: .trailing, spacing: 5) {
                        HStack(spacing: 4) {
                            Image(systemName: weekTrendPositive ? "arrow.up" : "arrow.down")
                                .font(.system(size: 9, weight: .black))
                            Text(weekTrendPositive ? "Improving" : "Declining")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundStyle(trendColor)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(trendColor.opacity(0.12))
                        .clipShape(Capsule())

                        Text("vs last week")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(.secondary)
                    }
                }

                // Bars
                VStack(spacing: 10) {
                    insightBar(
                        label: "This week",
                        progress: currW,
                        fill: AnyShapeStyle(trendColor.gradient),
                        value: weekHoursLabel(curr),
                        valuePrimary: true,
                        delay: 0.25
                    )
                    insightBar(
                        label: "Last week",
                        progress: prevW,
                        fill: AnyShapeStyle(Color(uiColor: .systemFill)),
                        value: weekHoursLabel(prev),
                        valuePrimary: false,
                        delay: 0.38
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 20)
            .background(Color(uiColor: .tertiarySystemBackground))

            // ── Divider ──────────────────────────────────────────────
            Rectangle()
                .fill(Color(uiColor: .separator).opacity(0.5))
                .frame(height: 0.5)

            // ── Bottom stats ─────────────────────────────────────────
            HStack(spacing: 0) {
                bottomStat(
                    icon: "star.fill",
                    iconColor: .secondary,
                    label: "Best day ever",
                    value: bestFocusDayLabel,
                    valueColor: .primary,
                    detail: bestFocusDaySubtitle
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, 20)

                Rectangle()
                    .fill(Color(uiColor: .separator).opacity(0.5))
                    .frame(width: 0.5)
                    .padding(.vertical, 16)

                bottomStat(
                    icon: "chart.line.uptrend.xyaxis",
                    iconColor: .secondary,
                    label: "Daily average",
                    value: dailyAvgShortLabel,
                    valueColor: dailyAvgVsGoalColor,
                    detail: dailyAvgVsGoalTag
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color(uiColor: .separator).opacity(0.8),
                            Color(uiColor: .separator).opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 16, x: 0, y: 6)
    }

    // Single bar row used inside quickInsightsCard
    private func insightBar(
        label: String,
        progress: Double,
        fill: AnyShapeStyle,
        value: String,
        valuePrimary: Bool,
        delay: Double
    ) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 12, weight: valuePrimary ? .semibold : .regular))
                .foregroundStyle(valuePrimary ? Color.primary : Color.secondary)
                .frame(width: 64, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(height: 11)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(fill)
                        .frame(width: appeared ? max(11, geo.size.width * progress) : 0, height: 11)
                        .animation(
                            .spring(response: 0.65, dampingFraction: 0.82).delay(delay),
                            value: appeared
                        )
                }
            }
            .frame(height: 11)

            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(valuePrimary ? Color.primary : Color.secondary)
                .frame(width: 48, alignment: .trailing)
        }
    }

    // Single bottom-stat cell used inside quickInsightsCard
    private func bottomStat(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        valueColor: Color,
        detail: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            // Icon + label
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            // Value
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            // Detail
            Text(detail)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func weekHoursLabel(_ minutes: Int) -> String {
        guard minutes > 0 else { return "0h" }
        let h = minutes / 60; let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private var weekTrendPositive: Bool {
        viewModel.focusMinutesThisWeek >= viewModel.prevWeekMinutes
    }

    private var weekTrendShortLabel: String {
        let curr = viewModel.focusMinutesThisWeek
        let prev = viewModel.prevWeekMinutes
        guard prev > 0 else { return curr == 0 ? "—" : "+\(weekHoursLabel(curr))" }
        let diff = curr - prev
        if abs(diff) < 60 { return "\(diff >= 0 ? "+" : "")\(diff)m" }
        let h = abs(diff) / 60; let m = abs(diff) % 60
        let time = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        return "\(diff >= 0 ? "+" : "-")\(time)"
    }

    private var bestFocusDayLabel: String {
        guard let best = taskStore.bestFocusDay else { return "—" }
        let m = best.minutes
        if m < 60 { return "\(m)m" }
        let h = m / 60; let rem = m % 60
        return rem > 0 ? "\(h)h \(rem)m" : "\(h)h"
    }

    private var bestFocusDaySubtitle: String {
        guard let best = taskStore.bestFocusDay else { return "No sessions yet" }
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"
        return f.string(from: best.date)
    }

    private var dailyAvgShortLabel: String {
        let daysElapsed = max(1, Calendar.current.component(.weekday, from: Date()) - 1)
        let avg = viewModel.focusMinutesThisWeek / daysElapsed
        if avg < 60 { return "\(avg)m" }
        let h = avg / 60; let m = avg % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    private var dailyAvgVsGoalColor: Color {
        let daysElapsed = max(1, Calendar.current.component(.weekday, from: Date()) - 1)
        let avg = viewModel.focusMinutesThisWeek / daysElapsed
        if avg >= settings.dailyFocusGoalToday { return .brg }
        if avg >= settings.dailyFocusGoalToday / 2 { return .orange }
        return .red
    }

    private var dailyAvgVsGoalTag: String {
        "goal \(settings.dailyFocusGoalToday / 60)h / day"
    }

    // MARK: - Streak dot strip (7-day row)
    private var streakWeekRow: some View {
        let days = Array(viewModel.streakDays.suffix(7))
        return HStack(spacing: 4) {
            ForEach(days, id: \.date) { entry in
                let isToday = Calendar.current.isDateInToday(entry.date)
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(entry.hadFocus ? Color.brg : Color(uiColor: .tertiarySystemFill))
                            .frame(width: 32, height: 32)
                        if isToday {
                            Circle()
                                .strokeBorder(Color.brg, lineWidth: 2)
                                .frame(width: 32, height: 32)
                        }
                        if entry.hadFocus {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                    Text(dayLetter(entry.date))
                        .font(.system(size: 9, weight: .regular))
                        .foregroundStyle(Color.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func dayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    // MARK: - FOCUS EXIT HANDLER
    private func handleFocusExit(_ exit: FocusSessionExit, for task: FocusTask) {
        taskStore.endFocus()
    }
}

// MARK: - Briefing Slot Picker Sheet

private struct BriefingSlotPickerSheet: View {
    let currentSlot: DashboardView.BriefingSlot
    let usedSlots: Set<DashboardView.BriefingSlot>
    let onSelect: (DashboardView.BriefingSlot) -> Void

    @Environment(\.dismiss) private var dismiss

    private var availableSlots: [DashboardView.BriefingSlot] {
        DashboardView.BriefingSlot.allCases.filter { slot in
            slot == currentSlot || !usedSlots.contains(slot)
        }
    }

    private var inUseSlots: [DashboardView.BriefingSlot] {
        DashboardView.BriefingSlot.allCases.filter { slot in
            slot != currentSlot && usedSlots.contains(slot)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Choose an insight") {
                    ForEach(availableSlots) { slot in
                        slotRow(slot: slot)
                    }
                }

                if !inUseSlots.isEmpty {
                    Section("Already in use") {
                        ForEach(inUseSlots) { slot in
                            slotRow(slot: slot)
                        }
                    }
                }
            }
            .navigationTitle("Change Insight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func slotRow(slot: DashboardView.BriefingSlot) -> some View {
        let isCurrent = slot == currentSlot
        let isUsed    = usedSlots.contains(slot) && !isCurrent

        Button {
            guard !isUsed else { return }
            onSelect(slot)
            dismiss()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(slot.color.opacity(isUsed ? 0.05 : 0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: slot.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(slot.color.opacity(isUsed ? 0.3 : 1))
                }

                Text(slot.displayName)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isUsed ? Color.secondary.opacity(0.4) : .primary)

                Spacer()

                if isCurrent {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                } else if isUsed {
                    Text("In use")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .disabled(isUsed)
    }
}

// MARK: - Card Style (kept for any remaining uses)
private extension View {
    func dashboardCard(highlighted: Bool = false) -> some View {
        self
            .padding()
            .background(
                highlighted
                ? Color.accentColor.opacity(0.18)
                : Color(uiColor: .secondarySystemBackground)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - Full Report Button Style
private struct InsightReportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

// MARK: - Training check row content (extracted to fix type-checker complexity)
private struct TrainingCheckRowContent: View {
    let done: Bool
    let streak: Int
    let weekCount: Int
    let goalMet: Bool
    let graceLeft: Double?
    let urgent: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 13) {
                // Circle icon
                circleIcon
                // Label
                labelStack
                Spacer()
                // Pip dots
                pipDots
                // Streak counter
                streakBadge
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(rowBackground)
        }
        .buttonStyle(.plain)
    }

    private var circleIcon: some View {
        ZStack {
            Circle()
                .fill(done ? Color.red.opacity(0.15) : Color.clear)
                .frame(width: 36, height: 36)
            Circle()
                .strokeBorder(Color.red.opacity(done ? 0 : 0.55), lineWidth: 1.5)
                .frame(width: 36, height: 36)
            Image(systemName: done ? "checkmark" : "figure.run")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(done ? .red : Color.red.opacity(0.55))
                .scaleEffect(done ? 1.05 : 0.9)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
        }
    }

    private var labelStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Training")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(done ? .primary : Color.red.opacity(0.7))
            subtitleText
                .font(.system(size: 10, weight: .medium))
        }
    }

    @ViewBuilder
    private var subtitleText: some View {
        if let gl = graceLeft, gl > 0, !done {
            Text(String(format: "%.0fh left in grace window", gl))
                .foregroundStyle(urgent ? .orange : .secondary)
        } else if done {
            Text("\(weekCount)/3 this week")
                .foregroundStyle(goalMet ? Color.green : Color(uiColor: .secondaryLabel))
        } else {
            Text("\(weekCount)/3 this week")
                .foregroundStyle(.secondary)
        }
    }

    private var pipDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(i < weekCount ? Color.red : Color.red.opacity(0.15))
                    .frame(width: 6, height: 6)
                    .animation(.spring(response: 0.35).delay(Double(i) * 0.06), value: weekCount)
            }
        }
    }

    private var streakBadge: some View {
        VStack(spacing: 1) {
            Text("\(streak)")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(streak > 0 ? Color.red : Color.red.opacity(0.30))
                .contentTransition(.numericText())
            Text(streak == 1 ? "workout" : "workouts")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(streak > 0 ? Color.red.opacity(0.6) : Color.red.opacity(0.20))
                .kerning(0.2)
        }
        .frame(minWidth: 40, alignment: .center)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(streak > 0 ? Color.red.opacity(0.09) : Color.red.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.red.opacity(streak > 0 ? 0.20 : 0.10), lineWidth: 1)
                )
        )
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(uiColor: .secondarySystemBackground))
    }
}
