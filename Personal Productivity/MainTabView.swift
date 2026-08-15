import SwiftUI

extension Notification.Name {
    static let calendarResetToNow = Notification.Name("calendarResetToNow")
}

// MARK: - MainTabView
struct MainTabView: View {
    // Fix #3: @StateObject property wrappers with default initialisers removed.
    // settings and taskStore are both constructed once in init() and handed to
    // StateObject — the compiler-generated default initialisers would have
    // allocated and immediately abandoned a second copy of each on every
    // scene reset.
    @StateObject private var settings: AppSettingsStore
    @StateObject private var taskStore: TaskStore
    @StateObject private var visionStore = VisionBoardStore()
    @EnvironmentObject var coordinator: FocusSessionCoordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var showAddTask  = false
    @State private var selectedTab: Tab = .dashboard

    /// Retained observer tokens — released when the view is torn down.
    @State private var notificationTokens: [NSObjectProtocol] = []

    enum Tab {
        case dashboard, focus, calendar, pipeline, visionBoard
    }

    init() {
        let settings = AppSettingsStore()
        _settings  = StateObject(wrappedValue: settings)
        _taskStore = StateObject(wrappedValue: TaskStore(settings: settings))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Fix #5: DashboardView now reads taskStore from the environment
            // (injected below via .environmentObject(taskStore) on the TabView).
            // Previously it received taskStore as an init parameter while every
            // other tab used the environment, creating an inconsistent dual-reference
            // path that could cause sub-views to hold a stale copy.
            DashboardView(focusTabSelector: $selectedTab)
                .tabItem { Label("Dashboard", systemImage: "house.fill") }
                .tag(Tab.dashboard)
                .environmentObject(coordinator)

            FocusTabView()
                .tabItem { Label("Focus", systemImage: "bolt.fill") }
                .tag(Tab.focus)
                .environmentObject(coordinator)
                .environmentObject(taskStore)

            CalendarView()
                .tabItem { Label("Calendar", systemImage: "calendar") }
                .tag(Tab.calendar)
                .environmentObject(taskStore)

            PipelineTabView()
                .tabItem { Label("Tracker", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(Tab.pipeline)
                .environmentObject(taskStore)

            VisionBoardView(visionStore: visionStore)
                .environmentObject(settings)
                .tabItem { Label("Vision", systemImage: "mountain.2.fill") }
                .tag(Tab.visionBoard)
        }
        .tint(.brg)
        // Fix #4: calendarResetToNow now fires only when the user is *leaving*
        // the calendar tab (oldTab == .calendar). The previous guard
        // (newTab != .calendar) fired on every non-calendar → non-calendar
        // transition, e.g. Dashboard → Focus, sending spurious resets.
        .onChange(of: selectedTab) { oldTab, newTab in
            if oldTab == .calendar && newTab != .calendar {
                NotificationCenter.default.post(name: .calendarResetToNow, object: nil)
            }
        }
        .sheet(isPresented: $showAddTask) {
            AddTaskView(onSave: { newTask in taskStore.addTask(newTask) })
                .environmentObject(taskStore)
        }
        .onAppear {
            guard notificationTokens.isEmpty else { return }   // already subscribed
            let nc = NotificationCenter.default
            notificationTokens = [
                nc.addObserver(forName: NSNotification.Name("ShowAddTask"),       object: nil, queue: .main) { _ in showAddTask  = true },
                nc.addObserver(forName: NSNotification.Name("StartFocusSession"), object: nil, queue: .main) { _ in selectedTab = .focus },
                nc.addObserver(forName: NSNotification.Name("OpenVisionBoard"),   object: nil, queue: .main) { _ in selectedTab = .visionBoard },
            ]
            writeWidgetInsights()
        }
        .onDisappear {
            notificationTokens.forEach { NotificationCenter.default.removeObserver($0) }
            notificationTokens = []
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { writeWidgetInsights() }
        }
        .environmentObject(settings)
        .environmentObject(taskStore)
        .environmentObject(visionStore)
    }

    // MARK: - Widget insights
    // Fix #6: @MainActor annotation added. WidgetCenter.shared.reloadTimelines
    // (called inside FocusWidgetInsights.write) must run on the main thread.
    // All current call sites are already on the main actor (.onAppear,
    // .onChange(of: scenePhase)) but the annotation enforces this contract
    // for any future caller.
    @MainActor
    private func writeWidgetInsights() {
        let pipeline   = PipelineStore.shared
        let calendar   = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        let dialsToday = pipeline.callLogs.filter { $0.date >= todayStart }.count

        let completedLogsToday = taskStore.sessionLogs.filter {
            $0.startDate >= todayStart
            && ($0.exitReason == .completed || $0.exitReason == .prolonged)
        }
        let sessionsToday = completedLogsToday.count
        let focusMinutes = completedLogsToday.reduce(0) { $0 + $1.durationMinutes }

        let hotLeads = pipeline.contactMetadata.filter {
            $0.tag == .hotLead || $0.tag == .activeClient
        }.count

        let pending: Int = {
            var grouped: [String: [CallLog]] = [:]
            for log in pipeline.callLogs {
                let raw = log.contactName.trimmingCharacters(in: .whitespaces)
                guard !raw.isEmpty else { continue }
                grouped[raw.lowercased(), default: []].append(log)
            }
            return grouped.values.filter { calls in
                let latest = calls.sorted { $0.date > $1.date }.first
                return (latest?.nextStep ?? .none) != .none
            }.count
        }()

        var insights = FocusWidgetInsights()
        insights.dialsToday        = dialsToday
        insights.dialTarget        = pipeline.dailyDialTarget
        insights.sessionsToday     = sessionsToday
        insights.focusMinutesToday = focusMinutes
        insights.hotLeadsCount     = hotLeads
        insights.pendingActions    = pending
        FocusWidgetInsights.write(insights)
    }
}
