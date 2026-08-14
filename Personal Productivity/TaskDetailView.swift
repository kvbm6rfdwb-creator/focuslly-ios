import SwiftUI

struct TaskDetailView: View {
    let task: FocusTask
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // Apple-style handle bar
            Capsule()
                .fill(Color.gray.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 16) {
                Text(task.title)
                    .font(.title3.weight(.semibold)) // veći naslov
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Divider()

                HStack {
                    Text("Focus Duration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(focusDurationMinutes) min")
                        .font(.subheadline.weight(.semibold))
                }

                HStack {
                    Text("Recurrence")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(recurrenceString)
                        .font(.subheadline.weight(.semibold))
                }

                HStack {
                    Text("Time")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(scheduledTimeString)
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 16)
            
            Spacer(minLength: 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    private var focusDurationMinutes: Int {
        task.focusPlan.blocks
            .filter { $0.type == .focus }
            .reduce(0) { $0 + $1.duration } / 60
    }

    private var scheduledTimeString: String {
        guard let time = task.scheduledTime else { return "No time set" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    private var recurrenceString: String {
        switch task.recurrenceType {
        case .once:
            return "Once only"
        case .daily:
            return "Every day"
        case .weekdays:
            return "Mon–Fri"
        case .custom:
            if let days = task.recurrenceDays, !days.isEmpty {
                let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
                let selectedDays = days.sorted().map { dayNames[$0 % 7] }
                return selectedDays.joined(separator: ", ")
            }
            return "Custom"
        }
    }
}
