path = "DashboardView.swift"
c = open(path).read()

# ── 1. Insert trainingCounterRow into dailyGlanceSection ───────────────────
old_glance = (
    "    private var dailyGlanceSection: some View {\n"
    "        VStack(spacing: 14) {\n"
    "            // \u2500\u2500 Cross-section nudge \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            nudgeCard\n\n"
    "            // 7-day streak strip\n"
)
new_glance = (
    "    private var dailyGlanceSection: some View {\n"
    "        VStack(spacing: 14) {\n"
    "            // \u2500\u2500 Cross-section nudge \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            nudgeCard\n\n"
    "            // \u2500\u2500 Training checkmark \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            trainingCheckRow\n\n"
    "            // 7-day streak strip\n"
)
if old_glance in c:
    c = c.replace(old_glance, new_glance, 1)
    print("dailyGlanceSection updated OK")
else:
    print("dailyGlanceSection anchor NOT found")

# ── 2. Replace the entire old trainingCounterRow property ─────────────────
# Find its start and end
start_marker = "    // Compact, unobtrusive training sessions counter for the dashboard\n    private var trainingCounterRow"
end_marker = "\n    // MARK: - Quick Insights card"

s = c.find(start_marker)
e = c.find(end_marker, s if s != -1 else 0)
if s != -1 and e != -1:
    new_prop = (
        "    // Subtle training checkmark row with streak for the dashboard\n"
        "    private var trainingCheckRow: some View {\n"
        "        let done   = pipeline.trainedToday\n"
        "        let streak = pipeline.trainingStreak\n\n"
        "        return Button {\n"
        "            HapticManager.impact()\n"
        "            var u = pipeline.bigFourToday\n"
        "            u.completedTraining = done ? 0 : 1\n"
        "            pipeline.saveBigFour(u)\n"
        "        } label: {\n"
        "            HStack(spacing: 12) {\n"
        "                // Checkmark circle\n"
        "                ZStack {\n"
        "                    Circle()\n"
        '                        .fill(done ? Color.red.opacity(0.12) : Color(uiColor: .tertiarySystemFill))\n'
        "                        .frame(width: 32, height: 32)\n"
        "                    Image(systemName: done ? \"checkmark\" : \"figure.run\")\n"
        "                        .font(.system(size: 13, weight: .semibold))\n"
        "                        .foregroundStyle(done ? .red : Color(uiColor: .tertiaryLabel))\n"
        "                }\n"
        '                Text("Training")\n'
        "                    .font(.system(size: 13, weight: .medium))\n"
        "                    .foregroundStyle(done ? .primary : .secondary)\n"
        "                Spacer()\n"
        "                // Streak badge — only shown when streak > 0\n"
        "                if streak > 0 {\n"
        "                    HStack(spacing: 3) {\n"
        '                        Image(systemName: "flame.fill")\n'
        "                            .font(.system(size: 10, weight: .semibold))\n"
        "                            .foregroundStyle(.orange)\n"
        "                        Text(\"\\(streak)d\")\n"
        "                            .font(.system(size: 11, weight: .bold, design: .rounded))\n"
        "                            .foregroundStyle(.orange)\n"
        "                    }\n"
        "                    .padding(.horizontal, 8)\n"
        "                    .padding(.vertical, 4)\n"
        "                    .background(Color.orange.opacity(0.10))\n"
        "                    .clipShape(Capsule())\n"
        "                } else if done {\n"
        "                    Text(\"Done today\")\n"
        "                        .font(.system(size: 11, weight: .medium))\n"
        "                        .foregroundStyle(.green)\n"
        "                }\n"
        "                Image(systemName: done ? \"checkmark.circle.fill\" : \"circle\")\n"
        "                    .font(.system(size: 18))\n"
        "                    .foregroundStyle(done ? .red : Color(uiColor: .quaternaryLabel))\n"
        "                    .animation(.spring(response: 0.3), value: done)\n"
        "            }\n"
        "            .padding(.horizontal, 14)\n"
        "            .padding(.vertical, 11)\n"
        "            .background(Color(uiColor: .secondarySystemBackground))\n"
        "            .clipShape(RoundedRectangle(cornerRadius: 16))\n"
        "        }\n"
        "        .buttonStyle(.plain)\n"
        "    }"
    )
    c = c[:s] + new_prop + c[e:]
    print("trainingCheckRow property replaced OK")
else:
    print("trainingCounterRow NOT found s=%d e=%d" % (s, e))
    # Try to find and insert as a new property before Quick Insights
    if "private var trainingCheckRow" not in c:
        qi = c.find("    // MARK: - Quick Insights card")
        if qi != -1:
            new_prop2 = (
                "    // Subtle training checkmark row with streak for the dashboard\n"
                "    private var trainingCheckRow: some View {\n"
                "        let done   = pipeline.trainedToday\n"
                "        let streak = pipeline.trainingStreak\n\n"
                "        return Button {\n"
                "            HapticManager.impact()\n"
                "            var u = pipeline.bigFourToday\n"
                "            u.completedTraining = done ? 0 : 1\n"
                "            pipeline.saveBigFour(u)\n"
                "        } label: {\n"
                "            HStack(spacing: 12) {\n"
                "                ZStack {\n"
                "                    Circle()\n"
                '                        .fill(done ? Color.red.opacity(0.12) : Color(uiColor: .tertiarySystemFill))\n'
                "                        .frame(width: 32, height: 32)\n"
                "                    Image(systemName: done ? \"checkmark\" : \"figure.run\")\n"
                "                        .font(.system(size: 13, weight: .semibold))\n"
                "                        .foregroundStyle(done ? .red : Color(uiColor: .tertiaryLabel))\n"
                "                }\n"
                '                Text("Training")\n'
                "                    .font(.system(size: 13, weight: .medium))\n"
                "                    .foregroundStyle(done ? .primary : .secondary)\n"
                "                Spacer()\n"
                "                if streak > 0 {\n"
                "                    HStack(spacing: 3) {\n"
                '                        Image(systemName: "flame.fill")\n'
                "                            .font(.system(size: 10, weight: .semibold))\n"
                "                            .foregroundStyle(.orange)\n"
                "                        Text(\"\\(streak)d\")\n"
                "                            .font(.system(size: 11, weight: .bold, design: .rounded))\n"
                "                            .foregroundStyle(.orange)\n"
                "                    }\n"
                "                    .padding(.horizontal, 8)\n"
                "                    .padding(.vertical, 4)\n"
                "                    .background(Color.orange.opacity(0.10))\n"
                "                    .clipShape(Capsule())\n"
                "                } else if done {\n"
                "                    Text(\"Done today\")\n"
                "                        .font(.system(size: 11, weight: .medium))\n"
                "                        .foregroundStyle(.green)\n"
                "                }\n"
                "                Image(systemName: done ? \"checkmark.circle.fill\" : \"circle\")\n"
                "                    .font(.system(size: 18))\n"
                "                    .foregroundStyle(done ? .red : Color(uiColor: .quaternaryLabel))\n"
                "                    .animation(.spring(response: 0.3), value: done)\n"
                "            }\n"
                "            .padding(.horizontal, 14)\n"
                "            .padding(.vertical, 11)\n"
                "            .background(Color(uiColor: .secondarySystemBackground))\n"
                "            .clipShape(RoundedRectangle(cornerRadius: 16))\n"
                "        }\n"
                "        .buttonStyle(.plain)\n"
                "    }\n\n"
            )
            c = c[:qi] + new_prop2 + c[qi:]
            print("trainingCheckRow inserted before Quick Insights OK")

open(path, "w").write(c)
print("DONE", len(c))
