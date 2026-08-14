import SwiftUI
import Charts

struct FocusChartView: View {
    let settings: AppSettingsStore
    @EnvironmentObject var taskStore: TaskStore

    // MARK: - Last 7 days aggregated data
    private var dailyDurations: [DailyFocusData] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).map { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: today)!

            let logsForDay = taskStore.sessionLogs.filter {
                $0.exitReason == .completed &&
                calendar.isDate($0.startDate, inSameDayAs: day)
            }

            let totalSeconds = logsForDay.reduce(0) {
                $0 + Int($1.endDate.timeIntervalSince($1.startDate))
            }

            return DailyFocusData(
                date: day,
                minutes: totalSeconds / 60
            )
        }
        .reversed()
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            Text("Last 7 days")
                .font(.headline)

            if dailyDurations.allSatisfy({ $0.minutes == 0 }) {
                Text("No focus data yet")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 24)
            } else {
                Chart(dailyDurations) { item in
                    BarMark(
                        x: .value("Day", item.date, unit: .day),
                        y: .value("Minutes", item.minutes)
                    )
                    .foregroundStyle(.blue)
                    .cornerRadius(6)
                }
                .frame(height: 220)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Data model
struct DailyFocusData: Identifiable {
    let id = UUID()
    let date: Date
    let minutes: Int
}

#Preview {
    FocusChartView(settings: AppSettingsStore())
        .environmentObject(TaskStore(settings: AppSettingsStore()))
}
