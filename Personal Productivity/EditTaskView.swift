import SwiftUI

// MARK: - Edit State

struct EditTaskState: Equatable {
    var title: String
    var durationMinutes: Int
    var scheduledDateTime: Date
    var recurrenceType: RecurrenceType
    var recurrenceDays: [Int]
}

// MARK: - EditTaskView

struct EditTaskView: View {
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss

    let task: FocusTask

    @State private var editState: EditTaskState
    private let originalState: EditTaskState
    @State private var showDiscardAlert = false
    @State private var showCalendarPicker = false
    @State private var showOverlapAlert = false
    @State private var overlappingTaskIDs: [UUID] = []
    @State private var pendingShiftInterval: TimeInterval = 0
    @State private var pendingSavedTask: FocusTask? = nil
    @State private var titlePreset: String? = nil
    @FocusState private var isAnyFieldFocused: Bool

    private let minuteOptions = Array(stride(from: 5, through: 600, by: 5))

    init(task: FocusTask) {
        self.task = task
        let dateTime = task.scheduledTime ?? Date().addingTimeInterval(3600)
        let durationMinutes = max(Int(task.focusPlan.blocks.first?.duration ?? 0) / 60, 5)
        let state = EditTaskState(
            title: task.title,
            durationMinutes: durationMinutes,
            scheduledDateTime: dateTime,
            recurrenceType: task.recurrenceType,
            recurrenceDays: task.recurrenceDays ?? []
        )
        _editState = State(initialValue: state)
        self.originalState = state
    }

    // MARK: - Helpers

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60; let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)min"
    }

    private var isOnce: Bool { editState.recurrenceType == .once }
    private var hasChanges: Bool { editState != originalState }
    private var isTitleValid: Bool { !editState.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var isDateValid: Bool { editState.scheduledDateTime > Date() }

    private var canSave: Bool {
        guard hasChanges && isTitleValid else { return false }
        if isOnce { return isDateValid }
        return true
    }

    // MARK: - Date wheel helpers

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
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }
    private func hourLabel(_ h: Int) -> String {
        String(format: "%02d", h)
    }

    private var selectedDay: Date { Calendar.current.startOfDay(for: editState.scheduledDateTime) }
    private var selectedHour: Int { Calendar.current.component(.hour, from: editState.scheduledDateTime) }
    private var selectedMinuteStep: Int {
        let m = Calendar.current.component(.minute, from: editState.scheduledDateTime)
        return (m / 5) * 5
    }

    private func setDay(_ day: Date) {
        var comps = Calendar.current.dateComponents([.hour, .minute], from: editState.scheduledDateTime)
        let dc = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.year = dc.year; comps.month = dc.month; comps.day = dc.day
        editState.scheduledDateTime = Calendar.current.date(from: comps) ?? editState.scheduledDateTime
    }
    private func setHour(_ h: Int) {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: editState.scheduledDateTime)
        comps.hour = h
        comps.minute = 0
        editState.scheduledDateTime = Calendar.current.date(from: comps) ?? editState.scheduledDateTime
    }
    private func setMinute(_ m: Int) {
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: editState.scheduledDateTime)
        comps.minute = m
        editState.scheduledDateTime = Calendar.current.date(from: comps) ?? editState.scheduledDateTime
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {

                    // MARK: Task name
                    FormCard(icon: "pencil", iconColor: .accentColor, title: "Task name") {
                        TextField("Task title", text: $editState.title)
                            .font(.body)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .focused($isAnyFieldFocused)
                            .onChange(of: editState.title) { _, _ in
                                if editState.title != titlePreset { titlePreset = nil }
                            }
                        if !isTitleValid {
                            Text("Task title cannot be empty")
                                .font(.caption).foregroundStyle(.red)
                        }

                        // Preset name chips
                        TaskNamePresetChips(selected: $titlePreset) { preset in
                            titlePreset = preset
                            editState.title = preset
                        }
                    }

                    // MARK: Focus duration
                    FormCard(icon: "timer", iconColor: .orange, title: "Focus duration") {
                        Picker("Focus duration", selection: $editState.durationMinutes) {
                            ForEach(minuteOptions, id: \.self) { minutes in
                                Text(durationLabel(minutes)).tag(minutes)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // MARK: Recurrence
                    FormCard(icon: "repeat", iconColor: .indigo, title: "Recurrence") {
                        Picker("Recurrence", selection: $editState.recurrenceType) {
                            Text("Once").tag(RecurrenceType.once)
                            Text("Daily").tag(RecurrenceType.daily)
                            Text("Weekdays").tag(RecurrenceType.weekdays)
                            Text("Custom").tag(RecurrenceType.custom)
                        }
                        .pickerStyle(.segmented)
                    }

                    // MARK: Custom days
                    if editState.recurrenceType == .custom {
                        FormCard(icon: "calendar.badge.checkmark", iconColor: .teal, title: "Repeat on") {
                            HStack(spacing: 6) {
                                ForEach(Weekday.allCases) { day in
                                    let selected = editState.recurrenceDays.contains(day.rawValue)
                                    Button {
                                        if selected { editState.recurrenceDays.removeAll { $0 == day.rawValue } }
                                        else { editState.recurrenceDays.append(day.rawValue) }
                                    } label: {
                                        Text(day.shortName)
                                            .font(.caption.bold())
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(selected ? Color.accentColor : Color(uiColor: .tertiarySystemGroupedBackground))
                                            .foregroundStyle(selected ? Color.white : Color.secondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    }
                                }
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    // MARK: Date / time — wheel pickers
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
                            HStack(spacing: 0) {
                                    Picker("Date", selection: Binding(get: { selectedDay }, set: { setDay($0) })) {
                                        ForEach(dateOptions, id: \.self) { d in
                                            Text(dateLabel(d)).tag(d)
                                        }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(maxWidth: .infinity)

                                    Picker("Hour", selection: Binding(get: { selectedHour }, set: { setHour($0) })) {
                                        ForEach(hourOptions, id: \.self) { h in Text(hourLabel(h)).tag(h) }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 64)

                                    Text(":")
                                        .font(.title2.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 14)

                                    Picker("Minute", selection: Binding(get: { selectedMinuteStep }, set: { setMinute($0) })) {
                                        ForEach(minuteStepOptions, id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                                    }
                                    .pickerStyle(.wheel)
                                    .frame(width: 64)
                                }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            if !isDateValid {
                                Text("Date must be in the future")
                                    .font(.caption).foregroundStyle(.red)
                            }
                        } else {
                            HStack(spacing: 0) {
                                Picker("Hour", selection: Binding(get: { selectedHour }, set: { setHour($0) })) {
                                    ForEach(hourOptions, id: \.self) { h in Text(hourLabel(h)).tag(h) }
                                }
                                .pickerStyle(.wheel).frame(maxWidth: .infinity)

                                Text(":").font(.title2.bold()).foregroundStyle(.secondary).frame(width: 16)

                                Picker("Minute", selection: Binding(get: { selectedMinuteStep }, set: { setMinute($0) })) {
                                    ForEach(minuteStepOptions, id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                                }
                                .pickerStyle(.wheel).frame(maxWidth: .infinity)
                            }
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .animation(.easeInOut(duration: 0.2), value: editState.recurrenceType)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { showDiscardAlert = true } else { dismiss() }
                    }
                    .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .foregroundStyle(canSave ? Color.accentColor : Color.secondary)
                        .disabled(!canSave)
                }
            }
            .alert("Discard changes?", isPresented: $showDiscardAlert) {
                Button("Keep Editing", role: .cancel) { }
                Button("Discard", role: .destructive) { dismiss() }
            } message: {
                Text("You have unsaved changes.")
            }
            .alert("Shift Following Tasks?", isPresented: $showOverlapAlert) {
                Button("Shift All", role: .none) {
                    if let updated = pendingSavedTask {
                        taskStore.updateTask(updated)
                        taskStore.shiftTasks(ids: overlappingTaskIDs, by: pendingShiftInterval)
                    }
                    dismiss()
                }
                Button("Keep as Is", role: .none) {
                    if let updated = pendingSavedTask { taskStore.updateTask(updated) }
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("\(overlappingTaskIDs.count) task\(overlappingTaskIDs.count == 1 ? "" : "s") scheduled after this one now overlap\(overlappingTaskIDs.count == 1 ? "s" : "") with the new time. Do you want to shift them forward to avoid conflicts?")
            }
            .sheet(isPresented: $showCalendarPicker) {
                CalendarPickerSheet(selectedDate: $editState.scheduledDateTime)
            }
        }
        .floatingKeyboardDismiss(isVisible: isAnyFieldFocused)
    }

    // MARK: - Save

    private func save() {
        var updatedTask = task
        updatedTask.title = editState.title
        updatedTask.recurrenceType = editState.recurrenceType
        updatedTask.recurrenceDays = editState.recurrenceDays
        updatedTask.scheduledTime = editState.scheduledDateTime
        updatedTask.focusPlan = FocusPlan(blocks: [
            FocusBlock(
                duration: editState.durationMinutes * 60,
                type: task.focusPlan.blocks.first?.type ?? .focus
            )
        ])

        // Detect overlap only when scheduledTime actually changed.
        let timeChanged = editState.scheduledDateTime != originalState.scheduledDateTime
        if timeChanged {
            let newStart  = editState.scheduledDateTime
            let newEnd    = newStart.addingTimeInterval(TimeInterval(editState.durationMinutes * 60))
            let shiftBy   = editState.scheduledDateTime.timeIntervalSince(originalState.scheduledDateTime)

            // Find pending tasks (excluding this one) that start before newEnd
            // and start at or after the original task's start — i.e., they follow
            // this task and now fall inside its new time window.
            let conflicting = taskStore.tasks.filter { other in
                guard other.id != task.id,
                      other.status == .pending,
                      let otherStart = other.scheduledTime else { return false }
                // Task starts inside or before the edited task's new end window.
                return otherStart >= originalState.scheduledDateTime && otherStart < newEnd
            }

            if !conflicting.isEmpty {
                overlappingTaskIDs   = conflicting.map { $0.id }
                pendingShiftInterval = shiftBy + TimeInterval(editState.durationMinutes * 60)
                                       - TimeInterval(originalState.durationMinutes * 60)
                pendingSavedTask     = updatedTask
                showOverlapAlert     = true
                return
            }
        }

        taskStore.updateTask(updatedTask)
        dismiss()
    }
}

// MARK: - Task Name Preset Chips

private struct TaskNamePresetChips: View {
    @Binding var selected: String?
    let onSelect: (String) -> Void

    private var presets: [String] { AppSettingsStore.shared.taskNamePresets }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(presets, id: \.self) { preset in
                Button {
                    onSelect(preset)
                } label: {
                    Text(preset)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selected == preset ? Color.accentColor : Color.primary.opacity(0.07))
                        .foregroundStyle(selected == preset ? .white : .primary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
