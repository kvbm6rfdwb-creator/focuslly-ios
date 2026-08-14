import WidgetKit
import SwiftUI

@main
struct FocusWidget: Widget {
    let kind = "FocusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusWidgetProvider()) { entry in
            FocusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Focus Timer")
        .description("Live countdown for your current focus or break session.")
        .supportedFamilies([
            .systemSmall,           // Home Screen
            .accessoryCircular,     // Lock Screen — ring + countdown
            .accessoryRectangular   // Lock Screen — bar with task title
        ])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    FocusWidget()
} timeline: {
    FocusWidgetEntry(
        date: .now,
        widgetData: FocusWidgetData(
            blockKind: .focus,
            taskTitle: "Deep Work Session",
            endDate: Date().addingTimeInterval(22 * 60),
            startDate: Date().addingTimeInterval(-3 * 60)
        ),
        insights: nil
    )
    FocusWidgetEntry(
        date: .now,
        widgetData: nil,
        insights: FocusWidgetInsights(
            dialsToday: 23, dialTarget: 55, sessionsToday: 2,
            focusMinutesToday: 90, hotLeadsCount: 3, pendingActions: 5, currentStreak: 0
        )
    )
}
