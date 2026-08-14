import SwiftUI
import Foundation   // 👈 BITNO za Darwin.cos / sin

struct TickRingView: View {

    let progress: Double        // 0.0 → 1.0
    let totalTicks: Int
    let accentColor: Color

    var body: some View {
        Canvas { context, size in

            let center = CGPoint(
                x: size.width / 2,
                y: size.height / 2
            )

            let radius = min(size.width, size.height) / 2

            // Apple Watch–like density
            let tickLength: CGFloat = 8
            let tickWidth: CGFloat = 2

            let activeTicks = Int(
                Double(totalTicks) * progress
            )

            for tick in 0..<totalTicks {

                let angle = Angle.degrees(
                    (Double(tick) / Double(totalTicks)) * 360 - 90
                )

                let isActive = tick < activeTicks

                let color: Color = isActive
                    ? accentColor
                    : Color.white.opacity(0.12)

                let start = CGPoint(
                    x: center.x
                        + CGFloat(Darwin.cos(angle.radians))
                        * (radius - tickLength),
                    y: center.y
                        + CGFloat(Darwin.sin(angle.radians))
                        * (radius - tickLength)
                )

                let end = CGPoint(
                    x: center.x
                        + CGFloat(Darwin.cos(angle.radians)) * radius,
                    y: center.y
                        + CGFloat(Darwin.sin(angle.radians)) * radius
                )

                var path = Path()
                path.move(to: start)
                path.addLine(to: end)

                context.stroke(
                    path,
                    with: .color(color),
                    lineWidth: tickWidth
                )
            }
        }
        .drawingGroup() // 👈 bolji performance, glađi rendering
    }
}
