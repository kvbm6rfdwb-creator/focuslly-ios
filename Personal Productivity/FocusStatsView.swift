import SwiftUI
import Charts

struct DailyFocusStat: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
}

struct FocusStatsView: View {
    let settings: AppSettingsStore
    @EnvironmentObject var taskStore: TaskStore

    private var last7Days: [DailyFocusStat] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!

            let minutes = taskStore.sessionLogs
                .filter {
                    ($0.exitReason == .completed || $0.exitReason == .prolonged) &&
                    calendar.isDate($0.startDate, inSameDayAs: day)
                }
                .reduce(0) {
                    $0 + Int($1.endDate.timeIntervalSince($1.startDate)) / 60
                }

            return DailyFocusStat(date: day, minutes: minutes)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {

                // 🔥 STREAK
                HStack {
                    Text("🔥 \(taskStore.dailyStreak) day streak")
                        .font(.title3.bold())

                    Spacer()
                }

                // 📊 CHART
                Chart(last7Days) { stat in
                    BarMark(
                        x: .value("Day", stat.date, unit: .day),
                        y: .value("Minutes", stat.minutes)
                    )
                    .foregroundStyle(.blue)
                }
                .frame(height: 220)

                Spacer()
            }
            .padding()
            .navigationTitle("Weekly Focus")
        }
    }
}

#Preview {
    FocusStatsView(settings: AppSettingsStore())
        .environmentObject(TaskStore(settings: AppSettingsStore()))
}
