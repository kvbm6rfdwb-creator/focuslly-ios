import SwiftUI
import EventKit

// Lane frame (global) preference.
private struct LaneGlobalFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

private struct PreviewCardGlobalFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct CalendarView: View {
    @EnvironmentObject var taskStore: TaskStore
    @ObservedObject private var calSyncStore = CalendarSyncStore.shared

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showMonthPicker = false
    @State private var didInitialScroll = false

    enum ViewMode { case day, month }
    @State private var viewMode: ViewMode = .day

    @State private var monthExpanded: Bool = false
    @State private var showYearPicker: Bool = false
    @State private var displayMonth: Date = Calendar.current.startOfDay(for: Date())
    @State private var taskCountByDay: [String: Int] = [:]
    @State private var cachedCategoryColors: [UUID: Color] = [:]
    @State private var cachedTaskIDsByDay: [String: [UUID]] = [:]

    nonisolated private static let isoDateKey: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; f.locale = Locale(identifier: "en_US_POSIX"); return f
    }()

    @Namespace private var dateNamespace

    private let calendar = Calendar.current
    private let itemWidth: CGFloat = 44
    private let appleRed = Color(red: 1.0, green: 0.23, blue: 0.19)

    private static let shortWeekdayFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "EE"; return df
    }()
    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "MMMM d"; return df
    }()
    private static let weekdayFormatter: DateFormatter = {
        let df = DateFormatter(); df.dateFormat = "EEEE"; return df
    }()

    @State private var daysInRange: [Date] = []
    @State private var appleCalendarEvents: [EKEvent] = []
    @State private var allDayCalendarEvents: [EKEvent] = []
    @State private var selectedEKEvent: EKEvent? = nil
    @State private var showEKEventDetail: Bool = false

    private let timelineStartHour = 5
    private let timelineEndHour = 24
    private var timelineHourIntervals: Int { timelineEndHour - timelineStartHour }
    private var timelineTotalHourRows: Int { timelineHourIntervals + 1 }

    static let cachedScreenScale: CGFloat = {
        if let ws = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            return ws.screen.scale
        }
        // Fallback for cold-launch edge case before any scene is active.
        return 2.0
    }()

    @State private var hourHeight: CGFloat = 76
    @State private var hourHeightAtPinchStart: CGFloat = 76
    private let maxHourHeight: CGFloat = 120
    private let fallbackMinHourHeight: CGFloat = 48
    private let absoluteMinHourHeight: CGFloat = 18
    private let timelineContentTopPadding: CGFloat = 12
    private let timelineContentBottomGuard: CGFloat = 2

    private func adaptiveMinHourHeight(viewportHeight: CGFloat) -> CGFloat {
        let reservedBottom = max(0, effectiveTimelineBottomInset)
        let usable = max(0, viewportHeight - reservedBottom - timelineContentTopPadding - timelineContentBottomGuard)
        let intervals = max(1, timelineHourIntervals)
        let rawFit = usable / CGFloat(intervals)
        let scale = Self.cachedScreenScale
        let alignedFit = floor(rawFit * scale) / scale
        let minToFit = max(absoluteMinHourHeight, alignedFit)
        return min(maxHourHeight, minToFit)
    }

    private func clampedHourHeight(_ proposed: CGFloat) -> CGFloat {
        let viewportH = timelineViewportHeight
        let minH: CGFloat = (viewportH.isFinite && viewportH > 0)
            ? adaptiveMinHourHeight(viewportHeight: viewportH)
            : fallbackMinHourHeight
        return min(max(minH, proposed), maxHourHeight)
    }

    private var isAtMinimumZoom: Bool {
        let viewportH = timelineViewportHeight
        guard viewportH.isFinite, viewportH > 0 else { return false }
        let minH = adaptiveMinHourHeight(viewportHeight: viewportH)
        return abs(hourHeight - minH) <= 0.25
    }

    @State private var selectedTask: FocusTask?
    @State private var showEditSheet = false
    @State private var showDeleteAlert = false
    @State private var pressedTaskID: UUID? = nil
    @State private var previewTaskID: UUID? = nil
    @State private var previewCardGrowthScale: CGFloat = 0.0
    @State private var contextMenuGrowthScale: CGFloat = 0.0
    private let contextMenuRevealDelay: TimeInterval = 0
    @State private var isTaskClickAnimating: Bool = false
    private let laneCoordinateSpaceName = "calendarTaskLane"
    @State private var laneGlobalFrame: CGRect = .zero
    @State private var pressedTaskRectInLane: CGRect = .zero
    @State private var viewportGlobalFrame: CGRect = .zero
    @State private var timelineViewportHeight: CGFloat = 0
    @State private var timelineBottomReservedInset: CGFloat = 0

    private var effectiveTimelineBottomInset: CGFloat {
        let base = min(max(timelineBottomReservedInset, 0), 22)
        return base + 4
    }

    @State private var measuredTaskTileWidths: [UUID: CGFloat] = [:]
    @State private var measuredTaskTileHeights: [UUID: CGFloat] = [:]
    @State private var measuredPreviewCardWidths: [UUID: CGFloat] = [:]
    @State private var previewCardAnchorGlobalFrame: CGRect = .zero

    @State private var cachedTasksForSelectedDay: [FocusTask] = []
    @State private var cachedTimelineItems:       [CalendarTimelineItem] = []
    @State private var cachedTimelineLayouts:     [UUID: CalendarTaskLayoutInfo] = [:]

    private var isSelectedDateToday: Bool {
        calendar.isDate(selectedDate, inSameDayAs: Date())
    }

    // MARK: - Tasks

    private var tasksForSelectedDay: [FocusTask] {
        cachedTasksForSelectedDay
    }

    // MARK: - Per-occurrence completion
    private func isTaskCompletedOnDay(_ task: FocusTask, day: Date) -> Bool {
        taskStore.sessionLogs.contains {
            $0.taskId == task.id &&
            $0.exitReason == .completed &&
            calendar.isDate($0.startDate, inSameDayAs: day)
        }
    }

    // MARK: - Derived data recomputation (async)

    private func recalculateDerivedCalendarData() {
        let date  = selectedDate
        let tasks = taskStore.tasks
        let cal   = calendar

        let categorySnapshot: [UUID: Color] = Dictionary(
            uniqueKeysWithValues: tasks.compactMap { task -> (UUID, Color)? in
                guard let cat = TaskCategoryStore.shared.category(for: task.id) else { return nil }
                return (task.id, cat.color)
            }
        )

        Task.detached(priority: .userInitiated) {
            let dayTasks: [FocusTask] = tasks
                .filter { task in
                    guard let time = task.scheduledTime else { return false }
                    switch task.recurrenceType {
                    case .once:
                        return cal.isDate(time, inSameDayAs: date)
                    case .daily:
                        return true
                    case .weekdays:
                        let weekday = cal.component(.weekday, from: date)
                        return weekday >= 2 && weekday <= 6
                    case .custom:
                        guard let days = task.recurrenceDays else { return false }
                        let weekdayZeroBased = cal.component(.weekday, from: date) - 1
                        return days.contains(weekdayZeroBased)
                    }
                }
                .sorted { ($0.scheduledTime ?? .distantPast) < ($1.scheduledTime ?? .distantPast) }

            // ── TIMEZONE-SAFE start time construction ──
            // For .once tasks viewed on their own day: use the original scheduledTime directly.
            // For recurring tasks (or any task viewed on a different day): extract the
            // wall-clock hour/minute/second as a TimeInterval offset from midnight, then add
            // that offset to the selected day's local midnight. This avoids all DateComponents
            // timezone bugs because startOfDay() and addingTimeInterval() are both timezone-safe.
            let viewedDayStart = cal.startOfDay(for: date)

            let items: [CalendarTimelineItem] = dayTasks.compactMap { task -> CalendarTimelineItem? in
                guard let scheduled = task.scheduledTime else { return nil }

                // ALWAYS transplant: extract wall-clock h:m:s from original scheduledTime,
                // apply to the currently-viewed day. This is correct for ALL cases:
                // - .once tasks on their own day (no-op: same day, same result)
                // - recurring tasks shown on a different day
                // Using startOfDay + addingTimeInterval is the most timezone-safe
                // method because both APIs operate on absolute seconds with
                // Calendar.current's timezone.
                let scheduledDayStart = cal.startOfDay(for: scheduled)
                let secondsFromMidnight = scheduled.timeIntervalSince(scheduledDayStart)
                let start = viewedDayStart.addingTimeInterval(secondsFromMidnight)

                let dur = Self.durationSecondsStatic(for: task)
                return CalendarTimelineItem(id: task.id, task: task, startTime: start, endTime: start.addingTimeInterval(dur))
            }

            let layouts = Self.computeLayoutsStatic(for: dayTasks, items: items)

            let keyFmt = CalendarView.isoDateKey
            let byDay: [String: [UUID]] = tasks.reduce(into: [:]) { dict, task in
                switch task.recurrenceType {
                case .once:
                    guard let t = task.scheduledTime else { return }
                    let k = keyFmt.string(from: cal.startOfDay(for: t))
                    dict[k, default: []].append(task.id)
                case .daily:
                    dict["*daily*", default: []].append(task.id)
                case .weekdays:
                    dict["*weekdays*", default: []].append(task.id)
                case .custom:
                    for wd in (task.recurrenceDays ?? []) {
                        dict["*wd\(wd)*", default: []].append(task.id)
                    }
                }
            }

            await MainActor.run {
                cachedTasksForSelectedDay = dayTasks
                cachedTimelineItems       = items
                cachedTimelineLayouts     = layouts
                cachedCategoryColors      = categorySnapshot
                cachedTaskIDsByDay        = byDay
            }
        }
    }

    // MARK: - Static helpers

    nonisolated private static func durationSecondsStatic(for task: FocusTask) -> TimeInterval {
        let blocks = task.focusPlan.blocks
        if blocks.count == 1, let b = blocks.first, b.type == .focus, b.duration > 0 { return TimeInterval(b.duration) }
        if let f = blocks.first(where: { $0.type == .focus && $0.duration > 0 }) { return TimeInterval(f.duration) }
        let any = blocks.map(\.duration).filter { $0 > 0 }.reduce(0, +)
        return any > 0 ? TimeInterval(any) : TimeInterval(25 * 60)
    }

    nonisolated private static func computeLayoutsStatic(
        for dayTasks: [FocusTask],
        items: [CalendarTimelineItem]
    ) -> [UUID: CalendarTaskLayoutInfo] {
        struct TI { let taskId: UUID; let start: TimeInterval; let end: TimeInterval }
        let visualBuffer: TimeInterval = 5 * 60

        let intervals: [TI] = items.map {
            TI(taskId: $0.id,
               start: $0.startTime.timeIntervalSince1970,
               end:   $0.endTime.timeIntervalSince1970)
        }.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            if $0.end   != $1.end   { return $0.end   < $1.end   }
            return $0.taskId.uuidString < $1.taskId.uuidString
        }

        // ── Step 1: Build conflict clusters ─────────────────────────────────
        var clusters: [[TI]] = []; var current: [TI] = []; var maxEnd: TimeInterval = -.infinity
        for i in intervals {
            if current.isEmpty { current = [i]; maxEnd = i.end; continue }
            if i.start < maxEnd + visualBuffer {
                current.append(i); maxEnd = max(maxEnd, i.end)
            } else {
                clusters.append(current); current = [i]; maxEnd = i.end
            }
        }
        if !current.isEmpty { clusters.append(current) }

        // ── Step 2: Assign columns greedily within each cluster ──────────────
        // Produces: columnIndex per task and the cluster-wide column ceiling
        struct AC { let end: TimeInterval; let column: Int }
        var assignedColumn = [UUID: Int]()
        var clusterCeiling = [UUID: Int]()   // max col assigned anywhere in this cluster

        for cluster in clusters {
            let sorted = cluster.sorted {
                if $0.start != $1.start { return $0.start < $1.start }
                if $0.end   != $1.end   { return $0.end   < $1.end   }
                return $0.taskId.uuidString < $1.taskId.uuidString
            }
            var active = [AC]()
            var free   = [Int]()   // sorted list of free column indices
            var maxColUsed = 0

            for interval in sorted {
                // Retire columns that are no longer active
                var toFree = [(offset: Int, col: Int)]()
                for (idx, a) in active.enumerated() {
                    if a.end + visualBuffer <= interval.start {
                        toFree.append((idx, a.column))
                    }
                }
                // Remove retired entries (reverse order to preserve indices)
                for (idx, col) in toFree.reversed() {
                    active.remove(at: idx)
                    // Insert col back into free list in sorted order
                    let pos = free.firstIndex(where: { $0 > col }) ?? free.count
                    free.insert(col, at: pos)
                }

                // Assign the lowest free column, or a new one
                let chosen: Int
                if let first = free.first {
                    chosen = first
                    free.removeFirst()
                } else {
                    chosen = (active.map(\.column).max() ?? -1) + 1
                }
                maxColUsed = max(maxColUsed, chosen)

                // Insert into active list sorted by end time
                let newAC = AC(end: interval.end, column: chosen)
                var lo = 0, hi = active.count
                while lo < hi {
                    let mid = (lo + hi) / 2
                    if active[mid].end <= newAC.end { lo = mid + 1 } else { hi = mid }
                }
                active.insert(newAC, at: lo)
                assignedColumn[interval.taskId] = chosen
            }

            // Record ceiling for every task in this cluster
            let ceiling = maxColUsed + 1
            for interval in cluster { clusterCeiling[interval.taskId] = ceiling }
        }

        // ── Step 3: Compute per-task LOCAL column count ──────────────────────
        // For each task, the local count = how many tasks (including itself) are
        // simultaneously active at that task's start time. This gives it the
        // correct width — non-overlapping tasks get full width even if a
        // different part of the cluster is busier.
        //
        // Algorithm: for each task T, count how many other tasks overlap T
        // (start < T.end+buffer AND end+buffer > T.start) and share the same
        // time-expanded window, then take max(that count, T.columnIndex+1) so
        // the column is always within bounds.
        var result = [UUID: CalendarTaskLayoutInfo]()
        result.reserveCapacity(intervals.count)

        for task in intervals {
            let colIdx = assignedColumn[task.taskId] ?? 0

            // Count concurrent tasks at task.start (using visual buffer)
            let concurrent = intervals.filter {
                $0.start < task.end   + visualBuffer &&
                $0.end   + visualBuffer > task.start
            }

            // The local column count is the maximum column index among
            // concurrent tasks + 1 (so all concurrent tasks fit side-by-side),
            // but at least colIdx+1 to keep the task within bounds.
            let maxConcurrentCol = concurrent.compactMap { assignedColumn[$0.taskId] }.max() ?? 0
            let localCount = max(maxConcurrentCol + 1, colIdx + 1)

            result[task.taskId] = CalendarTaskLayoutInfo(columnIndex: colIdx, columnCount: localCount)
        }

        // Fallback for tasks with no timeline item
        for t in dayTasks where result[t.id] == nil {
            result[t.id] = CalendarTaskLayoutInfo(columnIndex: 0, columnCount: 1)
        }
        return result
    }

    @ViewBuilder
    private var allDaySection: some View {
        if !allDayCalendarEvents.isEmpty {
            allDayBanner
            Divider().opacity(0.2)
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.2)
            if viewMode == .day {
                dayScroll
                Divider().opacity(0.2)
                allDaySection
                CalendarTimelineView(
                    items:               cachedTimelineItems,
                    taskLayouts:         cachedTimelineLayouts,
                    categoryColors:      cachedCategoryColors,
                    appleCalendarEvents: appleCalendarEvents,
                    selectedDate:        selectedDate,
                    isSelectedDateToday: isSelectedDateToday,
                    onDaySwipe: { delta in
                        let next = calendar.date(byAdding: .day, value: delta, to: selectedDate) ?? selectedDate
                        selectedDate = calendar.startOfDay(for: next)
                    },
                    onCompletionCheck: { task, day in isTaskCompletedOnDay(task, day: day) },
                    onEdit:   { task in selectedTask = task; showEditSheet   = true },
                    onDelete: { task in selectedTask = task; showDeleteAlert = true }
                )
            } else {
                monthView
            }
        }
        .background(Color(.systemGroupedBackground))
        .tint(appleRed)
        .sheet(isPresented: $showMonthPicker) {
            MonthGridPicker(selectedDate: $selectedDate, showMonthGrid: .constant(false))
        }
        .sheet(isPresented: $showYearPicker) {
            YearOverviewSheet(selectedDate: $selectedDate, displayMonth: $displayMonth, isPresented: $showYearPicker)
        }
        .sheet(isPresented: $showEditSheet, onDismiss: resetSelection) {
            if let task = selectedTask {
                EditTaskView(task: task).environmentObject(taskStore)
            }
        }
        .alert("Delete task?", isPresented: $showDeleteAlert, presenting: selectedTask) { task in
            Button("Delete", role: .destructive) { taskStore.deleteTask(task); resetSelection() }
            Button("Cancel", role: .cancel)      { resetSelection() }
        } message: { _ in Text("This action cannot be undone.") }
        .onAppear {
            rebuildDaysInRange()
            displayMonth = calendar.startOfDay(for: selectedDate)
            recalculateDerivedCalendarData()
            // Trigger a full sync — reloadCalendarEvents fires when isSyncing → false
            calSyncStore.sync()
        }
        .onChange(of: selectedDate) { _, newDate in
            ensureSelectedDateInRange(newDate)
            let newM = calendar.date(from: calendar.dateComponents([.year, .month], from: newDate)) ?? newDate
            let curM = calendar.date(from: calendar.dateComponents([.year, .month], from: displayMonth)) ?? displayMonth
            if !calendar.isDate(newM, inSameDayAs: curM) { displayMonth = newM }
            recalculateDerivedCalendarData()
            reloadCalendarEvents()
        }
        .onChange(of: taskStore.tasks)             { _, _ in recalculateDerivedCalendarData() }
        .onChange(of: taskStore.sessionLogs.count) { _, _ in recalculateDerivedCalendarData() }
        .onChange(of: calSyncStore.storeRevision)       { _, _ in reloadCalendarEvents() }
        .onChange(of: calSyncStore.selectedCalendarIDs) { _, _ in reloadCalendarEvents() }
        .onChange(of: calSyncStore.isSyncing) { _, syncing in
            if !syncing { reloadCalendarEvents() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .calendarResetToNow)) { _ in
            let today = calendar.startOfDay(for: Date())
            if !calendar.isDate(selectedDate, inSameDayAs: today) {
                selectedDate = today
            }
            viewMode = .day
        }
    }

    // MARK: - Calendar event helpers

    private func reloadCalendarEvents() {
        appleCalendarEvents  = calSyncStore.events(for: selectedDate)
        allDayCalendarEvents = calSyncStore.allDayEvents(for: selectedDate)
    }

    // MARK: - daysInRange management

    private func rebuildDaysInRange() {
        let center = calendar.startOfDay(for: selectedDate)
        daysInRange = (-180...180).compactMap { calendar.date(byAdding: .day, value: $0, to: center) }
    }

    private func ensureSelectedDateInRange(_ date: Date) {
        if !daysInRange.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
            rebuildDaysInRange()
        }
    }

    // MARK: - All-day banner

    private var allDayBanner: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(allDayCalendarEvents, id: \.eventIdentifier) { event in
                    let calColor: Color = {
                        if let c = event.calendar?.cgColor { return Color(c) }
                        return .accentColor
                    }()
                    HStack(spacing: 5) {
                        Circle().fill(calColor).frame(width: 7, height: 7)
                        Text(event.title ?? "Event")
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(calColor.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Month view

    private func tasksForDay(_ day: Date) -> [FocusTask] {
        let cal = calendar
        return taskStore.tasks.filter { task in
            guard let t = task.scheduledTime else { return false }
            switch task.recurrenceType {
            case .once:     return cal.isDate(t, inSameDayAs: day)
            case .daily:    return true
            case .weekdays: let w = cal.component(.weekday, from: day); return w >= 2 && w <= 6
            case .custom:
                guard let days = task.recurrenceDays else { return false }
                return days.contains(cal.component(.weekday, from: day) - 1)
            }
        }.sorted { ($0.scheduledTime ?? .distantPast) < ($1.scheduledTime ?? .distantPast) }
    }

    private var monthView: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3).foregroundColor(.secondary)
                        .frame(width: 44, height: 36)
                }
                Spacer()
                Button { showYearPicker = true } label: {
                    Text(monthYearString(for: displayMonth))
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3).foregroundColor(.secondary)
                        .frame(width: 44, height: 36)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemBackground))

            HStack(spacing: 0) {
                ForEach(Self.orderedWeekdaySymbols, id: \.self) { sym in
                    Text(sym)
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
            .background(Color(.systemBackground))

            Divider().opacity(0.2)

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    monthGrid
                    Rectangle().fill(Color.secondary.opacity(0.2)).frame(height: 1)
                    monthDayTaskList
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 30, coordinateSpace: .local)
                    .onEnded { value in
                        let h = abs(value.translation.width)
                        let v = abs(value.translation.height)
                        guard h > v * 2, h > 60 else { return }
                        withAnimation(.easeInOut(duration: 0.22)) {
                            if value.translation.width < 0 {
                                displayMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                            } else {
                                displayMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                            }
                        }
                    }
            )
        }
        .background(Color(.systemGroupedBackground))
    }

    private static let orderedWeekdaySymbols: [String] = {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        let syms = cal.shortWeekdaySymbols
        let offset = 1
        return (offset..<(syms.count + offset)).map { syms[$0 % syms.count] }
    }()

    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()

    private func monthYearString(for date: Date) -> String {
        Self.monthYearFormatter.string(from: date)
    }

    private static let mondayFirstCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = TimeZone.current
        c.locale   = Locale.current
        return c
    }()

    private var monthGridDays: [Date?] {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month], from: displayMonth)
        comps.day = 1
        guard let monthStart = cal.date(from: comps).map({ cal.startOfDay(for: $0) }),
              let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let firstWeekday = (cal.component(.weekday, from: monthStart) - 2 + 7) % 7
        var days: [Date?] = Array(repeating: nil, count: firstWeekday)
        for day in range {
            if let d = cal.date(byAdding: .day, value: day - 1, to: monthStart) {
                days.append(cal.startOfDay(for: d))
            }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    private var monthGrid: some View {
        let days = monthGridDays
        let rows = days.count / 7
        return VStack(spacing: 0) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7) { col in
                        let idx = row * 7 + col
                        if idx < days.count, let day = days[idx] {
                            monthGridCell(day: day)
                        } else {
                            Color.clear.frame(maxWidth: .infinity).frame(height: 46)
                        }
                    }
                }
                if row < rows - 1 { Divider().opacity(0.12) }
            }
        }
        .background(Color(.systemBackground))
        .drawingGroup()
    }

    private func cachedTaskIDs(for day: Date) -> [UUID] {
        let key    = Self.isoDateKey.string(from: calendar.startOfDay(for: day))
        var ids    = cachedTaskIDsByDay[key] ?? []
        ids += cachedTaskIDsByDay["*daily*"] ?? []
        let wd = calendar.component(.weekday, from: day)
        if wd >= 2 && wd <= 6 { ids += cachedTaskIDsByDay["*weekdays*"] ?? [] }
        let wdZero = wd - 1
        ids += cachedTaskIDsByDay["*wd\(wdZero)*"] ?? []
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }

    @ViewBuilder
    private func monthGridCell(day: Date) -> some View {
        let isSelected  = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday     = calendar.isDate(day, inSameDayAs: Date())
        let isThisMonth = calendar.isDate(day, equalTo: displayMonth, toGranularity: .month)
        let dotIDs      = cachedTaskIDs(for: day)
        let ekEvents    = calSyncStore.events(for: day) + calSyncStore.allDayEvents(for: day)
        let hasEKEvents = !ekEvents.isEmpty

        Button {
            selectedDate = calendar.startOfDay(for: day)
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.system(size: 17, weight: isToday || isSelected ? .bold : .regular))
                    .foregroundColor(
                        isSelected  ? .white
                        : isToday   ? appleRed
                        : isThisMonth ? .primary
                        : Color.secondary.opacity(0.4)
                    )
                    .frame(width: 32, height: 32)
                    .background(
                        Group {
                            if isSelected      { Circle().fill(appleRed) }
                            else if isToday    { Circle().stroke(appleRed, lineWidth: 1.5) }
                            else               { Color.clear }
                        }
                    )

                if dotIDs.isEmpty && !hasEKEvents {
                    Color.clear.frame(height: 5)
                } else {
                    HStack(spacing: 3) {
                        // Apple Calendar event dots (red)
                        if hasEKEvents {
                            Circle()
                                .fill(appleRed.opacity(isSelected ? 0.6 : 1))
                                .frame(width: 5, height: 5)
                        }
                        // App task dots (category color)
                        ForEach(dotIDs.prefix(hasEKEvents ? 2 : 3), id: \.self) { id in
                            Circle()
                                .fill(cachedCategoryColors[id] ?? Color.accentColor)
                                .frame(width: 5, height: 5)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(nil, value: isSelected)
    }

    private var monthDayTaskList: some View {
        let tasks    = tasksForDay(selectedDate)
        let ekEvents = (calSyncStore.allDayEvents(for: selectedDate)
                      + calSyncStore.events(for: selectedDate))
                      .sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }

        return VStack(alignment: .leading, spacing: 0) {
            if tasks.isEmpty && ekEvents.isEmpty {
                HStack {
                    Spacer()
                    Text("No tasks or events")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.vertical, 24)
            } else {
                // Apple Calendar events
                ForEach(ekEvents, id: \.eventIdentifier) { event in
                    monthEKEventRow(event: event)
                    Divider().padding(.leading, 38)
                }
                // App tasks
                ForEach(tasks) { task in
                    monthTaskRow(task: task)
                    if task.id != tasks.last?.id {
                        Divider().padding(.leading, 38)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .padding(.bottom, 120)
    }

    @ViewBuilder
    private func monthEKEventRow(event: EKEvent) -> some View {
        let calColor: Color = event.calendar?.cgColor.map { Color($0) } ?? appleRed
        let isAllDay = event.isAllDay
        let timeString: String = {
            guard !isAllDay, let start = event.startDate else { return "All day" }
            return Self.monthTimeFormatter.string(from: start)
        }()

        HStack(spacing: 12) {
            Circle().fill(calColor).frame(width: 10, height: 10).padding(.leading, 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Event")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.primary)
                Text(isAllDay ? "All day" : timeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            // Tap to switch to day view on that date
            Button {
                if let start = event.startDate {
                    selectedDate = calendar.startOfDay(for: start)
                }
                withAnimation(.easeInOut(duration: 0.22)) { viewMode = .day }
            } label: {
                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private static let monthTimeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    @ViewBuilder
    private func monthTaskRow(task: FocusTask) -> some View {
        let isDone     = isTaskCompletedOnDay(task, day: selectedDate) || (task.recurrenceType == .once && task.status == .completed)
        let catColor   = cachedCategoryColors[task.id] ?? Color.accentColor
        let timeString = task.scheduledTime.map { Self.monthTimeFormatter.string(from: $0) } ?? ""

        HStack(spacing: 12) {
            Circle().fill(catColor).frame(width: 10, height: 10).padding(.leading, 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline.weight(.medium))
                    .strikethrough(isDone)
                    .foregroundColor(isDone ? .secondary : .primary)
                if !timeString.isEmpty {
                    Text(timeString).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if isDone {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.brg).padding(.trailing, 16)
            } else {
                Button {
                    selectedDate = calendar.startOfDay(for: task.scheduledTime ?? selectedDate)
                    withAnimation(.easeInOut(duration: 0.22)) { viewMode = .day }
                } label: {
                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                }
                .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Text(viewMode == .day
                 ? Self.dayFormatter.string(from: selectedDate)
                 : monthYearString(for: displayMonth))
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.leading, 16)

            Spacer(minLength: 8)

            if isSelectedDateToday {
                Text("Today")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(appleRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(appleRed.opacity(0.12)))
                    .fixedSize()
            } else {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        selectedDate = calendar.startOfDay(for: Date())
                        displayMonth = calendar.date(
                            from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.left.circle.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("Today")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(appleRed))
                    .fixedSize()
                }
            }

            Picker("View", selection: $viewMode) {
                Image(systemName: "rectangle.portrait.and.arrow.right").tag(ViewMode.day)
                Image(systemName: "calendar").tag(ViewMode.month)
            }
            .pickerStyle(.segmented)
            .frame(width: 76)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .top))
    }

    // MARK: - Day scroll

    private var dayScroll: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(Array(daysInRange.enumerated()), id: \.offset) { index, day in
                        Button { selectedDate = calendar.startOfDay(for: day) } label: {
                            VStack(spacing: 4) {
                                Text(Self.shortWeekdayFormatter.string(from: day))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)

                                let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                                let isToday    = calendar.isDate(day, inSameDayAs: Date())

                                Text("\(calendar.component(.day, from: day))")
                                    .font(.headline)
                                    .foregroundColor(isSelected ? .white : isToday ? appleRed : .primary)
                                    .frame(width: 32, height: 32)
                                    .background(isSelected ? appleRed : Color.clear)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle().stroke(appleRed, lineWidth: 1.5)
                                            .opacity(isToday && !isSelected ? 1 : 0)
                                    )
                            }
                            .frame(width: itemWidth)
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 60)
            .onAppear {
                DispatchQueue.main.async {
                    scrollToSelected(proxy, animated: false)
                    didInitialScroll = true
                }
            }
            .onChange(of: daysInRange) { _, _ in
                if !didInitialScroll {
                    DispatchQueue.main.async {
                        scrollToSelected(proxy, animated: false)
                        didInitialScroll = true
                    }
                }
            }
            .onChange(of: selectedDate) { _, _ in
                scrollToSelected(proxy, animated: true)
            }
        }
    }

    private func scrollToSelected(_ proxy: ScrollViewProxy, animated: Bool) {
        guard let index = daysInRange.firstIndex(where: {
            calendar.isDate($0, inSameDayAs: selectedDate)
        }) else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(index, anchor: .center) }
        } else {
            proxy.scrollTo(index, anchor: .center)
        }
    }

    private func resetSelection() {
        selectedTask   = nil
        showEditSheet  = false
        showDeleteAlert = false
    }

    private func previousDay() {
        let prev = calendar.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        selectedDate = calendar.startOfDay(for: prev)
    }

    private func nextDay() {
        let next = calendar.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        selectedDate = calendar.startOfDay(for: next)
    }

    private func taskForId(_ id: UUID) -> FocusTask? {
        tasksForSelectedDay.first(where: { $0.id == id })
    }

    private let menuRevealHapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium

    private func normalizedStartDateOnSelectedDay(for task: FocusTask) -> Date? {
        guard let scheduled = task.scheduledTime else { return nil }
        let hour   = calendar.component(.hour,   from: scheduled)
        let minute = calendar.component(.minute, from: scheduled)
        let second = calendar.component(.second, from: scheduled)
        return calendar.date(bySettingHour: hour, minute: minute, second: second, of: selectedDate)
    }

    private func durationSeconds(for task: FocusTask) -> TimeInterval {
        Self.durationSecondsStatic(for: task)
    }
}

// MARK: - TimelineScrollViewConfigurator

struct TimelineScrollViewConfigurator: UIViewRepresentable {
    let disablesVerticalBounce: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let v = UIView(frame: .zero)
        v.isUserInteractionEnabled = false
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard context.coordinator.lastBounceDisabled != disablesVerticalBounce else { return }
        context.coordinator.lastBounceDisabled = disablesVerticalBounce
        DispatchQueue.main.async {
            guard let scrollView = uiView.findBestEnclosingScrollViewForVerticalTimeline() else { return }
            if context.coordinator.observedScrollView !== scrollView {
                context.coordinator.attach(to: scrollView)
            }
            if self.disablesVerticalBounce {
                scrollView.bounces = false
                scrollView.alwaysBounceVertical = false
                scrollView.isScrollEnabled = true
                context.coordinator.isClampingEnabled = true
                context.coordinator.clamp(scrollView)
            } else {
                context.coordinator.isClampingEnabled = false
                scrollView.isScrollEnabled = true
                scrollView.bounces = true
                scrollView.alwaysBounceVertical = false
            }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var observedScrollView: UIScrollView?
        weak var previousDelegate: UIScrollViewDelegate?
        var isClampingEnabled: Bool = false
        var lastBounceDisabled: Bool? = nil

        func attach(to scrollView: UIScrollView) {
            if let old = observedScrollView, old !== scrollView, old.delegate === self {
                old.delegate = previousDelegate
            }
            observedScrollView = scrollView
            previousDelegate = scrollView.delegate
            scrollView.delegate = self
        }

        func clamp(_ scrollView: UIScrollView) {
            let top = -scrollView.adjustedContentInset.top
            let maxOffset = max(top, scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom)
            let clampedY = min(max(scrollView.contentOffset.y, top), maxOffset)
            if abs(scrollView.contentOffset.y - clampedY) > 0.25 {
                scrollView.contentOffset.y = clampedY
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            previousDelegate?.scrollViewDidScroll?(scrollView)
            guard isClampingEnabled else { return }
            clamp(scrollView)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            previousDelegate?.scrollViewWillBeginDragging?(scrollView)
            guard isClampingEnabled else { return }
            clamp(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            previousDelegate?.scrollViewDidEndDragging?(scrollView, willDecelerate: decelerate)
            guard isClampingEnabled else { return }
            clamp(scrollView)
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            previousDelegate?.scrollViewDidEndDecelerating?(scrollView)
            guard isClampingEnabled else { return }
            clamp(scrollView)
        }
    }
}

private extension UIView {
    func findBestEnclosingScrollViewForVerticalTimeline() -> UIScrollView? {
        var candidate: UIScrollView?
        var v: UIView? = self
        while let current = v {
            if let scroll = current as? UIScrollView {
                if candidate == nil { candidate = scroll }
                let isLikelyVertical = scroll.showsVerticalScrollIndicator || (scroll.bounds.height >= scroll.bounds.width)
                if isLikelyVertical { return scroll }
            }
            v = current.superview
        }
        return candidate
    }

    func findEnclosingScrollView() -> UIScrollView? {
        var v: UIView? = self
        while let current = v {
            if let scroll = current as? UIScrollView { return scroll }
            v = current.superview
        }
        return nil
    }
}

// MARK: - Task action menu

struct TaskActionMenuLayout {
    let menuWidth: CGFloat
    let menuHeight: CGFloat
    let x: CGFloat
    let y: CGFloat

    init(
        anchorFrameInViewport: CGRect,
        viewportSize: CGSize,
        rowHeight: CGFloat,
        horizontalPadding: CGFloat,
        verticalGapFromAnchor: CGFloat
    ) {
        self.menuWidth = min(140, viewportSize.width - 24)
        self.menuHeight = rowHeight * 2 + 1
        let screenMargin: CGFloat = 10
        let cardCenterX = anchorFrameInViewport.midX
        let menuX = cardCenterX - (menuWidth / 2)
        self.x = max(screenMargin, min(menuX, viewportSize.width - menuWidth - screenMargin))
        let minMargin: CGFloat = 8
        let fixedGap: CGFloat = 6
        let spaceAbove = anchorFrameInViewport.minY - minMargin
        let spaceBelow = viewportSize.height - anchorFrameInViewport.maxY - minMargin
        let needed = menuHeight + fixedGap
        let canGoBelow = spaceBelow >= needed
        let canGoAbove = spaceAbove >= needed
        let placeBelow: Bool
        if canGoBelow && canGoAbove { placeBelow = spaceBelow >= spaceAbove }
        else if canGoBelow { placeBelow = true }
        else if canGoAbove { placeBelow = false }
        else { placeBelow = spaceBelow >= spaceAbove }
        let rawY: CGFloat
        if placeBelow { rawY = anchorFrameInViewport.maxY + fixedGap }
        else { rawY = anchorFrameInViewport.minY - menuHeight - fixedGap }
        let minY = minMargin
        let maxY = viewportSize.height - menuHeight - minMargin
        self.y = max(minY, min(rawY, maxY))
    }
}

struct TaskActionMenuContainer: View {
    let cornerRadius: CGFloat
    let content: AnyView
    var body: some View {
        content
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(LinearGradient(gradient: Gradient(colors: [Color.white.opacity(0.50), Color.white.opacity(0.12), Color.black.opacity(0.10)]), startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.8))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
            .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
            .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 10)
    }
}

struct TaskActionMenuPanel: View {
    let cornerRadius: CGFloat
    let rowHeight: CGFloat
    let onEdit: () -> Void
    let onDelete: () -> Void
    private var innerCornerRadius: CGFloat { max(10, cornerRadius - 4) }
    var body: some View {
        TaskActionMenuContainer(cornerRadius: cornerRadius, content: AnyView(
            VStack(spacing: 6) {
                TaskActionGlassButton(title: "Edit", systemImage: "pencil", isDestructive: false, cornerRadius: innerCornerRadius, action: onEdit)
                TaskActionGlassButton(title: "Delete", systemImage: "trash", isDestructive: true, cornerRadius: innerCornerRadius, action: onDelete)
            }.padding(6)
        ))
    }
}

struct TaskActionMenu: View {
    let anchorFrameInViewport: CGRect
    let viewportSize: CGSize
    let growthScale: CGFloat
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onDismiss: () -> Void
    private let rowHeight: CGFloat = 34
    private let cornerRadius: CGFloat = 16
    private let horizontalPadding: CGFloat = 10
    private let verticalGapFromAnchor: CGFloat = 6
    private var layout: TaskActionMenuLayout {
        TaskActionMenuLayout(anchorFrameInViewport: anchorFrameInViewport, viewportSize: viewportSize, rowHeight: rowHeight, horizontalPadding: horizontalPadding, verticalGapFromAnchor: verticalGapFromAnchor)
    }
    var body: some View {
        let layout = self.layout
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.001).frame(width: viewportSize.width, height: viewportSize.height).contentShape(Rectangle()).onTapGesture(perform: onDismiss)
            TaskActionMenuPanel(cornerRadius: cornerRadius, rowHeight: rowHeight, onEdit: onEdit, onDelete: onDelete)
                .frame(width: layout.menuWidth)
                .position(x: layout.x + layout.menuWidth / 2, y: layout.y + layout.menuHeight / 2)
                .scaleEffect(0.1 + (growthScale * 0.9), anchor: .center)
                .opacity(growthScale)
        }
        .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity.combined(with: .scale(scale: 0.95))))
        .animation(.easeOut(duration: 0.22), value: anchorFrameInViewport)
    }
}

struct TaskActionGlassButton: View {
    let title: String
    let systemImage: String
    let isDestructive: Bool
    let cornerRadius: CGFloat
    let action: () -> Void
    @State private var isPressed: Bool = false
    private let rowHeight: CGFloat = 34
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage).font(.system(size: 16, weight: .semibold)).frame(width: 18)
                Text(title).font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 0)
            }
            .frame(height: rowHeight)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isDestructive ? Color.red : Color.primary)
        .background(Color(.systemBackground).opacity(0.5))
        .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.5))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .opacity(isPressed ? 0.8 : 1.0)
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeOut(duration: 0.12), value: isPressed)
        .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in if !isPressed { isPressed = true } }.onEnded { _ in isPressed = false })
    }
}

struct TaskActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.08)).shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 2).shadow(color: .white.opacity(0.05), radius: 1, x: 0, y: -1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TaskActionGlassButtonStyleModifier: ViewModifier {
    let cornerRadius: CGFloat
    @Binding var isPressed: Bool
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
    func body(content: Content) -> some View {
        content
            .overlay(shape.stroke(Color.white.opacity(0.09), lineWidth: 0.8))
            .clipShape(shape)
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 4)
            .shadow(color: .white.opacity(0.05), radius: 1, x: 0, y: -1)
            .scaleEffect(isPressed ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: isPressed)
            .simultaneousGesture(DragGesture(minimumDistance: 0).onChanged { _ in if !isPressed { isPressed = true } }.onEnded { _ in isPressed = false })
    }
}

struct TaskActionGlassButtonBackground: View {
    let cornerRadius: CGFloat
    let isPressed: Bool
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
    var body: some View {
        shape.fill(.ultraThinMaterial).opacity(0.62)
            .overlay { TaskActionGlassButtonBevelOverlay(shape: shape) }
            .overlay { shape.fill(Color.white.opacity(isPressed ? 0.12 : 0)) }
    }
}

struct TaskActionGlassButtonBevelOverlay<S: InsettableShape>: View {
    let shape: S
    var body: some View {
        shape.stroke(Color.white.opacity(0.14), lineWidth: 1.05).blur(radius: 0.28).offset(y: -0.55).mask(shape)
            .overlay { shape.stroke(Color.black.opacity(0.12), lineWidth: 1.10).blur(radius: 0.85).offset(y: 0.85).mask(shape) }
            .overlay { shape.inset(by: 1.0).stroke(Color.white.opacity(0.06), lineWidth: 0.85).blur(radius: 0.20).offset(y: -0.30).mask(shape) }
            .overlay { shape.inset(by: 1.35).stroke(Color.black.opacity(0.08), lineWidth: 0.95).blur(radius: 0.80).offset(y: 0.70).mask(shape) }
    }
}

struct TaskActionMenuGlassBackground: View {
    let cornerRadius: CGFloat
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: .continuous) }
    var body: some View {
        shape.fill(.ultraThinMaterial).opacity(0.72)
            .overlay { TaskActionGlassBevelOverlay(shape: shape) }
            .overlay { shape.inset(by: 1.2).stroke(Color.white.opacity(0.08), lineWidth: 0.9).blur(radius: 0.25).offset(y: -0.4).mask(shape) }
            .overlay { shape.inset(by: 1.6).stroke(Color.black.opacity(0.10), lineWidth: 1.0).blur(radius: 0.9).offset(y: 0.9).mask(shape) }
    }
}

struct TaskActionGlassBevelOverlay<S: InsettableShape>: View {
    let shape: S
    var body: some View {
        shape.stroke(Color.white.opacity(0.22), lineWidth: 1.2).blur(radius: 0.32).offset(y: -0.78).mask(shape)
            .overlay { shape.stroke(Color.black.opacity(0.20), lineWidth: 1.3).blur(radius: 0.98).offset(y: 1.25).mask(shape) }
            .overlay { shape.inset(by: 1.0).stroke(Color.white.opacity(0.11), lineWidth: 0.9).blur(radius: 0.24).offset(y: -0.50).mask(shape) }
            .overlay { shape.inset(by: 1.4).stroke(Color.black.opacity(0.13), lineWidth: 1.0).blur(radius: 0.95).offset(y: 1.0).mask(shape) }
    }
}
