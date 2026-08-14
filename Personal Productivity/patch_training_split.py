path = "DashboardView.swift"
c = open(path).read()

start = "    private var trainingCheckRow: some View {"
end   = "\n    // MARK: - Quick Insights card"

s = c.find(start)
e = c.find(end, s)

new_prop = '''    private var trainingCheckRow: some View {
        let done      = pipeline.trainedToday
        let streak    = pipeline.trainingStreak
        let weekCount = pipeline.weeklyWorkoutCount
        let goalMet   = pipeline.weeklyWorkoutGoalMet
        let hours     = pipeline.hoursSinceLastWorkout
        let graceLeft: Double? = hours.map { max(0.0, 72.0 - $0) }
        let urgent    = graceLeft.map { $0 < 18 && $0 > 0 } ?? false

        return TrainingCheckRowContent(
            done: done, streak: streak, weekCount: weekCount,
            goalMet: goalMet, graceLeft: graceLeft, urgent: urgent
        ) {
            HapticManager.impact()
            var u = pipeline.bigFourToday
            u.completedTraining = done ? 0 : 1
            pipeline.saveBigFour(u)
        }
    }'''

if s != -1 and e != -1:
    c = c[:s] + new_prop + c[e:]
    print("trainingCheckRow simplified OK")
else:
    print("ERROR s=%d e=%d" % (s, e))

open(path, "w").write(c)
print("DONE", len(c))
