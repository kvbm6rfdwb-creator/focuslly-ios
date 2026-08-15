import SwiftUI
import WidgetKit

// British Racing Green — matches AppColors in the main target
private extension Color {
    static let brg       = Color(red: 0.0,  green: 0.259, blue: 0.145)
    static let brgBright = Color(red: 0.13, green: 0.74,  blue: 0.37)
}

private func formatFocusTime(_ minutes: Int) -> String {
    guard minutes >= 60 else { return "\(minutes)m" }
    let h = minutes / 60; let m = minutes % 60
    return m > 0 ? "\(h)h \(m)m" : "\(h)h"
}

/// Formats a raw seconds count as "MM:SS" — used when the timer is paused
/// so we can render a static label instead of a live `timerInterval`.
private func formatSeconds(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return String(format: "%02d:%02d", s / 60, s % 60)
}

// Fix #7 + #8: Single shared helper that computes the paused arc progress from
// a FocusWidgetData value. Eliminates the three-line duplication across
// FocusWidgetHomeScreen, FocusWidgetCircular, and FocusWidgetRectangular, and
// guards against elapsed going negative when pausedRemainingSeconds exceeds the
// total interval (e.g. due to a bug in the main app writing inconsistent data).
private func pausedProgress(for data: FocusWidgetData) -> Double {
    let total = max(1, data.endDate.timeIntervalSince(data.startDate))
    let remaining = max(0, TimeInterval(data.pausedRemainingSeconds))
    let elapsed = max(0, total - remaining)
    return min(1, elapsed / total)
}

// MARK: - Root view
struct FocusWidgetEntryView: View {
    let entry: FocusWidgetEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        switch family {
        case .accessoryCircular:    FocusWidgetCircular(entry: entry)
        case .accessoryRectangular: FocusWidgetRectangular(entry: entry)
        default:                    FocusWidgetHomeScreen(entry: entry)
        }
    }
}

// MARK: - Home screen small widget
struct FocusWidgetHomeScreen: View {
    let entry: FocusWidgetEntry
    private var accentColor: Color {
        entry.widgetData?.blockKind == .breakTime ? Color(red: 0.2, green: 0.8, blue: 0.4) : .orange
    }

    var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea()

            if let data = entry.widgetData {
                // ── ACTIVE SESSION ──
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        Circle().fill(accentColor).frame(width: 7, height: 7)
                        Text(data.blockKind == .focus ? "FOCUS" : "BREAK")
                            .font(.system(size: 9, weight: .heavy)).tracking(1.4)
                            .foregroundStyle(accentColor)
                        if data.isPaused {
                            Text("· PAUSED")
                                .font(.system(size: 9, weight: .heavy)).tracking(1.4)
                                .foregroundStyle(.white.opacity(0.4))
                        }
                    }
                    Spacer(minLength: 0)
                    if data.isPaused {
                        Text(formatSeconds(data.pausedRemainingSeconds))
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.6)).minimumScaleFactor(0.5).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(timerInterval: Date()...data.endDate, countsDown: true)
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white).minimumScaleFactor(0.5).lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Spacer(minLength: 4)
                    Text(data.taskTitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    Spacer(minLength: 10)
                    ProgressView(timerInterval: data.startDate...data.endDate, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: { EmptyView() }
                    .progressViewStyle(.linear).tint(data.isPaused ? accentColor.opacity(0.4) : accentColor)
                    .scaleEffect(x: 1, y: 0.6, anchor: .center)
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            } else if let ins = entry.insights {
                // ── IDLE WITH INSIGHTS ──
                let progress  = ins.dialTarget > 0 ? min(Double(ins.dialsToday) / Double(ins.dialTarget), 1.0) : 0
                let dialColor: Color = progress >= 1 ? .green : progress >= 0.6
                    ? Color(red: 1, green: 0.75, blue: 0.2)
                    : Color(red: 1, green: 0.45, blue: 0.2)

                VStack(alignment: .leading, spacing: 0) {

                    // ── Brand row ──────────────────────────────────────────────
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7, weight: .black))
                            .foregroundStyle(Color.orange.opacity(0.65))
                        Text("FOCUSLLY")
                            .font(.system(size: 7.5, weight: .heavy)).tracking(1.8)
                            .foregroundStyle(.white.opacity(0.22))
                        Spacer()
                        HStack(spacing: 3) {
                            Circle()
                                .fill(dialColor)
                                .frame(width: 4, height: 4)
                            Text(progress >= 1 ? "DONE" : "\(Int(progress * 100))%")
                                .font(.system(size: 7, weight: .heavy)).tracking(0.8)
                                .foregroundStyle(dialColor.opacity(0.9))
                        }
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(dialColor.opacity(0.12))
                        .clipShape(Capsule())
                    }

                    Spacer(minLength: 8)

                    // ── Hero dial count ─────────────────────────────────────────
                    HStack(alignment: .lastTextBaseline, spacing: 3) {
                        Text("\(ins.dialsToday)")
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(dialColor)
                        Text("/ \(ins.dialTarget)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.2))
                            .padding(.bottom, 4)
                    }
                    Text("dials today")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.28))
                        .padding(.top, -2)

                    Spacer(minLength: 6)

                    // ── Progress track ─────────────────────────────────────────
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.05)).frame(height: 3)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [dialColor.opacity(0.6), dialColor],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(3, geo.size.width * progress), height: 3)
                        }
                    }
                    .frame(height: 3)

                    Spacer(minLength: 9)

                    // ── Secondary stats ─────────────────────────────────────────
                    HStack(spacing: 0) {
                        idleStatMini(
                            icon: "bolt.fill",
                            value: "\(ins.sessionsToday)",
                            label: "sessions",
                            color: Color(red: 0.45, green: 0.65, blue: 1)
                        )
                        Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 22)
                        if ins.hotLeadsCount > 0 {
                            idleStatMini(icon: "flame.fill", value: "\(ins.hotLeadsCount)", label: "hot leads", color: .orange)
                        } else {
                            idleStatMini(icon: "timer", value: formatFocusTime(ins.focusMinutesToday), label: "focused", color: .white.opacity(0.55))
                        }
                    }
                }
                .padding(.horizontal, 13)
                .padding(.top, 11)
                .padding(.bottom, 11)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            } else {
                // ── NO DATA ──
                VStack(spacing: 7) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 20, weight: .thin))
                        .foregroundStyle(.white.opacity(0.12))
                    Text("Open app to\nstart tracking")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.18))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .containerBackground(for: .widget) { Color(red: 0.07, green: 0.07, blue: 0.09) }
    }

    private func idleStatMini(icon: String, value: String, label: String, color: Color = .white) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9.5, weight: .semibold))
                .foregroundStyle(color.opacity(0.5))
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color.opacity(0.92))
                Text(label)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.25))
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Lock screen circular
struct FocusWidgetCircular: View {
    let entry: FocusWidgetEntry

    var body: some View {
        ZStack {
            if let data = entry.widgetData {
                if data.isPaused {
                    // Fix #7+#8: Use shared pausedProgress(for:) helper.
                    let progress = pausedProgress(for: data)
                    ZStack {
                        Circle().stroke(.white.opacity(0.08), lineWidth: 4).padding(4)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                data.blockKind == .focus ? Color.orange.opacity(0.5) : Color.brg.opacity(0.5),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .padding(4)
                        Text(formatSeconds(data.pausedRemainingSeconds))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    ProgressView(
                        timerInterval: data.startDate...data.endDate,
                        countsDown: true,
                        label: { EmptyView() },
                        currentValueLabel: {
                            Text(timerInterval: Date()...data.endDate, countsDown: true)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .minimumScaleFactor(0.5)
                        }
                    )
                    .progressViewStyle(.circular)
                    .tint(data.blockKind == .focus ? .orange : .green)
                    .padding(4)
                }

            } else if let ins = entry.insights {
                let progress = ins.dialTarget > 0 ? min(Double(ins.dialsToday) / Double(ins.dialTarget), 1.0) : 0
                let ringColor: Color = progress >= 1 ? .green : .orange
                ZStack {
                    Circle().stroke(.white.opacity(0.08), lineWidth: 5)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: -1) {
                        Text("\(ins.dialsToday)")
                            .font(.system(size: 16, weight: .black, design: .rounded))
                        Text("dials")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(5)

            } else {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16, weight: .ultraLight))
                    .foregroundStyle(.secondary)
            }
        }
        .containerBackground(for: .widget) { Color(red: 0.07, green: 0.07, blue: 0.09) }
    }
}

// MARK: - Lock screen rectangular
struct FocusWidgetRectangular: View {
    let entry: FocusWidgetEntry

    var body: some View {
        ZStack {
            if let data = entry.widgetData {
                HStack(spacing: 10) {
                    if data.isPaused {
                        // Fix #7+#8: Use shared pausedProgress(for:) helper.
                        let progress = pausedProgress(for: data)
                        ZStack {
                            Circle().stroke(.white.opacity(0.1), lineWidth: 3)
                            Circle()
                                .trim(from: 0, to: progress)
                                .stroke(
                                    data.blockKind == .focus ? Color.orange.opacity(0.5) : Color.brg.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                        }
                        .frame(width: 26, height: 26)
                    } else {
                        ProgressView(
                            timerInterval: data.startDate...data.endDate,
                            countsDown: true,
                            label: { EmptyView() },
                            currentValueLabel: { EmptyView() }
                        )
                        .progressViewStyle(.circular)
                        .tint(data.blockKind == .focus ? .orange : .green)
                        .frame(width: 26, height: 26)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(data.blockKind == .focus ? "FOCUS" : "BREAK")
                                .font(.system(size: 9, weight: .heavy)).tracking(1.2)
                                .foregroundStyle(data.blockKind == .focus ? .orange : .green)
                            if data.isPaused {
                                Text("PAUSED")
                                    .font(.system(size: 9, weight: .heavy)).tracking(1.2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if data.isPaused {
                            Text(formatSeconds(data.pausedRemainingSeconds))
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .minimumScaleFactor(0.7).lineLimit(1)
                        } else {
                            Text(timerInterval: Date()...data.endDate, countsDown: true)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .minimumScaleFactor(0.7).lineLimit(1)
                        }
                        Text(data.taskTitle)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            } else if let ins = entry.insights {
                let dp = ins.dialTarget > 0 ? min(Double(ins.dialsToday) / Double(ins.dialTarget), 1.0) : 0
                let dc: Color = dp >= 1 ? .green : dp >= 0.5 ? .orange : Color(red: 1, green: 0.45, blue: 0.2)

                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(.white.opacity(0.05)).frame(height: 2)
                            Capsule()
                                .fill(LinearGradient(
                                    colors: [dc.opacity(0.5), dc],
                                    startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(2, geo.size.width * dp), height: 2)
                        }
                    }
                    .frame(height: 2)
                    .padding(.horizontal, 10)

                    HStack(spacing: 0) {
                        rectStatCell(
                            icon: "phone.fill", color: dc,
                            value: "\(ins.dialsToday)/\(ins.dialTarget)", label: "Dials"
                        )
                        rectDivider()
                        rectStatCell(
                            icon: "bolt.fill", color: Color(red: 0.45, green: 0.65, blue: 1),
                            value: "\(ins.sessionsToday)", label: "Sessions"
                        )
                        rectDivider()
                        rectStatCell(
                            icon: ins.hotLeadsCount > 0 ? "flame.fill" : "timer",
                            color: ins.hotLeadsCount > 0 ? .orange : .white.opacity(0.6),
                            value: ins.hotLeadsCount > 0 ? "\(ins.hotLeadsCount)" : formatFocusTime(ins.focusMinutesToday),
                            label: ins.hotLeadsCount > 0 ? "Hot leads" : "Focus"
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            } else {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill").font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("Open app to sync").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
        }
        .containerBackground(for: .widget) { Color(red: 0.07, green: 0.07, blue: 0.09) }
    }

    private func rectStatCell(icon: String, color: Color, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(.system(size: 14, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.6).lineLimit(1)
            Text(label)
                .font(.system(size: 7.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .frame(maxWidth: .infinity)
    }

    private func rectDivider() -> some View {
        Rectangle().fill(.white.opacity(0.06)).frame(width: 1, height: 30)
    }
}
