import Foundation

struct LostFocusDecisionEngine {

    enum Recommendation {
        case startBreak
        case finish
    }

    struct Decision {
        let recommendation: Recommendation
        let message: String
        let confidence: Double
    }

    static func decide(task: FocusTask) -> Decision {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        let store = TaskStoreLocator.shared.store

        var focusedMinutesToday = 0
        var streak = 0

        if let store {
            var totalSeconds = 0
            for log in store.sessionLogs {
                if log.exitReason != .completed { continue }
                if calendar.isDate(log.startDate, inSameDayAs: todayStart) {
                    totalSeconds += Int(log.endDate.timeIntervalSince(log.startDate))
                }
            }
            focusedMinutesToday = max(0, totalSeconds / 60)
            streak = max(0, store.strictDailyStreak)
        }

        // Category-aware stats (if available).
        let category = TaskCategoryStore.shared.category(for: task.id)
        let categorySnapshot: CategoryPerformanceStats.Snapshot? = category.map { CategoryPerformanceStats.snapshot(for: $0) }

        let plannedFocusSeconds = task.focusPlan.blocks
            .filter { $0.type == .focus }
            .reduce(0) { $0 + $1.duration }

        let plannedBreakSeconds = task.focusPlan.blocks
            .filter { $0.type == .breakTime }
            .reduce(0) { $0 + $1.duration }

        // Heuristic fatigue + endurance score.
        let fatigueFromMinutes: Int
        if focusedMinutesToday >= 150 {
            fatigueFromMinutes = 3
        } else if focusedMinutesToday >= 90 {
            fatigueFromMinutes = 2
        } else if focusedMinutesToday >= 45 {
            fatigueFromMinutes = 1
        } else {
            fatigueFromMinutes = 0
        }

        let fatigueFromStreak = streak >= 4 ? 1 : 0
        let fatigueFromPlan = plannedFocusSeconds >= 60 * 60 ? 1 : 0

        // Category load: if the user already spent a lot of time today in this category,
        // it's a strong signal for a break.
        let categoryFocusToday = categorySnapshot?.focusMinutesToday ?? 0
        let fatigueFromCategory = categoryFocusToday >= 60 ? 1 : 0

        // Break feedback: if breaks for this category are often "too short", nudge toward break.
        let feedbackSamples = categorySnapshot?.totalBreakFeedbackSamples ?? 0
        let tooShort = categorySnapshot?.breakFeedbackCounts[.tooShort] ?? 0
        let justRight = categorySnapshot?.breakFeedbackCounts[.justRight] ?? 0
        let breakOftenTooShort = feedbackSamples >= 6 && tooShort > justRight

        let fatigueScore = fatigueFromMinutes + fatigueFromStreak + fatigueFromPlan + fatigueFromCategory + (breakOftenTooShort ? 1 : 0)

        let recommendation: Recommendation
        let confidence: Double

        if fatigueScore >= 3 {
            recommendation = .startBreak
            confidence = 0.82
        } else if fatigueScore == 2 {
            recommendation = .startBreak
            confidence = 0.68
        } else {
            recommendation = .finish
            confidence = 0.62
        }

        // Message varies based on live metrics.
        let openerPool = [
            "It happens — thanks for being honest.",
            "Good catch. Noticing it early is a win.",
            "No stress. Resetting is part of the process."
        ]
        let opener = openerPool[(focusedMinutesToday + streak) % openerPool.count]

        // Detailed metrics/hints (Option 2) — aligned with BreakInsightDecisionEngine.
        var details: [String] = []
        details.append("Focused today: \(focusedMinutesToday)m")
        details.append("Streak: \(streak)d")

        let tooLong = categorySnapshot?.breakFeedbackCounts[.tooLong] ?? 0

        if let category, let snap = categorySnapshot {
            details.append("\(category.title): \(snap.focusMinutesToday)m focus today")
            details.append("Break today: \(snap.breakMinutesToday)m")
            details.append("Break last 7 days: \(snap.breakMinutesLast7Days)m")

            if snap.totalBreakFeedbackSamples >= 6 {
                if breakOftenTooShort {
                    details.append("Breaks in this category tend to feel too short lately")
                } else {
                    details.append("Break feedback for this category is mixed")
                }
                details.append("Feedback (last \(snap.totalBreakFeedbackSamples)): \(tooShort) short / \(justRight) ok / \(tooLong) long")
            }

            if let suggestion = snap.planSuggestion {
                let pct = Int((suggestion.confidence * 100.0).rounded())
                details.append("Suggested next: \(suggestion.recommendedFocusMinutes)m focus / \(suggestion.recommendedBreakMinutes)m break (\(pct)% confidence)")
            }
        }

        let metrics = details.joined(separator: " • ")

        let planText: String
        if plannedBreakSeconds > 0 {
            planText = "A short break can restore your edge before the next block."
        } else {
            planText = "A short break can help you regain clarity."
        }

        let message: String
        switch recommendation {
        case .startBreak:
            message = "\(opener) \(planText) \(metrics)"
        case .finish:
            message = "\(opener) It might be better to end the session cleanly and reset. \(metrics)"
        }

        return Decision(recommendation: recommendation, message: message, confidence: confidence)
    }
}
