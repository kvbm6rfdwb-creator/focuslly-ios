import Foundation

struct BreakInsightDecisionEngine {

    enum Recommendation: String, Codable {
        case continueBreak
        case skipBreak
    }

    struct Chip {
        let icon: String
        let label: String
        let value: String
        let highlight: Bool   // true = colour accent, false = neutral
    }

    struct Decision {
        let recommendation: Recommendation
        let headline: String          // one clean sentence shown large
        let supportingLine: String    // one short contextual line shown below headline
        let chips: [Chip]             // 2–4 stat chips shown below
        let confidence: Double

        /// Legacy compatibility — callers that use .message get the headline
        var message: String { headline }
    }

    static func decide(currentTask: FocusTask) -> Decision {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        let store = TaskStoreLocator.shared.store

        var focusedMinutesToday = 0
        var streak = 0

        if let store {
            // Focused minutes today from persisted sessionLogs (completed focus sessions only).
            var totalSeconds = 0
            for log in store.sessionLogs {
                if log.exitReason != .completed { continue }
                if calendar.isDate(log.startDate, inSameDayAs: todayStart) {
                    totalSeconds += Int(log.endDate.timeIntervalSince(log.startDate))
                }
            }
            focusedMinutesToday = max(0, totalSeconds / 60)

            // Streak derived from existing strictDailyStreak (safe, persisted inputs).
            streak = max(0, store.strictDailyStreak)
        }

        // Category-aware stats (if available).
        let category = TaskCategoryStore.shared.category(for: currentTask.id)
        let categorySnapshot: CategoryPerformanceStats.Snapshot? = category.map { CategoryPerformanceStats.snapshot(for: $0) }

        let planFocusSeconds = currentTask.focusPlan.blocks
            .filter { $0.type == .focus }
            .reduce(0) { $0 + $1.duration }

        let difficultyScore: Int
        if planFocusSeconds >= 75 * 60 {
            difficultyScore = 3
        } else if planFocusSeconds >= 40 * 60 {
            difficultyScore = 2
        } else {
            difficultyScore = 1
        }

        let categoryFocusToday = categorySnapshot?.focusMinutesToday ?? 0
        let fatigueScore = (focusedMinutesToday >= 120 ? 2 : (focusedMinutesToday >= 60 ? 1 : 0))
        + (categoryFocusToday >= 60 ? 1 : 0)
        + (streak >= 3 ? 1 : 0)
        let workloadScore = focusedMinutesToday >= 90 ? 2 : (focusedMinutesToday >= 30 ? 1 : 0)

        // Break feedback: if breaks for this category are often "too short"/"too long", bias recommendation.
        let feedbackSamples = categorySnapshot?.totalBreakFeedbackSamples ?? 0
        let tooShort = categorySnapshot?.breakFeedbackCounts[.tooShort] ?? 0
        let tooLong = categorySnapshot?.breakFeedbackCounts[.tooLong] ?? 0
        let justRight = categorySnapshot?.breakFeedbackCounts[.justRight] ?? 0

        let breakOftenTooShort = feedbackSamples >= 6 && tooShort > justRight && tooShort >= (tooLong + 1)
        let breakOftenTooLong = feedbackSamples >= 6 && tooLong > justRight && tooLong >= (tooShort + 1)

        // Post-break effectiveness nudge (conservative):
        // If history shows a break bucket that consistently improves next-focus completion,
        // and the planned break is likely below that bucket, lean toward continuing the break.
        let bestBreak = categorySnapshot?.bestBreakEffectiveness
        let strongBestBreakSignal = (bestBreak?.samples ?? 0) >= 10 && (bestBreak?.completionRate ?? 0) >= 0.70

        // Approximate current break length from plan (proxy; avoids touching timer flow).
        let planBreakSeconds = currentTask.focusPlan.blocks
            .filter { $0.type == .breakTime }
            .reduce(0) { $0 + $1.duration }
        let planBreakMinutes = max(0, planBreakSeconds / 60)

        func bucketLowerBoundMinutes(_ label: String) -> Int? {
            switch label {
            case "0–4m": return 0
            case "5–9m": return 5
            case "10–15m": return 10
            case "16m+": return 16
            default: return nil
            }
        }

        let bestBucketLowerBound = bestBreak.flatMap { bucketLowerBoundMinutes($0.bucketLabel) }
        let currentBreakLikelyBelowBest = strongBestBreakSignal && (bestBucketLowerBound != nil) && planBreakMinutes < (bestBucketLowerBound ?? 0)

        let recommendation: Recommendation
        let baseConfidence: Double

        if breakOftenTooShort {
            recommendation = .continueBreak
            baseConfidence = 0.80
        } else if breakOftenTooLong {
            recommendation = .skipBreak
            baseConfidence = 0.78
        } else if currentBreakLikelyBelowBest {
            recommendation = .continueBreak
            baseConfidence = 0.76
        } else if fatigueScore >= 2 && difficultyScore >= 2 {
            recommendation = .continueBreak
            baseConfidence = 0.78
        } else if workloadScore >= 2 && difficultyScore == 1 {
            recommendation = .skipBreak
            baseConfidence = 0.72
        } else if fatigueScore >= 3 {
            recommendation = .continueBreak
            baseConfidence = 0.82
        } else {
            recommendation = .skipBreak
            baseConfidence = 0.58
        }

        // MARK: - Headline (one clean, honest sentence)
        let headline: String
        let supporting: String

        if recommendation == .continueBreak {
            if fatigueScore >= 3 {
                headline = "You've been pushing hard — finish the break."
                supporting = "High fatigue detected. A full recovery now protects the rest of your day."
            } else if breakOftenTooShort {
                headline = "Your breaks tend to feel too short. Stay a bit longer."
                supporting = "Based on your past feedback for this type of task."
            } else if currentBreakLikelyBelowBest {
                if let best = bestBreak {
                    headline = "Your best focus follows ~\(best.bucketLabel) breaks."
                    supporting = "Finishing the break could improve your next session."
                } else {
                    headline = "A full break here will set you up better."
                    supporting = "You've built enough momentum — protect it."
                }
            } else {
                headline = "Take the rest of your break."
                supporting = "You'll perform better in the next block if you recover fully."
            }
        } else {
            // skipBreak
            if breakOftenTooLong {
                headline = "Your breaks tend to run long. You can start now."
                supporting = "Past feedback shows shorter breaks work better for you here."
            } else if workloadScore >= 2 && difficultyScore == 1 {
                headline = "Light task ahead — good time to keep the momentum."
                supporting = "You have energy left and the next task doesn't need a long ramp-up."
            } else if focusedMinutesToday == 0 {
                headline = "Fresh start — ready when you are."
                supporting = "No fatigue detected yet. Jump in when you feel set."
            } else {
                headline = "You're in a good rhythm. Keep going if you feel ready."
                supporting = "No strong signal to rest further right now."
            }
        }

        // MARK: - Stat chips (2–4 only, useful data, no internal debug)
        var chips: [Chip] = []

        // Always show today's focus time
        let focusHours = focusedMinutesToday / 60
        let focusMins  = focusedMinutesToday % 60
        let focusLabel = focusHours > 0 ? "\(focusHours)h \(focusMins)m" : "\(focusMins)m"
        chips.append(Chip(
            icon: "bolt.fill",
            label: "Focused today",
            value: focusLabel,
            highlight: focusedMinutesToday >= 60
        ))

        // Streak — only show if meaningful
        if streak > 0 {
            chips.append(Chip(
                icon: "flame.fill",
                label: "Streak",
                value: "\(streak)d",
                highlight: streak >= 3
            ))
        }

        // Category-specific break pattern insight (only if enough data)
        if let snap = categorySnapshot, snap.totalBreakFeedbackSamples >= 6 {
            let breakLabel: String
            let breakHighlight: Bool
            if breakOftenTooShort {
                breakLabel = "Often too short"
                breakHighlight = true
            } else if breakOftenTooLong {
                breakLabel = "Often too long"
                breakHighlight = true
            } else {
                breakLabel = "Well balanced"
                breakHighlight = false
            }
            chips.append(Chip(
                icon: "cup.and.saucer.fill",
                label: "Break pattern",
                value: breakLabel,
                highlight: breakHighlight
            ))
        }

        // Best break effectiveness — only if strong signal
        if let bestBreak, strongBestBreakSignal {
            let pct = Int((bestBreak.completionRate * 100.0).rounded())
            chips.append(Chip(
                icon: "chart.bar.fill",
                label: "Best after",
                value: "~\(bestBreak.bucketLabel) · \(pct)%",
                highlight: recommendation == .continueBreak
            ))
        }

        return Decision(
            recommendation: recommendation,
            headline: headline,
            supportingLine: supporting,
            chips: chips,
            confidence: min(max(baseConfidence, 0.0), 1.0)
        )
    }
}
