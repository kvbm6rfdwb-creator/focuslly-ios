import SwiftUI

struct SessionDetailView: View {

    let log: FocusSessionLog
    let taskTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            VStack(alignment: .leading, spacing: 8) {
                Text("Task")
                    .font(.headline)

                Text(taskTitle)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Started")
                    .font(.headline)

                Text(dateString(log.startDate))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Finished")
                    .font(.headline)

                Text(dateString(log.endDate))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Duration")
                    .font(.headline)

                Text(durationString)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Exit reason")
                    .font(.headline)

                Text(log.exitReason.rawValue.capitalized)
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Helpers

    private var durationString: String {
        let interval = log.endDate.timeIntervalSince(log.startDate)
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return "\(minutes) min \(seconds) sec"
    }

    private func dateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        SessionDetailView(
            log: FocusSessionLog(
                taskId: UUID(),
                startDate: Date().addingTimeInterval(-1800),
                endDate: Date(),
                exitReason: .completed
            ),
            taskTitle: "Deep Work"
        )
    }
}
