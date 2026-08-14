import SwiftUI

// MARK: - Scroll offset preference key
struct BreakScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Inline break suggestion card
struct BreakSuggestionCard: View {
    let decision: BreakSuggestionEngine.Decision
    let accentColor: Color

    /// Tracks which alternative the user has switched to (nil = primary)
    @State private var activeDecision: BreakSuggestionEngine.Decision? = nil

    private var shown: BreakSuggestionEngine.Decision { activeDecision ?? decision }

    private var effectiveAccent: Color {
        shown.category == .meditation ? Color(red: 0.55, green: 0.45, blue: 0.95) : accentColor
    }
    private var isMeditation: Bool { shown.category == .meditation }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Header ───────────────────────────────────────────────
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: breakTypeIcon(shown.breakType))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(effectiveAccent)
                Text("BREAK PLAN")
                    .font(.system(size: 10, weight: .heavy))
                    .tracking(1.0)
                    .foregroundStyle(.white.opacity(0.35))
                if isMeditation {
                    Text("MEDITATION")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(0.8)
                        .foregroundStyle(effectiveAccent.opacity(0.9))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(effectiveAccent.opacity(0.18)))
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .semibold))
                    Text(shown.durationRange)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(effectiveAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(effectiveAccent.opacity(0.15)))
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // ── Headline + goal ──────────────────────────────────────
            VStack(alignment: .leading, spacing: 6) {
                Text(shown.headline)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                Text(shown.goal)
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)

            // Hairline
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)

            // ── Step timeline ─────────────────────────────────────────
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(shown.plan.steps.enumerated()), id: \.offset) { index, step in
                    BreakStepRow(
                        step: step,
                        index: index,
                        isLast: index == shown.plan.steps.count - 1,
                        accentColor: step.isMeditation ? effectiveAccent : accentColor
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            // Hairline
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .frame(height: 0.5)

            // ── Why this plan, right now ──────────────────────────────
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "brain.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(effectiveAccent.opacity(0.7))
                    .padding(.top, 1)
                Text(shown.plan.rationale)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // ── Time of day note (optional) ──────────────────────────
            if let note = shown.timeOfDayNote {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: shown.isEndOfDay ? "moon.stars.fill" : "clock.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(shown.isEndOfDay ? Color.indigo.opacity(0.8) : Color.white.opacity(0.3))
                        .padding(.top, 1)
                    Text(note)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(shown.isEndOfDay ? Color.indigo.opacity(0.8) : Color.white.opacity(0.4))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            // ── Alternative choices (Trougakos 2014 — autonomy) ─────
            // Choosing your own break activity significantly amplifies recovery.
            let allChoices = buildChoiceList()
            if !allChoices.isEmpty {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 0.5)

                VStack(alignment: .leading, spacing: 10) {
                    Text("OR TRY INSTEAD")
                        .font(.system(size: 9, weight: .heavy))
                        .tracking(1.0)
                        .foregroundStyle(.white.opacity(0.25))
                        .padding(.bottom, 2)

                    ForEach(Array(allChoices.enumerated()), id: \.offset) { _, alt in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                activeDecision = alt
                            }
                        } label: {
                            HStack(spacing: 12) {
                                let altAccent: Color = alt.category == .meditation
                                    ? Color(red: 0.55, green: 0.45, blue: 0.95)
                                    : accentColor
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(altAccent.opacity(0.14))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: breakTypeIcon(alt.breakType))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(altAccent)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(alt.headline)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                    Text(alt.goal)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.45))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.25))
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(
                                        activeDecision?.breakType == alt.breakType ? 0.08 : 0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }
        }
        .background(Color.clear)
        .padding(.horizontal, 20)
    }

    /// Builds the list of alternatives — primary choices first, then the unselected primary.
    private func buildChoiceList() -> [BreakSuggestionEngine.Decision] {
        var list: [BreakSuggestionEngine.Decision] = []
        // If user picked an alternative, put the original primary back as an option
        if let active = activeDecision {
            if active.breakType != decision.breakType {
                list.append(decision)
            }
            // Add the other choices that aren't currently shown
            list += decision.breakChoices.filter { $0.breakType != active.breakType }
        } else {
            list = decision.breakChoices
        }
        return Array(list.prefix(3))
    }

    private func breakTypeIcon(_ type: BreakSuggestionEngine.BreakType) -> String {
        switch type {
        case .sensoryShift:              return "sparkles"
        case .physicalReset:             return "figure.flexibility"
        case .intentionalPause:          return "lungs.fill"
        case .playfulMovement:           return "figure.walk"
        case .cognitiveOffload:          return "brain.fill"
        case .trueRest:                  return "moon.zzz.fill"
        case .switchRitual:              return "sunset.fill"
        case .breathingMeditation:       return "lungs.fill"
        case .bodyScan:                  return "figure.mind.and.body"
        case .openAwareness:             return "eye"
        case .relaxationAudio:           return "headphones"
        // Tier 1
        case .napRest:                   return "moon.zzz.fill"
        case .physiologicalSigh:         return "wind"
        case .nsdRest:                   return "figure.mind.and.body"
        case .focusedAttentionMeditation: return "1.circle.fill"
        // Tier 2
        case .morningSunlight:           return "sun.horizon.fill"
        case .caffeineWarning:           return "cup.and.saucer.fill"
        case .coldWaterReset:            return "drop.fill"
        case .natureWalk:                return "leaf.fill"
        // Tier 3
        case .goalSwitchBreak:           return "brain.head.profile"
        case .pleasurableRest:           return "music.note"
        }
    }
}

// MARK: - Single step row inside the timeline
private struct BreakStepRow: View {
    let step: BreakSuggestionEngine.BreakStep
    let index: Int
    let isLast: Bool
    let accentColor: Color

    @State private var expanded = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {

            // ── Left column: connector line + icon ───────────────────
            VStack(spacing: 0) {
                // Icon badge
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(accentColor.opacity(0.18))
                        .frame(width: 42, height: 42)
                    Image(systemName: step.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

                // Connector line (hidden on last step)
                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.10))
                        .frame(width: 1.5)
                        .frame(minHeight: 20)
                        .padding(.top, 4)
                }
            }
            .frame(width: 42)

            // ── Right column: duration badge + action + instruction ──
            VStack(alignment: .leading, spacing: 6) {
                // Duration badge + action on same line
                HStack(alignment: .center, spacing: 8) {
                    Text("\(step.minutes) min")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(accentColor.opacity(0.14)))

                    Text(step.action)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Instruction — always visible
                Text(step.instruction)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : 18)
        }
    }
}

// MARK: - Compact sticky ring bar
struct CompactBreakBar: View {
    @ObservedObject var engine: FocusSessionEngine

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                AdaptiveTickRingView(
                    totalSeconds: engine.totalSeconds,
                    elapsedSeconds: engine.totalSeconds - engine.remainingSeconds,
                    accentColor: engine.accentColor
                )
                .frame(width: 60, height: 60)
                Text(timeString)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 2) {
                Text("BREAK")
                    .font(.system(size: 9, weight: .heavy))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.4))
                Text(engine.task.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color.black)
    }

    private var timeString: String {
        String(format: "%02d:%02d", engine.remainingSeconds / 60, engine.remainingSeconds % 60)
    }
}
