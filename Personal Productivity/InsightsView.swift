import SwiftUI
import Charts

// MARK: - InsightsView (fully restored with brgBright colour tokens)

enum InsightsTimeRange: String, CaseIterable, Identifiable {
    case week = "7 Days"; case month = "30 Days"; case quarter = "3 Months"
    var id: String { rawValue }
    var days: Int { switch self { case .week: return 7; case .month: return 30; case .quarter: return 90 } }
    var xLabelCount: Int { switch self { case .week: return 7; case .month: return 6; case .quarter: return 6 } }
}

struct InsightMetricInfo: Identifiable {
    let id = UUID(); let title: String; let explanation: String; let dataSources: [String]
}

struct InsightsView: View {
    let settings: AppSettingsStore
    @EnvironmentObject var taskStore: TaskStore
    @State private var timeRange: InsightsTimeRange = .week
    @State private var selectedCategoryFilter: TaskCategory? = nil
    @State private var drillDownLog: FocusSessionLog? = nil
    @State private var showDigestPreview = false
    @State private var showWhySheet: InsightMetricInfo? = nil
    @State private var animateCharts = false
    @State private var showAllSessionsView = false
    private let sessionPreviewLimit = 5

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    glanceHeader; filtersRow
                    if hasNoData { emptyStateView } else {
                        recommendationsSection; focusChartCard; breakChartCard
                        if selectedCategoryFilter == nil { categoryBreakdownCard }
                        recentSessionsList; digestPreviewCard
                    }
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16).padding(.top, 8)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Insights").navigationBarTitleDisplayMode(.large)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showDigestPreview = true } label: { Label("Digest", systemImage: "envelope.open") } } }
            .sheet(item: $drillDownLog) { SessionDrillDownSheet(log: $0, taskStore: taskStore) }
            .sheet(item: $showWhySheet) { MetricExplanationSheet(info: $0) }
            .sheet(isPresented: $showDigestPreview) {
                DigestPreviewSheet(settings: settings, weeklyMinutes: focusMinutesForRange(.week), prevWeekMinutes: focusMinutesPrevRange(.week), completedSessions: completedSessionsForRange(.week), streak: taskStore.strictDailyStreak, bestDay: taskStore.bestFocusDay)
            }
            .sheet(isPresented: $showAllSessionsView) {
                AllSessionsSheet(allSessions: taskStore.sessionLogs.filter { $0.exitReason == .completed }.sorted { $0.startDate > $1.startDate }, taskStore: taskStore)
            }
            .onAppear { withAnimation(.easeOut(duration: 0.6)) { animateCharts = true } }
            .onChange(of: timeRange) { animateCharts = false; withAnimation(.easeOut(duration: 0.5)) { animateCharts = true } }
        }
    }

    private var glanceFocusMin: Int { focusMinutesForRange(timeRange) }
    private var glancePrevFocusMin: Int { focusMinutesPrevRange(timeRange) }
    private var glanceCompleted: Int { completedSessionsForRange(timeRange) }
    private var glancePrevCompleted: Int { completedSessionsPrevRange(timeRange) }
    private var glanceAvgMin: Int { averageSessionMinutesForRange(timeRange) }
    private var glancePrevAvgMin: Int { averageSessionMinutesPrevRange(timeRange) }

    private var glanceHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                GlanceMetricTile(icon: "bolt.fill", label: "Focus min", value: "\(glanceFocusMin)", delta: deltaString(current: glanceFocusMin, previous: glancePrevFocusMin), deltaPositive: glanceFocusMin >= glancePrevFocusMin, color: .brgBright, info: InsightMetricInfo(title: "Focus Minutes", explanation: "Total minutes from completed focus sessions.", dataSources: ["Completed focus sessions"]), onInfo: { showWhySheet = $0 })
                GlanceMetricTile(icon: "checkmark.seal.fill", label: "Completed", value: "\(glanceCompleted)", delta: deltaString(current: glanceCompleted, previous: glancePrevCompleted), deltaPositive: glanceCompleted >= glancePrevCompleted, color: .brgBright, info: InsightMetricInfo(title: "Completed Sessions", explanation: "Sessions finished without distraction.", dataSources: ["Completed focus sessions"]), onInfo: { showWhySheet = $0 })
            }
            HStack(spacing: 12) {
                GlanceMetricTile(icon: "flame.fill", label: "Streak", value: "\(taskStore.strictDailyStreak)d", delta: nil, deltaPositive: true, color: .brgBright, info: InsightMetricInfo(title: "Daily Streak", explanation: "Consecutive days all tasks completed, no distractions.", dataSources: ["Tasks", "Session history"]), onInfo: { showWhySheet = $0 })
                GlanceMetricTile(icon: "clock.fill", label: "Avg session", value: "\(glanceAvgMin) min", delta: deltaString(current: glanceAvgMin, previous: glancePrevAvgMin), deltaPositive: glanceAvgMin >= glancePrevAvgMin, color: .brgBright, info: InsightMetricInfo(title: "Average Session Length", explanation: "Total focus minutes divided by sessions.", dataSources: ["Completed focus sessions"]), onInfo: { showWhySheet = $0 })
            }
        }
    }

    private var filtersRow: some View {
        VStack(spacing: 10) {
            Picker("Time range", selection: $timeRange) { ForEach(InsightsTimeRange.allCases) { r in Text(r.rawValue).tag(r) } }.pickerStyle(.segmented)
            let cats = availableCategories
            if !cats.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(label: "All", isSelected: selectedCategoryFilter == nil) { withAnimation { selectedCategoryFilter = nil } }
                        ForEach(cats, id: \.id) { cat in FilterChip(label: cat.title, isSelected: selectedCategoryFilter?.id == cat.id) { withAnimation { selectedCategoryFilter = selectedCategoryFilter?.id == cat.id ? nil : cat } } }
                    }.padding(.vertical, 2)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Image(systemName: "chart.bar.doc.horizontal").font(.system(size: 56)).foregroundStyle(.secondary)
            VStack(spacing: 8) { Text("No data yet").font(.title2.bold()); Text("Complete your first focus session to see insights here.").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
            VStack(spacing: 10) {
                Label("Schedule a task in the Tasks tab", systemImage: "plus.circle").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                Label("Start a focus session from the Focus tab", systemImage: "bolt.circle").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
            }
        }
        .padding(32).frame(maxWidth: .infinity).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder private var recommendationsSection: some View {
        let recs = recommendations
        if !recs.isEmpty {
            InsightCard(title: "Recommended Actions", icon: "lightbulb.fill", iconColor: .brgBright) {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(recs.enumerated()), id: \.offset) { _, rec in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: rec.icon).foregroundStyle(rec.color).frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) { Text(rec.title).font(.subheadline.weight(.semibold)); Text(rec.detail).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
        }
    }

    private var focusChartCard: some View {
        let data = chartData(for: timeRange)
        let delta = focusMinutesForRange(timeRange) - focusMinutesPrevRange(timeRange)
        return InsightCard(title: "Focus Minutes", icon: "bolt.fill", iconColor: .brgBright, badge: prevAvailable ? deltaLabel(delta: delta) : nil, badgeColor: delta >= 0 ? .brgBright : .red, onInfo: { showWhySheet = InsightMetricInfo(title: "Focus Minutes", explanation: "Each bar shows minutes in deep focus. Only completed sessions counted.", dataSources: ["Completed focus sessions"]) }) {
            VStack(alignment: .leading, spacing: 8) {
                Chart(data, id: \.date) { item in BarMark(x: .value("Period", item.date, unit: .day), y: .value("Minutes", animateCharts ? Double(item.minutes) : 0)).foregroundStyle(barGradient(for: item.minutes, data: data)).cornerRadius(4) }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: timeRange.xLabelCount)) { v in AxisValueLabel { if let d = v.as(Date.self) { Text(xLabel(d)).font(.caption2) } }; AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)) } }
                .chartYAxis { AxisMarks(position: .leading) { v in AxisValueLabel { if let n = v.as(Double.self) { Text("\(Int(n))m").font(.caption2) } }; AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3,3])) } }
                .frame(height: timeRange == .week ? 160 : 200).animation(.easeOut(duration: 0.5), value: animateCharts).animation(.easeOut(duration: 0.4), value: timeRange)
                Text("Tap a session below for details").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    private var breakChartCard: some View {
        let data = breakChartData(for: timeRange); let hasBreaks = data.contains { $0.minutes > 0 }
        return InsightCard(title: "Break Time", icon: "cup.and.saucer.fill", iconColor: .brgBright, onInfo: { showWhySheet = InsightMetricInfo(title: "Break Time", explanation: "Minutes on completed breaks. Aim 10–20% of focus time.", dataSources: ["Completed break sessions"]) }) {
            if !hasBreaks {
                HStack(spacing: 8) { Image(systemName: "info.circle").foregroundStyle(.secondary); Text("No break data. Breaks are logged when the break timer completes naturally.").font(.caption).foregroundStyle(.secondary) }
            } else {
                Chart(data, id: \.date) { item in BarMark(x: .value("Period", item.date, unit: .day), y: .value("Minutes", animateCharts ? item.minutes : 0)).foregroundStyle(Color.brgBright.gradient).cornerRadius(4) }
                .chartXAxis { AxisMarks(values: .automatic(desiredCount: timeRange.xLabelCount)) { v in AxisValueLabel { if let d = v.as(Date.self) { Text(xLabel(d)).font(.caption2) } }; AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3)) } }
                .chartYAxis { AxisMarks(position: .leading) { v in AxisValueLabel { if let n = v.as(Double.self) { Text("\(Int(n))m").font(.caption2) } }; AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [3,3])) } }
                .frame(height: 140).animation(.easeOut(duration: 0.5), value: animateCharts).animation(.easeOut(duration: 0.4), value: timeRange)
            }
        }
    }

    @ViewBuilder private var categoryBreakdownCard: some View {
        let breakdown = categoryBreakdown(for: timeRange)
        if !breakdown.isEmpty {
            InsightCard(title: "By Category", icon: "tag.fill", iconColor: .brgBright, onInfo: { showWhySheet = InsightMetricInfo(title: "Category Breakdown", explanation: "Focus minutes grouped by task category.", dataSources: ["Session logs"]) }) {
                VStack(spacing: 10) { ForEach(breakdown, id: \.name) { item in CategoryBreakdownRow(name: item.name, minutes: item.minutes, color: item.color, total: breakdown.map(\.minutes).reduce(0, +)) } }
            }
        }
    }

    @ViewBuilder private var recentSessionsList: some View {
        let all = filteredSessions(for: timeRange).sorted { $0.startDate > $1.startDate }
        let preview = Array(all.prefix(sessionPreviewLimit)); let overflow = all.count - sessionPreviewLimit
        if !preview.isEmpty {
            InsightCard(title: "Recent Sessions", icon: "list.bullet.rectangle", iconColor: .brgBright) {
                VStack(spacing: 0) {
                    ForEach(preview) { log in
                        Button { drillDownLog = log } label: {
                            HStack { VStack(alignment: .leading, spacing: 2) { Text(taskTitle(for: log.taskId)).font(.subheadline.weight(.medium)).foregroundStyle(.primary); Text(log.startDate.formatted(.dateTime.weekday(.short).month(.abbreviated).day().hour().minute())).font(.caption).foregroundStyle(.secondary) }; Spacer(); Text("\(Int(log.duration / 60)) min").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary) }.padding(.vertical, 10)
                        }.buttonStyle(.plain)
                        if log.id != preview.last?.id { Divider() }
                    }
                    if overflow > 0 {
                        Divider()
                        Button { showAllSessionsView = true } label: { HStack(spacing: 6) { Text("Show all \(all.count) sessions").font(.system(size: 13, weight: .semibold)); Image(systemName: "arrow.up.right").font(.system(size: 11, weight: .bold)) }.foregroundStyle(Color.brgBright).frame(maxWidth: .infinity).padding(.vertical, 12) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var digestPreviewCard: some View {
        InsightCard(title: "Weekly Digest", icon: "envelope.open.fill", iconColor: .brgBright) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Preview what your weekly notification will say.").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("This week: \(focusMinutesForRange(.week)) min").font(.subheadline.weight(.semibold))
                        let d = focusMinutesForRange(.week) - focusMinutesPrevRange(.week)
                        Text(d >= 0 ? "+\(d) min vs last week" : "\(d) min vs last week").font(.caption).foregroundStyle(d >= 0 ? Color.brgBright : .red)
                    }
                    Spacer()
                    Button("Preview") { showDigestPreview = true }.buttonStyle(.borderedProminent).tint(Color.brgBright).controlSize(.small)
                }
                HStack(spacing: 4) { Image(systemName: "bell.badge").font(.caption).foregroundStyle(.secondary); Text("Sent every Sunday at 8 PM if notifications are on.").font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    private var hasNoData: Bool { filteredSessions(for: timeRange).isEmpty }
    private var prevAvailable: Bool { focusMinutesPrevRange(timeRange) > 0 }

    private func filteredSessions(for range: InsightsTimeRange) -> [FocusSessionLog] {
        let cal = Calendar.current; let start = cal.date(byAdding: .day, value: -range.days, to: cal.startOfDay(for: Date())) ?? Date()
        return taskStore.sessionLogs.filter { log in guard log.exitReason == .completed, log.startDate >= start else { return false }; if let cat = selectedCategoryFilter { return TaskCategoryStore.shared.category(for: log.taskId)?.id == cat.id }; return true }
    }
    private func filteredSessionsPrev(for range: InsightsTimeRange) -> [FocusSessionLog] {
        let cal = Calendar.current
        let end = cal.date(byAdding: .day, value: -range.days, to: cal.startOfDay(for: Date())) ?? Date()
        let start = cal.date(byAdding: .day, value: -range.days * 2, to: cal.startOfDay(for: Date())) ?? Date()
        return taskStore.sessionLogs.filter { log in guard log.exitReason == .completed, log.startDate >= start, log.startDate < end else { return false }; if let cat = selectedCategoryFilter { return TaskCategoryStore.shared.category(for: log.taskId)?.id == cat.id }; return true }
    }
    private func focusMinutesForRange(_ range: InsightsTimeRange) -> Int { filteredSessions(for: range).reduce(0) { $0 + Int($1.duration / 60) } }
    private func focusMinutesPrevRange(_ range: InsightsTimeRange) -> Int { filteredSessionsPrev(for: range).reduce(0) { $0 + Int($1.duration / 60) } }
    private func completedSessionsForRange(_ range: InsightsTimeRange) -> Int { filteredSessions(for: range).count }
    private func completedSessionsPrevRange(_ range: InsightsTimeRange) -> Int { filteredSessionsPrev(for: range).count }
    private func averageSessionMinutesForRange(_ range: InsightsTimeRange) -> Int { let s = filteredSessions(for: range); guard !s.isEmpty else { return 0 }; return s.reduce(0) { $0 + Int($1.duration / 60) } / s.count }
    private func averageSessionMinutesPrevRange(_ range: InsightsTimeRange) -> Int { let s = filteredSessionsPrev(for: range); guard !s.isEmpty else { return 0 }; return s.reduce(0) { $0 + Int($1.duration / 60) } / s.count }

    private func chartData(for range: InsightsTimeRange) -> [(date: Date, minutes: Int)] {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())
        if range == .week { return (0..<7).map { offset in let day = cal.date(byAdding: .day, value: -(6-offset), to: today) ?? today; let mins = taskStore.sessionLogs.filter { $0.exitReason == .completed && cal.isDate($0.startDate, inSameDayAs: day) && categoryMatches($0.taskId) }.reduce(0) { $0 + Int($1.duration/60) }; return (date: day, minutes: mins) } }
        let buckets = range.days / 7
        return (0..<buckets).map { offset in let daysBack = (buckets-1-offset)*7; let ws = cal.date(byAdding: .day, value: -daysBack, to: today) ?? today; let we = cal.date(byAdding: .day, value: 7, to: ws) ?? ws; let mins = taskStore.sessionLogs.filter { $0.exitReason == .completed && $0.startDate >= ws && $0.startDate < we && categoryMatches($0.taskId) }.reduce(0) { $0 + Int($1.duration/60) }; return (date: ws, minutes: mins) }
    }
    private func breakChartData(for range: InsightsTimeRange) -> [(date: Date, minutes: Double)] {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())
        if range == .week { return (0..<7).map { offset in let day = cal.date(byAdding: .day, value: -(6-offset), to: today) ?? today; let mins = taskStore.sessionLogs.filter { $0.exitReason == .breakEnded && cal.isDate($0.startDate, inSameDayAs: day) && categoryMatches($0.taskId) }.reduce(0.0) { $0 + $1.duration/60 }; return (date: day, minutes: mins) } }
        let buckets = range.days / 7
        return (0..<buckets).map { offset in let daysBack = (buckets-1-offset)*7; let ws = cal.date(byAdding: .day, value: -daysBack, to: today) ?? today; let we = cal.date(byAdding: .day, value: 7, to: ws) ?? ws; let mins = taskStore.sessionLogs.filter { $0.exitReason == .breakEnded && $0.startDate >= ws && $0.startDate < we && categoryMatches($0.taskId) }.reduce(0.0) { $0 + $1.duration/60 }; return (date: ws, minutes: mins) }
    }
    private func categoryMatches(_ taskId: UUID) -> Bool { guard let cat = selectedCategoryFilter else { return true }; return TaskCategoryStore.shared.category(for: taskId)?.id == cat.id }

    private struct CategoryBreakdownItem { let name: String; let minutes: Int; let color: Color }
    private func categoryColor(_ cat: TaskCategory) -> Color {
        switch cat {
        case .coreWork: return .brgBright; case .admin: return Color(uiColor: .secondaryLabel)
        case .planning: return .brgBright.opacity(0.7); case .learning: return .brgBright
        case .creative: return .brgBright.opacity(0.6); case .meetings: return Color(uiColor: .secondaryLabel)
        case .maintenance: return Color(uiColor: .secondaryLabel); case .personalTasks: return Color(uiColor: .secondaryLabel)
        case .health: return .red; case .leisure: return .brgBright.opacity(0.5)
        }
    }
    private func categoryBreakdown(for range: InsightsTimeRange) -> [CategoryBreakdownItem] {
        var totals: [String: (minutes: Int, color: Color)] = [:]
        for log in filteredSessions(for: range) { let cat = TaskCategoryStore.shared.category(for: log.taskId); let name = cat?.title ?? "Uncategorized"; let color = cat.map { categoryColor($0) } ?? Color.gray; totals[name] = ((totals[name]?.minutes ?? 0) + Int(log.duration/60), color) }
        return totals.map { CategoryBreakdownItem(name: $0.key, minutes: $0.value.minutes, color: $0.value.color) }.sorted { $0.minutes > $1.minutes }
    }
    private var availableCategories: [TaskCategory] { var cats: [TaskCategory] = []; var seen = Set<String>(); for log in taskStore.sessionLogs { if let cat = TaskCategoryStore.shared.category(for: log.taskId), seen.insert(cat.id).inserted { cats.append(cat) } }; return cats.sorted { $0.title < $1.title } }

    private struct RecommendationItem { let title: String; let detail: String; let icon: String; let color: Color }
    private var recommendations: [RecommendationItem] {
        var recs: [RecommendationItem] = []
        let currMin = focusMinutesForRange(.week); let prevMin = focusMinutesPrevRange(.week)
        if prevMin > 0 && currMin < prevMin { recs.append(.init(title: "Focus time dropped by \(prevMin-currMin) min", detail: "Try scheduling one 25-minute session tomorrow morning.", icon: "arrow.down.circle.fill", color: .red)) }
        if !taskStore.sessionLogs.contains(where: { $0.exitReason == .completed && Calendar.current.isDateInToday($0.startDate) }) { recs.append(.init(title: "No focus session today", detail: "Even a 15-minute session counts. Schedule one from Tasks.", icon: "calendar.badge.plus", color: Color(uiColor: .secondaryLabel))) }
        if let window = bestTimeOfDay { recs.append(.init(title: "Your best focus window: \(window)", detail: "Schedule your hardest tasks during this time.", icon: "sun.max.fill", color: Color(uiColor: .secondaryLabel))) }
        let streak = taskStore.strictDailyStreak
        if streak > 2 { let tomorrowHasTasks = taskStore.tasks.contains { if let s = $0.scheduledTime { return Calendar.current.isDateInTomorrow(s) && $0.status == .pending }; return false }; if !tomorrowHasTasks { recs.append(.init(title: "Protect your \(streak)-day streak", detail: "No tasks scheduled for tomorrow. Add one to keep the streak alive.", icon: "flame.fill", color: .red)) } }
        let total = taskStore.sessionLogs.count; let distracted = taskStore.sessionLogs.filter { $0.exitReason == .distracted }.count
        if total > 3 && Double(distracted)/Double(total) > 0.3 { recs.append(.init(title: "High distraction rate (\(Int(Double(distracted)/Double(total)*100))%)", detail: "Try shorter 20-min sessions and remove your phone before starting.", icon: "eye.slash.fill", color: .red)) }
        return Array(recs.prefix(3))
    }
    private var bestTimeOfDay: String? {
        var morning = 0, afternoon = 0, evening = 0
        for log in taskStore.sessionLogs where log.exitReason == .completed { let hour = Calendar.current.component(.hour, from: log.startDate); if hour < 12 { morning += 1 } else if hour < 17 { afternoon += 1 } else { evening += 1 } }
        guard morning + afternoon + evening > 0 else { return nil }
        let m = Swift.max(morning, afternoon, evening)
        if m == morning { return "Morning (before noon)" }; if m == afternoon { return "Afternoon (12–17)" }; return "Evening (after 17)"
    }
    private func deltaString(current: Int, previous: Int) -> String? { guard previous > 0 else { return nil }; let d = current - previous; return d >= 0 ? "+\(d)" : "\(d)" }
    private func deltaLabel(delta: Int) -> String { delta >= 0 ? "+\(delta) min vs prev" : "\(delta) min vs prev" }
    private func xLabel(_ date: Date) -> String { switch timeRange { case .week: return date.formatted(.dateTime.weekday(.abbreviated)); case .month, .quarter: return date.formatted(.dateTime.month(.abbreviated).day()) } }
    private func barGradient(for value: Int, data: [(date: Date, minutes: Int)]) -> LinearGradient { let mx = data.map(\.minutes).max() ?? 1; let intensity = mx > 0 ? Double(value)/Double(mx) : 0; return LinearGradient(colors: [Color.brgBright.opacity(0.4+intensity*0.6), Color.brgBright], startPoint: .bottom, endPoint: .top) }
    private func taskTitle(for taskId: UUID) -> String { taskStore.tasks.first(where: { $0.id == taskId })?.title ?? "Unknown task" }
}

// MARK: - GlanceMetricTile
private struct GlanceMetricTile: View {
    let icon: String; let label: String; let value: String; let delta: String?; let deltaPositive: Bool; let color: Color; let info: InsightMetricInfo; let onInfo: (InsightMetricInfo) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack { Image(systemName: icon).foregroundStyle(color).font(.subheadline); Text(label).font(.caption).foregroundStyle(.secondary); Spacer(); Button { onInfo(info) } label: { Image(systemName: "info.circle").font(.caption).foregroundStyle(.tertiary) }.buttonStyle(.plain) }
            Text(value).font(.title2.bold())
            if let delta { Text(delta).font(.caption.weight(.medium)).foregroundStyle(deltaPositive ? Color.brgBright : Color.red) } else { Text(" ").font(.caption) }
        }
        .padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - FilterChip
private struct FilterChip: View {
    let label: String; var color: Color = Color.brgBright; let isSelected: Bool; let onTap: () -> Void
    var body: some View {
        Button(action: onTap) {
            Text(label).font(.caption.weight(.medium)).padding(.horizontal, 12).padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.15) : Color(uiColor: .systemBackground))
                .foregroundStyle(isSelected ? .primary : .secondary).clipShape(Capsule())
                .overlay(Capsule().stroke(isSelected ? color.opacity(0.5) : Color.secondary.opacity(0.2), lineWidth: 1))
        }.buttonStyle(.plain)
    }
}

// MARK: - InsightCard
private struct InsightCard<Content: View>: View {
    let title: String; let icon: String; let iconColor: Color; var badge: String? = nil; var badgeColor: Color = Color.brgBright; var onInfo: (() -> Void)? = nil; @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(iconColor).font(.subheadline.weight(.semibold)); Text(title).font(.headline); Spacer()
                if let badge { Text(badge).font(.caption.weight(.semibold)).foregroundStyle(.primary).padding(.horizontal, 8).padding(.vertical, 3).background(badgeColor.opacity(0.12), in: Capsule()) }
                if let onInfo { Button(action: onInfo) { Image(systemName: "info.circle").font(.subheadline).foregroundStyle(.tertiary) }.buttonStyle(.plain) }
            }
            content
        }
        .padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
}

// MARK: - CategoryBreakdownRow
private struct CategoryBreakdownRow: View {
    let name: String; let minutes: Int; let color: Color; let total: Int
    private var fraction: Double { total > 0 ? Double(minutes)/Double(total) : 0 }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(name).font(.subheadline.weight(.medium)); Spacer(); Text("\(minutes) min").font(.caption.weight(.semibold)).foregroundStyle(.secondary); Text("(\(Int(fraction*100))%)").font(.caption2).foregroundStyle(.tertiary) }
            GeometryReader { geo in ZStack(alignment: .leading) { RoundedRectangle(cornerRadius: 4).fill(Color(uiColor: .systemFill)).frame(height: 6); RoundedRectangle(cornerRadius: 4).fill(color.gradient).frame(width: geo.size.width*fraction, height: 6).animation(.easeOut(duration: 0.5), value: fraction) } }.frame(height: 6)
        }
    }
}

// MARK: - MetricExplanationSheet
private struct MetricExplanationSheet: View {
    let info: InsightMetricInfo; @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 20) { VStack(alignment: .leading, spacing: 8) { Text("How it's calculated").font(.headline); Text(info.explanation).font(.body).foregroundStyle(.secondary) }; VStack(alignment: .leading, spacing: 8) { Text("Data sources").font(.headline); ForEach(info.dataSources, id: \.self) { src in Label(src, systemImage: "cylinder.split.1x2").font(.subheadline).foregroundStyle(.secondary) } } }.padding() }
            .navigationTitle(info.title).navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.presentationDetents([.medium])
    }
}

// MARK: - SessionDrillDownSheet
private struct SessionDrillDownSheet: View {
    let log: FocusSessionLog; let taskStore: TaskStore; @Environment(\.dismiss) private var dismiss
    private var taskTitle: String { taskStore.tasks.first(where: { $0.id == log.taskId })?.title ?? "Unknown task" }
    private var category: TaskCategory? { TaskCategoryStore.shared.category(for: log.taskId) }
    var body: some View {
        NavigationStack {
            List {
                Section("Session") { LabeledContent("Task", value: taskTitle); if let cat = category { LabeledContent("Category", value: cat.title) }; LabeledContent("Outcome", value: log.exitReason.title) }
                Section("Timing") { LabeledContent("Started", value: log.startDate.formatted(.dateTime.weekday(.short).month(.abbreviated).day().hour().minute())); LabeledContent("Ended", value: log.endDate.formatted(.dateTime.hour().minute())); LabeledContent("Duration", value: "\(Int(log.duration/60)) min") }
                if let bm = log.breakMinutes, bm > 0 { Section("Break") { LabeledContent("Break taken", value: "\(bm) min") } }
                Section("Context") { Label(log.exitReason == .completed ? "Session fully completed" : "Session ended early", systemImage: log.exitReason == .completed ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(log.exitReason == .completed ? .primary : .secondary); if let hint = peakHint { Label(hint, systemImage: "lightbulb.fill").foregroundStyle(.secondary) } }
            }
            .navigationTitle("Session Details").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
    private var peakHint: String? {
        let hour = Calendar.current.component(.hour, from: log.startDate)
        switch hour { case ..<9: return "Early morning — great discipline"; case ..<12: return "Morning — peak cognitive window"; case ..<14: return "Late morning / around noon"; case ..<17: return "Afternoon session"; default: return "Evening session" }
    }
}

// MARK: - DigestPreviewSheet
private struct DigestPreviewSheet: View {
    let settings: AppSettingsStore; let weeklyMinutes: Int; let prevWeekMinutes: Int; let completedSessions: Int; let streak: Int; let bestDay: (date: Date, minutes: Int)?
    @Environment(\.dismiss) private var dismiss
    private var delta: Int { weeklyMinutes - prevWeekMinutes }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { Image(systemName: "envelope.open.fill").font(.title2).foregroundStyle(.primary); VStack(alignment: .leading, spacing: 2) { Text("Weekly Progress").font(.headline); Text("Sent every Sunday at 8 PM").font(.caption).foregroundStyle(.secondary) } }
                        Divider(); Text(digestBody).font(.body).foregroundStyle(.primary)
                    }.padding(20).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notification settings").font(.headline)
                        Toggle("Weekly & Monthly digests", isOn: Binding(get: { settings.notificationsDailySummary }, set: { settings.notificationsDailySummary = $0 })).tint(Color.brgBright).padding(14).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                        Text("Digests only fire if you have session data for that period.").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding()
            }
            .navigationTitle("Digest Preview").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
    private var digestBody: String {
        var lines = ["This week you focused for \(weeklyMinutes) minutes across \(completedSessions) completed session\(completedSessions == 1 ? "" : "s")."]
        if prevWeekMinutes > 0 { lines.append(delta >= 0 ? "That's \(delta) min more than last week — great progress! 🎉" : "That's \(abs(delta)) min less than last week. Try one extra session next week.") }
        if streak > 1 { lines.append("You're on a \(streak)-day streak. Keep it going!") }
        if let best = bestDay { lines.append("Best day: \(best.date.formatted(.dateTime.weekday(.wide))) with \(best.minutes) min.") }
        lines.append("\nOpen the app to see your full Insights breakdown.")
        return lines.joined(separator: "\n")
    }
}

// MARK: - AllSessionsSheet
private enum SessionHistoryRange: String, CaseIterable, Identifiable {
    case all = "All time"; case week = "7 Days"; case month = "30 Days"; case quarter = "3 Months"; case year = "This year"
    var id: String { rawValue }
    func startDate() -> Date? {
        let cal = Calendar.current; let today = cal.startOfDay(for: Date())
        switch self { case .all: return nil; case .week: return cal.date(byAdding: .day, value: -7, to: today); case .month: return cal.date(byAdding: .day, value: -30, to: today); case .quarter: return cal.date(byAdding: .day, value: -90, to: today); case .year: return cal.dateInterval(of: .year, for: today)?.start }
    }
}
private struct AllSessionsSheet: View {
    let allSessions: [FocusSessionLog]; let taskStore: TaskStore; @Environment(\.dismiss) private var dismiss
    @State private var historyRange: SessionHistoryRange = .all; @State private var searchText = ""; @State private var drillDownLog: FocusSessionLog? = nil
    private var rangeFiltered: [FocusSessionLog] { guard let start = historyRange.startDate() else { return allSessions }; return allSessions.filter { $0.startDate >= start } }
    private var filtered: [FocusSessionLog] { guard !searchText.isEmpty else { return rangeFiltered }; let q = searchText.lowercased(); return rangeFiltered.filter { taskTitle(for: $0.taskId).lowercased().contains(q) } }
    private var grouped: [(date: Date, logs: [FocusSessionLog])] { let cal = Calendar.current; let dict = Dictionary(grouping: filtered) { cal.startOfDay(for: $0.startDate) }; return dict.map { (date: $0.key, logs: $0.value.sorted { $0.startDate > $1.startDate }) }.sorted { $0.date > $1.date } }
    private var totalMinutes: Int { rangeFiltered.reduce(0) { $0 + Int($1.duration/60) } }
    private var earliestDate: Date? { allSessions.last?.startDate }
    var body: some View {
        NavigationStack {
            List {
                Section { Picker("Period", selection: $historyRange) { ForEach(SessionHistoryRange.allCases) { r in Text(r.rawValue).tag(r) } }.pickerStyle(.segmented).listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) }
                Section { HStack(spacing: 0) { summaryCell(icon: "list.bullet", label: "Sessions", value: "\(rangeFiltered.count)"); Divider().padding(.vertical, 8); summaryCell(icon: "clock.fill", label: "Total time", value: hoursLabel(totalMinutes)); Divider().padding(.vertical, 8); summaryCell(icon: "calendar", label: historyRange == .all ? "Since" : "Period", value: historyRange == .all ? (earliestDate.map { shortDate($0) } ?? "—") : historyRange.rawValue) }.padding(.vertical, 6) }
                if filtered.isEmpty {
                    Section { HStack { Spacer(); VStack(spacing: 8) { Image(systemName: searchText.isEmpty ? "calendar.badge.exclamationmark" : "magnifyingglass").font(.system(size: 32)).foregroundStyle(.secondary); Text(searchText.isEmpty ? "No sessions in this period" : "No results for \"\(searchText)\"").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }.padding(.vertical, 24); Spacer() } }
                } else {
                    ForEach(grouped, id: \.date) { group in Section {
                        ForEach(group.logs) { log in Button { drillDownLog = log } label: { HStack(spacing: 12) { Text(log.startDate.formatted(.dateTime.hour().minute())).font(.system(size: 13, weight: .medium, design: .rounded)).foregroundStyle(.secondary).frame(width: 46, alignment: .leading); VStack(alignment: .leading, spacing: 2) { Text(taskTitle(for: log.taskId)).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary).lineLimit(1); Text("\(Int(log.duration/60)) min").font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "chevron.right").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary) }.padding(.vertical, 2) }.buttonStyle(.plain) }
                    } header: { Text(sectionHeader(group.date)).font(.system(size: 12, weight: .semibold)).textCase(nil) } }
                }
            }
            .listStyle(.insetGrouped).navigationTitle("Session History").navigationBarTitleDisplayMode(.large).searchable(text: $searchText, prompt: "Search by task name")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
            .sheet(item: $drillDownLog) { SessionDrillDownSheet(log: $0, taskStore: taskStore) }
        }
    }
    private func taskTitle(for taskId: UUID) -> String { taskStore.tasks.first(where: { $0.id == taskId })?.title ?? "Unknown task" }
    private func hoursLabel(_ minutes: Int) -> String { guard minutes > 0 else { return "0m" }; let h = minutes/60; let m = minutes%60; if h == 0 { return "\(m)m" }; return m > 0 ? "\(h)h \(m)m" : "\(h)h" }
    private func shortDate(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).year()) }
    private func sectionHeader(_ date: Date) -> String { let cal = Calendar.current; if cal.isDateInToday(date) { return "Today" }; if cal.isDateInYesterday(date) { return "Yesterday" }; if cal.isDate(date, equalTo: Date(), toGranularity: .year) { return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()) }; return date.formatted(.dateTime.month(.abbreviated).day().year()) }
    private func summaryCell(icon: String, label: String, value: String) -> some View { VStack(spacing: 6) { Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary); Text(value).font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.primary).lineLimit(1).minimumScaleFactor(0.7); Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary) }.frame(maxWidth: .infinity) }
}

#Preview {
    InsightsView(settings: AppSettingsStore())
        .environmentObject(TaskStore(settings: AppSettingsStore()))
}
