import SwiftUI

struct FocusSessionSummary: View {
    let task: FocusTask
    let exitReason: FocusSessionExit
    let duration: TimeInterval
    let onDismiss: () -> Void

    var aiInsightOverride: String? = nil
    var aiInsightDecision: BreakInsightDecisionEngine.Decision? = nil

    // Actions
    var primaryActionTitle: String? = nil
    var onPrimaryAction: (() -> Void)? = nil

    var secondaryActionTitle: String? = nil
    var onSecondaryAction: (() -> Void)? = nil

    var tertiaryActionTitle: String? = nil
    var onTertiaryAction: (() -> Void)? = nil

    // 🔑 AI recommendation highlight
    var recommendedPrimary: Bool = false
    var recommendedSecondary: Bool = false

    @State private var pulse = false

    private var isBreakAIDecisionActive: Bool {
        (recommendedPrimary || recommendedSecondary)
    }

    // MARK: - Body
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: iconForReason)
                    .font(.system(size: 48))
                    .foregroundStyle(colorForReason)

                Text(titleForReason)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }

            // Duration
            VStack(spacing: 8) {
                Text("Duration")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)

                Text(formattedDuration)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }

            // AI Insight
            aiInsightBox

            Spacer()

            // MARK: - CTA Buttons
            VStack(spacing: 12) {

                // BREAK AI: Always show both CTAs, never show Done.
                if isBreakAIDecisionActive {
                    Button(action: { onSecondaryAction?() }) {
                        Text(secondaryActionTitle ?? "Continue break")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brg.opacity(recommendedSecondary ? 1 : 0.3))
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                            .scaleEffect(recommendedSecondary && pulse ? 1.04 : 1.0)
                            .shadow(
                                color: recommendedSecondary
                                ? Color.brg.opacity(pulse ? 0.55 : 0.25)
                                : .clear,
                                radius: recommendedSecondary ? 18 : 0
                            )
                    }
                    .disabled(onSecondaryAction == nil)

                    Button(action: { onPrimaryAction?() }) {
                        Text(primaryActionTitle ?? "Next task")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.brg.opacity(recommendedPrimary ? 1 : 0.3))
                            .foregroundStyle(.white)
                            .cornerRadius(12)
                            .scaleEffect(recommendedPrimary && pulse ? 1.04 : 1.0)
                            .shadow(
                                color: recommendedPrimary
                                ? Color.brg.opacity(pulse ? 0.55 : 0.25)
                                : .clear,
                                radius: recommendedPrimary ? 18 : 0
                            )
                    }
                    .disabled(onPrimaryAction == nil)

                } else {
                    // Existing non-break behavior: show provided actions if any, otherwise Done.
                    // Support tertiary action for multi-button flows
                    if let title = secondaryActionTitle, let action = onSecondaryAction {
                        Button(action: action) {
                            Text(title)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brg.opacity(0.3))
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    }

                    if let title = tertiaryActionTitle, let action = onTertiaryAction {
                        Button(action: action) {
                            Text(title)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brg.opacity(0.3))
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    }

                    if let title = primaryActionTitle, let action = onPrimaryAction {
                        Button(action: action) {
                            Text(title)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brg)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    }

                    if primaryActionTitle == nil && secondaryActionTitle == nil && tertiaryActionTitle == nil {
                        Button(action: onDismiss) {
                            Text("Done")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.brg)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            ZStack {
                Color.black.ignoresSafeArea()
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
        )
        .onAppear {
            if isBreakAIDecisionActive {
                withAnimation(
                    .spring(response: 0.6, dampingFraction: 0.75).repeatForever(autoreverses: true)
                ) {
                    pulse.toggle()
                }
            }
        }
    }

    // MARK: - AI Insight Box
    private var aiInsightBox: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header label
            Label("AI Insight", systemImage: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.brg)

            // Headline
            Text(insightHeadline)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            // Supporting line
            Text(insightSupporting)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)

            // Stat chips — only shown if Decision is available
            if let decision = aiInsightDecision, !decision.chips.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(decision.chips, id: \.label) { chip in
                            HStack(spacing: 5) {
                                Image(systemName: chip.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(chip.highlight ? Color.brg : .white.opacity(0.5))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(chip.label)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.5))
                                    Text(chip.value)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(chip.highlight ? Color.brg : .white.opacity(0.85))
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(chip.highlight
                                          ? Color.brg.opacity(0.15)
                                          : Color.white.opacity(0.07))
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.brg.opacity(0.25), lineWidth: 0.5)
                )
        )
    }

    private var insightHeadline: String {
        if let d = aiInsightDecision { return d.headline }
        if let o = aiInsightOverride, !o.isEmpty { return o }
        switch exitReason {
        case .completed:      return "Session complete. Well done."
        case .distracted:     return "Focus slipped this time — that's normal."
        case .earlyFinished:  return "Finished ahead of schedule."
        case .continueNow:    return "Back in focus quickly. Nice recovery."
        case .paused:         return "Session paused."
        case .prolonged:      return "You pushed through — great persistence."
        default:              return "Session ended."
        }
    }

    private var insightSupporting: String {
        if let d = aiInsightDecision { return d.supportingLine }
        switch exitReason {
        case .completed:      return "Keep this momentum going in your next session."
        case .distracted:     return "Try reducing notifications before the next block."
        case .earlyFinished:  return "Next time we'll suggest a tighter session length."
        case .continueNow:    return "You're building a strong focus habit."
        case .paused:         return "Resume when you're ready."
        case .prolonged:      return "The app will suggest a longer block next time."
        default:              return ""
        }
    }

    private var titleForReason: String {
        switch exitReason {
        case .completed:     return "Session Complete"
        case .distracted:    return "Lost Focus"
        case .earlyFinished: return "Finished Early"
        case .continueNow:   return "Continuing"
        case .prolonged:     return "Extended & Done"
        default:             return "Session Ended"
        }
    }

    private var iconForReason: String {
        switch exitReason {
        case .completed:     return "checkmark.circle.fill"
        case .distracted:    return "eye.slash.fill"
        case .earlyFinished: return "forward.end.fill"
        case .continueNow:   return "arrow.clockwise.circle.fill"
        case .prolonged:     return "plus.circle.fill"
        default:             return "xmark.circle.fill"
        }
    }

    private var colorForReason: Color {
        switch exitReason {
        case .completed:     return .brg
        case .distracted:    return .red
        case .earlyFinished: return .brg
        case .continueNow:   return .brg
        case .prolonged:     return .brg
        default:             return Color(uiColor: .secondaryLabel)
        }
    }

    // MARK: - Helpers
    private var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
