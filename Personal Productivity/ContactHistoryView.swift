import SwiftUI
import Contacts
import ContactsUI

// MARK: - Helpers

private func normalise(_ s: String) -> String {
    s.lowercased()
     .trimmingCharacters(in: .whitespaces)
     .components(separatedBy: .whitespaces)
     .filter { !$0.isEmpty }
     .joined(separator: " ")
}

private func tagColor(_ tag: ContactTag) -> Color {
    switch tag {
    case .hotLead:      return .red
    case .warmLead:     return .orange
    case .coldLead:     return .blue
    case .activeClient: return .brg
    case .pastClient:   return .purple
    case .referral:     return .teal
    case .nurture:      return .gray
    }
}

private func outcomeColor(_ outcome: CallOutcome?) -> Color {
    guard outcome != nil else { return .secondary }
    return .brg
}

// MARK: - Pipeline Contact (view model built from call logs + metadata)
struct PipelineContact: Identifiable, Hashable {
    let id: String
    let displayName: String
    let calls: [CallLog]
    let metadata: ContactMetadata?

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: PipelineContact, rhs: PipelineContact) -> Bool { lhs.id == rhs.id }

    var lastCallDate: Date       { calls.first?.date ?? .distantPast }
    var totalCalls: Int          { calls.count }
    var tag: ContactTag?         { metadata?.tag }
    var isPinned: Bool           { metadata?.isPinned ?? false }

    var latestNextStep: NextStepType? {
        guard let step = calls.first?.nextStep, step != .none else { return nil }
        return step
    }

    var appointmentCount: Int {
        calls.filter { $0.outcome == .meetingArranged || $0.outcome == .callAppointmentArranged }.count
    }

    var showingCount: Int {
        calls.filter { $0.outcome == .showingArranged }.count
    }
}

// MARK: - Tag Pill
struct TagPill: View {
    let tag: ContactTag
    var body: some View {
        Text(tag.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(tagColor(tag))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(tagColor(tag).opacity(0.12)))
    }
}

// MARK: - ClientType Pill
struct ClientTypePill: View {
    let type: ClientType
    var body: some View {
        Text(type.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(clientTypeColor(type))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(clientTypeColor(type).opacity(0.12)))
    }
    private func clientTypeColor(_ t: ClientType) -> Color {
        // All client types use brg for buyers/sellers
        switch t {
        case .buyerActive, .buyerOfferStage, .buyerNurture, .sellerListed, .sellerProspect:
            return .brg
        case .postSale:
            return .purple
        }
    }
}

// MARK: - CRM Card
struct CRMCard<Content: View>: View {
    var title: String? = nil
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: title != nil ? 12 : 0) {
            if let t = title {
                Text(t).font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary).textCase(.uppercase).tracking(0.5)
            }
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
        .frame(maxWidth: .infinity)
    }
}

// MARK: - CRM Form Card
struct CRMFormCard<Content: View>: View {
    var title: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary).textCase(.uppercase).tracking(0.5)
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}

// MARK: - Filter Chip
struct FilterChipCRM: View {
    let label: String; let isSelected: Bool
    var color: Color = .brg; var action: () -> Void // Default to brg
    var body: some View {
        Button(action: action) {
            Text(label).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? .white : color)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(Capsule().fill(isSelected ? color : color.opacity(0.10)))
        }.buttonStyle(.plain)
    }
}

// MARK: - Timeline Row
struct TimelineRow: View {
    let icon: String; let iconColor: Color
    let title: String; let subtitle: String; let date: Date
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(iconColor.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(iconColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 14, weight: .semibold))
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer()
            Text(date.formatted(.relative(presentation: .named)))
                .font(.system(size: 11)).foregroundStyle(Color(.tertiaryLabel))
        }
    }
}

// MARK: - Contact Card
struct ContactCard: View {
    let contact: PipelineContact
    let pipeline: PipelineStore

    private var isNextStepOverdue: Bool {
        guard let call = contact.calls.first, call.nextStep != NextStepType.none else { return false }
        let age = Date().timeIntervalSince(call.date) / 86400
        return age > Double(call.nextStep.defaultDurationMinutes) / 1440.0
    }

    var body: some View {
        let momentum = RelationshipMomentumEngine.momentum(contact: contact, allCallLogs: pipeline.callLogs)
        let hint     = PrescriptiveHintEngine.hint(for: contact, momentum: momentum)
        let dir      = momentum.direction
        let isWarning = hint.1 == .yellow || hint.1 == .orange
        let isError = hint.1 == .red
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().fill(Color.brg.opacity(0.15)).frame(width: 46, height: 46)
                    Text(initials(contact.displayName))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Color.brgBright.blendMode(.plusLighter)) // Brighter initials
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(contact.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        if contact.isPinned { Image(systemName: "pin.fill").font(.system(size: 10)).foregroundStyle(.white) }
                    }
                    HStack(spacing: 6) {
                        if let tag = contact.tag { TagPill(tag: tag) }
                        if let ct  = contact.metadata?.clientType { ClientTypePill(type: ct) }
                    }
                    if let co = contact.metadata?.company, !co.isEmpty {
                        Text(co).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 3) {
                        Image(systemName: dir.icon).font(.system(size: 10, weight: .bold)).foregroundStyle(.white)
                        Text(dir.label).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    }
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.brg.opacity(0.12)))
                    // Only show last-contact date when at least one call has been logged
                    if contact.lastCallDate != .distantPast {
                        Text(contact.lastCallDate.formatted(.relative(presentation: .named)))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            }.padding(14)

            HStack(spacing: 0) {
                statCell(value: "\(contact.totalCalls)", label: "Calls")
                Divider().frame(height: 28)
                statCell(value: "\(contact.appointmentCount)", label: "Appt")
                Divider().frame(height: 28)
                statCell(value: "\(contact.showingCount)", label: "Shows")
                if let ns = contact.latestNextStep, ns != NextStepType.none {
                    Divider().frame(height: 28)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill").font(.system(size: 10))
                            .foregroundStyle(.white)
                        Text(ns.rawValue).font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white).lineLimit(1)
                    }
                    .padding(.horizontal, 10).frame(maxWidth: .infinity, alignment: .leading)
                }
            }.padding(.horizontal, 14).padding(.bottom, 8)

            let hintText = hint.0; let hintColor: Color = isError ? .red : isWarning ? .yellow : .white; let hintIcon = hint.2
            HStack(spacing: 6) {
                Image(systemName: hintIcon).font(.system(size: 11, weight: .semibold)).foregroundStyle(hintColor)
                Text(hintText).font(.system(size: 11, weight: .medium)).lineLimit(1).foregroundStyle(hintColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Color.brg.opacity(0.07))
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isNextStepOverdue ? Color.red.opacity(0.35) : Color.clear, lineWidth: 1.5))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 14, weight: .bold))
            Text(label).font(.system(size: 10)).foregroundStyle(.secondary)
        }.frame(maxWidth: .infinity)
    }
    private func avatarColor(_ name: String) -> Color {
        let c: [Color] = [.blue,.indigo,.purple,.pink,.orange,.teal,.green,.cyan]
        return c[abs(name.hashValue) % c.count]
    }
    private func initials(_ name: String) -> String {
        let p = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        return p.count >= 2 ? (String(p[0].prefix(1))+String(p[1].prefix(1))).uppercased()
                            : String(name.prefix(2)).uppercased()
    }
}

// MARK: - ContactHistoryView
struct ContactHistoryView: View {
    @ObservedObject var pipeline: PipelineStore
    @EnvironmentObject var taskStore: TaskStore

    @State private var searchText              = ""
    @State private var selectedTag: ContactTag? = nil
    @State private var clientCategory: ClientCategory = .all
    @State private var showNewContact          = false
    @State private var showUpcomingSteps       = false
    @State private var showImportPicker        = false
    @State private var showAddSheet            = false
    @State private var importToastCount: Int   = 0
    @State private var showImportToast: Bool   = false
    @State private var sortMode: SortMode      = .lastContact
    @FocusState private var searchFocused: Bool

    enum SortMode: String, CaseIterable { case lastContact = "Recent", name = "Name", calls = "Most calls" }
    enum ClientCategory: String, CaseIterable { case all = "All", buyers = "Buyers", sellers = "Sellers" }

    private var allContacts: [PipelineContact] {
        var grouped: [String: [CallLog]] = [:]
        var displayNames: [String: String] = [:]
        for log in pipeline.callLogs {
            let raw = log.contactName.trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { continue }
            let key = PipelineStore.contactKey(raw)
            grouped[key, default: []].append(log)
            if displayNames[key] == nil { displayNames[key] = raw }
        }
        // Metadata entries with no calls still get a slot
        for meta in pipeline.contactMetadata where grouped[meta.id] == nil {
            grouped[meta.id] = []
        }
        // Always prefer the stored display name from metadata over the raw log name
        for meta in pipeline.contactMetadata {
            displayNames[meta.id] = meta.displayName
        }
        return grouped.map { key, calls in
            PipelineContact(id: key, displayName: displayNames[key] ?? key,
                           calls: calls.sorted { $0.date > $1.date },
                           metadata: pipeline.contactMeta(for: key))
        }
        .sorted { a, b in
            let aDate = a.metadata?.createdAt ?? .distantPast
            let bDate = b.metadata?.createdAt ?? .distantPast
            return aDate > bDate
        }
    }

    private var sortedContacts: [PipelineContact] {
        let pinned   = allContacts.filter { $0.isPinned }
        let unpinned = allContacts.filter { !$0.isPinned }

        func sort(_ contacts: [PipelineContact]) -> [PipelineContact] {
            switch sortMode {
            case .name:
                return contacts.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
            case .calls:
                return contacts.sorted { $0.totalCalls > $1.totalCalls }
            case .lastContact:
                // Contacts with calls: sorted by most-recent call date descending.
                // Contacts without calls: sorted by createdAt descending (stable — import order preserved).
                let withCalls    = contacts.filter { $0.lastCallDate != .distantPast }
                    .sorted { $0.lastCallDate > $1.lastCallDate }
                let withoutCalls = contacts.filter { $0.lastCallDate == .distantPast }
                    .sorted { ($0.metadata?.createdAt ?? .distantPast) > ($1.metadata?.createdAt ?? .distantPast) }
                return withCalls + withoutCalls
            }
        }

        return sort(pinned) + sort(unpinned)
    }

    private var filtered: [PipelineContact] {
        var result = sortedContacts
        switch clientCategory {
        case .buyers:
            result = result.filter { c in
                guard let ct = c.metadata?.clientType else { return false }
                return ct == .buyerActive || ct == .buyerOfferStage || ct == .buyerNurture
            }
        case .sellers:
            result = result.filter { c in
                guard let ct = c.metadata?.clientType else { return false }
                return ct == .sellerListed || ct == .sellerProspect
            }
        case .all: break
        }
        if let tag = selectedTag { result = result.filter { $0.tag == tag } }
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            result = result.filter {
                $0.displayName.lowercased().contains(q) ||
                ($0.metadata?.phone.lowercased().contains(q) ?? false) ||
                ($0.metadata?.email.lowercased().contains(q) ?? false) ||
                ($0.metadata?.company.lowercased().contains(q) ?? false)
            }
        }
        return result
    }

    // MARK: - Body
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                if !allContacts.isEmpty {
                    filterBar
                    searchBar
                    insightsStrip
                }
                if filtered.isEmpty { emptyState } else { contactList }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())

            if showImportToast {
                HStack(spacing: 10) {
                    Image(systemName: importToastCount > 0 ? "person.2.fill" : "info.circle.fill")
                        .foregroundStyle(.white)
                    Text(importToastCount == 0 ? "No new contacts imported" :
                         "\(importToastCount) contact\(importToastCount == 1 ? "" : "s") imported")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Capsule()
                    .fill(importToastCount > 0 ? Color.accentColor : Color(.systemGray))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4))
                .padding(.bottom, 32)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddSheet = true } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .floatingKeyboardDismiss(isVisible: searchFocused)
        .sheet(isPresented: $showNewContact) { NewContactSheet(pipeline: pipeline) }
        .sheet(isPresented: $showAddSheet) { AddContactChoiceSheet(showNewContact: $showNewContact, showImportPicker: $showImportPicker) }
        .sheet(isPresented: $showUpcomingSteps) {
            UpcomingStepsSheet(
                items: UpcomingStepsEngine.upcomingSteps(contacts: allContacts, tasks: taskStore.tasks),
                pipeline: pipeline
            ).environmentObject(taskStore)
        }
        .background(
            AppleContactsPicker(
                isPresented: $showImportPicker,
                onImported: { count in
                    importToastCount = count
                    withAnimation(.spring()) { showImportToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.spring()) { showImportToast = false }
                    }
                },
                pipeline: pipeline
            )
        )
    }

    private func categoryColor(_ cat: ClientCategory) -> Color {
        switch cat {
        case .buyers, .sellers:
            return .brg
        case .all:
            return .brg
        }
    }

    // MARK: - Search Bar (permanent, always visible)
    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search name, phone, email…", text: $searchText)
                .font(.system(size: 15))
                .autocorrectionDisabled()
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Insights Strip (sticky)
    private var insightsStrip: some View {
        let base     = filtered
        let pending  = base.filter { $0.latestNextStep != nil && $0.latestNextStep != NextStepType.none }.count
        let overdue  = base.filter { c in
            guard let call = c.calls.first, call.nextStep != NextStepType.none else { return false }
            return Date().timeIntervalSince(call.date) / 86400 > Double(call.nextStep.defaultDurationMinutes) / 1440.0
        }.count
        let followUp = UpcomingStepsEngine.upcomingSteps(contacts: allContacts, tasks: taskStore.tasks)
        let overdueFollowUp  = followUp.filter { $0.daysUntilDue < 0 }.count
        let dueTodayFollowUp = followUp.filter { $0.daysUntilDue == 0 }.count

        // Build stat cells based on active category
        let cells: [(icon: String, value: String, label: String, color: Color)]
        switch clientCategory {
        case .all:
            cells = [
                ("person.2.fill",         "\(base.count)",                                  "Total",     .primary),
                ("flame.fill",            "\(base.filter { $0.tag == .hotLead }.count)",    "Hot",       .red),
                ("clock.badge.exclamationmark", "\(overdue)",                               "Overdue",   overdue  > 0 ? .red    : .secondary),
                ("arrow.right.circle.fill",     "\(pending)",                               "Pending",   pending  > 0 ? .orange : .secondary),
            ]
        case .buyers:
            cells = [
                ("person.fill",           "\(base.count)",                                                                   "Buyers",     .blue),
                ("doc.text.fill",         "\(base.filter { $0.metadata?.clientType == .buyerOfferStage }.count)",            "Offer Stage",.indigo),
                ("checkmark.circle.fill", "\(base.filter { $0.metadata?.buyerSaturated == true }.count)",                   "Saturated",  .gray),
                ("arrow.right.circle.fill","\(pending)",                                                                     "Pending",    pending > 0 ? .orange : .secondary),
            ]
        case .sellers:
            cells = [
                ("house.fill",            "\(base.count)",                                                                   "Sellers",    .orange),
                ("tag.fill",              "\(base.filter { $0.metadata?.clientType == .sellerListed }.count)",               "Listed",     .orange),
                ("magnifyingglass",       "\(base.filter { $0.metadata?.clientType == .sellerProspect }.count)",             "Prospect",   .yellow),
                ("arrow.right.circle.fill","\(pending)",                                                                     "Pending",    pending > 0 ? .orange : .secondary),
            ]
        }

        let followUpColor: Color = overdueFollowUp > 0 ? .red : dueTodayFollowUp > 0 ? .orange : .brg

        return VStack(spacing: 0) {
            // ── Stat tiles ───────────────────────────────────────────
            HStack(spacing: 0) {
                ForEach(cells.indices, id: \.self) { i in
                    if i > 0 {
                        Rectangle()
                            .fill(Color(.separator).opacity(0.5))
                            .frame(width: 0.5, height: 36)
                    }
                    Button {
                        // tapping Overdue or Pending jumps to follow-up sheet
                        if (cells[i].label == "Overdue" || cells[i].label == "Pending") && !followUp.isEmpty {
                            showUpcomingSteps = true
                        }
                    } label: {
                        VStack(spacing: 3) {
                            HStack(spacing: 4) {
                                Image(systemName: cells[i].icon)
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(cells[i].color == .accentColor ? Color.brg.opacity(0.8) : cells[i].color.opacity(0.8))
                                Text(cells[i].value)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(cells[i].color == .accentColor ? Color.brg : cells[i].color)
                            }
                            Text(cells[i].label)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))

            // ── Follow-up banner (only when items exist) ─────────────
            if !followUp.isEmpty {
                Divider()
                Button { showUpcomingSteps = true } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(followUpColor.opacity(0.12))
                                .frame(width: 28, height: 28)
                            Image(systemName: overdueFollowUp > 0 ? "exclamationmark.circle.fill" : "clock.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(followUpColor)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(overdueFollowUp > 0 ? "Overdue follow-ups" : dueTodayFollowUp > 0 ? "Follow-ups due today" : "Upcoming follow-ups")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(followUpColor)
                            HStack(spacing: 6) {
                                if overdueFollowUp > 0  { badge("\(overdueFollowUp) overdue",  .red)    }
                                if dueTodayFollowUp > 0 { badge("\(dueTodayFollowUp) today",   .orange) }
                                let upcoming = followUp.count - overdueFollowUp - dueTodayFollowUp
                                if upcoming > 0         { badge("\(upcoming) upcoming",         .accentColor) }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Color(.secondarySystemGroupedBackground))
            }

            Divider()
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    // MARK: - Filter Bar
    private var filterBar: some View {
        HStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ClientCategory.allCases, id: \.self) { cat in
                        FilterChipCRM(label: cat.rawValue, isSelected: clientCategory == cat, color: categoryColor(cat)) {
                            clientCategory = cat; HapticManager.impact()
                        }
                    }
                    ForEach(ContactTag.allCases, id: \.self) { tag in
                        let count = filtered.filter { $0.tag == tag }.count
                        if count > 0 || selectedTag == tag {
                            FilterChipCRM(label: "\(tag.rawValue) (\(count))",
                                         isSelected: selectedTag == tag, color: tagColor(tag)) {
                                selectedTag = selectedTag == tag ? nil : tag; HapticManager.impact()
                            }
                        }
                    }
                }.padding(.horizontal, 16).padding(.vertical, 8)
            }
            Menu {
                ForEach(SortMode.allCases, id: \.self) { mode in
                    Button { sortMode = mode } label: {
                        Label(mode.rawValue, systemImage: sortMode == mode ? "checkmark" : "")
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 12, weight: .semibold))
                    Text(sortMode.rawValue).font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Capsule().fill(Color.accentColor.opacity(0.10)))
                .padding(.trailing, 12)
            }
        }.background(Color(.systemGroupedBackground))
    }

    // MARK: - Stats Strip
    private var statsStrip: some View {
        let base    = filtered
        let pending = base.filter { $0.latestNextStep != nil && $0.latestNextStep != NextStepType.none }.count
        let overdue = base.filter { c in
            guard let call = c.calls.first, call.nextStep != NextStepType.none else { return false }
            return Date().timeIntervalSince(call.date) / 86400 > Double(call.nextStep.defaultDurationMinutes) / 1440.0
        }.count

        return Group {
            if searchText.isEmpty {
                switch clientCategory {
                case .all:
                    statsRow([
                        (value: "\(base.count)", label: "Total", color: Color.primary),
                        (value: "\(pending)", label: "Pending", color: pending > 0 ? Color.orange : Color.secondary),
                        (value: "\(overdue)", label: "Overdue", color: overdue > 0 ? Color.red : Color.secondary),
                        (value: "\(base.filter { $0.tag == .hotLead }.count)", label: "Hot Leads", color: Color.red)
                    ])
                case .buyers:
                    statsRow([
                        (value: "\(base.count)", label: "Buyers", color: Color.primary),
                        (value: "\(base.filter { $0.metadata?.clientType == .buyerOfferStage }.count)", label: "Offer Stage", color: Color.indigo),
                        (value: "\(base.filter { $0.metadata?.buyerSaturated == true }.count)", label: "Saturated", color: Color.gray),
                        (value: "\(pending)", label: "Pending", color: pending > 0 ? Color.orange : Color.secondary)
                    ])
                case .sellers:
                    statsRow([
                        (value: "\(base.count)", label: "Sellers", color: Color.primary),
                        (value: "\(base.filter { $0.metadata?.clientType == .sellerListed }.count)", label: "Listed", color: Color.orange),
                        (value: "\(base.filter { $0.metadata?.clientType == .sellerProspect }.count)", label: "Prospect", color: Color.yellow),
                        (value: "\(pending)", label: "Pending", color: pending > 0 ? Color.orange : Color.secondary)
                    ])
                }
            }
        }
    }

    private func statsRow(_ cells: [(value: String, label: String, color: Color)]) -> some View {
        HStack(spacing: 0) {
            ForEach(cells.indices, id: \.self) { i in
                if i > 0 { Divider().frame(height: 28) }
                VStack(spacing: 2) {
                    Text(cells[i].value).font(.system(size: 16, weight: .bold)).foregroundStyle(cells[i].color)
                    Text(cells[i].label).font(.system(size: 10)).foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
    }

    // MARK: - Upcoming Steps Banner
    private var upcomingStepsBanner: some View {
        let items = UpcomingStepsEngine.upcomingSteps(contacts: allContacts, tasks: taskStore.tasks)
        guard !items.isEmpty else { return AnyView(EmptyView()) }
        let overdue  = items.filter { $0.daysUntilDue < 0 }.count
        let dueToday = items.filter { $0.daysUntilDue == 0 }.count
        let upcoming = items.count - overdue - dueToday
        let color: Color = overdue > 0 ? .red : dueToday > 0 ? .orange : .brg
        var parts: [String] = []
        if overdue  > 0 { parts.append("\(overdue) overdue") }
        if dueToday > 0 { parts.append("\(dueToday) due today") }
        if upcoming > 0         { parts.append("\(upcoming) coming up") }
        return AnyView(
            Button { showUpcomingSteps = true } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(color.opacity(0.15)).frame(width: 32, height: 32)
                        Image(systemName: overdue > 0 ? "exclamationmark.circle.fill" : "clock.fill")
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Follow-ups needed").font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                        Text(parts.joined(separator: " · ")).font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(color.opacity(0.07))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(color.opacity(0.2), lineWidth: 1)))
                .padding(.horizontal, 16).padding(.top, 8)
            }.buttonStyle(.plain)
        )
    }

    // MARK: - Contact List
    private var contactList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(filtered) { contact in
                    NavigationLink(value: contact) {
                        ContactCard(contact: contact, pipeline: pipeline)
                            .padding(.horizontal, 16)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) { deleteContact(contact) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
    }

    private func deleteContact(_ contact: PipelineContact) {
        pipeline.deleteContactMetadata(id: contact.id)
        pipeline.callLogs.filter { PipelineStore.contactKey($0.contactName) == contact.id }.map { $0.id }
            .forEach { pipeline.deleteCall(id: $0) }
        HapticManager.success()
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.08)).frame(width: 80, height: 80)
                Image(systemName: "person.2.slash").font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(Color.accentColor.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text(searchText.isEmpty ? "No contacts yet" : "No results").font(.system(size: 20, weight: .bold))
                Text(searchText.isEmpty ? "Add your first contact or import from Apple Contacts" : "Try a different search term")
                    .font(.system(size: 14)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if searchText.isEmpty {
                Button { showNewContact = true } label: {
                    Label("Add Contact", systemImage: "person.badge.plus")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 24).padding(.vertical, 12)
                        .background(Capsule().fill(Color.accentColor))
                }.buttonStyle(.plain)
            }
            Spacer()
        }.padding(32)
    }
}

// MARK: - New Contact Sheet
struct NewContactSheet: View {
    @ObservedObject var pipeline: PipelineStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""; @State private var phone = ""
    @State private var email = ""; @State private var company = ""
    @State private var tag: ContactTag? = nil; @State private var clientType: ClientType? = nil
    @State private var notes = ""
    @FocusState private var isAnyFieldFocused: Bool
    private var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    var body: some View {
        NavigationStack {
            Form {
                Section("Name") { TextField("Full name (required)", text: $name).focused($isAnyFieldFocused) }
                Section("Contact Info") {
                    TextField("Phone", text: $phone).keyboardType(.phonePad).focused($isAnyFieldFocused)
                    TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none).focused($isAnyFieldFocused)
                    TextField("Company", text: $company).focused($isAnyFieldFocused)
                }
                Section("Classification") {
                    Picker("Tag", selection: $tag) {
                        Text("None").tag(ContactTag?.none)
                        ForEach(ContactTag.allCases, id: \.self) { Text($0.rawValue).tag(ContactTag?.some($0)) }
                    }
                    Picker("Client Type", selection: $clientType) {
                        Text("None").tag(ClientType?.none)
                        ForEach(ClientType.allCases, id: \.self) { Text($0.rawValue).tag(ClientType?.some($0)) }
                    }
                }
                Section("Notes") { TextEditor(text: $notes).frame(minHeight: 80).focused($isAnyFieldFocused) }
            }
            .navigationTitle("New Contact").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.disabled(!canSave).bold() }
            }
        }
        .floatingKeyboardDismiss(isVisible: isAnyFieldFocused)
    }
    private func save() {
        let t = name.trimmingCharacters(in: .whitespaces)
        var m = ContactMetadata(id: PipelineStore.contactKey(t), displayName: t)
        m.phone = phone.trimmingCharacters(in: .whitespaces)
        m.email = email.trimmingCharacters(in: .whitespaces)
        m.company = company.trimmingCharacters(in: .whitespaces)
        m.tag = tag; m.clientType = clientType
        m.notes = notes.trimmingCharacters(in: .whitespaces)
        pipeline.upsertContactMetadata(m); HapticManager.success(); dismiss()
    }
}

// MARK: - Upcoming Steps Sheet
struct UpcomingStepsSheet: View {
    let items: [UpcomingStepItem]
    @ObservedObject var pipeline: PipelineStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContact: PipelineContact? = nil

    private var overdue:  [UpcomingStepItem] { items.filter { $0.daysUntilDue < 0 }.sorted { $0.dueDate < $1.dueDate } }
    private var dueToday: [UpcomingStepItem] { items.filter { $0.daysUntilDue == 0 } }
    private var thisWeek: [UpcomingStepItem] { items.filter { $0.daysUntilDue > 0 && $0.dueDate <= Date().addingTimeInterval(7*86400) }.sorted { $0.dueDate < $1.dueDate } }
    private var later:    [UpcomingStepItem] { items.filter { $0.daysUntilDue > 0 && $0.dueDate > Date().addingTimeInterval(7*86400) }.sorted { $0.dueDate < $1.dueDate } }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(Color.brg)
                        Text("All caught up!").font(.system(size: 22, weight: .bold))
                        Text("No upcoming follow-ups right now.").foregroundStyle(.secondary)
                        Spacer()
                    }
                } else {
                    List {
                        if !overdue.isEmpty  { section("🔴 Overdue",   items: overdue,  color: .red) }
                        if !dueToday.isEmpty { section("🟠 Due Today", items: dueToday, color: .orange) }
                        if !thisWeek.isEmpty { section("🟡 This Week", items: thisWeek, color: .yellow) }
                        if !later.isEmpty    { section("⚪ Upcoming",  items: later,    color: .secondary) }
                    }.listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Follow-Ups").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .sheet(item: $selectedContact) { c in
            ContactDetailView(contact: c, pipeline: pipeline).environmentObject(taskStore)
        }
    }

    private func section(_ title: String, items: [UpcomingStepItem], color: Color) -> some View {
        Section(header: Text(title)) {
            ForEach(items) { item in
                Button {
                    if item.sourceType == .contactNextStep {
                        let allC = buildContacts()
                        selectedContact = allC.first { $0.id == PipelineStore.contactKey(item.contactName) }
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(item.urgencyColor.opacity(0.12)).frame(width: 36, height: 36)
                            Image(systemName: item.icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(item.urgencyColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.contactName).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
                            Text(item.stepLabel).font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.daysUntilDue < 0 ? "Overdue" : item.dueDate.formatted(.relative(presentation: .named)))
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(item.urgencyColor)
                            if item.daysUntilDue < 0 {
                                Text("\(Int(Date().timeIntervalSince(item.dueDate)/86400))d late")
                                    .font(.system(size: 10)).foregroundStyle(Color(.tertiaryLabel))
                            }
                        }
                    }
                }.buttonStyle(.plain)
            }
        }
    }

    private func buildContacts() -> [PipelineContact] {
        var grouped: [String: [CallLog]] = [:]
        var displayNames: [String: String] = [:]
        for log in pipeline.callLogs {
            let raw = log.contactName.trimmingCharacters(in: .whitespaces)
            guard !raw.isEmpty else { continue }
            let key = PipelineStore.contactKey(raw)
            grouped[key, default: []].append(log)
            if displayNames[key] == nil { displayNames[key] = raw }
        }
        for meta in pipeline.contactMetadata where grouped[meta.id] == nil {
            grouped[meta.id] = []; displayNames[meta.id] = meta.displayName
        }
        return grouped.map { key, calls in
            PipelineContact(id: key, displayName: displayNames[key] ?? key,
                           calls: calls.sorted { $0.date > $1.date },
                           metadata: pipeline.contactMeta(for: key))
        }
        .sorted { ($0.metadata?.createdAt ?? .distantPast) > ($1.metadata?.createdAt ?? .distantPast) }
    }
}

// MARK: - Contact Detail View
struct ContactDetailView: View {
    let contact: PipelineContact
    @ObservedObject var pipeline: PipelineStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var showEdit          = false
    @State private var showLogCall        = false
    @State private var showLogActivity    = false
    @State private var showDeleteConfirm  = false
    @State private var meta: ContactMetadata?
    @State private var stepLoggedMessage: String? = nil
    private var currentMeta: ContactMetadata? { meta ?? pipeline.contactMeta(for: contact.id) ?? contact.metadata }

    /// Live-recomputed contact — always reflects the latest callLogs from pipeline.
    /// This ensures the view updates immediately after a call/activity is logged
    /// without needing to close and reopen the page.
    private var liveContact: PipelineContact {
        let liveCalls = pipeline.callLogs
            .filter { PipelineStore.contactKey($0.contactName) == contact.id }
            .sorted { $0.date > $1.date }
        return PipelineContact(
            id: contact.id,
            displayName: currentMeta?.displayName ?? contact.displayName,
            calls: liveCalls,
            metadata: currentMeta
        )
    }

    private var isImportedWithNoCalls: Bool {
        (currentMeta?.isImported ?? false) && liveContact.calls.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                profileHeader
                contactInfoCard
                if isImportedWithNoCalls {
                    noCallsYetCard
                } else {
                    activityStatsCard
                    buyerReadinessCard
                    nextStepCard
                    activityTimelineCard
                }
                notesCard
                // ── Delete contact ──────────────────────────────────
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "trash").font(.system(size: 14, weight: .semibold))
                        Text("Delete Contact").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.red.opacity(0.08))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.2), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }.padding(.horizontal, 16).padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(contact.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) { Button("Edit") { showEdit = true } }
        }
        .sheet(isPresented: $showEdit) {
            ContactEditView(contact: contact, pipeline: pipeline) { meta = $0 }
        }
        .sheet(isPresented: $showLogCall) {
            LogCallSheet(contact: contact, pipeline: pipeline)
        }
        .sheet(isPresented: $showLogActivity) {
            LogActivitySheet(contact: contact, pipeline: pipeline)
        }
        .alert("Delete Contact", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                pipeline.deleteContactMetadata(id: contact.id)
                pipeline.callLogs
                    .filter { PipelineStore.contactKey($0.contactName) == contact.id }
                    .map { $0.id }
                    .forEach { pipeline.deleteCall(id: $0) }
                HapticManager.success()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete \(contact.displayName) and all their call history.")
        }
        .onAppear { meta = contact.metadata }
    }

    private var profileHeader: some View {
        let colors: [Color] = [.blue,.indigo,.purple,.pink,.orange,.teal,.green,.cyan]
        let ac = Color.brg // Always use brg for contact icon
        let p  = contact.displayName.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let in2 = p.count >= 2 ? (String(p[0].prefix(1))+String(p[1].prefix(1))).uppercased() : String(contact.displayName.prefix(2)).uppercased()
        return CRMCard {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(ac.opacity(0.18)).frame(width: 70, height: 70)
                        Text(in2).font(.system(size: 26, weight: .bold)).foregroundStyle(Color.brgBright)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text(contact.displayName).font(.system(size: 22, weight: .bold))
                        HStack(spacing: 6) {
                            if let tag = currentMeta?.tag { TagPill(tag: tag) }
                            if let ct  = currentMeta?.clientType { ClientTypePill(type: ct) }
                        }
                        if let co = currentMeta?.company, !co.isEmpty {
                            Text(co).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }

                Divider().padding(.vertical, 16)

                HStack(spacing: 0) {
                    quickBtn("phone.arrow.up.right", "Log Call", .accentColor) { showLogCall = true }
                    quickBtn("star.circle.fill", "Log Activity", .purple) { showLogActivity = true }
                    let pinned = currentMeta?.isPinned ?? false
                    quickBtn(pinned ? "pin.slash.fill" : "pin.fill", pinned ? "Unpin" : "Pin", .orange) {
                        var u = currentMeta ?? ContactMetadata(id: contact.id, displayName: contact.displayName)
                        u.isPinned.toggle(); meta = u; pipeline.upsertContactMetadata(u)
                    }
                }
            }
        }
    }

    private func quickBtn(_ icon: String, _ label: String, _ color: Color, action: @escaping()->Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(Color.brg.opacity(0.12)).frame(width: 44, height: 44)
                    Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(Color.brg)
                }
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            }
        }.buttonStyle(.plain).frame(maxWidth: .infinity)
    }

    private var noCallsYetCard: some View {
        CRMCard {
            VStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.08)).frame(width: 56, height: 56)
                    Image(systemName: "phone.badge.plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.accentColor.opacity(0.6))
                }
                VStack(spacing: 6) {
                    Text("No calls logged yet")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Log your first call with \(contact.displayName) to start tracking your relationship and unlock insights.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Button { showLogCall = true } label: {
                    Label("Log First Call", systemImage: "phone.arrow.up.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.accentColor))
                }.buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
    }

    private var contactInfoCard: some View {
        ContactInfoCard(
            phone:   currentMeta?.phone   ?? "",
            email:   currentMeta?.email   ?? "",
            company: currentMeta?.company ?? ""
        )
    }

    private var activityStatsCard: some View {
        CRMCard(title: "Activity") {
            HStack(spacing: 0) {
                detStat("\(liveContact.totalCalls)", "Total Calls")
                Divider().frame(height: 36)
                detStat("\(liveContact.appointmentCount)", "Appointments")
                Divider().frame(height: 36)
                detStat("\(liveContact.showingCount)", "Showings")
                Divider().frame(height: 36)
                detStat(liveContact.lastCallDate == .distantPast ? "—" :
                    liveContact.lastCallDate.formatted(.dateTime.month(.abbreviated).day()), "Last Contact")
            }
            .frame(maxWidth: .infinity)
        }
    }
    private func detStat(_ value: String,_ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold))
            Text(label).font(.system(size: 11)).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity)
    }

    private var buyerReadinessCard: some View {
        let result     = BuyerReadinessEngine.score(contact: liveContact, saleLogs: pipeline.saleLogs, callLogs: pipeline.callLogs)
        let momentum   = RelationshipMomentumEngine.momentum(contact: liveContact, allCallLogs: pipeline.callLogs)
        let dir        = momentum.direction
        let cardTitle  = result.isSeller ? "Seller Readiness" : "Buyer Readiness"
        let stageColor: Color = .brg // Always use brg for readiness
        let allStages  = BuyerReadinessStage.allCases
        let stageIndex = allStages.firstIndex(of: result.stage) ?? 0
        let preApproval = liveContact.metadata?.preApprovalStatus ?? .notStarted

        return CRMCard(title: cardTitle) {
            VStack(alignment: .leading, spacing: 16) {

                // ── Score ring + stage + velocity ──────────────────────────
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 10)
                            .frame(width: 90, height: 90)
                        Circle()
                            .trim(from: 0, to: CGFloat(result.score) / 100)
                            .stroke(
                                LinearGradient(colors: [Color.brg.opacity(0.6), Color.brg],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .frame(width: 90, height: 90)
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 1) {
                            Text("\(result.score)")
                                .font(.system(size: 26, weight: .black))
                                .foregroundStyle(Color.brg)
                            Text("/ 100")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 7) {
                        // Stage badge
                        HStack(spacing: 6) {
                            Circle().fill(Color.brg).frame(width: 8, height: 8)
                            Text(result.stage.rawValue)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Color.brg)
                        }
                        // Score velocity pill
                        if let velocity = result.scoreVelocity, velocity != 0 {
                            HStack(spacing: 4) {
                                Image(systemName: velocity > 0 ? "arrow.up.right" : "arrow.down.right")
                                    .font(.system(size: 9, weight: .bold))
                                Text(velocity > 0 ? "+\(velocity) this week" : "\(velocity) this week")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(velocity > 0 ? Color.brg : Color.red)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill((velocity > 0 ? Color.brg : Color.red).opacity(0.12)))
                        } else {
                            // Momentum pill when no velocity data
                            HStack(spacing: 4) {
                                Image(systemName: dir.icon).font(.system(size: 10, weight: .bold))
                                Text(dir.label).font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Color.brg)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.brg.opacity(0.12)))
                        }
                        // Pre-approval badge (buyer only)
                        if !result.isSeller {
                            HStack(spacing: 4) {
                                Image(systemName: preApproval.icon)
                                    .font(.system(size: 10, weight: .semibold))
                                Text(preApproval.shortLabel)
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(Color.brg)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.brg.opacity(0.12)))
                        }
                        Text(result.stage.description)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                // ── Stage Progress Bar ─────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        ForEach(Array(allStages.enumerated()), id: \.offset) { idx, _ in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(idx <= stageIndex ? stageColor : Color(.systemGray5))
                                .frame(height: 5)
                                .animation(.easeInOut(duration: 0.4), value: stageIndex)
                        }
                    }
                    HStack {
                        Text(allStages.first?.rawValue ?? "").font(.system(size: 10)).foregroundStyle(.secondary)
                        Spacer()
                        Text(allStages.last?.rawValue ?? "").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }

                // ── Risk Flags ─────────────────────────────────────────────
                if !result.flags.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(result.flags) { flag in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: flag.icon)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(flag.color)
                                    .frame(width: 20)
                                    .padding(.top, 1)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(flag.title)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(flag.color)
                                    Text(flag.detail)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(flag.color.opacity(0.07))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(flag.color.opacity(0.2), lineWidth: 1)))
                        }
                    }
                }

                // ── 3-Step Action Plan ─────────────────────────────────────
                if !result.actionPlan.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Action Plan")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.4)
                        ForEach(result.actionPlan) { step in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.brg.opacity(0.12))
                                        .frame(width: 32, height: 32)
                                    Image(systemName: step.icon)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.brg)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(step.action)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text(step.reason)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 10)
                            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground)))
                        }
                    }
                }

                // ── Momentum Insight ───────────────────────────────────────
                if !momentum.reason.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .semibold))
                        Text(momentum.reason)
                            .font(.system(size: 12))
                            .lineLimit(2)
                    }
                    .foregroundStyle(dir.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(dir.color.opacity(0.07)))
                }

                // ── Key Scoring Factors ────────────────────────────────────
                if !result.topFactors.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Key Factors")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.4)
                        ForEach(result.topFactors) { factor in
                            HStack(spacing: 10) {
                                Image(systemName: factor.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(factor.points > 0 ? Color.brg : factor.points < 0 ? .red : .secondary)
                                    .frame(width: 20)
                                Text(factor.label)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if factor.points != 0 {
                                    Text(factor.points > 0 ? "+\(factor.points)" : "\(factor.points)")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(factor.points > 0 ? Color.brg : .red)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Capsule().fill(
                                            (factor.points > 0 ? Color.brg : Color.red).opacity(0.10)))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var nextStepCard: some View {
        guard let latestCall = liveContact.calls.first, latestCall.nextStep != NextStepType.none else { return AnyView(EmptyView()) }
        let step    = latestCall.nextStep
        let setDate = latestCall.date
        let dueDate = setDate.addingTimeInterval(Double(step.defaultDurationMinutes) / 1440.0 * 86400)
        let daysLeft = dueDate.timeIntervalSince(Date()) / 86400
        let isOverdue = daysLeft < 0
        let badge = isOverdue ? "Overdue by \(abs(Int(daysLeft)))d" : daysLeft < 1 ? "Due today" : "Due in \(Int(daysLeft))d"
        let stepColor: Color = isOverdue ? .red : .orange
        let (aLabel, aIcon, _) = nextStepAction(for: step)
        return AnyView(
            CRMCard(title: "Next Step") {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(stepColor.opacity(0.12)).frame(width: 42, height: 42)
                            Image(systemName: step.icon).font(.system(size: 16, weight: .semibold)).foregroundStyle(stepColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.rawValue).font(.system(size: 15, weight: .semibold))
                            Text("Set after call on \(setDate.formatted(.dateTime.month(.abbreviated).day()))")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(badge).font(.system(size: 11, weight: .semibold)).foregroundStyle(stepColor)
                            .padding(.horizontal, 8).padding(.vertical, 4).background(Capsule().fill(stepColor.opacity(0.12)))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 11))
                        Text(isOverdue ? "This step was due \(abs(Int(daysLeft))) day\(abs(Int(daysLeft))==1 ? "" : "s") ago" :
                             daysLeft < 1 ? "This step is due today" :
                             "This step is due in \(Int(daysLeft)) day\(Int(daysLeft)==1 ? "" : "s")")
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(stepColor.opacity(0.8)).frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(stepColor.opacity(0.07)))
                    Button {
                        logNextStep(step)
                    } label: {
                        Label(aLabel, systemImage: aIcon).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(stepColor))
                    }.buttonStyle(.plain)
                    // Inline confirmation toast
                    if let msg = stepLoggedMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.brg)
                            Text(msg)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.brg.opacity(0.09)))
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        )
    }

    private func nextStepAction(for step: NextStepType) -> (String, String, Bool) {
        switch step {
        case .sendOffer:       return ("Log offer sent",            "envelope.fill",             false)
        case .sendListingInfo: return ("Log listing info sent",     "house.fill",                false)
        case .appointment, .prepareCMA: return ("Log showing / meeting", "calendar.badge.checkmark", false)
        case .nurture:         return ("Log nurture call",          "leaf.fill",                 false)
        case .openHouse:       return ("Log open house visit",      "person.3.fill",             false)
        default:               return ("Log call now",              "phone.fill",                true)
        }
    }

    /// Logs the next step silently (for activity-type steps) or opens the call sheet.
    private func logNextStep(_ step: NextStepType) {
        switch step {
        case .followUpCall, .retryCall, .none:
            // These need a full call log — open the sheet
            showLogCall = true

        case .sendOffer:
            var log = SaleLog(type: .offerSent)
            log.contactName = contact.displayName
            pipeline.addSale(log)
            showToast("Offer sent logged")

        case .sendListingInfo:
            var log = SaleLog(type: .offerSent)   // closest type; use notes to distinguish
            log.contactName = contact.displayName
            log.notes = "Listing info sent"
            pipeline.addSale(log)
            showToast("Listing info sent logged")

        case .appointment, .prepareCMA:
            var log = SaleLog(type: .showingDone)
            log.contactName = contact.displayName
            log.notes = step == .prepareCMA ? "CMA / meeting done" : "Showing / meeting done"
            pipeline.addSale(log)
            showToast(step == .prepareCMA ? "Meeting logged" : "Showing logged")

        case .nurture:
            var log = SaleLog(type: .showingDone)
            log.contactName = contact.displayName
            log.notes = "Nurture call done"
            // Log as a call log instead so it registers as recency
            var callLog = CallLog()
            callLog.contactName = contact.displayName
            callLog.outcome = .callAppointmentArranged
            callLog.nextStep = .none
            callLog.notes = "Nurture call"
            pipeline.addCall(callLog)
            showToast("Nurture call logged")

        case .openHouse:
            var log = SaleLog(type: .showingDone)
            log.contactName = contact.displayName
            log.notes = "Open house visit"
            pipeline.addSale(log)
            showToast("Open house visit logged")
        }
        HapticManager.success()
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            stepLoggedMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                stepLoggedMessage = nil
            }
        }
    }

    private var notesCard: some View {
        guard let notes = currentMeta?.notes, !notes.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(CRMCard(title: "Notes") {
            Text(notes).font(.system(size: 14)).foregroundStyle(.primary).frame(maxWidth: .infinity, alignment: .leading)
        })
    }

    struct ActivityItem: Identifiable {
        let id = UUID(); let date: Date; let icon: String
        let color: Color; let title: String; let subtitle: String
    }

    private var activityTimelineCard: some View {
        let callItems = liveContact.calls.map { log in
            ActivityItem(date: log.date, icon: "phone.fill", color: Color.brg, // brg for all call items
                        title: log.outcome.rawValue,
                        subtitle: [log.nextStep != NextStepType.none ? "Next: \(log.nextStep.rawValue)" : "",
                                   log.notes].filter { !$0.isEmpty }.joined(separator: " · "))
        }
        let saleItems = pipeline.saleLogs.filter { PipelineStore.contactKey($0.contactName) == contact.id }.map { log in
            ActivityItem(date: log.date, icon: "star.fill", color: Color.brg, title: log.type.rawValue, subtitle: log.notes)
        }
        let all = (callItems + saleItems).sorted { $0.date > $1.date }
        guard !all.isEmpty else { return AnyView(EmptyView()) }
        return AnyView(CRMCard(title: "Activity Timeline") {
            VStack(spacing: 12) {
                ForEach(all.prefix(8)) { item in
                    TimelineRow(icon: item.icon, iconColor: Color.brg, title: item.title, subtitle: item.subtitle, date: item.date)
                    if item.id != all.prefix(8).last?.id { Divider() }
                }
            }
        })
    }
}

// MARK: - Placeholder Views for missing sheets
struct AddContactChoiceSheet: View {
    @Binding var showNewContact: Bool
    @Binding var showImportPicker: Bool
    var body: some View {
        VStack(spacing: 20) {
            Text("AddContactChoiceSheet Placeholder")
            Button("Show New Contact") { showNewContact = true }
            Button("Show Import Picker") { showImportPicker = true }
            Button("Dismiss") { showNewContact = false; showImportPicker = false }
        }.padding()
    }
}

struct ContactEditView: View {
    let contact: PipelineContact
    let pipeline: PipelineStore
    var onSave: (ContactMetadata) -> Void
    var body: some View {
        VStack(spacing: 20) {
            Text("ContactEditView Placeholder")
            Button("Save") {
                onSave(contact.metadata ?? ContactMetadata(id: contact.id, displayName: contact.displayName))
            }
        }.padding()
    }
}

struct LogCallSheet: View {
    let contact: PipelineContact
    let pipeline: PipelineStore
    var body: some View {
        VStack(spacing: 20) {
            Text("LogCallSheet Placeholder")
            Button("Dismiss") {}
        }.padding()
    }
}

struct LogActivitySheet: View {
    let contact: PipelineContact
    let pipeline: PipelineStore
    var body: some View {
        VStack(spacing: 20) {
            Text("LogActivitySheet Placeholder")
            Button("Dismiss") {}
        }.padding()
    }
}

// MARK: - No Highlight Button Style
struct NoHighlightButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Contact Info Card (restored, styled)
private struct ContactInfoCard: View {
    let phone: String
    let email: String
    let company: String
    var body: some View {
        CRMCard(title: "Contact Info") {
            VStack(alignment: .leading, spacing: 12) {
                if !phone.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "phone.fill").foregroundStyle(Color.brg)
                        Text(phone).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
                    }
                }
                if !email.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "envelope.fill").foregroundStyle(Color.brg)
                        Text(email).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
                    }
                }
                if !company.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "building.2.fill").foregroundStyle(Color.brg)
                        Text(company).font(.system(size: 15, weight: .medium)).foregroundStyle(.primary)
                    }
                }
            }
        }
    }
}
