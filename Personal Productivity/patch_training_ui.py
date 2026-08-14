path = "DashboardView.swift"
c = open(path).read()

start = "    private var trainingCheckRow: some View {"
end   = "\n    // MARK: - Quick Insights card"

s = c.find(start)
e = c.find(end, s)

if s == -1 or e == -1:
    print("ERROR: markers not found s=%d e=%d" % (s, e))
else:
    new_prop = '''    private var trainingCheckRow: some View {
        let done      = pipeline.trainedToday
        let streak    = pipeline.trainingStreak
        let weekCount = pipeline.weeklyWorkoutCount
        let goalMet   = pipeline.weeklyWorkoutGoalMet
        let hours     = pipeline.hoursSinceLastWorkout
        let graceLeft = hours.map { max(0.0, 72.0 - $0) }
        let urgent    = graceLeft.map { $0 < 18 && $0 > 0 } ?? false

        return Button {
            HapticManager.impact()
            var u = pipeline.bigFourToday
            u.completedTraining = done ? 0 : 1
            pipeline.saveBigFour(u)
        } label: {
            HStack(spacing: 13) {

                // ── Circle icon: red outline unfilled → red filled on press ──
                ZStack {
                    Circle()
                        .fill(done
                              ? Color.red.opacity(0.15)
                              : Color.clear)
                        .frame(width: 36, height: 36)
                    Circle()
                        .strokeBorder(Color.red.opacity(done ? 0 : 0.55), lineWidth: 1.5)
                        .frame(width: 36, height: 36)
                    Image(systemName: done ? "checkmark" : "figure.run")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(done ? .red : Color.red.opacity(0.55))
                        .scaleEffect(done ? 1.05 : 0.9)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
                }

                // ── Label + subtext ───────────────────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text("Training")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(done ? .primary : Color.red.opacity(0.7))

                    Group {
                        if let gl = graceLeft, gl > 0, !done {
                            Text(String(format: "%.0fh left in grace window", gl))
                                .foregroundStyle(urgent ? .orange : .secondary)
                        } else if done {
                            Text("\\(weekCount)/3 this week")
                                .foregroundStyle(goalMet ? Color.green : Color(uiColor: .secondaryLabel))
                        } else {
                            Text("\\(weekCount)/3 this week")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .font(.system(size: 10, weight: .medium))
                }

                Spacer()

                // ── Weekly pip dots (red) ─────────────────────────────────
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \\.self) { i in
                        Circle()
                            .fill(i < weekCount
                                  ? Color.red
                                  : Color.red.opacity(0.15))
                            .frame(width: 6, height: 6)
                            .animation(.spring(response: 0.35).delay(Double(i) * 0.06), value: weekCount)
                    }
                }

                // ── Streak counter (always visible, red) ──────────────────
                VStack(spacing: 1) {
                    Text("\\(streak)")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(streak > 0 ? Color.red : Color.red.opacity(0.30))
                        .contentTransition(.numericText())
                    Text(streak == 1 ? "workout" : "workouts")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(streak > 0 ? Color.red.opacity(0.6) : Color.red.opacity(0.20))
                        .kerning(0.2)
                }
                .frame(minWidth: 40, alignment: .center)
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(streak > 0
                              ? Color.red.opacity(0.09)
                              : Color.red.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.red.opacity(streak > 0 ? 0.20 : 0.10), lineWidth: 1)
                        )
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
                                urgent ? Color.orange.opacity(0.5) :
                                done   ? Color.red.opacity(0.25)   : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }'''
    c = c[:s] + new_prop + c[e:]
    print("trainingCheckRow rewritten OK")

open(path, "w").write(c)
print("DONE", len(c))
