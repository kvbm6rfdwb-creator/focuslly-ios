import SwiftUI

// MARK: - FollowUpDetailView

struct FollowUpDetailView: View {
    @ObservedObject var pipeline: PipelineStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss

    // MARK: - Sections

    private enum Section: String {
        case overdue    = "Overdue"
        case dueToday   = "Due Today"
        case thisWeek   = "This Week"
        case upcoming   = "Upcoming"
    }

    private struct SectionData: Identifiable {
        let id: Section
        let title: String
        let icon: String
        let color: Color
        let items: [PipelineStore.FollowUpContact]
    }

    private var sections: [SectionData] {
        let all = pipeline.smartFollowUps
        let cal = Calendar.current

        // Overdue: daysSince >= overdueDays, sorted most-overdue first
        let overdue = all
            .filter { $0.isOverdue }
            .sorted { ($0.daysSince - $0.overdueDays) > ($1.daysSince - $1.overdueDays) }

        // Due today: window expires today (0 days left), not yet overdue
        let dueToday = all
            .filter { c in
                guard !c.isOverdue else { return false }
                let daysLeft = c.overdueDays - c.daysSince
                return daysLeft == 0
            }
            .sorted { $0.lastCallDate < $1.lastCallDate }

        // This week: 1–7 days left, not overdue, not today
        let thisWeek = all
            .filter { c in
                guard !c.isOverdue else { return false }
                let daysLeft = c.overdueDays - c.daysSince
                return daysLeft >= 1 && daysLeft <= 7
            }
            .sorted { ($0.overdueDays - $0.daysSince) < ($1.overdueDays - $1.daysSince) }

        // Upcoming: more than 7 days left
        let upcoming = all
            .filter { c in
                guard !c.isOverdue else { return false }
                return (c.overdueDays - c.daysSince) > 7
            }
            .sorted { ($0.overdueDays - $0.daysSince) < ($1.overdueDays - $1.daysSince) }

        var result: [SectionData] = []
        if !overdue.isEmpty {
            result.append(SectionData(id: .overdue,  title: "Overdue",    icon: "exclamationmark.circle.fill", color: .red,    items: overdue))
        }
        if !dueToday.isEmpty {
            result.append(SectionData(id: .dueToday, title: "Due Today",  icon: "clock.fill",                  color: .orange, items: dueToday))
        }
        if !thisWeek.isEmpty {
            result.append(SectionData(id: .thisWeek, title: "This Week",  icon: "calendar.circle.fill",        color: Color(red: 0.75, green: 0.6, blue: 0), items: thisWeek))
        }
        if !upcoming.isEmpty {
            result.append(SectionData(id: .upcoming, title: "Upcoming",   icon: "arrow.clockwise.circle",      color: .secondary, items: upcoming))
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            if sections.isEmpty {
                emptyState
            } else {
                VStack(spacing: 20) {
                    // Summary strip
                    summaryStrip

                    // Sections
                    ForEach(sections) { section in
                        sectionCard(section)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Follow-Up Tracker")
        .navigationBarTitleDisplayMode(.large)
    }

    // MARK: - Summary strip

    private var summaryStrip: some View {
        let all = pipeline.smartFollowUps
        let overdue  = all.filter { $0.isOverdue }.count
        let dueToday = sections.first(where: { $0.id == .dueToday })?.items.count ?? 0
        let thisWeek = sections.first(where: { $0.id == .thisWeek })?.items.count ?? 0
        let upcoming = sections.first(where: { $0.id == .upcoming })?.items.count ?? 0

        return HStack(spacing: 0) {
            summaryStatCell(value: overdue,  label: "Overdue",    color: overdue > 0 ? .red : .secondary)
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1, height: 32)
            summaryStatCell(value: dueToday, label: "Due today",  color: dueToday > 0 ? .orange : .secondary)
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1, height: 32)
            summaryStatCell(value: thisWeek, label: "This week",  color: thisWeek > 0 ? Color(red: 0.75, green: 0.6, blue: 0) : .secondary)
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1, height: 32)
            summaryStatCell(value: upcoming, label: "Upcoming",   color: .secondary)
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func summaryStatCell(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(value > 0 ? color : Color.secondary.opacity(0.4))
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section card

    private func sectionCard(_ section: SectionData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(section.color.opacity(0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: section.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(section.color)
                }
                Text(section.title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(section.id == .overdue ? .red : .primary)
                Spacer()
                Text("\(section.items.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(minWidth: 24, minHeight: 24)
                    .padding(.horizontal, 8)
                    .background(section.color.opacity(section.id == .upcoming ? 0.3 : 0.85))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1).padding(.horizontal, 16)

            // Contact rows
            ForEach(Array(section.items.enumerated()), id: \.element.name) { idx, contact in
                if idx > 0 {
                    Divider().padding(.leading, 64)
                }
                contactRow(contact, sectionColor: section.color, section: section.id)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Contact row

    private func contactRow(_ c: PipelineStore.FollowUpContact, sectionColor: Color, section: Section) -> some View {
        let daysLeft = c.overdueDays - c.daysSince
        let daysOverdue = c.daysSince - c.overdueDays

        return HStack(spacing: 14) {
            // Avatar / client type icon
            ZStack {
                Circle()
                    .fill((c.clientType?.color ?? Color.secondary).opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: c.clientType?.icon ?? "person.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(c.clientType?.color ?? Color.secondary)
            }

            // Name + step + client type
            VStack(alignment: .leading, spacing: 3) {
                Text(c.name.isEmpty ? "Unknown contact" : c.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Image(systemName: c.nextStep.icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Text(c.nextStep.rawValue)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                if let ct = c.clientType {
                    Text(ct.shortLabel)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ct.color.opacity(0.8))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(ct.color.opacity(0.10))
                        .clipShape(Capsule())
                }
            }

            Spacer()

            // Timing badge
            VStack(alignment: .trailing, spacing: 4) {
                // Primary badge
                Group {
                    switch section {
                    case .overdue:
                        Text("\(daysOverdue)d overdue")
                            .foregroundStyle(.red)
                    case .dueToday:
                        Text("Due today")
                            .foregroundStyle(.orange)
                    case .thisWeek:
                        Text("in \(daysLeft)d")
                            .foregroundStyle(Color(red: 0.75, green: 0.6, blue: 0))
                    case .upcoming:
                        Text("in \(daysLeft)d")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))

                // Last contact
                Text("Last: \(relativeDate(c.lastCallDate))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                // Urgency dot for overdue
                if section == .overdue {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 7, height: 7)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.brg)
            Text("All caught up!")
                .font(.system(size: 22, weight: .bold))
            Text("Every follow-up is on track.\nKeep the momentum going.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if days == 0 { return "today" }
        if days == 1 { return "yesterday" }
        if days < 7  { return "\(days)d ago" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
