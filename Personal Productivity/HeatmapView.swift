import SwiftUI

struct HeatmapView: View {

    @EnvironmentObject var taskStore: TaskStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            Text("Heatmap")
                .font(.largeTitle)
                .bold()

            ForEach(taskStore.tasks) { task in
                HStack {
                    Text(task.title)

                    Spacer()

                    Circle()
                        .fill(task.status == .completed ? Color.brg : Color.gray)
                        .frame(width: 12, height: 12)
                }
            }

            Spacer()
        }
        .padding()
    }
}

