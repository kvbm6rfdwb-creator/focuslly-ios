import SwiftUI

extension Notification.Name {
    static let calendarResetToNow = Notification.Name("calendarResetToNow")
}

// MARK: - MainTabView
struct MainTabView: View {
    @StateObject private var settings = AppSettingsStore()
    @StateObject private var taskStore: TaskStore
    @StateObject private var visionStore = VisionBoardStore()
    @EnvironmentObject var coordinator: FocusSessionCoordinator
    @Environment(\.scenePhase) private var scenePhase

    @State private var showAddTask = false
    @State private var selectedTab: Tab = .dashboard

    enum Tab {
        case dashboard, focus, calendar, pipeline, visionBoard
    }

    init() {
        let settings = AppSettingsStore()
        _settings = StateObject(wrappedValue: settings)
        _taskStore = StateObject(wrappedValue: TaskStore(settings: settings))
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(taskStore: taskStore, focusTabSelector: $selectedTab)
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
                .onChange(of: selectedTab) { _, newTab in
                    if newTab != .calendar {
                        NotificationCenter.default.post(name: .calendarResetToNow, object: nil)
                    }
                }

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
        .sheet(isPresented: $showAddTask) {
            AddTaskView(onSave: { newTask in taskStore.addTask(newTask) })
                .environmentObject(taskStore)
        }
        .onAppear {
            NotificationCenter.default.addObserver(forName: NSNotification.Name("ShowAddTask"), object: nil, queue: .main) { _ in showAddTask = true }
            NotificationCenter.default.addObserver(forName: NSNotification.Name("StartFocusSession"), object: nil, queue: .main) { _ in selectedTab = .focus }
            NotificationCenter.default.addObserver(forName: NSNotification.Name("OpenVisionBoard"), object: nil, queue: .main) { _ in selectedTab = .visionBoard }
            writeWidgetInsights()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { writeWidgetInsights() }
        }
        .environmentObject(settings)
        .environmentObject(taskStore)
        .environmentObject(visionStore)
    }

    private func writeWidgetInsights() {
        let pipeline  = PipelineStore.shared
        let calendar  = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())

        let dialsToday = pipeline.callLogs.filter { $0.date >= todayStart }.count

        let completedLogsToday = taskStore.sessionLogs.filter {
            $0.startDate >= todayStart
            && ($0.exitReason == .completed || $0.exitReason == .prolonged)
        }
        let sessionsToday = completedLogsToday.count
        let focusMinutes  = completedLogsToday
            .reduce(0) { $0 + Int($1.endDate.timeIntervalSince($1.startDate) / 60) }
        let hotLeads       = pipeline.contactMetadata.filter { $0.tag == .hotLead || $0.tag == .activeClient }.count
        let pending: Int   = {
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
