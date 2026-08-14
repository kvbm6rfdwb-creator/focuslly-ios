import Foundation

/// Lightweight, local aggregation of performance signals by category.
///
/// This is intentionally deterministic and transparent (no network/ML).
struct CategoryPerformanceStats {

    enum TimeOfDayBin: String, CaseIterable {
        case morning
        case afternoon
        case evening

        var title: String {
            switch self {
            case .morning: return "morning"
            case .afternoon: return "afternoon"
            case .evening: return "evening"
            }
        }

        static func bin(for date: Date, calendar: Calendar = .current) -> TimeOfDayBin {
            let hour = calendar.component(.hour, from: date)
            if hour < 12 { return .morning }
            if hour < 17 { return .afternoon }
            return .evening
        }
    }

    struct BreakEffectiveness {
        let bucketLabel: String
        let completionRate: Double
        let samples: Int
    }

    struct PlanSuggestion {
        let recommendedFocusMinutes: Int
        let recommendedBreakMinutes: Int
        let confidence: Double
        let rationale: String
    }

    struct Snapshot {
        var focusMinutesToday: Int
        var focusMinutesLast7Days: Int
        var breakMinutesToday: Int
        var breakMinutesLast7Days: Int

        var focusSessionsLast7Days: Int
        var completionRateLast7Days: Double

        var completionRateByTimeOfDayLast7Days: [TimeOfDayBin: Double]
        var focusSessionCountsByTimeOfDayLast7Days: [TimeOfDayBin: Int]

        var bestBreakEffectiveness: BreakEffectiveness?
        var planSuggestion: PlanSuggestion?

        var breakFeedbackCounts: [BreakDurationLearningStore.Feedback: Int]

        var totalBreakFeedbackSamples: Int {
            breakFeedbackCounts.values.reduce(0, +)
        }

        /// Returns a best-effort best time window if enough samples exist.
        /// Requires at least 3 sessions in a bin to be considered.
        func bestTimeOfDayHint(categoryTitle: String) -> String? {
            let minSamplesPerBin = 3
            // We can't infer samples directly from the rates, so this is intentionally conservative.
            guard completionRateByTimeOfDayLast7Days.count == TimeOfDayBin.allCases.count else { return nil }

            // Ensure at least one bin has meaningful sample size by requiring
            // that the best bin's rate is meaningfully separated.
            let ordered = completionRateByTimeOfDayLast7Days.sorted { $0.value > $1.value }
            guard let best = ordered.first, let second = ordered.dropFirst().first else { return nil }

            let bestSamples = focusSessionCountsByTimeOfDayLast7Days[best.key, default: 0]
            guard bestSamples >= minSamplesPerBin else { return nil }

            let delta = best.value - second.value
            guard delta >= 0.15 else { return nil }

            // This does not guarantee minSamplesPerBin (we don't store counts in Snapshot to keep it small),
            // but the delta threshold plus overall 7-day window reduces noise.
            _ = minSamplesPerBin
            return "You tend to complete \(categoryTitle) sessions best in the \(best.key.title)."
        }
    }

    static func snapshot(for category: TaskCategory) -> Snapshot {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let store = TaskStoreLocator.shared.store

        var focusMinutesToday = 0
        var focusMinutesLast7 = 0
        var breakMinutesToday = 0
        var breakMinutesLast7 = 0

        var focusSessionsLast7 = 0
        var completedFocusSessionsLast7 = 0

        // Time-of-day bins
        var sessionsByBin: [TimeOfDayBin: Int] = [.morning: 0, .afternoon: 0, .evening: 0]
        var completedByBin: [TimeOfDayBin: Int] = [.morning: 0, .afternoon: 0, .evening: 0]

        // Post-break effectiveness buckets
        var breakBucketSamples: [String: Int] = [:]
        var breakBucketCompletedNextFocus: [String: Int] = [:]

        if let store {
            let logs = store.sessionLogs
            let sevenDaysAgo = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            let sortedLogs = logs.sorted { $0.endDate < $1.endDate }

            func categoryForTask(_ taskId: UUID) -> TaskCategory? {
                TaskCategoryStore.shared.category(for: taskId)
            }

            func breakBucketLabel(minutes: Int) -> String {
                switch minutes {
                case ..<5: return "0–4m"
                case 5..<10: return "5–9m"
                case 10..<16: return "10–15m"
                default: return "16m+"
                }
            }

            func isFocusOutcome(_ r: FocusExitReason) -> Bool {
                r == .completed || r == .distracted || r == .interrupted || r == .paused || r == .other || r == .tired
            }

            for (idx, log) in sortedLogs.enumerated() {
                guard let taskCategory = categoryForTask(log.taskId) else { continue }
                guard taskCategory == category else { continue }

                let isInLast7Days = log.startDate >= sevenDaysAgo

                // Focus logs (completed)
                if log.exitReason == .completed {
                    let minutes = Int(log.endDate.timeIntervalSince(log.startDate) / 60.0)
                    if calendar.isDate(log.startDate, inSameDayAs: todayStart) {
                        focusMinutesToday += max(0, minutes)
                    }
                    if isInLast7Days {
                        focusMinutesLast7 += max(0, minutes)
                        completedFocusSessionsLast7 += 1
                        focusSessionsLast7 += 1

                        let bin = TimeOfDayBin.bin(for: log.startDate, calendar: calendar)
                        sessionsByBin[bin, default: 0] += 1
                        completedByBin[bin, default: 0] += 1
                    }
                }

                // Focus logs (non-completed outcomes) – count toward session count for completion rate.
                if log.exitReason == .distracted || log.exitReason == .interrupted || log.exitReason == .paused || log.exitReason == .other || log.exitReason == .tired {
                    if isInLast7Days {
                        focusSessionsLast7 += 1
                        let bin = TimeOfDayBin.bin(for: log.startDate, calendar: calendar)
                        sessionsByBin[bin, default: 0] += 1
                    }
                }

                // Break logs
                if log.exitReason == .breakEnded {
                    let minutes = Int(log.endDate.timeIntervalSince(log.startDate) / 60.0)
                    if calendar.isDate(log.startDate, inSameDayAs: todayStart) {
                        breakMinutesToday += max(0, minutes)
                    }
                    if isInLast7Days {
                        breakMinutesLast7 += max(0, minutes)

                        let windowEnd = log.endDate.addingTimeInterval(2 * 60 * 60)
                        var nextFocus: FocusSessionLog?
                        var j = idx + 1
                        while j < sortedLogs.count {
                            let candidate = sortedLogs[j]
                            if candidate.startDate > windowEnd { break }
                            if isFocusOutcome(candidate.exitReason) {
                                nextFocus = candidate
                                break
                            }
                            j += 1
                        }

                        if let nextFocus {
                            let bucket = breakBucketLabel(minutes: minutes)
                            breakBucketSamples[bucket, default: 0] += 1
                            if nextFocus.exitReason == .completed {
                                breakBucketCompletedNextFocus[bucket, default: 0] += 1
                            }
                        }
                    }
                }
            }
        }

        let completionRate: Double = focusSessionsLast7 > 0
        ? Double(completedFocusSessionsLast7) / Double(focusSessionsLast7)
        : 0

        var completionRateByBin: [TimeOfDayBin: Double] = [.morning: 0, .afternoon: 0, .evening: 0]
        for bin in TimeOfDayBin.allCases {
            let total = sessionsByBin[bin, default: 0]
            let completed = completedByBin[bin, default: 0]
            completionRateByBin[bin] = total > 0 ? Double(completed) / Double(total) : 0
        }

        var bestBreak: BreakEffectiveness? = nil
        for (bucket, samples) in breakBucketSamples {
            guard samples >= 5 else { continue }
            let completed = breakBucketCompletedNextFocus[bucket, default: 0]
            let rate = Double(completed) / Double(samples)
            let candidate = BreakEffectiveness(bucketLabel: bucket, completionRate: rate, samples: samples)
            if let currentBest = bestBreak {
                if candidate.completionRate > currentBest.completionRate {
                    bestBreak = candidate
                }
            } else {
                bestBreak = candidate
            }
        }

        let suggestion: PlanSuggestion? = {
            guard let bestBreak, bestBreak.samples >= 10, bestBreak.completionRate >= 0.70 else { return nil }

            let breakMinutes: Int? = {
                switch bestBreak.bucketLabel {
                case "0–4m": return 4
                case "5–9m": return 8
                case "10–15m": return 12
                case "16m+": return 16
                default: return nil
                }
            }()
            guard let breakMinutes else { return nil }

            let focusMinutes: Int = {
                if completionRate < 0.55 { return 25 }
                if completionRate < 0.70 { return 35 }
                if completionRate < 0.85 { return 45 }
                return 55
            }()

            let conf = min(0.95, max(0.55, bestBreak.completionRate))
            let rationale = "Suggested from your last 7 days: ~\(breakMinutes)m breaks correlate with better next-focus completion; \(focusMinutes)m focus blocks match your completion trend."
            return PlanSuggestion(recommendedFocusMinutes: focusMinutes, recommendedBreakMinutes: breakMinutes, confidence: conf, rationale: rationale)
        }()

        let feedbackCounts = BreakDurationLearningStoreCategoryReader.feedbackCounts(category: category, lastN: 30)

        return Snapshot(
            focusMinutesToday: focusMinutesToday,
            focusMinutesLast7Days: focusMinutesLast7,
            breakMinutesToday: breakMinutesToday,
            breakMinutesLast7Days: breakMinutesLast7,
            focusSessionsLast7Days: focusSessionsLast7,
            completionRateLast7Days: completionRate,
            completionRateByTimeOfDayLast7Days: completionRateByBin,
            focusSessionCountsByTimeOfDayLast7Days: sessionsByBin,
            bestBreakEffectiveness: bestBreak,
            planSuggestion: suggestion,
            breakFeedbackCounts: feedbackCounts
        )
    }
}

/// Reads category-based break feedback from BreakDurationLearningStore's persisted entries.
///
/// Kept separate so BreakDurationLearningStore itself remains backwards compatible and minimal.
private enum BreakDurationLearningStoreCategoryReader {
    static func feedbackCounts(category: TaskCategory, lastN: Int) -> [BreakDurationLearningStore.Feedback: Int] {
        let key = "category:" + category.rawValue
        let all = BreakDurationLearningStore.shared.allFeedback()

        // Filter to category
        let entries = all.filter { ($0["categoryKey"] as? String) == key }
        let slice = entries.suffix(max(0, lastN))

        var counts: [BreakDurationLearningStore.Feedback: Int] = [.tooShort: 0, .justRight: 0, .tooLong: 0]
        for e in slice {
            guard let raw = e["feedback"] as? String, let fb = BreakDurationLearningStore.Feedback(rawValue: raw) else { continue }
            counts[fb, default: 0] += 1
        }
        return counts
    }
}
