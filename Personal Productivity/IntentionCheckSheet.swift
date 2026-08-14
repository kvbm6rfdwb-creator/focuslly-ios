import SwiftUI

// MARK: - Intention Check Sheet

/// Shown after the break-length feedback rating.
/// Asks whether the user accomplished their session intention.
/// If not, shows a full follow-up task form with smart duration suggestion,
/// an editable duration picker, and a date/time scheduler.
struct IntentionCheckSheet: View {

    let taskTitle: String
    let intention: String
    let nextTask: FocusTask?

    /// Seconds of the original planned focus block
    let originalDurationSeconds: Int
    /// Seconds actually spent in the session
    let spentSeconds: Int

    let onComplete: () -> Void
    let onAddTask: (FocusTask) -> Void
    let onNextTask: ((FocusTask) -> Void)?

    @State private var showAddTask = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Intention echo
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.orange.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "text.quote")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(taskTitle)
                            .font(.system(size: 14, weight: .bold))
                            .lineLimit(1)
                        if !intention.isEmpty {
                            Text("Intention: \(intention)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                Divider()

                if showAddTask {
                    FollowUpTaskForm(
                        taskTitle: taskTitle,
                        intention: intention,
                        originalDurationSeconds: originalDurationSeconds,
                        spentSeconds: spentSeconds,
                        onSave: { newTask in onAddTask(newTask) },
                        onBack: { withAnimation { showAddTask = false } }
                    )
                } else {
                    VStack(spacing: 14) {
                        Text("Did you accomplish your intention?")
                            .font(.system(size: 16, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .padding(.top, 20)

                        Button {
                            if let next = nextTask, let handler = onNextTask {
                                handler(next)
                            } else {
                                onComplete()
                            }
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.primary)
                                Text(nextTask != nil ? "Yes — next task" : "Yes, I'm done")
                                    .fontWeight(.semibold)
                                if let next = nextTask {
                                    Spacer()
                                    Text(next.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.brg.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button {
                            HapticManager.impact()
                            withAnimation { showAddTask = true }
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.orange)
                                Text("No — add a follow-up task")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.orange.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        Button { onComplete() } label: {
                            Text("Skip")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Session complete")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Follow-Up Task Form

private struct FollowUpTaskForm: View {

    let taskTitle: String
    let intention: String
    let originalDurationSeconds: Int
    let spentSeconds: Int
    let onSave: (FocusTask) -> Void
    let onBack: () -> Void

    @State private var title: String = ""
    @State private var focusMinutes: Int = 25
    @State private var scheduleMode: ScheduleMode = .now
    @State private var selectedDay: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedHour: Int = {
        let h = Calendar.current.component(.hour, from: Date())
        return min(h + 1, 23)
    }()
    @State private var selectedMinute: Int = 0

    private let minuteOptions = Array(stride(from: 5, through: 600, by: 5))
    private let hourOptions   = Array(0..<24)
    private let minuteStepOptions = Array(stride(from: 0, through: 55, by: 5))
    private let dateOptions: [Date] = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<365).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }()

    enum ScheduleMode: String, CaseIterable {
        case now     = "Now"
        case later   = "Schedule"
    }

    private func durationLabel(_ m: Int) -> String {
        m < 60 ? "\(m) min" : (m % 60 == 0 ? "\(m/60)h" : "\(m/60)h \(m%60)min")
    }

    private func dateLabel(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d)     { return "Today" }
        if cal.isDateInTomorrow(d)  { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: d)
    }

    private var suggestion: Int {
        FollowUpTaskStore.shared.suggestedFollowUpMinutes(
            taskTitle: taskTitle,
            originalSeconds: originalDurationSeconds,
            spentSeconds: spentSeconds
        )
    }

    private var computedScheduledTime: Date? {
        switch scheduleMode {
        case .now:
            return Date().addingTimeInterval(300)
        case .later:
            var comps = Calendar.current.dateComponents([.year, .month, .day], from: selectedDay)
            comps.hour = selectedHour
            comps.minute = selectedMinute
            return Calendar.current.date(from: comps)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                // Back
                HStack {
                    Button {
                        onBack()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Back")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }

                // Task name
                FollowUpFormCard(icon: "pencil", iconColor: .accentColor, title: "Task name") {
                    TextField("What still needs to be done?", text: $title)
                        .font(.body)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                // Duration
                FollowUpFormCard(icon: "timer", iconColor: .orange, title: "Focus duration") {
                    VStack(spacing: 8) {
                        // Suggestion chip
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text("Suggested: \(durationLabel(suggestion))")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if focusMinutes != suggestion {
                                Button("Use") {
                                    withAnimation { focusMinutes = suggestion }
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.orange)
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Color.orange.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        Picker("Duration", selection: $focusMinutes) {
                            ForEach(minuteOptions, id: \.self) { m in
                                Text(durationLabel(m)).tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }

                // When
                FollowUpFormCard(icon: "calendar", iconColor: .brg, title: "When") {
                    Picker("Schedule", selection: $scheduleMode) {
                        ForEach(ScheduleMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Date/time picker — only when .later
                if scheduleMode == .later {
                    FollowUpFormCard(icon: "clock", iconColor: .indigo, title: "Date & time") {
                        HStack(spacing: 0) {
                            Picker("Date", selection: $selectedDay) {
                                ForEach(dateOptions, id: \.self) { d in
                                    Text(dateLabel(d)).tag(d)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(maxWidth: .infinity)

                            Picker("Hour", selection: $selectedHour) {
                                ForEach(hourOptions, id: \.self) { h in
                                    Text(String(format: "%02d", h)).tag(h)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60)

                            Text(":")
                                .font(.title2.bold())
                                .foregroundStyle(.secondary)
                                .frame(width: 14)

                            Picker("Minute", selection: $selectedMinute) {
                                ForEach(minuteStepOptions, id: \.self) { m in
                                    Text(String(format: "%02d", m)).tag(m)
                                }
                            }
                            .pickerStyle(.wheel)
                            .frame(width: 60)
                        }
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Save
                Button { saveTask() } label: {
                    Text("Save task")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(canSave ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                        .foregroundStyle(canSave ? Color.white : Color.secondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(!canSave)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
            .animation(.easeInOut(duration: 0.2), value: scheduleMode)
        }
        .onAppear {
            title = intention.isEmpty ? taskTitle : intention
            focusMinutes = suggestion
        }
    }

    private func saveTask() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Record overrun so the next suggestion for this task improves
        FollowUpTaskStore.shared.recordOverrun(
            taskTitle: taskTitle,
            originalSeconds: originalDurationSeconds,
            spentSeconds: spentSeconds
        )

        let plan = FocusPlan(blocks: [FocusBlock(duration: focusMinutes * 60, type: .focus)])
        let task = FocusTask(
            title: trimmed,
            focusPlan: plan,
            startDate: Date(),
            scheduledTime: computedScheduledTime,
            recurrenceType: .once
        )
        onSave(task)
    }
}

// MARK: - FormCard helper (file-private)

private struct FollowUpFormCard<Content: View>: View {
    let icon: String
    let iconColor: Color
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 22)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            content()
        }
        .padding(16)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
    }
}
