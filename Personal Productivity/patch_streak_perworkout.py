path = "PipelineStore.swift"
c = open(path).read()

old = '''    var trainedToday: Bool { bigFourToday.completedTraining > 0 }

    /// Number of workout sessions logged in the current calendar week (Mon–Sun).
    var weeklyWorkoutCount: Int {
        bigFourChecks.filter { isInCurrentWeek($0.date) && $0.completedTraining > 0 }.count
    }

    /// Whether the user is safe for this week's 3-workout minimum.
    var weeklyWorkoutGoalMet: Bool { weeklyWorkoutCount >= 3 }

    /// Hours since the last recorded workout (nil if never trained).
    var hoursSinceLastWorkout: Double? {
        let last = bigFourChecks
            .filter { $0.completedTraining > 0 }
            .sorted { $0.date > $1.date }
            .first
        guard let last else { return nil }
        return Date().timeIntervalSince(last.date) / 3600
    }

    /// True when the 72h grace window has expired (streak at risk).
    var workoutGraceExpired: Bool {
        guard let h = hoursSinceLastWorkout else { return false }
        return h > 72
    }

    /// Streak of consecutive weeks where the user:
    ///   - logged at least 3 workouts, AND
    ///   - never went more than 72 h without a workout.
    /// Within-week grace: a single gap of up to 72 h is forgiven.
    var trainingStreak: Int {
        let cal = Calendar.current
        var streak = 0
        let today = Date()
        // Walk back week by week (up to 2 years)
        for weekOffset in 0..<104 {
            guard let weekStart = cal.date(
                byAdding: .weekOfYear, value: -weekOffset,
                to: cal.startOfWeek(for: today)) else { break }
            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let weekChecks = bigFourChecks
                .filter { $0.date >= weekStart && $0.date < weekEnd && $0.completedTraining > 0 }
                .sorted { $0.date < $1.date }
            // Must have at least 3 sessions this week
            guard weekChecks.count >= 3 else {
                // Current partial week: don't break yet if today is early in the week
                if weekOffset == 0 { continue }
                break
            }
            // No gap > 72 h between consecutive sessions
            var maxGap: Double = 0
            if weekOffset > 0 {
                // Also check gap from last session of previous week to first of this week
                // (handled implicitly — if the streak was already counted it\'s fine)
            }
            for i in 1..<weekChecks.count {
                let gap = weekChecks[i].date.timeIntervalSince(weekChecks[i-1].date) / 3600
                maxGap = max(maxGap, gap)
            }
            if maxGap > 72 { break }
            streak += 1
        }
        return streak
    }'''

new = '''    var trainedToday: Bool { bigFourToday.completedTraining > 0 }

    /// Number of workout sessions logged in the current calendar week (Mon–Sun).
    var weeklyWorkoutCount: Int {
        bigFourChecks.filter { isInCurrentWeek($0.date) && $0.completedTraining > 0 }.count
    }

    /// Whether the user has hit the 3-per-week minimum.
    var weeklyWorkoutGoalMet: Bool { weeklyWorkoutCount >= 3 }

    /// Hours since the last recorded workout session (nil if never trained).
    var hoursSinceLastWorkout: Double? {
        let last = bigFourChecks
            .filter { $0.completedTraining > 0 }
            .sorted { $0.date > $1.date }
            .first
        guard let last else { return nil }
        return Date().timeIntervalSince(last.date) / 3600
    }

    /// True when 72h have passed since the last workout — grace window expired.
    var workoutGraceExpired: Bool {
        (hoursSinceLastWorkout ?? 0) > 72
    }

    /// Total consecutive workouts without breaking either rule:
    ///   1. No gap > 72h between any two consecutive sessions.
    ///   2. The week that each session belongs to must contain >= 3 sessions.
    /// Rule 2 is not enforced for the *current* (in-progress) week.
    var trainingStreak: Int {
        let cal  = Calendar.current
        // All days on which the user trained, sorted newest first
        let trainedDays = bigFourChecks
            .filter { $0.completedTraining > 0 }
            .map    { cal.startOfDay(for: $0.date) }
            .sorted { $0 > $1 }
        guard !trainedDays.isEmpty else { return 0 }

        // Group by calendar week so we can enforce the 3/week rule
        func weekKey(_ date: Date) -> String {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return "\\(comps.yearForWeekOfYear ?? 0)-\\(comps.weekOfYear ?? 0)"
        }

        var weekCounts: [String: Int] = [:]
        for day in trainedDays { weekCounts[weekKey(day), default: 0] += 1 }

        let currentWeekKey = weekKey(Date())

        var streak = 0
        for (idx, day) in trainedDays.enumerated() {
            // Rule 1: gap to next (more recent) session must be <= 72h
            if idx > 0 {
                let gapHours = trainedDays[idx - 1].timeIntervalSince(day) / 3600
                if gapHours > 72 { break }
            }
            // Rule 2: the week this session belongs to must have >= 3 sessions,
            //         unless it\'s the current (not yet finished) week.
            let wk = weekKey(day)
            if wk != currentWeekKey && (weekCounts[wk] ?? 0) < 3 { break }

            streak += 1
        }
        return streak
    }'''

if old in c:
    c = c.replace(old, new, 1)
    print("PipelineStore: trainingStreak replaced OK")
else:
    print("NOT FOUND")

open(path, "w").write(c)
print("DONE", len(c))
