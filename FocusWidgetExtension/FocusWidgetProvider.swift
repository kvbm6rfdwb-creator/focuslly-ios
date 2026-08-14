import WidgetKit
import SwiftUI

// MARK: - Timeline Entry
struct FocusWidgetEntry: TimelineEntry {
    let date: Date
    let widgetData: FocusWidgetData?
    let insights: FocusWidgetInsights?
}

// MARK: - Timeline Provider
struct FocusWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> FocusWidgetEntry {
        FocusWidgetEntry(
            date: Date(),
            widgetData: FocusWidgetData(
                blockKind: .focus,
                taskTitle: "Deep Work",
                endDate: Date().addingTimeInterval(25 * 60),
                startDate: Date()
            ),
            insights: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusWidgetEntry) -> Void) {
        completion(FocusWidgetEntry(date: Date(), widgetData: FocusWidgetData.read(), insights: FocusWidgetInsights.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusWidgetEntry>) -> Void) {
        let data     = FocusWidgetData.read()
        let insights = FocusWidgetInsights.read()
        let now      = Date()

        if let data {
            if data.isPaused {
                // Timer is paused — just show the current frozen state.
                // Don't schedule an expiry entry at endDate because that date is no longer
                // meaningful while paused. Refresh after 30 s so we pick up a resume quickly.
                let entry = FocusWidgetEntry(date: now, widgetData: data, insights: insights)
                let refreshAt = now.addingTimeInterval(30)
                completion(Timeline(entries: [entry], policy: .after(refreshAt)))
            } else {
                // Timer is running — schedule a second entry right after endDate so the
                // widget snaps to idle as soon as the session finishes.
                let entries: [FocusWidgetEntry] = [
                    FocusWidgetEntry(date: now,                                widgetData: data,  insights: insights),
                    FocusWidgetEntry(date: data.endDate.addingTimeInterval(1), widgetData: nil,   insights: insights)
                ]
                completion(Timeline(entries: entries, policy: .atEnd))
            }
        } else {
            let entry = FocusWidgetEntry(date: now, widgetData: nil, insights: insights)
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now)!
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}
