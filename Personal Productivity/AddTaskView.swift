import SwiftUI

// MARK: - Shared form card style

struct FormCard<Content: View, Trailing: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let trailing: Trailing
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                trailing
            }
            content
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// Convenience overload — no trailing view (keeps all existing call sites working)
extension FormCard where Trailing == EmptyView {
    init(icon: String, iconColor: Color, title: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.trailing = EmptyView()
        self.content = content()
    }
}

// MARK: - AddTaskView

struct AddTaskView: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var taskStore: TaskStore
    let onSave: (FocusTask) -> Void

    @State private var title: String = ""
    @State private var focusMinutes: Int = 25
    @State private var selectedDate = Date().addingTimeInterval(3600)
    @State private var recurrence: RecurrenceType = .once
    @State private var customDays: Set<Weekday> = []
    @State private var intention: String = ""
    @State private var intentionPreset: String? = nil
    @State private var titlePreset: String? = nil
    @State private var showCalendarPicker = false
    @State private var schedulingAdvice: [TaskSchedulingAdvisor.Advice] = []
    @FocusState private var isAnyFieldFocused: Bool

    private struct PendingCategoryConfirmation: Identifiable {
        let id = UUID()
        let task: FocusTask
        let suggestion: TaskCategorizer.Result
    }
    @State private var pendingCategoryConfirmation: PendingCategoryConfirmation? = nil

    private let minuteOptions = Array(stride(from: 5, through: 600, by: 5))
    private let categoryConfirmationThreshold: Double = 0.65

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60; let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)min"
    }

    private var isOnce: Bool { recurrence == .once }
    private var isTitleValid: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }
    private var isDateValid: Bool { selectedDate > Date() }
    private var isRecurrenceValid: Bool { recurrence != .custom || !customDays.isEmpty }

    private var canSave: Bool {
        guard isTitleValid && isRecurrenceValid else { return false }
        if isOnce { return isDateValid }
        return true
    }

    // MARK: - Date helpers

    /// Date wheel options: today + 364 more days
    private var dateOptions: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<365).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }
    private var hourOptions: [Int] { Array(0..<24) }
    private var minuteStepOptions: [Int] { Array(stride(from: 0, through: 55, by: 5)) }

    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    // 24-hour label: "00" … "23"
    private func hourLabel(_ h: Int) -> String { String(format: "%02d", h) }

    private var selectedDay: Date { Calendar.current.startOfDay(for: selectedDate) }
    private var selectedHour: Int { Calendar.current.component(.hour, from: selectedDate) }
    private var selectedMinuteStep: Int {
        let m = Calendar.current.component(.minute, from: selectedDate)
        return (m / 5) * 5
    }

    private func setDay(_ day: Date) {
        var comps = Calendar.current.dateComponents([.hour, .minute], from: selectedDate)
        let dc = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.year = dc.year; comps.month = dc.month; comps.day = dc.day
        selectedDate = Calendar.current.date(from: comps) ?? selectedDate
    }
    private func setHour(_ h: Int) {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: selectedDate)
        comps.hour = h; comps.minute = 0
        selectedDate = Calendar.current.date(from: comps) ?? selectedDate
    }
    private func setMinute(_ m: Int) {
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: selectedDate)
        comps.minute = m
        selectedDate = Calendar.current.date(from: comps) ?? selectedDate
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {

                    // MARK: Task name
                    FormCard(icon: "pencil", iconColor: .accentColor, title: "Task name") {
                        TextField("What do you want to work on?", text: $title)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .focused($isAnyFieldFocused)
                            .onChange(of: title) { _, _ in
                                if title != titlePreset { titlePreset = nil }
                            }

                        // Preset name chips
                        let taskNamePresets = AppSettingsStore.shared.taskNamePresets
                        FlowLayout(spacing: 8) {
                            ForEach(taskNamePresets, id: \.self) { preset in
                                Button {
                                    titlePreset = preset
                                    title = preset
                                } label: {
                                    Text(preset)
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(titlePreset == preset ? Color.accentColor : Color.primary.opacity(0.07))
                                        .foregroundStyle(titlePreset == preset ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // MARK: Focus duration
                    FormCard(icon: "timer", iconColor: .orange, title: "Focus duration") {
                        Picker("Focus duration", selection: $focusMinutes) {
                            ForEach(minuteOptions, id: \.self) { m in
                                Text(durationLabel(m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // MARK: Recurrence
                    FormCard(icon: "repeat", iconColor: .indigo, title: "Recurrence") {
                        Picker("Recurrence", selection: $recurrence) {
                            Text("Once").tag(RecurrenceType.once)
                            Text("Daily").tag(RecurrenceType.daily)
                            Text("Weekdays").tag(RecurrenceType.weekdays)
                            Text("Custom").tag(RecurrenceType.custom)
                        }
                        .pickerStyle(.segmented)
                    }

                    // MARK: Custom days
                    if recurrence == .custom {
                        FormCard(icon: "calendar.badge.checkmark", iconColor: .teal, title: "Repeat on") {
                            HStack(spacing: 6) {
                                ForEach(Weekday.allCases) { day in
                                    Button {
                                        if customDays.contains(day) { customDays.remove(day) }
                                        else { customDays.insert(day) }
                                    } label: {
                                        Text(day.shortName)
                                            .font(.caption.bold())
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(customDays.contains(day) ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
                                            .foregroundStyle(customDays.contains(day) ? Color.white : Color.secondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: Date / time
                    FormCard(
                        icon: isOnce ? "calendar" : "clock",
                        iconColor: .green,
                        title: isOnce ? "Scheduled for" : "Start time",
                        trailing: {
                            if isOnce {
                                Button { showCalendarPicker = true } label: {
                                    Image(systemName: "calendar")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                        .frame(width: 30, height: 30)
                                        .background(Color.accentColor.opacity(0.12), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    ) {
                        if isOnce {
                            // Three-column wheel: Date | Hour : Minute
                            HStack(spacing: 0) {
                                Picker("Date", selection: Binding(
                                    get: { selectedDay },
                                    set: { setDay($0) }
                                )) {
                                    ForEach(dateOptions, id: \.self) { d in
                                        Text(dateLabel(d)).tag(d)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)

                                Picker("Hour", selection: Binding(
                                    get: { selectedHour },
                                    set: { setHour($0) }
                                )) {
                                    ForEach(hourOptions, id: \.self) { h in
                                        Text(hourLabel(h)).tag(h)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 64)

                                Text(":")
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)

                                Picker("Minute", selection: Binding(
                                    get: { selectedMinuteStep },
                                    set: { setMinute($0) }
                                )) {
                                    ForEach(minuteStepOptions, id: \.self) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(width: 64)
                            }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        } else {
                            // Start time — hour : minute only
                            HStack(spacing: 0) {
                                Picker("Hour", selection: Binding(
                                    get: { selectedHour },
                                    set: { setHour($0) }
                                )) {
                                    ForEach(hourOptions, id: \.self) { h in
                                        Text(hourLabel(h)).tag(h)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)

                                Text(":")
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 16)

                                Picker("Minute", selection: Binding(
                                    get: { selectedMinuteStep },
                                    set: { setMinute($0) }
                                )) {
                                    ForEach(minuteStepOptions, id: \.self) { m in
                                        Text(String(format: "%02d", m)).tag(m)
                                    }
                                }
                                .pickerStyle(.wheel)
                                .frame(maxWidth: .infinity)
                            }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                // ── Scheduling advice banners ────────────────────────
                if !schedulingAdvice.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(schedulingAdvice.indices, id: \.self) { idx in
                            let advice = schedulingAdvice[idx]
                            SchedulingAdviceBanner(
                                advice: advice,
                                onApplyTime: { newDate in
                                    withAnimation { selectedDate = newDate }
                                },
                                onApplyDuration: { mins in
                                    withAnimation { focusMinutes = mins }
                                }
                            )
                        }
                    }
                }

                // MARK: Intention (optional)
                FormCard(icon: "text.quote", iconColor: .purple, title: "Intention") {
                    VStack(alignment: .leading, spacing: 10) {
                        // Preset chips
                        let presets = AppSettingsStore.shared.intentionPresets
                        FlowLayout(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    intentionPreset = preset
                                    intention = preset
                                } label: {
                                    Text(preset)
                                        .font(.system(size: 12, weight: .medium))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(intentionPreset == preset ? Color.purple : Color.primary.opacity(0.07))
                                        .foregroundStyle(intentionPreset == preset ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        TextField("What will you accomplish in this session?", text: $intention, axis: .vertical)
                            .font(.body)
                            .lineLimit(3...5)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .focused($isAnyFieldFocused)
                            .onChange(of: intention) { _, _ in
                                if intention != intentionPreset { intentionPreset = nil }
                            }
                        Text("Optional — if set, the app won't ask again when you start this task.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.2), value: recurrence)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: title) { _, _ in refreshAdvice() }
            .onChange(of: focusMinutes) { _, _ in refreshAdvice() }
            .onChange(of: selectedDate) { _, _ in refreshAdvice() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { saveTask() } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundStyle(canSave ? Color.accentColor : Color.secondary)
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showCalendarPicker) {
                CalendarPickerSheet(selectedDate: $selectedDate)
            }
        }
        .floatingKeyboardDismiss(isVisible: isAnyFieldFocused)
        .sheet(item: $pendingCategoryConfirmation) { pending in
            TaskCategoryConfirmationSheet(
                title: pending.task.title,
                suggested: pending.suggestion.category,
                confidence: pending.suggestion.confidence,
                onConfirm: { chosen in
                    TaskCategoryStore.shared.set(category: chosen, for: pending.task.id, confirmed: true)
                    TaskCategorizationLearningStore.shared.recordUserCorrection(title: pending.task.title, category: chosen)
                    let trimmedIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmedIntention.isEmpty {
                        SessionIntentionStore.shared.set(trimmedIntention, for: pending.task.id)
                    }
                    onSave(pending.task)
                    pendingCategoryConfirmation = nil
                    dismiss()
                }
            )
        }
    }

    private func refreshAdvice() {
        guard isTitleValid else { schedulingAdvice = []; return }
        schedulingAdvice = TaskSchedulingAdvisor.advise(
            title: title,
            durationMinutes: focusMinutes,
            scheduledTime: selectedDate,
            existingTasks: taskStore.tasks,
            sessionLogs: taskStore.sessionLogs
        )
    }

    private func saveTask() {
        guard canSave else { return }
        let focusBlock = FocusBlock(duration: focusMinutes * 60, type: .focus)
        let baseTask = FocusTask(
            title: title.trimmingCharacters(in: .whitespaces),
            focusPlan: FocusPlan(blocks: [focusBlock]),
            status: .pending,
            scheduledTime: selectedDate,
            recurrenceType: recurrence,
            recurrenceDays: recurrence == .custom ? customDays.map { $0.rawValue } : nil
        )
        let suggestion = TaskCategorizer.categorize(title: baseTask.title)
        if suggestion.confidence < categoryConfirmationThreshold {
            pendingCategoryConfirmation = PendingCategoryConfirmation(task: baseTask, suggestion: suggestion)
            return
        }
        TaskCategoryStore.shared.set(category: suggestion.category, for: baseTask.id, confirmed: true)
        TaskCategorizationLearningStore.shared.recordUserCorrection(title: baseTask.title, category: suggestion.category)
        let trimmedIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedIntention.isEmpty {
            SessionIntentionStore.shared.set(trimmedIntention, for: baseTask.id)
        }
        onSave(baseTask)
        dismiss()
    }
}

// MARK: - Scheduling Advice Banner

struct SchedulingAdviceBanner: View {
    let advice: TaskSchedulingAdvisor.Advice
    let onApplyTime: (Date) -> Void
    let onApplyDuration: (Int) -> Void

    private var icon: String {
        switch advice.kind {
        case .overlap:       return "exclamationmark.triangle.fill"
        case .durationTooLong, .breakItUp: return "scissors"
        case .betterTimeSlot: return "clock.badge.checkmark"
        }
    }

    private var color: Color {
        switch advice.kind {
        case .overlap:       return .red
        case .breakItUp, .durationTooLong: return .orange
        case .betterTimeSlot: return .blue
        }
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(advice.message)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                if let newTime = advice.suggestedTime {
                    Button("Move to " + shortTime(newTime)) {
                        onApplyTime(newTime)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
                }

                if let mins = advice.suggestedDurationMinutes {
                    Button("Use \(mins)m") {
                        onApplyDuration(mins)
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
        .padding(14)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Calendar picker sheet (shared by Add & Edit)

struct CalendarPickerSheet: View {
    @Binding var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    @State private var displayedMonth: Date
    @State private var showMonthYearPicker = false

    // Wheel picker state
    @State private var pickerMonth: Int
    @State private var pickerYear: Int

    private let cal = Calendar.current
    private let today = Calendar.current.startOfDay(for: Date())

    // Sheet is always tall enough for 6 rows + header + weekday row
    // header(64) + weekday(24) + grid(6×40=240) + bottom(16) = 344
    private static let fixedHeight: CGFloat = 344

    private static let monthNames = DateFormatter().monthSymbols ?? [
        "January","February","March","April","May","June",
        "July","August","September","October","November","December"
    ]
    private static let yearRange = Array(2025...2035)

    init(selectedDate: Binding<Date>) {
        self._selectedDate = selectedDate
        let start = Calendar.current.startOfDay(for: selectedDate.wrappedValue)
        let comps = Calendar.current.dateComponents([.year, .month], from: start)
        let month = Calendar.current.date(from: comps) ?? start
        self._displayedMonth = State(initialValue: month)
        self._pickerMonth = State(initialValue: comps.month ?? 1)
        self._pickerYear  = State(initialValue: comps.year  ?? 2025)
    }

    // MARK: - Helpers

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: displayedMonth)
    }

    private func go(by offset: Int) {
        guard let next = cal.date(byAdding: .month, value: offset, to: displayedMonth) else { return }
        displayedMonth = next
        let c = cal.dateComponents([.year, .month], from: next)
        pickerMonth = c.month ?? pickerMonth
        pickerYear  = c.year  ?? pickerYear
    }

    private func applyWheelPicker() {
        var comps = DateComponents()
        comps.year = pickerYear
        comps.month = pickerMonth
        comps.day = 1
        if let date = cal.date(from: comps) { displayedMonth = date }
        showMonthYearPicker = false
    }

    private var dayCells: [Date?] {
        guard let range = cal.range(of: .day, in: .month, for: displayedMonth),
              let first = cal.date(from: cal.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }
        let offset = (cal.component(.weekday, from: first) + 5) % 7
        var cells: [Date?] = Array(repeating: nil, count: offset)
        for d in range { cells.append(cal.date(byAdding: .day, value: d - 1, to: first)) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var selectedDay: Date { cal.startOfDay(for: selectedDate) }
    private func isSelected(_ d: Date) -> Bool { cal.isDate(d, inSameDayAs: selectedDay) }
    private func isToday(_ d: Date)    -> Bool { cal.isDateInToday(d) }
    private func isPast(_ d: Date)     -> Bool { d < today }

    private func pickDay(_ date: Date) {
        var dc = cal.dateComponents([.year, .month, .day], from: date)
        let tc = cal.dateComponents([.hour, .minute], from: selectedDate)
        dc.hour = tc.hour; dc.minute = tc.minute
        selectedDate = cal.date(from: dc) ?? date
        dismiss()
    }

    // MARK: - Layout constants
    private let columns   = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
    private let dayLetters = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        VStack(spacing: 0) {

            // ── Header — always fixed, never moves ───────────────────────────
            HStack(spacing: 4) {
                Button { withAnimation(.easeInOut(duration: 0.22)) { go(by: -1) } } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Circle())
                }
                .foregroundStyle(.primary)
                .opacity(showMonthYearPicker ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: showMonthYearPicker)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showMonthYearPicker.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(monthTitle)
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: showMonthYearPicker ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Capsule())
                }

                Spacer()

                Button { withAnimation(.easeInOut(duration: 0.22)) { go(by: 1) } } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground), in: Circle())
                }
                .foregroundStyle(.primary)
                .opacity(showMonthYearPicker ? 0 : 1)
                .animation(.easeInOut(duration: 0.15), value: showMonthYearPicker)
            }
            .frame(height: 50)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // ── Body region — fixed height, grid and picker share the same space ──
            ZStack(alignment: .top) {

                // Day-of-week + grid (shown when picker is hidden)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        ForEach(Array(dayLetters.enumerated()), id: \.offset) { i, letter in
                            Text(letter)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(i >= 5 ? Color.accentColor.opacity(0.7) : Color.secondary)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 24)
                    .padding(.horizontal, 12)

                    LazyVGrid(columns: columns, spacing: 0) {
                        ForEach(Array(dayCells.enumerated()), id: \.offset) { _, date in
                            if let date {
                                let past      = isPast(date)
                                let selected  = isSelected(date)
                                let todayMark = isToday(date)
                                let isWeekend = { let wd = cal.component(.weekday, from: date); return wd == 1 || wd == 7 }()

                                Button { if !past { pickDay(date) } } label: {
                                    Text("\(cal.component(.day, from: date))")
                                        .font(.system(size: 15, weight: selected ? .bold : .regular))
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 36)
                                        .background(
                                            selected  ? Color.accentColor :
                                            todayMark ? Color.accentColor.opacity(0.15) : Color.clear,
                                            in: Circle()
                                        )
                                        .foregroundStyle(
                                            selected  ? Color.white :
                                            past      ? Color.secondary.opacity(0.28) :
                                            isWeekend ? Color.accentColor.opacity(0.8) :
                                                        Color.primary
                                        )
                                }
                                .disabled(past)
                            } else {
                                Color.clear.frame(height: 36)
                            }
                        }
                    }
                    .frame(height: 6 * 40, alignment: .top)
                    .padding(.horizontal, 12)
                }
                .opacity(showMonthYearPicker ? 0 : 1)
                .animation(.easeInOut(duration: 0.18), value: showMonthYearPicker)

                // Month / year wheel picker (shown when picker is visible)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Picker("Month", selection: $pickerMonth) {
                            ForEach(1...12, id: \.self) { m in
                                Text(Self.monthNames[m - 1]).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)

                        Picker("Year", selection: $pickerYear) {
                            ForEach(Self.yearRange, id: \.self) { y in
                                Text(String(y)).tag(y)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 100)
                    }
                    .frame(height: 24 + 4 * 40)   // same as weekday row + 4 visible rows

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { applyWheelPicker() }
                    } label: {
                        Text("OK")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentColor,
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 16)
                    }
                    .frame(height: 2 * 40)
                }
                .opacity(showMonthYearPicker ? 1 : 0)
                .animation(.easeInOut(duration: 0.18), value: showMonthYearPicker)
            }
            .frame(height: 24 + 6 * 40)  // weekday row (24) + 6 grid rows (240) — never changes
            .padding(.bottom, 12)
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { v in
                    guard !showMonthYearPicker else { return }
                    let h = v.translation.width
                    guard abs(h) > abs(v.translation.height), abs(h) > 30 else { return }
                    withAnimation(.easeInOut(duration: 0.22)) { go(by: h < 0 ? 1 : -1) }
                }
        )
        .presentationDetents([.height(Self.fixedHeight)])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(24)
        .presentationBackground(Color(uiColor: .secondarySystemGroupedBackground))
    }
}



// MARK: - Weekday

enum Weekday: Int, CaseIterable, Identifiable, Codable {
    case mon = 1, tue, wed, thu, fri, sat, sun
    var id: Int { rawValue }
    var shortName: String {
        switch self {
        case .mon: return "Mon"
        case .tue: return "Tue"
        case .wed: return "Wed"
        case .thu: return "Thu"
        case .fri: return "Fri"
        case .sat: return "Sat"
        case .sun: return "Sun"
        }
    }
}

// MARK: - Flow layout (for intention preset chips)

