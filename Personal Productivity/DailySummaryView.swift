import SwiftUI

struct DailySummaryView: View {
    let settings: AppSettingsStore
    @EnvironmentObject var taskStore: TaskStore

    // Grupiramo sesije po danu
    private var sessionsByDay: [(date: Date, totalDuration: TimeInterval)] {

        let grouped = Dictionary(grouping: taskStore.sessionLogs) { log in
            Calendar.current.startOfDay(for: log.startDate)
        }

        return grouped
            .map { (date, logs) in
                let total = logs.reduce(0) {
                    $0 + $1.endDate.timeIntervalSince($1.startDate)
                }
                return (date: date, totalDuration: total)
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if sessionsByDay.isEmpty {
                Text("No data yet")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sessionsByDay, id: \.date) { day in
                    HStack {
                        Text(
                            day.date.formatted(
                                date: .abbreviated,
                                time: .omitted
                            )
                        )

                        Spacer()

                        Text(formattedDuration(day.totalDuration))
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .navigationTitle("Daily Focus")
    }

    // MARK: - Helpers

    private func formattedDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        } else {
            return "\(remainingMinutes)m"
        }
    }
}

#Preview {
    NavigationStack {
        DailySummaryView(settings: AppSettingsStore())
            .environmentObject(TaskStore(settings: AppSettingsStore()))
    }
}
