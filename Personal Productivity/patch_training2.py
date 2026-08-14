path = "DashboardView.swift"
c = open(path).read()

# Find the exact block by searching for key anchor strings
old_anchor = "            // 7-day streak strip\n            streakWeekRow\n"
insert_before = "            // 7-day streak strip\n"

new_row_block = (
    "            // \u2500\u2500 Training counter (subtle) \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\n"
    "            trainingCounterRow\n\n"
)

if insert_before in c and "trainingCounterRow" not in c:
    c = c.replace(insert_before, new_row_block + insert_before, 1)
    print("Inserted trainingCounterRow reference OK")
elif "trainingCounterRow" in c:
    print("Already present")
else:
    print("Anchor not found")

# Now insert the property definition — find a good anchor after dailyGlanceSection closes
# Insert right before "    // MARK: - Quick Insights card"
insert_prop_before = "    // MARK: - Quick Insights card"

training_prop = (
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
    '                Image(systemName: "figure.run")\n'
    "                    .font(.system(size: 13, weight: .semibold))\n"
    "                    .foregroundStyle(.red)\n"
    "            }\n"
    "            VStack(alignment: .leading, spacing: 2) {\n"
    '                Text("Training today")\n'
    "                    .font(.system(size: 13, weight: .semibold))\n"
    '                Text(weekMins > 0 ? "\\(weekMins) min this week" : "No training logged yet")\n'
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
    '                    Image(systemName: "minus.circle.fill")\n'
    "                        .font(.system(size: 20))\n"
    "                        .foregroundStyle(count > 0 ? Color.red : Color(uiColor: .tertiaryLabel))\n"
    "                }\n"
    "                .buttonStyle(.plain)\n\n"
    '                Text("\\(count)")\n'
    "                    .font(.system(size: 16, weight: .bold, design: .rounded))\n"
    "                    .foregroundStyle(count > 0 ? .primary : .secondary)\n"
    "                    .frame(minWidth: 18, alignment: .center)\n\n"
    "                Button {\n"
    "                    HapticManager.impact()\n"
    "                    var u = pipeline.bigFourToday\n"
    "                    u.completedTraining += 1\n"
    "                    pipeline.saveBigFour(u)\n"
    "                } label: {\n"
    '                    Image(systemName: "plus.circle.fill")\n'
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
    "    }\n\n"
)

if insert_prop_before in c and "private var trainingCounterRow" not in c:
    c = c.replace(insert_prop_before, training_prop + insert_prop_before, 1)
    print("trainingCounterRow property inserted OK")
elif "private var trainingCounterRow" in c:
    print("Property already present")
else:
    print("Property anchor not found")

open(path, "w").write(c)
print("DONE", len(c))
