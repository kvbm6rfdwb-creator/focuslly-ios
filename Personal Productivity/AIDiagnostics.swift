import Foundation

struct AIDiagnostics {

    struct Summary {
        let focusLogsLast7Days: Int
        let breakLogsLast7Days: Int
        let breakFeedbackSamplesTotal: Int
        let learnedTokenCount: Int
    }

    static func summary(taskStore: TaskStore) -> Summary {
        let calendar = Calendar.current
        let now = Date()
        let cutoff = calendar.date(byAdding: .day, value: -7, to: now) ?? now

        let focus = taskStore.sessionLogs.filter { log in
            log.exitReason == .completed && log.startDate >= cutoff
        }.count

        let breaks = taskStore.sessionLogs.filter { log in
            log.exitReason == .breakEnded && log.startDate >= cutoff
        }.count

        let feedback = BreakDurationLearningStore.shared.allFeedback().count

        // TaskCategorizationLearningStore doesn't expose internals; compute a safe approximation.
        // We store tokenWeights as a JSON dict; count tokens by decoding that blob if present.
        let tokenCount: Int = {
            let key = "task_categorization_learning_v1"
            guard let data = UserDefaults.standard.data(forKey: key) else { return 0 }
            guard let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else { return 0 }
            return decoded.keys.count
        }()

        return Summary(
            focusLogsLast7Days: focus,
            breakLogsLast7Days: breaks,
            breakFeedbackSamplesTotal: feedback,
            learnedTokenCount: tokenCount
        )
    }
}
