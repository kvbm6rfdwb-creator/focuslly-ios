import SwiftUI

// MARK: - TrainingSettingsView

struct TrainingSettingsView: View {
    @EnvironmentObject var settings: AppSettingsStore
    @EnvironmentObject var taskStore: TaskStore

    // Day names (Sun=1 … Sat=7)
    private let dayNames: [(Int, String)] = [
        (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"),
        (6, "Fri"), (7, "Sat"), (1, "Sun")
    ]

    var body: some View {
        List {
            // ── Schedule ────────────────────────────────────────────
            Section {
                // Days per week stepper
                HStack {
                    Label("Days per week", systemImage: "calendar")
                        .font(.system(size: 14))
                    Spacer()
                    HStack(spacing: 10) {
                        Button {
                            if settings.trainingDaysPerWeek > 1 { settings.trainingDaysPerWeek -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(settings.trainingDaysPerWeek > 1 ? Color.brg : .secondary)
                        }
                        .buttonStyle(.plain)
                        Text("\(settings.trainingDaysPerWeek)")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .frame(minWidth: 20, alignment: .center)
                        Button {
                            if settings.trainingDaysPerWeek < 7 { settings.trainingDaysPerWeek += 1 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(settings.trainingDaysPerWeek < 7 ? Color.brg : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Day picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Training days")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        ForEach(dayNames, id: \.0) { (num, name) in
                            let selected = settings.trainingWeekdays.contains(num)
                            Button {
                                withAnimation(.spring(response: 0.25)) {
                                    if selected {
                                        if settings.trainingWeekdays.count > 1 {
                                            settings.trainingWeekdays.remove(num)
                                        }
                                    } else {
                                        settings.trainingWeekdays.insert(num)
                                    }
                                    settings.trainingDaysPerWeek = settings.trainingWeekdays.count
                                }
                            } label: {
                                Text(name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(selected ? Color.brg : Color(.tertiarySystemFill))
                                    .foregroundStyle(selected ? .white : .secondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
            } header: {
                Text("Schedule")
            } footer: {
                Text("The streak counter automatically adapts to your selected training frequency.")
                    .font(.caption)
            }

            // ── This week's progress ─────────────────────────────────
            Section {
                weekProgressView
            } header: {
                Text("This Week")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Training")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Week progress

    private var weekProgressView: some View {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today)
        let startOfWeek = cal.date(byAdding: .day, value: -(weekday == 1 ? 6 : weekday - 2), to: cal.startOfDay(for: today)) ?? today

        let trainedDays: Set<Int> = Set(
            taskStore.sessionLogs
                .filter { log in
                    guard log.exitReason == .completed else { return false }
                    guard log.startDate >= startOfWeek else { return false }
                    let mins = Int(log.endDate.timeIntervalSince(log.startDate) / 60)
                    guard mins >= settings.trainingMinSessionMinutes else { return false }
                    if let task = taskStore.tasks.first(where: { $0.id == log.taskId }) {
                        switch settings.trainingStreakMode {
                        case .anyPhysicalTask:
                            return task.pipelineCategory == .physicalTraining ||
                                   task.title.lowercased().contains("train") ||
                                   task.title.lowercased().contains("gym") ||
                                   task.title.lowercased().contains("run") ||
                                   task.title.lowercased().contains("workout")
                        case .quickStartOnly:
                            return task.pipelineCategory == .physicalTraining
                        case .manualLog:
                            return false
                        }
                    }
                    return false
                }
                .compactMap { log in cal.component(.weekday, from: log.startDate) }
        )

        let targetCount = settings.trainingWeekdays.count
        let doneCount = settings.trainingWeekdays.filter { trainedDays.contains($0) }.count
        let streakColor: Color = doneCount == targetCount ? Color.brg : doneCount > 0 ? Color.brgMuted : .secondary

        return VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(doneCount) / \(targetCount)")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundStyle(streakColor)
                    Text("training sessions this week")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: doneCount == targetCount ? "checkmark.seal.fill" : "figure.run")
                    .font(.system(size: 28))
                    .foregroundStyle(streakColor.opacity(0.7))
            }

            // Day row
            HStack(spacing: 6) {
                ForEach(dayNames, id: \.0) { (num, name) in
                    let isTarget = settings.trainingWeekdays.contains(num)
                    let isDone   = trainedDays.contains(num)
                    let isToday  = cal.component(.weekday, from: today) == num
                    VStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(isDone ? Color.brg.opacity(0.12) :
                                      isTarget ? Color.brg.opacity(0.08) :
                                      Color(.tertiarySystemFill))
                                .frame(width: 32, height: 32)
                            if isDone {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.primary)
                            } else if isTarget {
                                Image(systemName: "figure.run")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Text(name)
                            .font(.system(size: 9, weight: isToday ? .bold : .regular))
                            .foregroundStyle(isToday ? Color.brg : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
