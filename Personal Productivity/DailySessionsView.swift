import SwiftUI

struct DailySessionsView: View {

    let date: Date
    let sessions: [FocusSessionLog]
    let taskStore: TaskStore

    var body: some View {
        List {
            ForEach(sessions) { log in
                VStack(alignment: .leading, spacing: 6) {

                    Text(taskTitle(for: log.taskId))
                        .font(.headline)

                    Text(timeRange(for: log))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(log.exitReason.rawValue.capitalized)
                        .font(.caption)
                        .foregroundStyle(log.exitReason == .completed ? .green : .orange)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(dayTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func taskTitle(for id: UUID) -> String {
        taskStore.tasks.first(where: { $0.id == id })?.title ?? "Unknown task"
    }

    private func timeRange(for log: FocusSessionLog) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: log.startDate)) – \(formatter.string(from: log.endDate))"
    }
}
