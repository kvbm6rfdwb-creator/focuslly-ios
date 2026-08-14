import SwiftUI

struct ProductivityHeatmap: View {

    @EnvironmentObject var taskStore: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Productivity Heatmap")
                .font(.title2)
                .fontWeight(.bold)

            ForEach(taskStore.tasks) { task in
                HStack {
                    Text(task.title)
                    Spacer()
                    Text(task.startDate.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
    }
}

