import Foundation

// MARK: - Task Scheduling Advisor
// Analyses the proposed task against existing tasks and historical session data
// to surface overlap warnings and smart suggestions before the task is saved.

struct TaskSchedulingAdvisor {

    struct Advice {
        enum Kind { case overlap, durationTooLong, betterTimeSlot, breakItUp }
        let kind: Kind
        let message: String
        let suggestedDurationMinutes: Int?   // nil = no duration change suggested
        let suggestedTime: Date?             // nil = no time change suggested
    }

    // MARK: - Public entry point

    /// Returns zero or more pieces of advice for the proposed task.
    static func advise(
        title: String,
        durationMinutes: Int,
        scheduledTime: Date,
        existingTasks: [FocusTask],
        sessionLogs: [FocusSessionLog]
    ) -> [Advice] {
        var results: [Advice] = []

        // 1. Overlap check
        if let overlap = checkOverlap(
            proposed: scheduledTime,
            duration: durationMinutes,
            existing: existingTasks
        ) {
            results.append(overlap)
        }

        // 2. Duration vs personal history
        if let durationAdvice = adviseDuration(
            title: title,
            requestedMinutes: durationMinutes,
            logs: sessionLogs
        ) {
            results.append(durationAdvice)
        }

        // 3. Time-of-day suitability
        if let timeAdvice = adviseTimeOfDay(
            durationMinutes: durationMinutes,
            scheduledTime: scheduledTime,
            logs: sessionLogs
        ) {
            results.append(timeAdvice)
        }

        return results
    }

    // MARK: - Overlap

    private static func checkOverlap(
        proposed: Date,
        duration: Int,
        existing: [FocusTask]
    ) -> Advice? {
        let durationSec = TimeInterval(duration * 60)
        let proposedEnd = proposed.addingTimeInterval(durationSec)

        // Build sorted occupied intervals from all pending tasks
        let occupied: [(start: Date, end: Date)] = existing
            .filter { $0.status == .pending }
            .compactMap { task in
                guard let taskTime = task.scheduledTime else { return nil }
                let durSec = TimeInterval(task.focusPlan.blocks.first(where: { $0.type == .focus })?.duration ?? 0)
                guard durSec > 0 else { return nil }
                return (taskTime, taskTime.addingTimeInterval(durSec))
            }
            .sorted { $0.start < $1.start }

        // Quick exit — no overlap at all
        guard occupied.contains(where: { proposed < $0.end && proposedEnd > $0.start }) else { return nil }

        // Merge adjacent/overlapping blocks into one sorted list
        var merged: [(start: Date, end: Date)] = []
        for interval in occupied {
            if merged.isEmpty {
                merged.append(interval)
            } else if interval.start <= merged.last!.end {
                merged[merged.count - 1] = (merged.last!.start, max(merged.last!.end, interval.end))
            } else {
                merged.append(interval)
            }
        }

        // Walk the entire merged timeline once to find the first gap that fits
        var candidate = proposed
        for busy in merged {
            if candidate.addingTimeInterval(durationSec) <= busy.start { break }
            if candidate < busy.end { candidate = busy.end }
        }

        let f = DateFormatter(); f.timeStyle = .short
        return Advice(
            kind: .overlap,
            message: "This overlaps with existing tasks. First free slot is at \(f.string(from: candidate)).",
            suggestedDurationMinutes: nil,
            suggestedTime: candidate
        )
    }

    // MARK: - Duration advice

    private static func adviseDuration(
        title: String,
        requestedMinutes: Int,
        logs: [FocusSessionLog]
    ) -> Advice? {
        // Look at past sessions with similar titles (simple word overlap)
        let titleWords = Set(title.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 })
        guard !titleWords.isEmpty else { return nil }

        let similar = logs.filter { log in
            // We don't have task title on the log directly, but we can compare duration patterns.
            // For now only fire if requestedMinutes is dramatically above the user's personal max focus block
            _ = log
            return true
        }

        // Personal max: 90th percentile of completed session durations
        let completedMinutes = similar
            .filter { $0.exitReason == .completed }
            .map { Int($0.duration / 60) }
            .sorted()

        guard completedMinutes.count >= 5 else { return nil }

        let p90Index = Int(Double(completedMinutes.count) * 0.9)
        let personalMax = completedMinutes[min(p90Index, completedMinutes.count - 1)]

        if requestedMinutes > personalMax + 30 {
            // Suggest breaking it up
            let sessions = (requestedMinutes + personalMax - 1) / personalMax
            return Advice(
                kind: .breakItUp,
                message: "Your typical focus limit is around \(personalMax) min. Consider splitting this into \(sessions) sessions for better results.",
                suggestedDurationMinutes: personalMax,
                suggestedTime: nil
            )
        }

        return nil
    }

    // MARK: - Time-of-day advice

    private static func adviseTimeOfDay(
        durationMinutes: Int,
        scheduledTime: Date,
        logs: [FocusSessionLog]
    ) -> Advice? {
        let hour = Calendar.current.component(.hour, from: scheduledTime)

        // Only advise for long sessions (>= 60 min) scheduled in the afternoon slump (13-15h)
        guard durationMinutes >= 60 && (hour >= 13 && hour <= 15) else { return nil }

        // Check if the user historically performs worse in this window
        let afternoonSessions = logs.filter {
            let h = Calendar.current.component(.hour, from: $0.startDate)
            return h >= 13 && h <= 15 && $0.exitReason == .completed
        }
        let morningSessions = logs.filter {
            let h = Calendar.current.component(.hour, from: $0.startDate)
            return h >= 8 && h <= 12 && $0.exitReason == .completed
        }

        guard afternoonSessions.count >= 3, morningSessions.count >= 3 else { return nil }

        let afternoonAvg = afternoonSessions.map { $0.duration }.reduce(0, +) / Double(afternoonSessions.count)
        let morningAvg   = morningSessions.map   { $0.duration }.reduce(0, +) / Double(morningSessions.count)

        guard afternoonAvg < morningAvg * 0.75 else { return nil }

        // Suggest 9 AM the same day or next morning
        var components = Calendar.current.dateComponents([.year, .month, .day], from: scheduledTime)
        components.hour = 9; components.minute = 0
        let morning = Calendar.current.date(from: components) ?? scheduledTime
        let suggestion = morning > Date() ? morning : Calendar.current.date(byAdding: .day, value: 1, to: morning) ?? scheduledTime

        return Advice(
            kind: .betterTimeSlot,
            message: "Your focus sessions tend to be shorter in the early afternoon. Morning scheduling often works better for long tasks.",
            suggestedDurationMinutes: nil,
            suggestedTime: suggestion
        )
    }
}
