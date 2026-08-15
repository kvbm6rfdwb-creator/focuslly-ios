import SwiftUI

struct FocusTabView: View {

    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var coordinator: FocusSessionCoordinator
    @EnvironmentObject var settings: AppSettingsStore

    var body: some View {
        NavigationStack {
            if let task = taskStore.activeFocusTask {
                FocusEngineHostView(task: task)
                    .id(task.id)
            } else {
                FocusIdleView()
                    .environmentObject(settings)
                    .navigationTitle("Focus")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        // Fix #6: suppress sheet when intention is already stored — .onChange handles that fast
        // path. Sheet only presents when user input is still required. This eliminates the
        // double-start race where both paths fired simultaneously.
        .sheet(item: Binding<FocusTask?>(
            get: {
                guard let next = taskStore.pendingChainTask else { return nil }
                return SessionIntentionStore.shared.get(for: next.id) == nil ? next : nil
            },
            set: { _ in }
        )) { next in
            SessionPreparationSheet(task: next) { intention in
                if let intention, !intention.isEmpty {
                    SessionIntentionStore.shared.set(intention, for: next.id)
                }
                coordinator.startFocus(task: next)
                taskStore.confirmChainTask(next)
            }
            .interactiveDismissDisabled(true)
        }
        .onChange(of: taskStore.pendingChainTask) { _, next in
            guard let next else { return }
            // Only fast-path when intention is already stored; sheet handles the other case.
            guard SessionIntentionStore.shared.get(for: next.id) != nil else { return }
            coordinator.startFocus(task: next)
            taskStore.confirmChainTask(next)
        }
    }
}

// MARK: - Idle View
private struct FocusIdleView: View {

    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var coordinator: FocusSessionCoordinator
    @EnvironmentObject var settings: AppSettingsStore

    @State private var appeared = false
    @State private var preparingTask: FocusTask? = nil
    @State private var quickStartPreset: AppSettingsStore.QuickStartTaskPreset? = nil
    @State private var showMealLog = false
    @State private var mealTick = 0
    // Fix #3: ratings dict cached in @State; reloaded on appear and on session log changes,
    // not decoded from UserDefaults on every render pass.
    @State private var sessionRatings: [String: String] = [:]

    private var mealStore: MealStore { MealStore.shared }

    // MARK: - Recommended task
    private var recommendedTask: FocusTask? {
        let now = Date()
        return taskStore.getTodaysTasks().min { lhs, rhs in
            let lTime = lhs.scheduledTime ?? lhs.startDate
            let rTime = rhs.scheduledTime ?? rhs.startDate
            let lDiff = abs(lTime.timeIntervalSince(now))
            let rDiff = abs(rTime.timeIntervalSince(now))
            if abs(lDiff - rDiff) < 60 {
                let lDur = lhs.focusPlan.blocks.first(where: { $0.type == .focus })?.duration ?? Int.max
                let rDur = rhs.focusPlan.blocks.first(where: { $0.type == .focus })?.duration ?? Int.max
                return lDur < rDur
            }
            let lOverdue = lTime <= now
            let rOverdue = rTime <= now
            if lOverdue != rOverdue { return lOverdue }
            return lDiff < rDiff
        }
    }

    private func taskTitle(for log: FocusSessionLog) -> String {
        taskStore.tasks.first { $0.id == log.taskId }?.title ?? "Session"
    }

    // MARK: - Daily progress

    // Fix #4: single computed property that derives the full Set once; all dependent
    // properties read todayProgress so completedTodayTaskIds is never built more than
    // once per body evaluation.
    private var todayProgress: (done: Int, total: Int, focusMinutes: Int) {
        let doneIds: Set<UUID> = Set(
            taskStore.sessionLogs
                .filter {
                    ($0.exitReason == .completed || $0.exitReason == .prolonged)
                    && Calendar.current.isDateInToday($0.startDate)
                }
                .map { $0.taskId }
        )
        let done = doneIds.count
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
        let pending = taskStore.tasks.filter { task in
            guard task.status == .pending, !doneIds.contains(task.id) else { return false }
            let taskDate = task.scheduledTime ?? task.startDate
            return taskDate < tomorrowStart
        }.count
        let mins = taskStore.sessionLogs
            .filter {
                ($0.exitReason == .completed || $0.exitReason == .prolonged)
                && Calendar.current.isDateInToday($0.startDate)
            }
            .reduce(0) { $0 + $1.durationMinutes }
        return (done: done, total: done + pending, focusMinutes: mins)
    }

    // MARK: - Ratings cache helper
    private func reloadRatings() {
        sessionRatings = (UserDefaults.standard.dictionary(forKey: SessionRatingSheet.ratingsKey)
            as? [String: String]) ?? [:]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                if let task = recommendedTask {
                    recommendedTaskCard(task: task)
                } else {
                    allClearCard
                }
                dailyProgressCard
                quickStartCard
                sessionHistoryCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { appeared = true }
            reloadRatings() // Fix #3
        }
        // Fix #3: refresh ratings cache whenever session logs change.
        .onChange(of: taskStore.sessionLogs) { _, _ in reloadRatings() }
        .sheet(item: $preparingTask) { task in
            SessionPreparationSheet(task: task) { intention in
                taskStore.startFocus(task: task)
                coordinator.startFocus(task: task)
                if let intention, !intention.isEmpty {
                    SessionIntentionStore.shared.set(intention, for: task.id)
                }
            }
        }
        .sheet(item: $quickStartPreset) { preset in
            QuickStartSheet(preset: preset) { minutes, intention in
                startQuickSession(
                    title: preset.title,
                    minutes: minutes,
                    intention: intention,
                    pipelineCategory: PipelineTaskCategory(rawValue: preset.pipelineCategoryRaw ?? "")
                )
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showMealLog = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "fork.knife")
                            .font(.system(size: 15, weight: .semibold))
                        if mealStore.isHungry || mealStore.hasNotEatenToday {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 7, height: 7)
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .foregroundStyle(Color.primary)
            }
        }
        .sheet(isPresented: $showMealLog) { MealLogView() }
        .onReceive(MealStore.shared.$entries) { _ in mealTick += 1 }
    }

    // MARK: - Recommended task card
    private func recommendedTaskCard(task: FocusTask) -> some View {
        let mins = (task.focusPlan.blocks.first(where: { $0.type == .focus })?.duration ?? 0) / 60
        let scheduledTime = task.scheduledTime ?? task.startDate
        let isOverdue = scheduledTime < Date()
        let timeLabel: String = {
            if isOverdue {
                let ago = Int(Date().timeIntervalSince(scheduledTime) / 60)
                return ago < 60 ? "\(ago)m overdue" : "\(ago / 60)h overdue"
            } else {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                return "at \(formatter.string(from: scheduledTime))"
            }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text("RECOMMENDED")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(1)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: isOverdue ? "clock.badge.exclamationmark" : "clock")
                        .font(.system(size: 11))
                    Text(timeLabel)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(isOverdue ? Color.red : Color.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background((isOverdue ? Color.red : Color(uiColor: .tertiarySystemFill)).opacity(isOverdue ? 0.12 : 1))
                .clipShape(Capsule())
            }

            Text(task.title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 10) {
                Button {
                    HapticManager.impact()
                    startTask(task)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Start \u{00B7} \(mins)m")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.brg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
                }

                if taskStore.getTodaysTasks().count > 1 {
                    Button {
                        HapticManager.impact()
                        taskStore.skipTask(task)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private func startTask(_ task: FocusTask) {
        if SessionIntentionStore.shared.get(for: task.id) != nil {
            taskStore.startFocus(task: task)
            coordinator.startFocus(task: task)
        } else {
            preparingTask = task
        }
    }

    // MARK: - All clear card
    private var allClearCard: some View {
        HStack(spacing: 14) {
            Text("\u{1F389}").font(.system(size: 32))
            VStack(alignment: .leading, spacing: 3) {
                Text("All caught up!")
                    .font(.headline)
                Text("No tasks remaining today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(18)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: - Daily progress card
    private var dailyProgressCard: some View {
        // Fix #4: single call; no repeated Set construction.
        let stats    = todayProgress
        let total    = stats.total
        let done     = stats.done
        let progress = total > 0 ? Double(done) / Double(total) : 0.0
        let mins     = stats.focusMinutes

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's plan")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(done) of \(total) done")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.brg)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(duration: 0.6), value: progress)
                }
            }
            .frame(height: 6)

            HStack {
                Label(
                    mins < 60 ? "\(mins)m focused" : "\(mins / 60)h \(mins % 60)m focused",
                    systemImage: "bolt.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                Spacer()
                if progress >= 1 {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: - Quick Start card
    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Quick start")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Tap to start")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            VStack(spacing: 10) {
                ForEach(settings.quickStartTaskPresets) { preset in
                    Button {
                        HapticManager.impact()
                        quickStartPreset = preset
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Color.brg)
                                    .frame(width: 36, height: 36)
                                Image(systemName: preset.icon)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.brgBright, Color.white.opacity(0.7)]),
                                            startPoint: .top, endPoint: .bottom
                                        )
                                    )
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(preset.description)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(preset.defaultMinutes)m")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: - Session history card
    private var sessionHistoryCard: some View {
        let todaySessions = taskStore.sessionLogs
            .filter {
                ($0.exitReason == .completed || $0.exitReason == .prolonged)
                && Calendar.current.isDateInToday($0.startDate)
            }
            .sorted { $0.startDate > $1.startDate }
        // Fix #3: use cached @State value — no UserDefaults decode on render.
        let ratings = sessionRatings

        return Group {
            if !todaySessions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {

                    HStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text("Today's Sessions")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Text("\(todaySessions.count) completed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                    ForEach(Array(todaySessions.enumerated()), id: \.element.id) { index, log in
                        let mins = log.durationMinutes
                        let title = taskTitle(for: log)
                        let ratingKey = SessionRatingSheet.ratingKey(taskId: log.taskId, startDate: log.startDate)
                        let rating = ratings[ratingKey]

                        let ratingColor: Color = {
                            switch rating {
                            case "Went well":  return .primary
                            case "Distracted": return .orange
                            case "Too long":   return .red
                            default:           return Color(uiColor: .quaternaryLabel)
                            }
                        }()

                        let ratingIcon: String = {
                            switch rating {
                            case "Went well":  return "hand.thumbsup.fill"
                            case "Distracted": return "eye.slash.fill"
                            case "Too long":   return "clock.badge.exclamationmark.fill"
                            default:           return "circle.fill"
                            }
                        }()

                        if index > 0 {
                            Divider().padding(.leading, 52)
                        }

                        HStack(spacing: 12) {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(log.startDate.formatted(.dateTime.hour().minute()))
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.secondary)
                                Text("\u{2013}")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color(uiColor: .quaternaryLabel))
                                Text(log.endDate.formatted(.dateTime.hour().minute()))
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
                            }
                            .frame(width: 36)

                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(ratingColor.opacity(rating != nil ? 0.5 : 0.15))
                                .frame(width: 3)
                                .frame(maxHeight: .infinity)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text("\(mins) min")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            if let rating {
                                HStack(spacing: 4) {
                                    Image(systemName: ratingIcon)
                                        .font(.system(size: 10, weight: .semibold))
                                    Text(rating)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundStyle(ratingColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(ratingColor.opacity(0.1))
                                .clipShape(Capsule())
                            } else {
                                Circle()
                                    .fill(Color(uiColor: .quaternaryLabel))
                                    .frame(width: 6, height: 6)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }

                    Spacer(minLength: 12)
                }
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)
            }
        }
    }

    // MARK: - Actions
    private func startQuickSession(title: String, minutes: Int, intention: String?,
                                   pipelineCategory: PipelineTaskCategory? = nil) {
        let duration = minutes * 60
        let plan = FocusPlan(blocks: [FocusBlock(duration: duration, type: .focus)])
        var task = FocusTask(
            title: title,
            focusPlan: plan,
            startDate: Date(),
            recurrenceType: .once
        )
        task.scheduledTime = Date()
        task.pipelineCategory = pipelineCategory
        if let intention, !intention.isEmpty {
            SessionIntentionStore.shared.set(intention, for: task.id)
        }
        taskStore.addTask(task)
        taskStore.startFocus(task: task)
        coordinator.startFocus(task: task)
    }
}

// MARK: - Quick Start Sheet
private struct QuickStartSheet: View {
    let preset: AppSettingsStore.QuickStartTaskPreset
    let onStart: (Int, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var minutes: Int
    @State private var intention: String = ""
    @State private var selectedPreset: String? = nil
    @FocusState private var intentionFocused: Bool

    init(preset: AppSettingsStore.QuickStartTaskPreset, onStart: @escaping (Int, String?) -> Void) {
        self.preset = preset
        self.onStart = onStart
        _minutes = State(initialValue: preset.defaultMinutes)
    }

    private let steps = [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 75, 90, 120]

    private var intentionPresets: [String] { settings.intentionPresets }

    // Fix #5: snap any value not present in steps to the nearest valid entry.
    private func nearestStep(to value: Int) -> Int {
        steps.min(by: { abs($0 - value) < abs($1 - value) }) ?? value
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(preset.color.opacity(0.12))
                                .frame(width: 52, height: 52)
                            Image(systemName: preset.icon)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(preset.color)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preset.title)
                                .font(.system(size: 18, weight: .bold))
                            Text(preset.description)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("DURATION")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(0.4)

                        HStack(spacing: 16) {
                            Button {
                                HapticManager.impact()
                                if let idx = steps.firstIndex(of: minutes), idx > 0 {
                                    minutes = steps[idx - 1]
                                }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(minutes > (steps.first ?? 5) ? preset.color : Color(uiColor: .tertiaryLabel))
                            }
                            .buttonStyle(.plain)

                            Spacer()
                            VStack(spacing: 2) {
                                Text("\(minutes)")
                                    .font(.system(size: 52, weight: .bold, design: .rounded))
                                    .foregroundStyle(preset.color)
                                    .contentTransition(.numericText())
                                    .animation(.spring(response: 0.3), value: minutes)
                                Text("minutes")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()

                            Button {
                                HapticManager.impact()
                                if let idx = steps.firstIndex(of: minutes), idx < steps.count - 1 {
                                    minutes = steps[idx + 1]
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(minutes < (steps.last ?? 120) ? preset.color : Color(uiColor: .tertiaryLabel))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                let chips = settings.setTimePresets.isEmpty
                                    ? [15, 25, 30, 45, 60, 90]
                                    : settings.setTimePresets.map(\.minutes)
                                ForEach(chips, id: \.self) { m in
                                    Button {
                                        HapticManager.impact()
                                        // Fix #5: always land on a value steps knows about.
                                        minutes = nearestStep(to: m)
                                    } label: {
                                        let snapped = nearestStep(to: m)
                                        Text("\(m)m")
                                            .font(.system(size: 13, weight: .semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(minutes == snapped ? preset.color : Color(uiColor: .tertiarySystemFill))
                                            .foregroundStyle(minutes == snapped ? .white : .primary)
                                            .clipShape(Capsule())
                                            .animation(.easeInOut(duration: 0.15), value: minutes == snapped)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("INTENTION (OPTIONAL)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(0.4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(intentionPresets, id: \.self) { p in
                                    Button {
                                        HapticManager.impact()
                                        selectedPreset = p
                                        intention = p
                                    } label: {
                                        Text(p)
                                            .font(.system(size: 12, weight: .medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(selectedPreset == p ? preset.color : Color(uiColor: .tertiarySystemFill))
                                            .foregroundStyle(selectedPreset == p ? .white : .primary)
                                            .clipShape(Capsule())
                                            .animation(.easeInOut(duration: 0.15), value: selectedPreset == p)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }

                        TextField("What do you want to achieve in this session?", text: $intention, axis: .vertical)
                            .font(.system(size: 15))
                            .textFieldStyle(.plain)
                            .lineLimit(2...4)
                            .padding(14)
                            .background(Color(uiColor: .tertiarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($intentionFocused)
                            .onChange(of: intention) { _, newVal in
                                if newVal != selectedPreset { selectedPreset = nil }
                            }
                    }

                    Button {
                        HapticManager.impact(.medium)
                        onStart(minutes, intention.isEmpty ? nil : intention)
                        dismiss()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Start \(preset.title) \u{00B7} \(minutes)m")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(preset.color)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .buttonStyle(.plain)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Quick Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .floatingKeyboardDismiss(isVisible: intentionFocused)
        .presentationDetents([.fraction(0.82)])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Fix #5: snap initial value on sheet open in case preset.defaultMinutes
            // is not already in steps.
            minutes = nearestStep(to: minutes)
        }
    }
}

// MARK: - FocusEngineHostView
// Fix #1: engine is initialised with taskStore: nil (idle, no timer). setTaskStore() is called
// first in onAppear, then FocusView.onAppear calls engine.start() — guaranteeing taskStore is
// non-nil before the first tick can fire.
//
// Fix #2: onExit closure removed from this view's public API. The original call site always
// passed { _ in }, making it dead API. Exit routing is owned entirely by FocusView and
// FocusSessionCoordinator; surfacing it here created a misleading seam. Removing it makes
// ownership unambiguous and eliminates the risk of a future caller accidentally shadowing
// the coordinator's exit handling.
private struct FocusEngineHostView: View {
    let task: FocusTask

    @EnvironmentObject private var taskStore: TaskStore
    @StateObject private var engine: FocusSessionEngine

    init(task: FocusTask) {
        self.task = task
        _engine = StateObject(wrappedValue: FocusSessionEngine(task: task, taskStore: nil))
    }

    var body: some View {
        FocusView(engine: engine)
            .onAppear {
                // Wire store first — engine.start() (called inside FocusView.onAppear)
                // is guaranteed to see a non-nil taskStore from this point on.
                engine.setTaskStore(taskStore)
            }
            .id(engine.task.id)
    }
}
