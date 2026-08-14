import SwiftUI
import EventKit

// MARK: - CalendarTimelineView
// Self-contained timeline component. Owns all zoom state, task-interaction state,
// layout caches and rendering so that pinch-zoom only invalidates this subtree —
// NOT the entire CalendarView body.

struct CalendarTimelineView: View {

    // ── Inputs (stable; change only when day/task-data changes, not on every zoom tick) ──
    let items:              [CalendarTimelineItem]
    let taskLayouts:        [UUID: CalendarTaskLayoutInfo]
    let categoryColors:     [UUID: Color]
    let appleCalendarEvents:[EKEvent]
    let selectedDate:       Date
    let isSelectedDateToday:Bool
    let onDaySwipe:         (Int) -> Void    // +1 = next day, -1 = previous day
    let onCompletionCheck:  (FocusTask, Date) -> Bool  // is task done on day?

    // ── Callbacks to parent for sheet presentation ──
    let onEdit:   (FocusTask) -> Void
    let onDelete: (FocusTask) -> Void

    // ── Constants ──
    private let timelineStartHour   = 5
    private let timelineEndHour     = 24
    private var timelineHourIntervals: Int { timelineEndHour - timelineStartHour }

    private let maxHourHeight:          CGFloat = 120
    private let fallbackMinHourHeight:  CGFloat = 48
    private let absoluteMinHourHeight:  CGFloat = 18
    private let timelineContentTopPadding:    CGFloat = 12
    private let timelineContentBottomGuard:   CGFloat = 2
    private let hourGutterWidth:        CGFloat = 56
    private let interColumnSpacing:     CGFloat = 1

    private let appleRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    private let calendar = Calendar.current

    // ── Zoom state — owned here so pinch doesn't invalidate CalendarView ──
    @State private var hourHeight:             CGFloat = 76
    @State private var hourHeightAtPinchStart: CGFloat = 76
    @State private var timelineViewportHeight: CGFloat = 0
    @State private var timelineBottomInset:    CGFloat = 0
    @State private var viewportGlobalFrame:    CGRect  = .zero
    @State private var laneGlobalFrame:        CGRect  = .zero

    // ── Task-interaction state ──
    @State private var pressedTaskID:          UUID?   = nil
    @State private var previewTaskID:          UUID?   = nil
    @State private var previewCardGrowthScale: CGFloat = 0.0
    @State private var pressedTaskRectInLane:  CGRect  = .zero
    @State private var measuredTaskTileWidths: [UUID: CGFloat] = [:]
    @State private var measuredPreviewCardWidths: [UUID: CGFloat] = [:]
    @State private var showEKEventDetail:      Bool    = false
    @State private var selectedEKEvent:        EKEvent? = nil

    // ── Layout caches ──
    @State private var cachedPackedWidths:   [Int: [CGFloat]] = [:]
    @State private var cachedPackedOffsets:  [Int: [CGFloat]] = [:]
    @State private var cachedLayoutHH:       CGFloat = -1
    @State private var cachedLayoutLW:       CGFloat = -1

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            timelineScrollView
            overlayLayer
        }
        .sheet(isPresented: $showEKEventDetail) {
            if let ev = selectedEKEvent { EKEventDetailSheet(event: ev) }
        }
    }

    // MARK: - Zoom helpers

    private var effectiveBottomInset: CGFloat { min(max(timelineBottomInset, 0), 22) + 4 }

    private func adaptiveMinHourHeight() -> CGFloat {
        guard timelineViewportHeight > 0 else { return fallbackMinHourHeight }
        let usable = max(0, timelineViewportHeight - effectiveBottomInset
                        - timelineContentTopPadding - timelineContentBottomGuard)
        let raw    = usable / CGFloat(max(1, timelineHourIntervals))
        let scale  = CalendarView.cachedScreenScale
        let aligned = floor(raw * scale) / scale
        return min(maxHourHeight, max(absoluteMinHourHeight, aligned))
    }

    private func clamped(_ proposed: CGFloat) -> CGFloat {
        let minH = timelineViewportHeight > 0 ? adaptiveMinHourHeight() : fallbackMinHourHeight
        return min(max(minH, proposed), maxHourHeight)
    }

    private var isAtMinZoom: Bool {
        guard timelineViewportHeight > 0 else { return false }
        return abs(hourHeight - adaptiveMinHourHeight()) <= 0.25
    }

    // MARK: - Offset helpers

    private func yOffset(for date: Date) -> CGFloat {
        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let seconds = Double(c.hour ?? 0) * 3600
                    + Double(c.minute ?? 0) * 60
                    + Double(c.second ?? 0)
                    + Double(c.nanosecond ?? 0) / 1_000_000_000
        let start   = Double(timelineStartHour) * 3600
        let end     = Double(timelineEndHour)   * 3600
        let cl      = min(max(seconds, start), max(start, end - 0.001))
        return CGFloat((cl - start) / 3600.0) * hourHeight
    }

    private func taskHeight(duration: TimeInterval) -> CGFloat {
        max(hourHeight * 0.35, CGFloat(duration / 3600.0) * hourHeight)
    }

    private func isNowVisible(_ now: Date) -> Bool {
        let h = calendar.component(.hour, from: now)
        return h >= timelineStartHour && h < timelineEndHour
    }

    // MARK: - Layout cache rebuild (horizontal columns only — no vertical push)

    private func rebuildLayoutCaches(laneWidth: CGFloat) {
        guard laneWidth > 0 else { return }
        let hh = hourHeight
        let lw = laneWidth
        guard hh != cachedLayoutHH || lw != cachedLayoutLW else { return }

        let colCounts = Set(items.compactMap { taskLayouts[$0.id]?.columnCount })
        var pw = [Int: [CGFloat]]()
        var po = [Int: [CGFloat]]()
        for cols in colCounts {
            guard cols > 0 else { continue }
            let spacing = interColumnSpacing
            let usable  = max(lw - CGFloat(cols - 1) * spacing, 0)
            let colW    = max(usable / CGFloat(cols), 0)
            pw[cols] = Array(repeating: colW, count: cols)
            po[cols] = (0..<cols).map { CGFloat($0) * (colW + spacing) }
        }
        cachedPackedWidths  = pw
        cachedPackedOffsets = po
        cachedLayoutHH = hh
        cachedLayoutLW = lw
    }

    // MARK: - Timeline scroll view

    private var timelineScrollView: some View {
        let baseH    = CGFloat(timelineHourIntervals) * hourHeight
        let contentH: CGFloat = {
            guard isAtMinZoom, timelineViewportHeight > 0 else { return baseH }
            let pad = timelineContentTopPadding + effectiveBottomInset
            return min(baseH, max(0, timelineViewportHeight - pad))
        }()

        return ScrollView(.vertical, showsIndicators: false) {
            HStack(spacing: 0) {
                hourGutter
                    .frame(width: hourGutterWidth)
                timelineLane(contentHeight: contentH)
                    .frame(maxWidth: .infinity, minHeight: contentH, alignment: .topLeading)
                    .overlay {
                        GeometryReader { g in
                            Color.clear.preference(key: TLLaneFrameKey.self,
                                                   value: g.frame(in: .global))
                        }
                        .allowsHitTesting(false)
                    }
            }
            .padding(.top, timelineContentTopPadding)
            .padding(.bottom, effectiveBottomInset)
            .frame(maxWidth: .infinity, minHeight: contentH, alignment: .topLeading)
        }
        .scrollBounceBehavior(isAtMinZoom ? .basedOnSize : .automatic)
        .background {
            GeometryReader { g in
                Color.clear
                    .onAppear      { applyViewport(g) }
                    .onChange(of: g.frame(in: .global)) { _, _ in applyViewport(g) }
                    .onChange(of: g.size)               { _, _ in applyViewport(g) }
            }
        }
        .safeAreaInset(edge: .bottom) {
            GeometryReader { g in
                Color.clear
                    .onAppear { applyBottomInset(g.safeAreaInsets.bottom) }
                    .onChange(of: g.safeAreaInsets.bottom) { _, v in applyBottomInset(v) }
            }
            .frame(height: 0)
        }
        .onPreferenceChange(TLLaneFrameKey.self) { laneGlobalFrame = $0 }
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { scale in hourHeight = clamped(hourHeightAtPinchStart * scale) }
                .onEnded   { _ in hourHeightAtPinchStart = hourHeight }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onEnded { v in
                    let h = abs(v.translation.width), vv = abs(v.translation.height)
                    guard h > vv * 2.5, h > 50 else { return }
                    onDaySwipe(v.translation.width < 0 ? 1 : -1)
                }
        )
    }

    private func applyViewport(_ g: GeometryProxy) {
        viewportGlobalFrame    = g.frame(in: .global)
        timelineViewportHeight = g.size.height
        hourHeight             = clamped(hourHeight)
        hourHeightAtPinchStart = hourHeight
    }

    private func applyBottomInset(_ value: CGFloat) {
        timelineBottomInset    = value
        hourHeight             = clamped(hourHeight)
        hourHeightAtPinchStart = hourHeight
    }

    // MARK: - Hour gutter (Canvas)

    private var hourGutter: some View {
        let intervals = timelineHourIntervals
        let rowH      = hourHeight
        let start     = timelineStartHour
        let totalH    = CGFloat(intervals + 1) * rowH
        let scale     = CalendarView.cachedScreenScale

        return Canvas { ctx, size in
            for i in 0...(intervals) {
                let hour  = (start + i) % 24
                let y     = CGFloat(i) * rowH + rowH * 0.5
                let label = String(format: "%02d", hour)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11),
                    .foregroundColor: UIColor.secondaryLabel
                ]
                let str = NSAttributedString(string: label, attributes: attrs)
                let sz  = str.size()
                ctx.withCGContext { cg in
                    UIGraphicsPushContext(cg)
                    str.draw(at: CGPoint(x: 36 - sz.width - 4, y: y - sz.height / 2))
                    UIGraphicsPopContext()
                    cg.setStrokeColor(UIColor.separator.withAlphaComponent(0.10).cgColor)
                    cg.setLineWidth(1.0 / scale)
                    cg.move(to: CGPoint(x: 40, y: y))
                    cg.addLine(to: CGPoint(x: size.width, y: y))
                    cg.strokePath()
                }
            }
        }
        .frame(height: totalH)
    }

    // MARK: - Grid background (Canvas)

    private func gridBackground(width: CGFloat, height: CGFloat) -> some View {
        let intervals = timelineHourIntervals
        let rowH      = hourHeight
        let scale     = CalendarView.cachedScreenScale
        return Canvas { ctx, _ in
            ctx.withCGContext { cg in
                let line = 1.0 / scale
                cg.setLineWidth(line)
                cg.setStrokeColor(UIColor.separator.withAlphaComponent(0.15).cgColor)
                for i in 0...intervals {
                    let y = CGFloat(i) * rowH
                    cg.move(to: CGPoint(x: 0, y: y)); cg.addLine(to: CGPoint(x: width, y: y))
                }
                cg.strokePath()
                cg.setStrokeColor(UIColor.separator.withAlphaComponent(0.08).cgColor)
                for i in 0..<intervals {
                    let y = (CGFloat(i) + 0.5) * rowH
                    cg.move(to: CGPoint(x: 0, y: y)); cg.addLine(to: CGPoint(x: width, y: y))
                }
                cg.strokePath()
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }

    // MARK: - Timeline lane

    private func timelineLane(contentHeight: CGFloat) -> some View {
        let h = CGFloat(timelineHourIntervals) * hourHeight
        return Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: h)
            .background {
                GeometryReader { g in
                    let w = max(g.size.width, 0)
                    ZStack(alignment: .topLeading) {
                        gridBackground(width: w, height: h)
                        taskLayer(laneWidth: w, timelineHeight: h)
                    }
                    .onAppear { rebuildLayoutCaches(laneWidth: w) }
                    .onChange(of: g.size.width) { _, nw in rebuildLayoutCaches(laneWidth: nw) }
                    .onChange(of: hourHeight)    { _, _  in rebuildLayoutCaches(laneWidth: w)  }
                    .onChange(of: items.count)   { _, _  in rebuildLayoutCaches(laneWidth: w)  }
                }
            }
    }

    // MARK: - Task layer

    @ViewBuilder
    private func taskLayer(laneWidth: CGFloat, timelineHeight: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Now-line
            if isSelectedDateToday {
                TimelineView(.periodic(from: Date(), by: 30)) { ctx in
                    let now = ctx.date
                    if isNowVisible(now) {
                        nowLine(laneWidth: laneWidth, now: now)
                    }
                }
            }

            // Apple Calendar events
            ForEach(appleCalendarEvents, id: \.eventIdentifier) { event in
                if let start = event.startDate, let end = event.endDate {
                    let dayStart   = calendar.startOfDay(for: selectedDate)
                    let tlStart    = dayStart.addingTimeInterval(TimeInterval(timelineStartHour * 3600))
                    let tlEnd      = dayStart.addingTimeInterval(TimeInterval(timelineEndHour   * 3600))
                    let cs = max(start, tlStart); let ce = min(end, tlEnd)
                    if ce > cs {
                        let yTop  = yOffset(for: cs)
                        let yBot  = yOffset(for: ce)
                        let blockH = max(yBot - yTop, 28)
                        let color: Color = event.calendar?.cgColor.map { Color($0) } ?? .accentColor
                        AppleCalendarEventTile(
                            title: event.title ?? "",
                            start: start, end: end,
                            calendarColor: color,
                            width: laneWidth, height: blockH)
                        .position(x: laneWidth / 2, y: yTop + blockH / 2)
                        .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            selectedEKEvent = event; showEKEventDetail = true
                        })
                        .zIndex(-1)
                    }
                }
            }

            // Task tiles
            ForEach(items, id: \.id) { item in
                taskTile(item: item, laneWidth: laneWidth)
            }
        }
        .frame(width: laneWidth, height: timelineHeight)
    }

    @ViewBuilder
    private func nowLine(laneWidth: CGFloat, now: Date) -> some View {
        let y = yOffset(for: now)
        ZStack(alignment: .leading) {
            Rectangle().fill(appleRed).frame(height: 1).frame(maxWidth: .infinity)
            Text(now, style: .time)
                .font(.caption2.weight(.semibold)).foregroundColor(appleRed)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.9)))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(appleRed.opacity(0.35), lineWidth: 1))
                .offset(x: 6, y: -14)
        }
        .frame(width: laneWidth, height: 1)
        .position(x: laneWidth / 2, y: y)
        .allowsHitTesting(false)
    }

    // MARK: - Task tile

    @ViewBuilder
    private func taskTile(item: CalendarTimelineItem, laneWidth: CGFloat) -> some View {
        let layout = taskLayouts[item.id] ?? CalendarTaskLayoutInfo(columnIndex: 0, columnCount: 1)
        let cols   = max(layout.columnCount, 1)
        let col    = min(max(layout.columnIndex, 0), cols - 1)

        let colW   = cachedPackedWidths[cols]?[safe: col]
                     ?? max((laneWidth - CGFloat(cols - 1) * interColumnSpacing) / CGFloat(cols), 0)
        let xLeft  = cachedPackedOffsets[cols]?[safe: col]
                     ?? CGFloat(col) * (colW + interColumnSpacing)

        let baseY  = yOffset(for: item.startTime)
        let baseH  = taskHeight(duration: item.duration)

        let isPreviewing   = previewTaskID == item.id
        let isBackgrounded = previewTaskID != nil && previewTaskID != item.id
        let zVal           = Double(baseY) * 1000 + Double(col) + (isPreviewing ? 1_000_000 : 0)

        CalendarTaskRow(
            task: item.task,
            maxAllowedWidth: colW,
            displayTime: item.startTime,
            categoryColor: categoryColors[item.id],
            onMeasuredWidth: { w in
                if w > (measuredTaskTileWidths[item.id] ?? 0) { measuredTaskTileWidths[item.id] = w }
            }
        )
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        .frame(width: colW, alignment: .topLeading)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.32, maximumDistance: 20).onEnded { _ in
            guard pressedTaskID == nil else { return }
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            pressedTaskID         = item.id
            previewTaskID         = item.id
            pressedTaskRectInLane = CGRect(x: xLeft, y: baseY, width: colW, height: baseH)
            previewCardGrowthScale = 0.0
            withAnimation(.interactiveSpring(response: 0.5, dampingFraction: 0.78)) {
                previewCardGrowthScale = 1.0
            }
        })
        .opacity(isPreviewing ? 0 : (isBackgrounded ? 0.55 : 1))
        .blur(radius: isBackgrounded ? 1.2 : 0)
        .offset(x: xLeft, y: baseY)
        .zIndex(zVal)
        .animation(.easeInOut(duration: 0.14), value: isBackgrounded)
    }

    // MARK: - Preview overlay

    private var overlayLayer: some View {
        GeometryReader { geo in
            let overlayGlobal = geo.frame(in: .global)
            ZStack {
                if let id = previewTaskID,
                   let item = items.first(where: { $0.id == id }),
                   !pressedTaskRectInLane.isEmpty {
                    let pf    = previewFrame(overlayGlobal: overlayGlobal)
                    let taskCX = laneGlobalFrame.minX + pressedTaskRectInLane.midX - overlayGlobal.minX
                    let taskCY = laneGlobalFrame.minY + pressedTaskRectInLane.midY - overlayGlobal.minY
                    let cx = taskCX + (pf.centerXLocal - taskCX) * previewCardGrowthScale
                    let cy = taskCY + (pf.centerYLocal - taskCY) * previewCardGrowthScale
                    CalendarTaskPreviewCard(
                        task: item.task,
                        start: item.startTime, end: item.endTime,
                        maxAllowedWidth: pf.maxWidth, maxAllowedHeight: pf.maxHeight,
                        isCompletedOnDay: onCompletionCheck(item.task, selectedDate),
                        onMeasuredWidth: { _ in })
                    .shadow(color: .black.opacity(0.12), radius: 12, x: 0, y: 6)
                    .position(x: cx, y: cy)
                    .scaleEffect(0.1 + previewCardGrowthScale * 0.9)
                    .opacity(previewCardGrowthScale)
                    .zIndex(99_999)
                }
                if let id = pressedTaskID, previewTaskID == id,
                   !pressedTaskRectInLane.isEmpty,
                   let item = items.first(where: { $0.id == id }) {
                    let pf = previewFrame(overlayGlobal: overlayGlobal)
                    let mw = measuredPreviewCardWidths[id] ?? pf.maxWidth
                    let cardRect = CGRect(
                        x: pf.centerXLocal - mw / 2,
                        y: pf.centerYLocal - pf.maxHeight / 2,
                        width: mw, height: pf.maxHeight)
                    TaskActionMenu(
                        anchorFrameInViewport: cardRect,
                        viewportSize: geo.size,
                        growthScale: previewCardGrowthScale,
                        onEdit:    { dismiss(); onEdit(item.task) },
                        onDelete:  { dismiss(); onDelete(item.task) },
                        onDismiss: { dismiss() }
                    )
                    .zIndex(100_000)
                }
            }
        }
    }

    private func dismiss() {
        withAnimation(.easeOut(duration: 0.15)) { previewCardGrowthScale = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            pressedTaskID = nil; previewTaskID = nil
            pressedTaskRectInLane = .zero
        }
    }

    private struct PF {
        let maxWidth: CGFloat; let maxHeight: CGFloat
        let centerXLocal: CGFloat; let centerYLocal: CGFloat
    }

    private func previewFrame(overlayGlobal: CGRect) -> PF {
        let margin: CGFloat = 16
        let maxW   = max(0, viewportGlobalFrame.width - margin * 2)
        let maxH: CGFloat = 220
        let taskGCX = laneGlobalFrame.minX + pressedTaskRectInLane.midX
        let halfW   = maxW / 2
        let cx      = min(max(taskGCX, viewportGlobalFrame.minX + margin + halfW),
                          viewportGlobalFrame.maxX - margin - halfW) - overlayGlobal.minX
        let taskGBot   = laneGlobalFrame.minY + pressedTaskRectInLane.maxY
        let spaceBelow = viewportGlobalFrame.maxY - taskGBot
        let topGlobal: CGFloat
        if spaceBelow >= maxH + 8 { topGlobal = taskGBot }
        else { topGlobal = (laneGlobalFrame.minY + pressedTaskRectInLane.minY) - maxH }
        let cy = min(max(topGlobal, viewportGlobalFrame.minY + 40),
                     viewportGlobalFrame.maxY - maxH - 40) + maxH / 2 - overlayGlobal.minY
        return PF(maxWidth: maxW, maxHeight: maxH, centerXLocal: cx, centerYLocal: cy)
    }
}

// MARK: - Supporting types

/// Flattened data model for a single task occurrence on the timeline.
struct CalendarTimelineItem: Identifiable {
    let id:        UUID    // == task.id
    let task:      FocusTask
    let startTime: Date
    let endTime:   Date
    var duration:  TimeInterval { endTime.timeIntervalSince(startTime) }
}

/// Column-layout result from the greedy overlap algorithm.
struct CalendarTaskLayoutInfo: Hashable {
    let columnIndex: Int
    let columnCount: Int
}

// MARK: - Preference key

private struct TLLaneFrameKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let n = nextValue(); if n != .zero { value = n }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
