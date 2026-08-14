import SwiftUI

struct SessionHistoryView: View {
    let settings: AppSettingsStore
    @EnvironmentObject var taskStore: TaskStore

    // MARK: - Day group
    private struct DayGroup: Identifiable {
        let id = UUID()
        let date: Date
        let logs: [FocusSessionLog]
        let title: String
        let totalMinutes: Int
    }

    // MARK: - Grouped logs
    private var dayGroups: [DayGroup] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        let grouped = Dictionary(grouping: taskStore.sessionLogs) {
            calendar.startOfDay(for: $0.startDate)
        }

        return grouped
            .map { date, logs in
                let sortedLogs = logs.sorted { $0.startDate > $1.startDate }

                let totalSeconds = logs.reduce(0) {
                    $0 + Int($1.endDate.timeIntervalSince($1.startDate))
                }

                let title: String
                if calendar.isDate(date, inSameDayAs: today) {
                    title = "Today"
                } else if calendar.isDate(date, inSameDayAs: yesterday) {
                    title = "Yesterday"
                } else {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .medium
                    title = formatter.string(from: date)
                }

                return DayGroup(
                    date: date,
                    logs: sortedLogs,
                    title: title,
                    totalMinutes: max(totalSeconds / 60, 1)
                )
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            Group {
                if dayGroups.isEmpty {
                    emptyState        // ✅ NEW
                } else {
                    List {
                        ForEach(dayGroups) { group in
                            Section {
                                ForEach(group.logs) { log in
                                    NavigationLink {
                                        SessionDetailView(
                                            log: log,
                                            taskTitle: taskTitle(for: log.taskId)
                                        )
                                    } label: {
                                        sessionRow(log)
                                    }
                                }
                            } header: {
                                dayHeader(group)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Session History")
        }
    }

    // MARK: - Empty state (6.3) ✅ NEW
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "timer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No focus sessions yet")
                .font(.headline)

            Text("Start your first focus session and track your progress here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Header
    private func dayHeader(_ group: DayGroup) -> some View {
        HStack {
            Text(group.title.uppercased())
                .font(.caption.bold())

            Spacer()

            Text("\(group.totalMinutes) min")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Row
    private func sessionRow(_ log: FocusSessionLog) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(taskTitle(for: log.taskId))
                    .font(.headline)

                Text(timeRangeText(for: log))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(durationText(for: log))
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(badgeBackground(for: log.exitReason))
                .foregroundStyle(badgeColor(for: log.exitReason))
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helpers
    private func taskTitle(for taskId: UUID) -> String {
        taskStore.tasks.first(where: { $0.id == taskId })?.title ?? "Unknown task"
    }

    private func timeRangeText(for log: FocusSessionLog) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: log.startDate)) – \(formatter.string(from: log.endDate))"
    }

    private func durationText(for log: FocusSessionLog) -> String {
        let interval = log.endDate.timeIntervalSince(log.startDate)
        let minutes = max(Int(interval) / 60, 1)
        return "\(minutes) min"
    }

    private func badgeBackground(for reason: FocusExitReason) -> Color {
        reason == .completed ? .green.opacity(0.2) : .orange.opacity(0.2)
    }

    private func badgeColor(for reason: FocusExitReason) -> Color {
        reason == .completed ? .green : .orange
    }
}

#Preview {
    SessionHistoryView(settings: AppSettingsStore())
        .environmentObject(TaskStore(settings: AppSettingsStore()))
}
