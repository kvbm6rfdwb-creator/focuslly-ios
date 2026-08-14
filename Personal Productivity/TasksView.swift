import SwiftUI

struct TasksView: View {

    @EnvironmentObject var taskStore: TaskStore
    @State private var showAddTask = false

    var body: some View {
        List {
            ForEach(taskStore.tasks) { task in
                VStack(alignment: .leading) {
                    Text(task.title)
                        .font(.headline)

                    Text(task.startDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Tasks")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddTask = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddTask) {
            Text("AddTaskView goes here")
        }
    }
}
