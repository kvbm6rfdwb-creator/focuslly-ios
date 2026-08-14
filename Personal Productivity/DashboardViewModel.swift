import Foundation
import SwiftUI
import Combine

final class DashboardViewModel: ObservableObject {

    // MARK: - Published output — today
    @Published private(set) var last7DaysData: [(date: Date, minutes: Int)] = []
    @Published private(set) var last30DaysData: [(date: Date, minutes: Int)] = []
    /// Last 14 calendar days: (date, hadFocus). Used for the streak dot strip.
    @Published private(set) var streakDays: [(date: Date, hadFocus: Bool)] = []
    @Published private(set) var completedToday: Int = 0
    @Published private(set) var focusMinutesToday: Int = 0
    @Published private(set) var sessionsToday: Int = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var activeTasks: [FocusTask] = []

    // MARK: - Published output — extended
    @Published private(set) var focusMinutesThisWeek: Int = 0
    @Published private(set) var focusMinutesThisMonth: Int = 0
    @Published private(set) var completionRateThisWeek: Double = 0   // 0–1
    @Published private(set) var overdueCount: Int = 0
    @Published private(set) var upcomingTasks: [FocusTask] = []      // next 7 days, pending
    @Published private(set) var prevWeekMinutes: Int = 0
    @Published private(set) var prevMonthMinutes: Int = 0

    // MARK: - Dashboard card layout (10 — personalizable)
    enum CardID: String, CaseIterable, Identifiable, Codable {
        case kpi, nowFocusing, primaryAction, upNext, quickFilters, chart, streak
        var id: String { rawValue }
        var defaultTitle: String {
            switch self {
            case .kpi:           return "Stats"
            case .nowFocusing:   return "Now Focusing"
            case .primaryAction: return "Today's Tasks"
            case .upNext:        return "Up Next"
            case .quickFilters:  return "Filters"
            case .chart:         return "Focus Chart"
            case .streak:        return "Streak"
            }
        }
    }

    @Published var cardOrder: [CardID] {
        didSet { saveCardOrder() }
    }
    @Published var hiddenCards: Set<CardID> {
        didSet { saveHiddenCards() }
    }

    // MARK: - Dependencies
    private let taskStore: TaskStore
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(taskStore: TaskStore) {
        self.taskStore = taskStore
        self.cardOrder   = Self.loadCardOrder()
        self.hiddenCards = Self.loadHiddenCards()
        bind()
        recalculate()
    }

    // MARK: - Bindings
    private func bind() {
        taskStore.$sessionLogs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recalculate() }
            .store(in: &cancellables)
        taskStore.$tasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.recalculate() }
            .store(in: &cancellables)
    }

    // MARK: - Recalculate
    func recalculate() {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let snapshot = taskStore.focusStatsSnapshot(referenceDate: today)

        completedToday      = snapshot.sessionsToday
        sessionsToday       = snapshot.sessionsToday
        focusMinutesToday   = snapshot.focusedMinutesToday
        currentStreak       = snapshot.currentStreak
        last7DaysData       = snapshot.last7Days.map { ($0.date, $0.focusedMinutes) }

        // Last 30 days
        last30DaysData = (0..<30).map { offset -> (Date, Int) in
            let day = cal.date(byAdding: .day, value: -(29 - offset), to: today) ?? today
            let mins = taskStore.sessionLogs
                .filter { $0.exitReason == .completed && cal.isDate($0.startDate, inSameDayAs: day) }
                .reduce(0) { $0 + Int($1.duration / 60) }
            return (day, mins)
        }

        // Last 30 days streak dots (view slices to 7 or 30 based on timeframe)
        streakDays = (0..<30).map { offset -> (Date, Bool) in
            let day = cal.date(byAdding: .day, value: -(29 - offset), to: today) ?? today
            let hadFocus = taskStore.sessionLogs.contains {
                $0.exitReason == .completed && cal.isDate($0.startDate, inSameDayAs: day)
            }
            return (day, hadFocus)
        }

        focusMinutesThisWeek  = taskStore.focusMinutesThisWeek
        focusMinutesThisMonth = taskStore.focusMinutesThisMonth

        // Prev week minutes
        if let weekStart = cal.dateInterval(of: .weekOfYear, for: today)?.start,
           let prevWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: weekStart),
           let prevWeekEnd   = cal.date(byAdding: .weekOfYear, value:  1, to: prevWeekStart) {
            let interval = DateInterval(start: prevWeekStart, end: prevWeekEnd)
            prevWeekMinutes = taskStore.sessionLogs.filter {
                $0.exitReason == .completed && interval.contains($0.startDate)
            }.reduce(0) { $0 + Int($1.duration / 60) }
        }

        // Prev month minutes
        if let monthStart = cal.dateInterval(of: .month, for: today)?.start,
           let prevMonthStart = cal.date(byAdding: .month, value: -1, to: monthStart),
           let prevMonthEnd   = cal.date(byAdding: .month, value:  1, to: prevMonthStart) {
            let interval = DateInterval(start: prevMonthStart, end: prevMonthEnd)
            prevMonthMinutes = taskStore.sessionLogs.filter {
                $0.exitReason == .completed && interval.contains($0.startDate)
            }.reduce(0) { $0 + Int($1.duration / 60) }
        }

        // Rate % — denominator: tasks the user is responsible for today
        //   • pending tasks scheduled today or overdue (carried forward)
        //   • tasks completed today (have a completed session log today)
        // This way the denominator never includes stale completed tasks from previous days.
        let tomorrow = cal.date(byAdding: .day, value: 1, to: today) ?? today

        let completedTodayIDs = Set(
            taskStore.sessionLogs.filter { log in
                log.exitReason == .completed && cal.isDate(log.startDate, inSameDayAs: today)
            }.map { $0.taskId }
        )

        let rateDenominatorTasks = taskStore.tasks.filter { task in
            let s = task.scheduledTime ?? task.startDate
            if task.status == .pending {
                return s < tomorrow          // pending today or overdue
            } else {
                return completedTodayIDs.contains(task.id)  // completed in today's session
            }
        }

        let completedTodayCount = rateDenominatorTasks.filter { completedTodayIDs.contains($0.id) }.count
        completionRateThisWeek = rateDenominatorTasks.isEmpty ? 0 : Double(completedTodayCount) / Double(rateDenominatorTasks.count)

        // Overdue: pending tasks scheduled before today
        overdueCount = taskStore.tasks.filter { task in
            guard task.status == .pending else { return false }
            let d = task.scheduledTime ?? task.startDate
            return cal.startOfDay(for: d) < today
        }.count

        // Upcoming: pending tasks in next 7 days (excluding today)
        let in7days = cal.date(byAdding: .day, value: 7, to: today) ?? today
        upcomingTasks = taskStore.tasks.filter { task in
            guard task.status == .pending, let s = task.scheduledTime else { return false }
            return s >= tomorrow && s < in7days
        }.sorted { ($0.scheduledTime ?? $0.startDate) < ($1.scheduledTime ?? $1.startDate) }
    }

    // MARK: - Card order persistence
    private static let cardOrderKey   = "dashboard_card_order_v1"
    private static let hiddenCardsKey = "dashboard_hidden_cards_v1"

    private static func loadCardOrder() -> [CardID] {
        guard let data = UserDefaults.standard.data(forKey: cardOrderKey),
              let decoded = try? JSONDecoder().decode([CardID].self, from: data) else {
            return CardID.allCases
        }
        // Merge: keep saved order but append any new cards not yet in saved list
        var merged = decoded
        for c in CardID.allCases where !merged.contains(c) { merged.append(c) }
        return merged
    }

    private static func loadHiddenCards() -> Set<CardID> {
        guard let data = UserDefaults.standard.data(forKey: hiddenCardsKey),
              let decoded = try? JSONDecoder().decode([CardID].self, from: data) else { return [] }
        return Set(decoded)
    }

    private func saveCardOrder() {
        if let data = try? JSONEncoder().encode(cardOrder) {
            UserDefaults.standard.set(data, forKey: Self.cardOrderKey)
        }
    }

    private func saveHiddenCards() {
        if let data = try? JSONEncoder().encode(Array(hiddenCards)) {
            UserDefaults.standard.set(data, forKey: Self.hiddenCardsKey)
        }
    }

    func toggleHidden(_ card: CardID) {
        if hiddenCards.contains(card) { hiddenCards.remove(card) }
        else { hiddenCards.insert(card) }
    }

    func moveCard(from source: IndexSet, to destination: Int) {
        cardOrder.move(fromOffsets: source, toOffset: destination)
    }
}
