path = "PipelineTabView.swift"
content = open(path).read()

# ── 1. Replace the old bigFourBanner property ──────────────────────────────
old_banner_start = "\n    // MARK: - Big Four banner (bug 22)\n    private var bigFourBanner: some View {"
# find its end by locating the matching closing brace after ".buttonStyle(.plain)\n    }"
idx = content.find(old_banner_start)
if idx == -1:
    print("ERROR: bigFourBanner not found")
else:
    # find "    }\n\n    // MARK: - Primary actions" as the terminator
    terminator = "\n    // MARK: - Primary actions"
    end_idx = content.find(terminator, idx)
    if end_idx == -1:
        print("ERROR: terminator not found")
    else:
        # Build the new inline dailyDisciplineCard property
        new_card = """
    // MARK: - Daily Discipline card
    private var dailyDisciplineCard: some View {
        let check = pipeline.bigFourToday
        let done  = check.totalActions
        let passes = check.passesRule

        return VStack(alignment: .leading, spacing: 0) {

            // ── Header ──────────────────────────────────────────────────
            HStack(spacing: 8) {
                Image(systemName: passes ? "checkmark.seal.fill" : "seal")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(passes ? .green : .orange)
                Text("DAILY DISCIPLINE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.4)
                Spacer()
                Text(passes ? "\\(done) actions today ✓" : "Not completed yet")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(passes ? .green : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background((passes ? Color.green : Color.orange).opacity(0.10))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // ── Counter rows ─────────────────────────────────────────────
            VStack(spacing: 0) {
                InlineDisciplineRow(
                    icon: "signature", iconColor: .blue,
                    label: "Signed",
                    subtitle: "Contract, listing or agreement",
                    value: check.signedSomething
                ) { delta in
                    var updated = pipeline.bigFourToday
                    updated.signedSomething = max(0, updated.signedSomething + delta)
                    pipeline.saveBigFour(updated)
                }
                Divider().padding(.leading, 58)
                InlineDisciplineRow(
                    icon: "house.fill", iconColor: .green,
                    label: "Sold",
                    subtitle: "Closed sale or purchase",
                    value: check.soldSomething
                ) { delta in
                    var updated = pipeline.bigFourToday
                    updated.soldSomething = max(0, updated.soldSomething + delta)
                    pipeline.saveBigFour(updated)
                }
                Divider().padding(.leading, 58)
                InlineDisciplineRow(
                    icon: "calendar.badge.checkmark", iconColor: .orange,
                    label: "Appointment set",
                    subtitle: "Showing, meeting or call booked",
                    value: check.setAppointment
                ) { delta in
                    var updated = pipeline.bigFourToday
                    updated.setAppointment = max(0, updated.setAppointment + delta)
                    pipeline.saveBigFour(updated)
                }
                Divider().padding(.leading, 58)
                InlineDisciplineRow(
                    icon: "figure.run", iconColor: .red,
                    label: "Training completed",
                    subtitle: "Physical or professional session",
                    value: check.completedTraining
                ) { delta in
                    var updated = pipeline.bigFourToday
                    updated.completedTraining = max(0, updated.completedTraining + delta)
                    pipeline.saveBigFour(updated)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
"""
        content = content[:idx] + new_card + content[end_idx:]
        print("bigFourBanner replaced OK")

# ── 2. Remove the old BigFourSheet struct (sheet is no longer needed) ──────
bf_sheet_mark = "\n// MARK: - Big Four Sheet\nprivate struct BigFourSheet: View {"
bf_counter_end = "\n// MARK: - Supporting sub-views"
s = content.find(bf_sheet_mark)
e = content.find(bf_counter_end, s if s != -1 else 0)
if s != -1 and e != -1:
    content = content[:s] + "\n" + content[e:]
    print("BigFourSheet+BigFourCounter removed OK")
else:
    print("WARNING: BigFourSheet block not found s=%d e=%d" % (s, e))

# ── 3. Remove leftover reference to showBigFour if any ──────────────────
content = content.replace("            .sheet(isPresented: $showBigFour) {\n                BigFourSheet(pipeline: pipeline)\n            }\n", "", 1)

open(path, "w").write(content)
print("DONE", len(content))
