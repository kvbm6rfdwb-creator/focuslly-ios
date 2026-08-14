import SwiftUI

// MARK: - Call Wizard (multi-step, tap-only)
struct CallWizardView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var taskStore: TaskStore
    @ObservedObject var pipeline: PipelineStore

    var prefillName: String = ""

    @State private var step = 0

    // Step 0 – who
    @State private var contactName = ""
    @State private var showContactPicker = false
    @State private var contactRequired = false   // flashes red when user taps Next without a contact
    @State private var leadSource: LeadSource? = nil
    @State private var responseTimeSeconds: Int? = nil

    // Step 1 – next step
    @State private var nextStep: NextStepType = .none
    @State private var nextStepChosen: Bool = false   // tracks whether user has tapped a choice

    // Step 2 – schedule (mirrors AddTaskView)
    @State private var taskDate: Date = Calendar.current.date(byAdding: .hour, value: 2, to: Date()) ?? Date()
    @State private var focusMinutes: Int = 25
    @State private var intention: String = ""
    @State private var intentionPreset: String? = nil
    @State private var showCalendarPicker = false
    @State private var schedulingAdvice: [TaskSchedulingAdvisor.Advice] = []
    @State private var taskNotes: String = ""   // task title / name

    private let intentionPresets = ["Offer sent", "Call done", "Showing done", "Listing added", "Read a book"]

    private var totalSteps: Int { 3 }

    // MARK: - Validation
    private var canAdvance: Bool {
        switch step {
        case 0:
            return !contactName.trimmingCharacters(in: .whitespaces).isEmpty
                && leadSource != nil
                && responseTimeSeconds != nil
        case 1:
            return nextStepChosen          // any tap counts, including "No next step"
        default:
            return true
        }
    }

    @FocusState private var isAnyFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                progressBar
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        stepContent
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
                .scrollDismissesKeyboard(.interactively)
                // Reserve space at bottom so content isn't hidden behind the fixed bar
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    Color.clear.frame(height: 80)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(stepTitle)
            .onAppear { if !prefillName.isEmpty { contactName = prefillName } }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Bottom bar pinned outside keyboard avoidance
            .overlay(alignment: .bottom) {
                bottomBar
                    .background(.regularMaterial)
                    .ignoresSafeArea(edges: .bottom)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            // Floating checkmark above keyboard — inside NavigationStack so it respects keyboard frame
            .overlay(alignment: .bottomTrailing) {
                if isAnyFieldFocused {
                    Button { isAnyFieldFocused = false } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.9)
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.55),
                                            Color.white.opacity(0.1),
                                            Color.black.opacity(0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                        .shadow(color: .white.opacity(0.06), radius: 2, x: 0, y: -1)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 260)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isAnyFieldFocused)
                }
            }
        }
    }

    // MARK: - Progress Bar
    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Color.primary.opacity(0.07)).frame(height: 3)
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(totalSteps), height: 3)
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: step)
            }
        }
        .frame(height: 3)
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Who did you call?"
        case 1: return "What's the next step?"
        case 2: return "Schedule next action"
        default: return ""
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: step0_who
        case 1: step1_nextStep
        case 2: step2_schedule
        default: EmptyView()
        }
    }

    // MARK: – Step 0: Who
    private var step0_who: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardCard(title: "Contact name  ✳︎", highlighted: contactRequired && contactName.isEmpty) {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(contactRequired && contactName.isEmpty ? Color.red : contactName.isEmpty ? Color(.tertiaryLabel) : Color.accentColor)
                    if contactName.isEmpty {
                        Text(contactRequired ? "Contact is required" : "Select or add contact")
                            .font(.system(size: 15))
                            .foregroundStyle(contactRequired ? Color.red.opacity(0.85) : .secondary)
                    } else {
                        Text(contactName)
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Spacer()
                    if contactName.isEmpty {
                        Image(systemName: contactRequired ? "exclamationmark.circle.fill" : "chevron.right")
                            .font(.system(size: contactRequired ? 16 : 12, weight: .semibold))
                            .foregroundStyle(contactRequired ? Color.red : Color(.tertiaryLabel))
                    } else {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color(.tertiaryLabel))
                            .onTapGesture { contactName = "" }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { contactRequired = false; showContactPicker = true }
            }
            .sheet(isPresented: $showContactPicker) {
                CallContactPickerSheet(
                    knownContacts: Array(Set(pipeline.callLogs
                        .map { $0.contactName.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty })).sorted(),
                    selected: $contactName
                )
            }
            .onChange(of: contactName) { _, new in
                if !new.isEmpty { contactRequired = false }
            }

            WizardCard(title: "Lead source  ✳︎") {
                WrapChips(
                    selection: Binding(get: { leadSource }, set: { leadSource = $0 }),
                    options: LeadSource.allCases
                ) { $0.rawValue }
            }

            WizardCard(title: "Response time  ✳︎") {
                WrapChips(
                    selection: Binding<String?>(
                        get: { responseTimeLabel },
                        set: { if let v = $0 { responseTimeSeconds = responseTimeLabelToSeconds(v) } }
                    ),
                    options: ["< 5 min", "5–30 min", "30 min – 2 h", "2–24 h", "> 24 h", "Inbound call"]
                ) { $0 }
            }

            if !canAdvance {
                VStack(alignment: .leading, spacing: 6) {
                    if contactName.trimmingCharacters(in: .whitespaces).isEmpty {
                        Label("Select a contact to continue", systemImage: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.red.opacity(0.85))
                    }
                    if leadSource == nil || responseTimeSeconds == nil {
                        Label("Select lead source and response time to continue", systemImage: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var responseTimeLabel: String? {
        guard let t = responseTimeSeconds else { return nil }
        if t == 0    { return "Inbound call" }
        if t <= 300  { return "< 5 min" }
        if t <= 1800 { return "5–30 min" }
        if t <= 7200 { return "30 min – 2 h" }
        if t <= 86400 { return "2–24 h" }
        return "> 24 h"
    }

    private func responseTimeLabelToSeconds(_ label: String) -> Int {
        switch label {
        case "Inbound call": return 0
        case "< 5 min":      return 180
        case "5–30 min":     return 900
        case "30 min – 2 h": return 3600
        case "2–24 h":       return 10800
        default:             return 90000
        }
    }

    // MARK: – Step 1: Next step
    private var step1_nextStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            WizardCard(title: "Choose one  ✳︎") {
                VStack(spacing: 8) {
                    ForEach(relevantNextSteps) { opt in
                        SelectionRowButton(icon: opt.icon, label: opt.rawValue, isSelected: nextStep == opt) {
                            nextStep = opt
                            if opt != .none { focusMinutes = pipeline.suggestedDuration(for: opt) }
                            nextStepChosen = true
                        }
                    }
                }
            }

            if !canAdvance {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle").font(.system(size: 12))
                    Text("Select a next step to continue")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            }
        }
    }

    private var relevantNextSteps: [NextStepType] {
        [.appointment, .sendOffer, .followUpCall, .sendListingInfo, .nurture, .none]
    }

    // MARK: – Step 2: Schedule (mirrors AddTaskView exactly)

    private let minuteOptions = Array(stride(from: 5, through: 600, by: 5))

    private func durationLabel(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60; let m = minutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)min"
    }

    private var dateOptions: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<365).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }
    private var hourOptions: [Int] { Array(0..<24) }
    private var minuteStepOptions: [Int] { Array(stride(from: 0, through: 55, by: 5)) }

    private var selectedDay: Date { Calendar.current.startOfDay(for: taskDate) }
    private var selectedHour: Int { Calendar.current.component(.hour, from: taskDate) }
    private var selectedMinuteStep: Int {
        let m = Calendar.current.component(.minute, from: taskDate)
        return (m / 5) * 5
    }

    private func setDay(_ day: Date) {
        var comps = Calendar.current.dateComponents([.hour, .minute], from: taskDate)
        let dc = Calendar.current.dateComponents([.year, .month, .day], from: day)
        comps.year = dc.year; comps.month = dc.month; comps.day = dc.day
        taskDate = Calendar.current.date(from: comps) ?? taskDate
    }
    private func setHour(_ h: Int) {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: taskDate)
        comps.hour = h; comps.minute = 0
        taskDate = Calendar.current.date(from: comps) ?? taskDate
    }
    private func setMinute(_ m: Int) {
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: taskDate)
        comps.minute = m
        taskDate = Calendar.current.date(from: comps) ?? taskDate
    }
    private func dateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"
        return f.string(from: date)
    }

    private func refreshAdvice() {
        guard !taskNotes.trimmingCharacters(in: .whitespaces).isEmpty else { schedulingAdvice = []; return }
        schedulingAdvice = TaskSchedulingAdvisor.advise(
            title: taskNotes,
            durationMinutes: focusMinutes,
            scheduledTime: taskDate,
            existingTasks: taskStore.tasks,
            sessionLogs: taskStore.sessionLogs
        )
    }

    private var step2_schedule: some View {
        Group {
            if nextStep == .none {
                // No task — clean confirmation
                VStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Color.accentColor.opacity(0.10)).frame(width: 80, height: 80)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 38, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                    VStack(spacing: 6) {
                        Text("Ready to save").font(.system(size: 20, weight: .bold))
                        Text("No follow-up task needed. The call will be logged and counted toward your daily targets.")
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(28)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 22))

            } else {
                VStack(spacing: 14) {
                    // Task name
                    FormCard(icon: "pencil", iconColor: .accentColor, title: "Task name") {
                        TextField("What do you want to work on?", text: $taskNotes)
                            .font(.body)
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .textInputAutocapitalization(.sentences)
                            .focused($isAnyFieldFocused)
                    }
                    .onAppear {
                        if taskNotes.isEmpty {
                            let client = contactName.trimmingCharacters(in: .whitespaces)
                            taskNotes = client.isEmpty ? nextStep.rawValue : "\(nextStep.rawValue) – \(client)"
                        }
                    }

                    // Focus duration
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

                    // Date / time
                    FormCard(
                        icon: "calendar",
                        iconColor: .green,
                        title: "Scheduled for",
                        trailing: {
                            Button { showCalendarPicker = true } label: {
                                Image(systemName: "calendar")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 30, height: 30)
                                    .background(Color.accentColor.opacity(0.12), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    ) {
                        HStack(spacing: 0) {
                            Picker("Date", selection: Binding(get: { selectedDay }, set: { setDay($0) })) {
                                ForEach(dateOptions, id: \.self) { d in Text(dateLabel(d)).tag(d) }
                            }
                            .pickerStyle(.wheel).frame(maxWidth: .infinity)

                            Picker("Hour", selection: Binding(get: { selectedHour }, set: { setHour($0) })) {
                                ForEach(hourOptions, id: \.self) { h in Text(String(format: "%02d", h)).tag(h) }
                            }
                            .pickerStyle(.wheel).frame(width: 64)

                            Text(":").font(.title2.bold()).foregroundStyle(.secondary).frame(width: 14)

                            Picker("Minute", selection: Binding(get: { selectedMinuteStep }, set: { setMinute($0) })) {
                                ForEach(minuteStepOptions, id: \.self) { m in Text(String(format: "%02d", m)).tag(m) }
                            }
                            .pickerStyle(.wheel).frame(width: 64)
                        }
                        .frame(height: 130)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .sheet(isPresented: $showCalendarPicker) {
                        CalendarPickerSheet(selectedDate: $taskDate)
                    }

                    // Scheduling advice banners
                    if !schedulingAdvice.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(schedulingAdvice, id: \.message) { advice in
                                SchedulingAdviceBanner(
                                    advice: advice,
                                    onApplyTime: { (d: Date) in withAnimation { taskDate = d } },
                                    onApplyDuration: { (m: Int) in withAnimation { focusMinutes = m } }
                                )
                            }
                        }
                    }

                    // Intention
                    FormCard(icon: "text.quote", iconColor: .purple, title: "Intention") {
                        VStack(alignment: .leading, spacing: 10) {
                            // Preset chips
                            FlowLayout(spacing: 8) {
                                ForEach(intentionPresets, id: \.self) { preset in
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
                                .font(.body).lineLimit(3...5)
                                .padding(.horizontal, 12).padding(.vertical, 10)
                                .background(Color(uiColor: .tertiarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .focused($isAnyFieldFocused)
                                .onChange(of: intention) { _, _ in
                                    if intention != intentionPreset { intentionPreset = nil }
                                }
                            Text("Optional — if set, the app won't ask again when you start this task.")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                .onChange(of: taskNotes)    { _, _ in refreshAdvice() }
                .onChange(of: focusMinutes) { _, _ in refreshAdvice() }
                .onChange(of: taskDate)     { _, _ in refreshAdvice() }
            }
        }
    }

    // MARK: - Bottom bar
    private var bottomBar: some View {
        HStack(spacing: 16) {
            if step > 0 {
                Button {
                    withAnimation { step -= 1 }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.primary.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            let isLast = step == totalSteps - 1

            Button {
                if !canAdvance {
                    if step == 0 && contactName.trimmingCharacters(in: .whitespaces).isEmpty {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.4)) {
                            contactRequired = true
                        }
                        HapticManager.impact()
                    }
                    return
                }
                if isLast {
                    saveAndDismiss()
                } else {
                    withAnimation { step += 1 }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(isLast ? "Save" : "Next")
                    if !isLast { Image(systemName: "chevron.right") }
                }
                .font(.system(size: 15, weight: .semibold))
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(canAdvance ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundStyle(canAdvance ? Color.white : Color(.tertiaryLabel))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .animation(.easeInOut(duration: 0.15), value: canAdvance)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }

    // MARK: - Save
    private func saveAndDismiss() {
        var log = CallLog()
        log.contactName = contactName.trimmingCharacters(in: .whitespaces)
        log.leadSource = leadSource ?? .coldCall
        log.outcome = .callAppointmentArranged
        log.askedForAppointment = false
        log.nextStep = nextStep
        log.responseTimeSeconds = responseTimeSeconds
        log.notes = taskNotes

        if nextStep != .none {
            let titleStr = taskNotes.trimmingCharacters(in: .whitespaces).isEmpty
                ? nextStep.rawValue
                : taskNotes.trimmingCharacters(in: .whitespaces)
            let focusBlock = FocusBlock(duration: focusMinutes * 60, type: .focus)
            let task = FocusTask(
                title: titleStr,
                focusPlan: FocusPlan(blocks: [focusBlock]),
                status: .pending,
                scheduledTime: taskDate,
                recurrenceType: .once,
                recurrenceDays: nil
            )
            // Auto-categorize
            let suggestion = TaskCategorizer.categorize(title: titleStr)
            TaskCategoryStore.shared.set(category: suggestion.category, for: task.id, confirmed: true)
            TaskCategorizationLearningStore.shared.recordUserCorrection(title: titleStr, category: suggestion.category)
            // Save intention if set
            let trimmedIntention = intention.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedIntention.isEmpty {
                SessionIntentionStore.shared.set(trimmedIntention, for: task.id)
            }
            taskStore.addTask(task)
            log.generatedTaskID = task.id
        }

        pipeline.addCall(log)
        HapticManager.impact()
        dismiss()
    }
}

// MARK: - Reusable wizard subviews

private struct WizardCard<Content: View>: View {
    let title: String
    var highlighted: Bool = false
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(highlighted ? Color.red.opacity(0.85) : .secondary)
                .kerning(0.4)
            VStack(alignment: .leading, spacing: 0) { content }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .strokeBorder(highlighted ? Color.red.opacity(0.6) : Color.clear, lineWidth: 1.5)
                )
        }
    }
}

private struct SelectionRow: View {
    var icon: String? = nil
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 20)
            }
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(isSelected ? .primary : .secondary)
            Spacer()
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: 1.5)
                    .frame(width: 20, height: 20)
                if isSelected {
                    Circle().fill(Color.accentColor).frame(width: 12, height: 12)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(isSelected ? Color.accentColor.opacity(0.07) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.12), value: isSelected)
        .contentShape(Rectangle())
    }
}

// Wrap SelectionRow's tap in a plain Button so ScrollView doesn't swallow first touch
private struct SelectionRowButton: View {
    var icon: String? = nil
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        Button {
            HapticManager.impact()
            onTap()
        } label: {
            SelectionRow(icon: icon, label: label, isSelected: isSelected, onTap: {})
        }
        .buttonStyle(.plain)
    }
}

private struct WrapChips<T: Hashable>: View {
    @Binding var selection: T?
    let options: [T]
    let label: (T) -> String
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { opt in
                Button {
                    HapticManager.impact()
                    selection = opt
                } label: {
                    Text(label(opt))
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selection == opt ? Color.accentColor : Color.primary.opacity(0.07))
                        .foregroundStyle(selection == opt ? .white : .primary)
                        .clipShape(Capsule())
                        .animation(.easeInOut(duration: 0.15), value: selection == opt)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Contact Picker Sheet (for New Call)
private struct CallContactPickerSheet: View {
    let knownContacts: [String]
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showingNewField = false
    @State private var newName = ""
    @FocusState private var newNameFocused: Bool
    @FocusState private var searchFocused: Bool

    private var filtered: [String] {
        guard !searchText.isEmpty else { return knownContacts }
        return knownContacts.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    private let avatarColors: [Color] = [.blue, .indigo, .purple, .pink, .orange, .teal, .green, .cyan]
    private func avatarColor(for name: String) -> Color { avatarColors[abs(name.hashValue) % avatarColors.count] }
    private func initials(for name: String) -> String {
        let p = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return p.count >= 2 ? (String(p[0].prefix(1)) + String(p[1].prefix(1))).uppercased() : String(name.prefix(2)).uppercased()
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(.secondary)
                    TextField("Search contacts…", text: $searchText).font(.system(size: 15))
                        .focused($searchFocused)
                    if !searchText.isEmpty {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary).onTapGesture { searchText = "" }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        // Add new toggle
                        if showingNewField {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("NEW CONTACT").font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.accentColor).kerning(0.5)
                                    Spacer()
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.tertiaryLabel))
                                        .onTapGesture { withAnimation { showingNewField = false; newName = "" } }
                                }
                                HStack(spacing: 10) {
                                    TextField("Full name", text: $newName)
                                        .font(.system(size: 16)).textFieldStyle(.plain)
                                        .focused($newNameFocused).submitLabel(.done)
                                        .textInputAutocapitalization(.words)
                                        .onSubmit { confirm() }
                                    if !newName.isEmpty {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.tertiaryLabel)).onTapGesture { newName = "" }
                                    }
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                                .background(Color(.tertiarySystemFill)).clipShape(RoundedRectangle(cornerRadius: 12))
                                Button { confirm() } label: {
                                    Text("Confirm").font(.system(size: 15, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 13)
                                        .background(newName.trimmingCharacters(in: .whitespaces).isEmpty ? Color(.tertiarySystemFill) : Color.accentColor)
                                        .foregroundStyle(newName.trimmingCharacters(in: .whitespaces).isEmpty ? Color(.tertiaryLabel) : .white)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                }.disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty).buttonStyle(.plain)
                            }
                            .padding(16).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 16).transition(.opacity.combined(with: .move(edge: .top)))
                        } else {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(Color.accentColor.opacity(0.1)).frame(width: 40, height: 40)
                                    Image(systemName: "plus").font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.accentColor)
                                }
                                Text("Add new contact").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14)
                            .background(Color.accentColor.opacity(0.06)).clipShape(RoundedRectangle(cornerRadius: 18))
                            .padding(.horizontal, 16).contentShape(Rectangle())
                            .onTapGesture { withAnimation(.spring(response: 0.3)) { showingNewField = true; newNameFocused = true } }
                        }

                        if !knownContacts.isEmpty {
                            VStack(spacing: 0) {
                                ForEach(Array(filtered.enumerated()), id: \.element) { idx, name in
                                    VStack(spacing: 0) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle().fill(avatarColor(for: name).opacity(0.12)).frame(width: 40, height: 40)
                                                Text(initials(for: name)).font(.system(size: 14, weight: .semibold)).foregroundStyle(avatarColor(for: name))
                                            }
                                            Text(name).font(.system(size: 15, weight: .medium))
                                            Spacer()
                                            if selected == name { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.accentColor).font(.system(size: 18)) }
                                        }
                                        .padding(.horizontal, 16).padding(.vertical, 12)
                                        .contentShape(Rectangle())
                                        .onTapGesture { HapticManager.impact(); selected = name; dismiss() }
                                        if idx < filtered.count - 1 { Divider().padding(.leading, 68) }
                                    }
                                }
                            }
                            .background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 18)).padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 4).padding(.bottom, 32)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Select contact").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
        .floatingKeyboardDismiss(isVisible: searchFocused || newNameFocused)
        .presentationDetents([.medium, .large]).presentationDragIndicator(.visible)
    }

    private func confirm() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        HapticManager.success(); selected = name; dismiss()
    }
}

// MARK: - Simple flow layout

