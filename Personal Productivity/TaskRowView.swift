import SwiftUI

struct TaskRowView: View {
    let task: FocusTask
    let index: Int
    let total: Int
    var onStart: (() -> Void)? = nil
    @EnvironmentObject var taskStore: TaskStore
    @EnvironmentObject var coordinator: FocusSessionCoordinator
    @Binding var selectedTask: FocusTask?
    @Binding var showEditSheet: Bool
    @Binding var showDeleteAlert: Bool
    @Binding var showEditNotAllowedAlert: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Task \(index + 1) of \(total)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(task.title)
                        .font(.headline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            HStack {
                Image(systemName: "clock.fill")
                Text("\(Int(task.focusPlan.blocks.first?.duration ?? 0) / 60) min")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(14)
        .contentShape(Rectangle())
        .onTapGesture {
            HapticManager.impact()
            SoundManager.tap()
            if let onStart {
                onStart()
            } else {
                taskStore.startFocus(task: task)
                coordinator.startFocus(task: task)
            }
        }
        .contextMenu {
            Button {
                selectedTask = task
                if task.isActive || task.status.rawValue == "inProgress" {
                    showEditNotAllowedAlert = true
                } else {
                    showEditSheet = true
                }
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            Button {
                if !task.isActive && task.status.rawValue != "inProgress" {
                    taskStore.skipTask(task)
                }
            } label: {
                Label("Skip", systemImage: "forward.fill")
            }
            Button {
                if !task.isActive {
                    HapticManager.success()
                    taskStore.completeTask(task)
                }
            } label: {
                Label("Mark as Done", systemImage: "checkmark.circle.fill")
            }
            Button(role: .destructive) {
                selectedTask = task
                showDeleteAlert = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}
