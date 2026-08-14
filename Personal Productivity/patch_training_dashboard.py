import re

# ── DashboardView.swift ──────────────────────────────────────────────────────
path = "DashboardView.swift"
c = open(path).read()

old = (
    "    // MARK: - DAILY GLANCE\n"
    "    private var dailyGlanceSection: some View {\n"
    "        VStack(spacing: 14) {\n"
    "            // \u2500\u2500 Cross-section nudge \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            nudgeCard\n\n"
    "            // 7-day streak strip\n"
    "            streakWeekRow\n"
    "                .padding(18)\n"
    "                .background(Color(uiColor: .secondarySystemBackground))\n"
    "                .clipShape(RoundedRectangle(cornerRadius: 22))\n\n"
    "            // \u2500\u2500 Quick Insights card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            quickInsightsCard\n"
    "        }\n"
    "        .opacity(appeared ? 1 : 0)\n"
    "        .offset(y: appeared ? 0 : 18)\n"
    "    }"
)

new = (
    "    // MARK: - DAILY GLANCE\n"
    "    private var dailyGlanceSection: some View {\n"
    "        VStack(spacing: 14) {\n"
    "            // \u2500\u2500 Cross-section nudge \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            nudgeCard\n\n"
    "            // \u2500\u2500 Training counter (subtle) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            trainingCounterRow\n\n"
    "            // 7-day streak strip\n"
    "            streakWeekRow\n"
    "                .padding(18)\n"
    "                .background(Color(uiColor: .secondarySystemBackground))\n"
    "                .clipShape(RoundedRectangle(cornerRadius: 22))\n\n"
    "            // \u2500\u2500 Quick Insights card \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            quickInsightsCard\n"
    "        }\n"
    "        .opacity(appeared ? 1 : 0)\n"
    "        .offset(y: appeared ? 0 : 18)\n"
    "    }\n\n"
    "    // Compact, unobtrusive training sessions counter for the dashboard\n"
    "    private var trainingCounterRow: some View {\n"
    "        let check    = pipeline.bigFourToday\n"
    "        let count    = check.completedTraining\n"
    "        let weekMins = pipeline.trainingMinutesThisWeek\n\n"
    "        return HStack(spacing: 14) {\n"
    "            ZStack {\n"
    "                RoundedRectangle(cornerRadius: 10)\n"
    "                    .fill(Color.red.opacity(0.10))\n"
    "                    .frame(width: 34, height: 34)\n"
    "                Image(systemName: \"figure.run\")\n"
    "                    .font(.system(size: 13, weight: .semibold))\n"
    "                    .foregroundStyle(.red)\n"
    "            }\n"
    "            VStack(alignment: .leading, spacing: 2) {\n"
    "                Text(\"Training today\")\n"
    "                    .font(.system(size: 13, weight: .semibold))\n"
    "                Text(weekMins > 0 ? \"\\(weekMins) min this week\" : \"No training logged yet\")\n"
    "                    .font(.system(size: 11))\n"
    "                    .foregroundStyle(.secondary)\n"
    "            }\n"
    "            Spacer()\n"
    "            HStack(spacing: 10) {\n"
    "                Button {\n"
    "                    HapticManager.impact()\n"
    "                    var u = pipeline.bigFourToday\n"
    "                    u.completedTraining = max(0, u.completedTraining - 1)\n"
    "                    pipeline.saveBigFour(u)\n"
    "                } label: {\n"
    "                    Image(systemName: \"minus.circle.fill\")\n"
    "                        .font(.system(size: 20))\n"
    "                        .foregroundStyle(count > 0 ? Color.red : Color(uiColor: .tertiaryLabel))\n"
    "                }\n"
    "                .buttonStyle(.plain)\n\n"
    "                Text(\"\\(count)\")\n"
    "                    .font(.system(size: 16, weight: .bold, design: .rounded))\n"
    "                    .foregroundStyle(count > 0 ? .primary : .secondary)\n"
    "                    .frame(minWidth: 18, alignment: .center)\n\n"
    "                Button {\n"
    "                    HapticManager.impact()\n"
    "                    var u = pipeline.bigFourToday\n"
    "                    u.completedTraining += 1\n"
    "                    pipeline.saveBigFour(u)\n"
    "                } label: {\n"
    "                    Image(systemName: \"plus.circle.fill\")\n"
    "                        .font(.system(size: 20))\n"
    "                        .foregroundStyle(.red)\n"
    "                }\n"
    "                .buttonStyle(.plain)\n"
    "            }\n"
    "        }\n"
    "        .padding(.horizontal, 14)\n"
    "        .padding(.vertical, 12)\n"
    "        .background(Color(uiColor: .secondarySystemBackground))\n"
    "        .clipShape(RoundedRectangle(cornerRadius: 18))\n"
    "    }"
)

if old in c:
    c = c.replace(old, new, 1)
    print("DashboardView: dailyGlanceSection updated OK")
else:
    print("DashboardView: NOT FOUND")
    # Show surrounding context
    idx = c.find("MARK: - DAILY GLANCE")
    if idx != -1:
        print(repr(c[idx:idx+400]))

open(path, "w").write(c)
print("DashboardView DONE", len(c))
