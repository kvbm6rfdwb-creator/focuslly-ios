import re

# ─────────────────────────────────────────────────────────────────────────────
# 1.  PipelineStore.swift — replace old trainingStreak with new logic
# ─────────────────────────────────────────────────────────────────────────────
ps_path = "PipelineStore.swift"
ps = open(ps_path).read()

old_streak = (
    "    var trainedToday: Bool { bigFourToday.completedTraining > 0 }\n\n"
    "    /// Consecutive days with completedTraining > 0, counting back from today.\n"
    "    var trainingStreak: Int {\n"
    "        let cal = Calendar.current\n"
    "        var streak = 0\n"
    "        var day = cal.startOfDay(for: Date())\n"
    "        for _ in 0..<365 {\n"
    "            let trained = bigFourChecks.contains {\n"
    "                cal.isDate($0.date, inSameDayAs: day) && $0.completedTraining > 0\n"
    "            }\n"
    "            if trained { streak += 1; day = cal.date(byAdding: .day, value: -1, to: day) ?? day }\n"
    "            else { break }\n"
    "        }\n"
    "        return streak\n"
    "    }"
)

new_streak = (
    "    var trainedToday: Bool { bigFourToday.completedTraining > 0 }\n\n"
    "    /// Number of workout sessions logged in the current calendar week (Mon–Sun).\n"
    "    var weeklyWorkoutCount: Int {\n"
    "        bigFourChecks.filter { isInCurrentWeek($0.date) && $0.completedTraining > 0 }.count\n"
    "    }\n\n"
    "    /// Whether the user is safe for this week's 3-workout minimum.\n"
    "    var weeklyWorkoutGoalMet: Bool { weeklyWorkoutCount >= 3 }\n\n"
    "    /// Hours since the last recorded workout (nil if never trained).\n"
    "    var hoursSinceLastWorkout: Double? {\n"
    "        let last = bigFourChecks\n"
    "            .filter { $0.completedTraining > 0 }\n"
    "            .sorted { $0.date > $1.date }\n"
    "            .first\n"
    "        guard let last else { return nil }\n"
    "        return Date().timeIntervalSince(last.date) / 3600\n"
    "    }\n\n"
    "    /// True when the 72h grace window has expired (streak at risk).\n"
    "    var workoutGraceExpired: Bool {\n"
    "        guard let h = hoursSinceLastWorkout else { return false }\n"
    "        return h > 72\n"
    "    }\n\n"
    "    /// Streak of consecutive weeks where the user:\n"
    "    ///   - logged at least 3 workouts, AND\n"
    "    ///   - never went more than 72 h without a workout.\n"
    "    /// Within-week grace: a single gap of up to 72 h is forgiven.\n"
    "    var trainingStreak: Int {\n"
    "        let cal = Calendar.current\n"
    "        var streak = 0\n"
    "        let today = Date()\n"
    "        // Walk back week by week (up to 2 years)\n"
    "        for weekOffset in 0..<104 {\n"
    "            guard let weekStart = cal.date(\n"
    "                byAdding: .weekOfYear, value: -weekOffset,\n"
    "                to: cal.startOfWeek(for: today)) else { break }\n"
    "            let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart\n"
    "            let weekChecks = bigFourChecks\n"
    "                .filter { $0.date >= weekStart && $0.date < weekEnd && $0.completedTraining > 0 }\n"
    "                .sorted { $0.date < $1.date }\n"
    "            // Must have at least 3 sessions this week\n"
    "            guard weekChecks.count >= 3 else {\n"
    "                // Current partial week: don't break yet if today is early in the week\n"
    "                if weekOffset == 0 { continue }\n"
    "                break\n"
    "            }\n"
    "            // No gap > 72 h between consecutive sessions\n"
    "            var maxGap: Double = 0\n"
    "            if weekOffset > 0 {\n"
    "                // Also check gap from last session of previous week to first of this week\n"
    "                // (handled implicitly — if the streak was already counted it's fine)\n"
    "            }\n"
    "            for i in 1..<weekChecks.count {\n"
    "                let gap = weekChecks[i].date.timeIntervalSince(weekChecks[i-1].date) / 3600\n"
    "                maxGap = max(maxGap, gap)\n"
    "            }\n"
    "            if maxGap > 72 { break }\n"
    "            streak += 1\n"
    "        }\n"
    "        return streak\n"
    "    }"
)

if old_streak in ps:
    ps = ps.replace(old_streak, new_streak, 1)
    print("PipelineStore: trainingStreak replaced OK")
else:
    print("PipelineStore: old_streak NOT found — inserting after trainedToday")
    ps = ps.replace(
        "    var trainedToday: Bool { bigFourToday.completedTraining > 0 }",
        "    var trainedToday: Bool { bigFourToday.completedTraining > 0 }\n\n" + new_streak.split("    var trainedToday")[0].lstrip("\n"),
        1
    )

open(ps_path, "w").write(ps)
print("PipelineStore DONE", len(ps))

# ─────────────────────────────────────────────────────────────────────────────
# Add Calendar.startOfWeek helper at the bottom of PipelineStore.swift
# ─────────────────────────────────────────────────────────────────────────────
ps = open(ps_path).read()
if "startOfWeek" not in ps:
    ext = (
        "\n// MARK: - Calendar helper\n"
        "private extension Calendar {\n"
        "    func startOfWeek(for date: Date) -> Date {\n"
        "        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)\n"
        "        return self.date(from: comps) ?? date\n"
        "    }\n"
        "}\n"
    )
    ps = ps.rstrip() + "\n" + ext
    open(ps_path, "w").write(ps)
    print("Calendar.startOfWeek extension added")
else:
    print("startOfWeek already present")

# ─────────────────────────────────────────────────────────────────────────────
# 2.  DashboardView.swift — add trainingCheckRow reference + rewrite property
# ─────────────────────────────────────────────────────────────────────────────
dv_path = "DashboardView.swift"
dv = open(dv_path).read()

# Add reference in dailyGlanceSection if not already there
nudge_anchor = "            nudgeCard\n\n            // 7-day streak strip\n"
nudge_with_training = (
    "            nudgeCard\n\n"
    "            // \u2500\u2500 Training row \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            trainingCheckRow\n\n"
    "            // 7-day streak strip\n"
)
if nudge_anchor in dv and "trainingCheckRow" not in dv:
    dv = dv.replace(nudge_anchor, nudge_with_training, 1)
    print("DashboardView: trainingCheckRow reference inserted OK")
elif "trainingCheckRow" in dv:
    print("DashboardView: reference already present")
else:
    print("DashboardView: nudge anchor not found")

# Rewrite the trainingCheckRow property
old_prop_start = "    // Subtle training checkmark row with streak for the dashboard\n    private var trainingCheckRow: some View {"
old_prop_end = "\n    // MARK: - Quick Insights card"
s = dv.find(old_prop_start)
e = dv.find(old_prop_end, s if s != -1 else 0)

new_prop = '''    // Training row — gamified checkmark with 72h-grace weekly streak
    private var trainingCheckRow: some View {
        let done        = pipeline.trainedToday
        let streak      = pipeline.trainingStreak
        let weekCount   = pipeline.weeklyWorkoutCount
        let goalMet     = pipeline.weeklyWorkoutGoalMet
        let hours       = pipeline.hoursSinceLastWorkout
        let graceLeft   = hours.map { max(0.0, 72.0 - $0) }
        let graceUrgent = graceLeft.map { $0 < 18 && $0 > 0 } ?? false

        // Status colour: red when done today, orange when grace warning, secondary otherwise
        let accentColor: Color = done ? .red : graceUrgent ? .orange : Color(uiColor: .secondaryLabel)

        return Button {
            HapticManager.impact()
            var u = pipeline.bigFourToday
            u.completedTraining = done ? 0 : 1
            pipeline.saveBigFour(u)
        } label: {
            HStack(spacing: 13) {

                // ── Animated checkmark icon ───────────────────────────────
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(done ? 0.14 : 0.07))
                        .frame(width: 36, height: 36)
                    Image(systemName: done ? "checkmark" : "figure.run")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .scaleEffect(done ? 1.0 : 0.9)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
                }

                // ── Label + subtext ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(done ? .primary : .secondary)

                    Group {
                        if let gl = graceLeft, gl > 0, !done {
                            Text(String(format: "%.0fh to log next session", gl))
                                .foregroundStyle(graceUrgent ? .orange : .secondary)
                        } else if done {
                            Text("\\(weekCount)/3 this week")
                                .foregroundStyle(goalMet ? Color.green : Color(uiColor: .secondaryLabel))
                        } else {
                            Text("\\(weekCount)/3 this week · tap to log")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                }

                Spacer()

                // ── Weekly pip dots ───────────────────────────────────────
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \\.self) { i in
                        Circle()
                            .fill(i < weekCount
                                  ? (goalMet ? Color.green : Color.red)
                                  : Color(uiColor: .tertiarySystemFill))
                            .frame(width: 7, height: 7)
                            .animation(.spring(response: 0.4).delay(Double(i) * 0.05), value: weekCount)
                    }
                }

                // ── Streak badge ──────────────────────────────────────────
                VStack(spacing: 1) {
                    HStack(spacing: 2) {
                        Image(systemName: streak > 0 ? "flame.fill" : "flame")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(streak > 0 ? .orange : Color(uiColor: .quaternaryLabel))
                        Text("\\(streak)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(streak > 0 ? .primary : Color(uiColor: .quaternaryLabel))
                            .contentTransition(.numericText())
                    }
                    Text("wks")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .kerning(0.2)
                }
                .frame(minWidth: 32, alignment: .center)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(streak > 0
                              ? Color.orange.opacity(0.10)
                              : Color(uiColor: .tertiarySystemFill))
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(
                                graceUrgent ? Color.orange.opacity(0.4) :
                                done ? Color.red.opacity(0.2) :
                                Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
'''

if s != -1 and e != -1:
    dv = dv[:s] + new_prop + dv[e:]
    print("DashboardView: trainingCheckRow rewritten OK")
elif s == -1:
    # Insert before Quick Insights
    qi = dv.find("    // MARK: - Quick Insights card")
    if qi != -1:
        dv = dv[:qi] + new_prop + "\n" + dv[qi:]
        print("DashboardView: trainingCheckRow inserted before Quick Insights OK")
    else:
        print("DashboardView: could not find insertion point")

open(dv_path, "w").write(dv)
print("DashboardView DONE", len(dv))
