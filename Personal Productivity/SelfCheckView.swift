import SwiftUI

struct SelfCheckView: View {

    @EnvironmentObject var taskStore: TaskStore

    private var diagnostics: AIDiagnostics.Summary {
        AIDiagnostics.summary(taskStore: taskStore)
    }

    private var hasAnyTasks: Bool { !taskStore.tasks.isEmpty }
    private var hasAnySessionLogs: Bool { !taskStore.sessionLogs.isEmpty }

    var body: some View {
        List {

            // MARK: - Intro banner
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("App Health Check", systemImage: "heart.text.square.fill")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("This screen shows whether the app has enough data to give you accurate focus insights and smart suggestions. Green means everything is working. Orange means more usage is needed.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }

            // MARK: - Your data
            Section {
                HealthRow(
                    icon: "checkmark.circle.fill",
                    title: "Tasks",
                    description: hasAnyTasks
                        ? "You have \(taskStore.tasks.count) task\(taskStore.tasks.count == 1 ? "" : "s") saved."
                        : "You haven't added any tasks yet.",
                    advice: hasAnyTasks ? nil : "Go to the Dashboard and tap the + button to add your first task.",
                    status: hasAnyTasks ? .good : .needsData
                )

                HealthRow(
                    icon: "timer",
                    title: "Focus sessions",
                    description: hasAnySessionLogs
                        ? "You have completed \(taskStore.sessionLogs.count) focus session\(taskStore.sessionLogs.count == 1 ? "" : "s") in total."
                        : "You haven't completed any focus sessions yet.",
                    advice: hasAnySessionLogs ? nil : "Start a focus session from the Dashboard to begin tracking your progress.",
                    status: hasAnySessionLogs ? .good : .needsData
                )
            } header: {
                Text("Your data")
            }

            // MARK: - This week
            Section {
                HealthRow(
                    icon: "bolt.fill",
                    title: "Focus sessions this week",
                    description: diagnostics.focusLogsLast7Days > 0
                        ? "You completed \(diagnostics.focusLogsLast7Days) focus session\(diagnostics.focusLogsLast7Days == 1 ? "" : "s") in the last 7 days. The app can generate meaningful insights from this."
                        : "You haven't completed any focus sessions in the last 7 days.",
                    advice: diagnostics.focusLogsLast7Days == 0 ? "Complete at least one focus session this week so your Insights tab has real data to show." : nil,
                    status: diagnostics.focusLogsLast7Days > 0 ? .good : .needsData
                )

                HealthRow(
                    icon: "cup.and.saucer.fill",
                    title: "Breaks taken this week",
                    description: diagnostics.breakLogsLast7Days > 0
                        ? "You took \(diagnostics.breakLogsLast7Days) break\(diagnostics.breakLogsLast7Days == 1 ? "" : "s") this week. The app uses this to suggest the right break length for you."
                        : "No breaks have been recorded this week.",
                    advice: diagnostics.breakLogsLast7Days == 0 ? "Let the focus timer run all the way to the end at least once. When it finishes, a break will be logged automatically." : nil,
                    status: diagnostics.breakLogsLast7Days > 0 ? .good : .needsData
                )
            } header: {
                Text("This week")
            }

            // MARK: - Smart features
            Section {
                HealthRow(
                    icon: "brain.head.profile",
                    title: "Break length learning",
                    description: diagnostics.breakFeedbackSamplesTotal > 0
                        ? "The app has \(diagnostics.breakFeedbackSamplesTotal) break feedback response\(diagnostics.breakFeedbackSamplesTotal == 1 ? "" : "s"). It uses these to learn how long your breaks should be."
                        : "The app doesn't know yet how long your ideal break is.",
                    advice: diagnostics.breakFeedbackSamplesTotal == 0 ? "After your next break, answer the short question that appears (\"Was that enough time?\"). Your answer teaches the app your preferences." : nil,
                    status: diagnostics.breakFeedbackSamplesTotal > 0 ? .good : .needsData
                )

                HealthRow(
                    icon: "tag.fill",
                    title: "Task category learning",
                    description: diagnostics.learnedTokenCount > 0
                        ? "The app has learned from \(diagnostics.learnedTokenCount) of your task title\(diagnostics.learnedTokenCount == 1 ? "" : "s") and can now suggest better categories automatically."
                        : "The app hasn't learned your task naming style yet.",
                    advice: diagnostics.learnedTokenCount == 0 ? "When you add a new task and the app suggests a category, either confirm it or choose a different one. Each correction teaches the app your preferences." : nil,
                    status: diagnostics.learnedTokenCount > 0 ? .good : .needsData
                )
            } header: {
                Text("Smart features")
            } footer: {
                Text("Smart features improve automatically the more you use the app. You don't need to do anything special — just use Focuslly normally.")
            }
        }
        .navigationTitle("App Health")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - HealthRow

private struct HealthRow: View {
    enum Status { case good, needsData }

    let icon: String
    let title: String
    let description: String
    let advice: String?
    let status: Status

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(status == .good ? Color.brg : Color(uiColor: .secondaryLabel))
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(status == .good ? "Good" : "Needs more data")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(status == .good ? Color(uiColor: .label) : Color(uiColor: .secondaryLabel))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                (status == .good ? Color.brg : Color(uiColor: .secondarySystemFill)).opacity(0.12),
                                in: Capsule()
                            )
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let advice {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.top, 1)
                    Text(advice)
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                .padding(.leading, 40)
            }
        }
        .padding(.vertical, 4)
    }
}
