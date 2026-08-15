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
                // Fix #6: Cap the paused-refresh interval so an abandoned session
                // does not wake the widget extension every 30 s indefinitely.
                // Poll every 30 s only while the session could still be resumed
                // (i.e. endDate is in the future). Once endDate has passed, defer
                // to atEnd so WidgetKit chooses the next sensible reload time.
                let entry = FocusWidgetEntry(date: now, widgetData: data, insights: insights)
                if data.endDate > now {
                    let refreshAt = min(
                        now.addingTimeInterval(30),
                        data.endDate.addingTimeInterval(5 * 60)
                    )
                    completion(Timeline(entries: [entry], policy: .after(refreshAt)))
                } else {
                    completion(Timeline(entries: [entry], policy: .atEnd))
                }
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
            // Fix #5: Calendar.date(byAdding:) returns Date? — force-unwrap would crash
            // the widget extension process on any calendar edge case or extreme clock value.
            // Fall back to a 5-minute addingTimeInterval which cannot return nil.
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: now)
                ?? now.addingTimeInterval(5 * 60)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}
