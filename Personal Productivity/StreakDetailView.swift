import SwiftUI

struct StreakDetailView: View {
    let settings: AppSettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss

    private let calendar = Calendar.current

    private enum DayStatus {
        case allCompleted
        case lostFocus
        case noTasks

        var tint: Color {
            switch self {
            case .allCompleted: return .brg
            case .lostFocus: return .red
            case .noTasks: return .gray
            }
        }
    }

    private struct DayRow: Identifiable {
        let id: Date
        let dayStart: Date
        let completedTasks: Int
        let status: DayStatus
    }

    private var currentStreak: Int {
        taskStore.strictDailyStreak
    }

    private var last30Days: [DayRow] {
        let todayStart = calendar.startOfDay(for: Date())

        return (0..<30).map { offset in
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart
            return buildRow(for: dayStart)
        }
    }

    private func buildRow(for dayStart: Date) -> DayRow {
        let dayTasks: [FocusTask] = taskStore.tasks.filter { task in
            let d = task.scheduledTime ?? task.startDate
            return calendar.isDate(d, inSameDayAs: dayStart)
        }

        let hadLostFocus = taskStore.sessionLogs.contains { log in
            log.exitReason == .distracted && calendar.isDate(log.startDate, inSameDayAs: dayStart)
        }

        let completedLogTaskIDs: Set<UUID> = Set(
            taskStore.sessionLogs
                .filter { $0.exitReason == .completed && calendar.isDate($0.startDate, inSameDayAs: dayStart) }
                .map { $0.taskId }
        )

        let completedTasks = dayTasks.filter { task in
            task.status == .completed && completedLogTaskIDs.contains(task.id)
        }.count

        let status: DayStatus
        if dayTasks.isEmpty {
            status = .noTasks
        } else if hadLostFocus {
            status = .lostFocus
        } else if completedTasks == dayTasks.count {
            status = .allCompleted
        } else {
            // Not all tasks completed but no lost focus today: treat as not qualifying (red is reserved for lost focus)
            // Keep indicator gray in this case to avoid introducing a new status.
            status = .noTasks
        }

        return DayRow(id: dayStart, dayStart: dayStart, completedTasks: completedTasks, status: status)
    }

    // ✅ NOVO: Ukupan broj dana u posljednjih 30 dana kada su svi zadaci završeni i nema distrakcija
    private var totalCollectedStreaksLast30Days: Int {
        let todayStart = calendar.startOfDay(for: Date())
        var count = 0

        for offset in 0..<30 {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) ?? todayStart

            let dayTasks = taskStore.tasks.filter { task in
                let d = task.scheduledTime ?? task.startDate
                return calendar.isDate(d, inSameDayAs: dayStart)
            }

            guard !dayTasks.isEmpty else { continue } // skip days with no tasks

            let hadLostFocus = taskStore.sessionLogs.contains { log in
                log.exitReason == .distracted && calendar.isDate(log.startDate, inSameDayAs: dayStart)
            }
            if hadLostFocus { continue }

            let completedLogTaskIDs: Set<UUID> = Set(
                taskStore.sessionLogs
                    .filter { $0.exitReason == .completed && calendar.isDate($0.startDate, inSameDayAs: dayStart) }
                    .map { $0.taskId }
            )

            let allCompleted = dayTasks.allSatisfy { completedLogTaskIDs.contains($0.id) }
            if allCompleted { count += 1 }
        }

        return count
    }

    private func formattedDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, EEE"
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {

                VStack(alignment: .leading, spacing: 6) {
                    Text("\u{1F525} Current Streak")
                        .font(.headline)

                    Text("\(currentStreak)")
                        .font(.largeTitle.bold())

                    Text(currentStreak == 1 ? "day" : "days")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                List {
                    ForEach(last30Days) { row in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(row.status.tint)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(formattedDay(row.dayStart))
                                    .font(.headline)

                                Text("Completed tasks: \(row.completedTasks)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }

                    // ✅ NOVO: prikaz total collected streaks u posljednjih 30 dana
                    Section {
                        HStack {
                            Text("Total collected streaks in last 30 days")
                                .font(.headline)
                            Spacer()
                            Text("\(totalCollectedStreaksLast30Days)")
                                .font(.headline)
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("Streak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    StreakDetailView(settings: AppSettingsStore())
        .environmentObject(TaskStore(settings: AppSettingsStore()))
}
