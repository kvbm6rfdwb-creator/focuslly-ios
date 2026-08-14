import SwiftUI
import UIKit
import EventKit

// MARK: - SettingsView

struct SettingsView: View {

    @EnvironmentObject var settings: AppSettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @ObservedObject private var calSyncStore = CalendarSyncStore.shared

    @State private var showDeleteDataConfirmation = false

    private let appName     = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Focuslly"
    private let appVersion  = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.1"
    private let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {

                appHeader

                focusSection
                tasksSection
                notificationsSection
                crmSection
                trainingSection
                calendarSection
                soundSection
                dataSection
                dangerZone

                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .tint(.brg)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Sections (split to avoid type-check timeout)

    private var focusSection: some View {
        SettingsCard(title: "Focus") {
            FocusGoalRow(icon: "sun.max.fill",     label: "Weekday goal",
                         valueMinutes: $settings.dailyFocusGoalWeekday, range: 30...720, step: 30)
            CardDivider()
            FocusGoalRow(icon: "sun.horizon.fill", label: "Weekend goal",
                         valueMinutes: $settings.dailyFocusGoalWeekend, range: 30...720, step: 30)
            CardDivider()
            SettingsNavLink(icon: "plus.circle",
                            title: "Focus Extension Times",
                            subtitle: settings.setTimePresets.map(\.label).joined(separator: " · ")) {
                SetTimesSettingsView().environmentObject(settings)
            }
            CardDivider()
            SettingsNavLink(icon: "bolt",
                            title: "Quick Start Tasks",
                            subtitle: "\(settings.quickStartTaskPresets.count) configured") {
                QuickStartTasksSettingsView().environmentObject(settings)
            }
            CardDivider()
            SettingsNavLink(icon: "text.badge.star",
                            title: "Task Name & Intention Presets",
                            subtitle: "\(settings.taskNamePresets.count) names · \(settings.intentionPresets.count) intentions") {
                PresetsSettingsView().environmentObject(settings)
            }
        }
    }

    private var tasksSection: some View {
        SettingsCard(title: "Tasks") {
            SettingsNavLink(icon: "tag",
                            title: "Categories",
                            subtitle: "Names, colours, icons, add or remove") {
                TaskCategoriesSettingsView().environmentObject(taskStore)
            }
        }
    }

    private var notificationsSection: some View {
        SettingsCard(title: "Notifications") {
            CardToggleRow(icon: "bell", label: "Task Reminders",
                          isOn: $settings.notificationsReminders)
            if settings.notificationsReminders {
                CardDivider()
                ReminderPickerRow(selection: $settings.taskReminderMinutesBefore)
            }
            CardDivider()
            CardToggleRow(icon: "person.crop.circle.badge.clock",
                          label: "Follow-Up Reminders",
                          subtitle: "Notified when it's time to follow up with a client",
                          isOn: $settings.notificationsFollowUp)
            CardDivider()
            CardToggleRow(icon: "chart.bar", label: "Daily Summary",
                          isOn: $settings.notificationsDailySummary)
            CardDivider()
            CardToggleRow(icon: "play", label: "Focus Session Start",
                          isOn: $settings.notificationsFocusStart)
        }
    }

    private var crmSection: some View {
        SettingsCard(title: "CRM Tracker") {
            TrackerStepperRow(icon: "phone", label: "Daily dial target",
                value: Binding(get: { PipelineStore.shared.dailyDialTarget },
                               set: { PipelineStore.shared.dailyDialTarget = $0 }),
                range: 10...200, step: 5)
            CardDivider()
            TrackerStepperRow(icon: "chart.line.uptrend.xyaxis", label: "Weekly dial target",
                value: Binding(get: { PipelineStore.shared.weeklyDialTarget },
                               set: { PipelineStore.shared.weeklyDialTarget = $0 }),
                range: 50...1000, step: 25)
        }
    }

    private var trainingSection: some View {
        SettingsCard(title: "Training") {
            SettingsNavLink(icon: "figure.run",
                            title: "Training Schedule & Streaks",
                            subtitle: "\(settings.trainingDaysPerWeek)×/week · \(settings.trainingMinSessionMinutes)m minimum") {
                TrainingSettingsView().environmentObject(settings)
            }
        }
    }

    private var calendarSection: some View {
        SettingsCard(title: "Calendar Sync") {
            calendarContent
        }
        .onAppear { settings.forceCalendarSync() }
    }

    private var soundSection: some View {
        SettingsCard(title: "Sound & Haptics") {
            CardToggleRow(icon: "iphone.radiowaves.left.and.right", label: "Haptics",
                          isOn: $settings.hapticsEnabled)
            CardDivider()
            CardToggleRow(icon: "speaker.wave.2", label: "Sounds",
                          isOn: $settings.soundsEnabled)
        }
    }

    private var dataSection: some View {
        SettingsCard(title: "Data & History") {
            SettingsNavLink(icon: "clock.arrow.circlepath",
                            title: "Session History", subtitle: nil) {
                SessionHistoryView(settings: settings).environmentObject(taskStore)
            }
            CardDivider()
            SettingsNavLink(icon: "heart.text.square",
                            title: "App Health", subtitle: nil) {
                SelfCheckView().environmentObject(taskStore)
            }
        }
    }

    // MARK: - App Header

    private var appHeader: some View {
        HStack(spacing: 14) {
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(appName)
                    .font(.system(size: 17, weight: .semibold))
                Text("Your personal productivity system")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Danger Zone (extracted to avoid type-check timeout)

    private var dangerZone: some View {
        VStack(spacing: 1) {
            Button(role: .destructive) { settings.showResetConfirmation = true } label: {
                HStack {
                    Text("Reset All Settings")
                        .font(.system(size: 15))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .confirmationDialog("Reset all settings to defaults? This cannot be undone.",
                                isPresented: $settings.showResetConfirmation, titleVisibility: .visible) {
                Button("Reset All Settings", role: .destructive) { settings.resetAll() }
                Button("Cancel", role: .cancel) {}
            }

            Divider().padding(.leading, 16)

            Button(role: .destructive) { showDeleteDataConfirmation = true } label: {
                HStack {
                    Text("Delete All Data")
                        .font(.system(size: 15))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .confirmationDialog("This will permanently delete all tasks and session history. This cannot be undone.",
                                isPresented: $showDeleteDataConfirmation, titleVisibility: .visible) {
                Button("Delete All Data", role: .destructive) { taskStore.deleteAllData() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Calendar Content (extracted to avoid type-check timeout)

    @ViewBuilder
    private var calendarContent: some View {
        if !calSyncStore.calendars.isEmpty {
            ForEach(Array(calSyncStore.calendars.enumerated()), id: \.element.calendarIdentifier) { idx, cal in
                if idx > 0 { CardDivider() }
                CardToggleRow(
                    icon: "calendar", label: cal.title,
                    isOn: Binding(
                        get: { settings.syncedCalendarIDs.contains(cal.calendarIdentifier) },
                        set: { on in
                            if on { settings.syncedCalendarIDs.insert(cal.calendarIdentifier) }
                            else  { settings.syncedCalendarIDs.remove(cal.calendarIdentifier) }
                        }
                    )
                )
            }
        } else if calSyncStore.authorizationStatus == .denied || calSyncStore.authorizationStatus == .restricted {
            HStack(spacing: 12) {
                SettingsIcon(systemName: "calendar.badge.exclamationmark")
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calendar access denied")
                        .font(.system(size: 14, weight: .medium))
                    Text("Enable in iOS Settings → Privacy → Calendars")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Open") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
            }
            .padding(.vertical, 10)
        } else {
            HStack(spacing: 12) {
                SettingsIcon(systemName: "calendar.badge.exclamationmark")
                Text("No calendars found")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Settings Card Container

private struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.5)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
    }
}

// MARK: - Shared Icon

private struct SettingsIcon: View {
    let systemName: String
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(.secondary)
            .frame(width: 28, height: 28)
    }
}

// MARK: - Nav Link Row

private struct SettingsNavLink<Destination: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    @ViewBuilder let destination: () -> Destination

    init(icon: String, title: String, subtitle: String? = nil, @ViewBuilder destination: @escaping () -> Destination) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.destination = destination
    }

    var body: some View {
        NavigationLink(destination: destination()) {
            HStack(spacing: 12) {
                SettingsIcon(systemName: icon)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15))
                        .foregroundStyle(Color(uiColor: .label))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(Color(uiColor: .secondaryLabel))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(uiColor: .tertiaryLabel))
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Toggle Row

private struct CardToggleRow: View {
    let icon: String
    let label: String
    var subtitle: String? = nil
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.brg)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Card Divider

private struct CardDivider: View {
    var body: some View {
        Divider().padding(.leading, 40)
    }
}

// MARK: - Reminder Picker Row

private struct ReminderPickerRow: View {
    @Binding var selection: Int
    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: "clock")
            Text("Remind before task")
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            Picker("", selection: $selection) {
                Text("5m").tag(5)
                Text("10m").tag(10)
                Text("15m").tag(15)
                Text("30m").tag(30)
                Text("1h").tag(60)
            }
            .pickerStyle(.menu)
            .tint(.secondary)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Focus Goal Row

private struct FocusGoalRow: View {
    let icon: String
    let label: String
    @Binding var valueMinutes: Int
    let range: ClosedRange<Int>
    let step: Int

    private var displayValue: String {
        let h = valueMinutes / 60
        let m = valueMinutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                SettingsIcon(systemName: icon)
                Text(label)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                Spacer()
                Text(displayValue)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }
            Slider(
                value: Binding(
                    get: { Double(valueMinutes) },
                    set: { valueMinutes = (Int($0) / step) * step }
                ),
                in: Double(range.lowerBound)...Double(range.upperBound),
                step: Double(step)
            )
            .tint(.brg)
            .padding(.leading, 40)
            HStack {
                Text("\(range.lowerBound / 60)h")
                Spacer()
                Text("\(range.upperBound / 60)h")
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .padding(.leading, 40)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Tracker Stepper Row

private struct TrackerStepperRow: View {
    let icon: String
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack(spacing: 12) {
            SettingsIcon(systemName: icon)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            HStack(spacing: 16) {
                Button {
                    if value - step >= range.lowerBound { value -= step }
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(value - step >= range.lowerBound ? Color(uiColor: .label) : Color(uiColor: .tertiaryLabel))
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Text("\(value)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
                    .frame(minWidth: 36, alignment: .center)

                Button {
                    if value + step <= range.upperBound { value += step }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(value + step <= range.upperBound ? Color(uiColor: .label) : Color(uiColor: .tertiaryLabel))
                        .frame(width: 30, height: 30)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Legacy stubs (kept for any existing call sites)

private struct SettingsToggleRow: View {
    let icon: String; let label: String; @Binding var isOn: Bool
    var body: some View {
        CardToggleRow(icon: icon, label: label, isOn: $isOn)
    }
}

private struct SettingsNavRow: View {
    let icon: String; let label: String
    var body: some View {
        HStack(spacing: 8) {
            SettingsBadge(icon: icon)
            Text(label).font(.system(size: 14)).foregroundStyle(.primary)
        }
    }
}

private struct SettingsBadge: View {
    let icon: String
    var color: Color = Color(uiColor: .systemGray3)
    var destructive: Bool = false
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(destructive ? Color.red : color)
                .frame(width: 24, height: 24)
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}
