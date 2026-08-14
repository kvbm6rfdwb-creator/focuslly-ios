import SwiftUI

// Extracted, reusable content-fit task row and preview card used by CalendarView.
// Keeping it isolated avoids SwiftUI result-builder edge cases inside CalendarView.swift.

// MARK: - Sizing preferences

struct CalendarPreviewContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

struct CalendarTaskRowContentSizePreferenceKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

// MARK: - Preview card

struct CalendarTaskPreviewCard: View {
    let task: FocusTask
    let start: Date
    let end: Date
    let maxAllowedWidth: CGFloat
    let maxAllowedHeight: CGFloat
    /// Whether this task has a completed session on the currently displayed day
    /// (used for recurring tasks — avoids reading task.status which is global).
    var isCompletedOnDay: Bool = false
    var onMeasuredWidth: ((CGFloat) -> Void)? = nil

    @State private var measuredSize: CGSize = .zero

    private func durationText() -> String {
        let seconds = max(0, Int(end.timeIntervalSince(start)))
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min" }
        let h = minutes / 60; let m = minutes % 60
        return m == 0 ? "\(h) h" : "\(h) h \(m) min"
    }

    private func recurrenceText() -> String {
        switch task.recurrenceType {
        case .once: return "Once"
        case .daily: return "Daily"
        case .weekdays: return "Weekdays"
        case .custom: return "Custom"
        }
    }

    private var category: TaskCategory? {
        TaskCategoryStore.shared.category(for: task.id)
    }

    private var categoryText: String {
        category?.title ?? "—"
    }

    /// Number of completed sessions ever logged for this task — no Mirror, no reflection
    private var sessionCountText: String {
        // TaskStore is not injected here; use TaskStoreLocator if available, else "—"
        guard let store = TaskStoreLocator.shared.store else { return "—" }
        let count = store.sessionLogs.filter {
            $0.taskId == task.id && $0.exitReason == .completed
        }.count
        return count > 0 ? "\(count) session\(count == 1 ? "" : "s")" : "None yet"
    }

    private let appleGreen = Color(red: 0.20, green: 0.78, blue: 0.35)

    var body: some View {
        let safeAllowedW = max(0, maxAllowedWidth)
        let safeAllowedH = max(0, maxAllowedHeight)
        let intrinsicW   = measuredSize.width
        let targetWidth: CGFloat = (intrinsicW > 0) ? min(intrinsicW, safeAllowedW) : safeAllowedW
        let catColor     = category?.color ?? Color.accentColor

        ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                // Category colour bar on the left edge
                Rectangle()
                    .fill(catColor)
                    .frame(width: 4)
                    .clipShape(RoundedRectangle(cornerRadius: 2))
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 10) {
                    // Title
                    Text(task.title)
                        .font(.headline.weight(.bold))
                        .lineLimit(2)

                    // Time row
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(catColor)
                        Text(start, style: .time)
                            .font(.subheadline.weight(.semibold))
                        Text("–").foregroundColor(.secondary)
                        Text(end, style: .time)
                            .font(.subheadline.weight(.semibold))
                        Spacer(minLength: 0)
                        Text(durationText())
                            .font(.caption.weight(.semibold))
                            .foregroundColor(catColor)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(catColor.opacity(0.1))
                            .cornerRadius(6)
                    }

                    Divider().opacity(0.15).padding(.vertical, 3)

                    VStack(alignment: .leading, spacing: 11) {
                        CalendarPreviewMetaRow(label: "Category",   value: categoryText)
                        CalendarPreviewMetaRow(label: "Recurrence", value: recurrenceText())
                        CalendarPreviewMetaRow(label: "Sessions",   value: sessionCountText)
                    }
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Checkmark badge — uses per-occurrence completion for recurring tasks
            if isCompletedOnDay || (task.recurrenceType == .once && task.status == .completed) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(appleGreen)
                    .padding(10)
                    .background(Color(.systemBackground).opacity(0.95))
                    .clipShape(Circle())
                    .offset(x: 12, y: -12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.50),
                            Color.white.opacity(0.12),
                            Color.black.opacity(0.10)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 2, x: 0, y: 1)
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
        .shadow(color: .black.opacity(0.10), radius: 20, x: 0, y: 10)
        .background {
            GeometryReader { g in
                Color.clear
                    .preference(key: CalendarPreviewContentSizePreferenceKey.self, value: g.size)
            }
        }
        .onPreferenceChange(CalendarPreviewContentSizePreferenceKey.self) {
            measuredSize = $0
            if $0.width > 0 {
                onMeasuredWidth?($0.width)
            }
        }
        // Prefer intrinsic width and height; clamp to viewport-provided max with scrolling support
        .fixedSize(horizontal: true, vertical: true)
        .frame(maxWidth: targetWidth, maxHeight: safeAllowedH > 0 ? safeAllowedH : nil, alignment: .topLeading)
    }
}

struct CalendarPreviewMetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            // Label with refined styling
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .frame(width: 72, alignment: .leading)
                .opacity(0.75)
            
            // Value with premium appearance
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .tracking(0.2)
            
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Task row

struct CalendarTaskRow: View {
    let task: FocusTask
    let maxAllowedWidth: CGFloat
    let displayTime: Date?
    /// Pre-resolved category color — pass from cached map to avoid per-render store lookup.
    var categoryColor: Color? = nil
    var onMeasuredWidth: ((CGFloat) -> Void)? = nil
    var onMeasuredHeight: ((CGFloat) -> Void)? = nil

    @State private var measuredSize: CGSize = .zero

    private static let taskTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }()

    private let appleGreen = Color(red: 0.20, green: 0.78, blue: 0.35)

    var body: some View {
        let paddingH: CGFloat = 8
        let paddingV: CGFloat = 9
        let catColor = categoryColor ?? TaskCategoryStore.shared.category(for: task.id)?.color ?? Color.clear

        ZStack(alignment: .topLeading) {
            HStack(spacing: 0) {
                // Category colour bar — 3px left edge accent
                Rectangle()
                    .fill(catColor)
                    .frame(width: 3)
                    .padding(.vertical, 4)
                    .padding(.leading, 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(2)
                        if task.status == .completed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(appleGreen)
                        }
                    }
                    if let time = (displayTime ?? task.scheduledTime) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text(Self.taskTimeFormatter.string(from: time))
                                .font(.caption2.weight(.medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                        }
                    }
                }
                .padding(.horizontal, paddingH)
                .padding(.vertical, paddingV)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        // Measure the fully styled row using fixedSize to get intrinsic size
        .fixedSize(horizontal: true, vertical: true)
        .background {
            GeometryReader { g in
                Color.clear
                    .preference(key: CalendarTaskRowContentSizePreferenceKey.self, value: g.size)
            }
        }
        .onPreferenceChange(CalendarTaskRowContentSizePreferenceKey.self) {
            measuredSize = $0
            if $0.width > 0 {
                onMeasuredWidth?($0.width)
            }
            if $0.height > 0 {
                onMeasuredHeight?($0.height)
            }
        }
        // Apply shadow after sizing
        .shadow(color: .black.opacity(0.04), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
        // Keep a stable hit target within the assigned overlap column
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Apple Calendar Event Tile

/// Matches CalendarTaskRow's visual design exactly.
/// Only differentiator: a small coloured dot + calendar glyph in the top-right corner.
struct AppleCalendarEventTile: View {

    let title: String
    let start: Date
    let end: Date
    let calendarColor: Color
    let width: CGFloat
    let height: CGFloat

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    var body: some View {
        let paddingH: CGFloat = 8
        let paddingV: CGFloat = 9

        ZStack(alignment: .topLeading) {
            // ── Same card background as CalendarTaskRow ────────────────
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground).opacity(0.92))

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)

            // ── Content ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                // Title row — same font as app tasks
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                // Time row — identical to app task clock row
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                    Text("\(Self.timeFormatter.string(from: start)) – \(Self.timeFormatter.string(from: end))")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, paddingH)
            .padding(.vertical, paddingV)
            // Leave room on the right for the indicator dot
            .padding(.trailing, 20)

            // ── Apple Calendar indicator — top-right corner ────────────
            VStack(spacing: 2) {
                // Coloured dot = calendar colour (blue/green/red etc.)
                Circle()
                    .fill(calendarColor)
                    .frame(width: 8, height: 8)
                // Tiny calendar glyph beneath the dot
                Image(systemName: "calendar")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(calendarColor.opacity(0.7))
            }
            .padding(.top, paddingV)
            .padding(.trailing, paddingH)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: width, height: height)
        .shadow(color: .black.opacity(0.04), radius: 1.5, y: 1)
        .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Apple Calendar event detail sheet

import EventKit

struct EKEventDetailSheet: View {
    let event: EKEvent

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short; return f
    }()
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .full; f.timeStyle = .none; return f
    }()

    @Environment(\.dismiss) private var dismiss

    private var calColor: Color {
        if let c = event.calendar?.cgColor { return Color(c) }
        return .accentColor
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title + calendar colour
                    HStack(alignment: .top, spacing: 12) {
                        Circle().fill(calColor).frame(width: 12, height: 12).padding(.top, 4)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title ?? "Event")
                                .font(.title2.weight(.bold))
                            if let calName = event.calendar?.title {
                                Text(calName)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Divider()

                    // Date & Time
                    if let start = event.startDate, let end = event.endDate {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar").foregroundStyle(calColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.dateFormatter.string(from: start))
                                    .font(.subheadline.weight(.semibold))
                                if !event.isAllDay {
                                    Text("\(Self.timeFormatter.string(from: start)) – \(Self.timeFormatter.string(from: end))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    // Location
                    if let loc = event.location, !loc.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "mappin").foregroundStyle(calColor)
                            Text(loc).font(.subheadline)
                        }
                    }

                    // Notes
                    if let notes = event.notes, !notes.isEmpty {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "note.text").foregroundStyle(calColor)
                            Text(notes).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }

                    // Open in Calendar button
                    Button {
                        if let url = URL(string: "calshow://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open in Calendar", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
            .navigationTitle("Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
