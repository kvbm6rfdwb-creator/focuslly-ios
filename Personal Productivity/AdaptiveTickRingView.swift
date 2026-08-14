import SwiftUI
import Foundation
import Combine

struct AdaptiveTickRingView: View {

    let totalSeconds: Int
    let elapsedSeconds: Int
    let accentColor: Color

    // MARK: - Tunables (overridable for compact use)
    var minTicks: Int = 48
    var maxTicks: Int = 72

    var baseTickLength: CGFloat = 6
    var maxTickGrowth: CGFloat = 14
    var baseTickWidth: CGFloat = 2
    var maxTickWidth: CGFloat = 3.5

    // MARK: - Sub-second smoothing
    @State private var smoothElapsed: Double = 0

    private var displayTimer: AnyPublisher<Date, Never> {
        Timer
            .publish(every: 1.0 / 60.0, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()
    }

    var body: some View {
        Canvas { context, size in

            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let baseRadius = min(size.width, size.height) / 2 - maxTickGrowth

            // MARK: - Tick count (geometry only)
            let desiredTicks = max(totalSeconds / 60, minTicks)
            let totalTicks = min(desiredTicks, maxTicks)

            // MARK: - Real time mapping (FIXED)
            let secondsPerTick = Double(totalSeconds) / Double(totalTicks)

            for tick in 0..<totalTicks {

                let tickStart = Double(tick) * secondsPerTick
                let tickProgress = clamp(
                    (smoothElapsed - tickStart) / secondsPerTick,
                    0,
                    1
                )

                let angle = Angle.degrees(
                    Double(tick) / Double(totalTicks) * 360 - 90
                )

                let length =
                    baseTickLength + maxTickGrowth * tickProgress

                let width =
                    baseTickWidth + (maxTickWidth - baseTickWidth) * tickProgress

                let halfLength = length / 2
                let innerRadius = baseRadius - halfLength
                let outerRadius = baseRadius + halfLength

                let color: Color = tickProgress > 0
                    ? accentColor
                    : Color.white.opacity(0.12)

                let start = CGPoint(
                    x: center.x + CGFloat(Darwin.cos(angle.radians)) * innerRadius,
                    y: center.y + CGFloat(Darwin.sin(angle.radians)) * innerRadius
                )

                let end = CGPoint(
                    x: center.x + CGFloat(Darwin.cos(angle.radians)) * outerRadius,
                    y: center.y + CGFloat(Darwin.sin(angle.radians)) * outerRadius
                )

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .color(color),
                    style: StrokeStyle(
                        lineWidth: width,
                        lineCap: .round   // ✅ round ticks
                    )
                )
            }
        }
        .drawingGroup()
        // MARK: - Smooth time update
        .onReceive((totalSeconds > 0 && elapsedSeconds > 0 && elapsedSeconds < totalSeconds) ? displayTimer : Empty<Date, Never>().eraseToAnyPublisher()) { _ in
            let target = Double(elapsedSeconds)
            // lag-free smoothing
            smoothElapsed += (target - smoothElapsed) * 0.25
        }
        .onAppear {
            smoothElapsed = Double(elapsedSeconds)
        }
    }

    // MARK: - Helpers
    private func clamp<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
        min(max(value, minValue), maxValue)
    }
}
