import SwiftUI

struct LogOutcomeView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pipeline: PipelineStore
    var onSave: (() -> Void)? = nil
    var prefillContact: String = ""

    @State private var type: SaleOutcomeType = .listingSigned
    @State private var contactName = ""
    @State private var property = ""
    @State private var valueText = ""
    @State private var priceMinText = ""
    @State private var priceMaxText = ""
    @State private var selectedRegions: Set<String> = []
    @State private var showRegionPicker = false
    @State private var referralSource: ReferralSource = .existingClient
    @State private var referralSourceName = ""
    @State private var referredClientName = ""
    @State private var showSourcePicker = false
    @State private var showReferredPicker = false
    // Closed deal
    @State private var buyerName = ""
    @State private var sellerName = ""
    @State private var listedPriceText = ""
    @State private var soldPriceText = ""
    @State private var showBuyerPicker = false
    @State private var showSellerPicker = false
    // Showing done
    @State private var showingAddress = ""
    @State private var showingFeedback: ShowingFeedback? = nil
    // Buyer context (urgency / market time)
    @State private var showBuyerContext = false
    @State private var buyerMonthsInMarket: Int = 0
    @State private var buyerUrgency: BuyerUrgency? = nil
    @State private var buyerUrgencyNote = ""
    @State private var notes = ""
    @State private var selectedDealID: UUID? = nil
    @State private var showContactPicker = false
    @State private var keyboardVisible = false
    @FocusState private var isAnyFieldFocused: Bool

    private var knownContacts: [String] {
        Array(Set(pipeline.callLogs
            .map { $0.contactName.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty })).sorted()
    }

    private var matchingDeals: [PipelineDeal] {
        guard !contactName.isEmpty else { return [] }
        let q = contactName.lowercased()
        return pipeline.deals.filter { $0.contactName.lowercased().contains(q) }
    }

    private var regionSummary: String {
        if selectedRegions.isEmpty { return "Select regions" }
        if selectedRegions.count == 1 { return selectedRegions.first! }
        return "\(selectedRegions.count) regions selected"
    }

    private var canSave: Bool {
        switch type {
        case .listingSigned:
            return !contactName.isEmpty && !property.isEmpty && !valueText.isEmpty
        case .offerSent:
            return !contactName.isEmpty && !priceMinText.isEmpty && !priceMaxText.isEmpty && !selectedRegions.isEmpty
        case .showingDone:
            return !contactName.isEmpty && !showingAddress.isEmpty && showingFeedback != nil
        case .closedDeal:
            return !buyerName.isEmpty && !sellerName.isEmpty && !listedPriceText.isEmpty && !soldPriceText.isEmpty && !selectedRegions.isEmpty
        case .referralReceived:
            return !referralSourceName.isEmpty && !referredClientName.isEmpty
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    outcomeTypeCard
                    if type != .referralReceived && type != .closedDeal { clientCard }
                    if type == .referralReceived { referralCards }
                    priceAndRegionCards
                    if type == .showingDone || type == .offerSent { buyerContextCard }
                    OutcomeCard(title: "Notes (optional)") {
                        TextField("Any context…", text: $notes, axis: .vertical)
                            .textFieldStyle(.plain).lineLimit(2...5)
                            .focused($isAnyFieldFocused)
                    }
                    SaveButton(enabled: canSave) { saveSaleLog() }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Log Activity")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !prefillContact.isEmpty {
                    contactName       = prefillContact
                    buyerName         = prefillContact
                    referralSourceName = prefillContact
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { keyboardVisible = true }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { keyboardVisible = false }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if keyboardVisible {
                HStack {
                    Spacer()
                    Button {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.45)
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [Color.white.opacity(0.55), Color.white.opacity(0.1), Color.black.opacity(0.25)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    ), lineWidth: 1.5
                                )
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        .shadow(color: .white.opacity(0.06), radius: 2, x: 0, y: -1)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.vertical, 12)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Sub-sections

    private var outcomeTypeCard: some View {
        OutcomeCard(title: "Outcome type") {
            VStack(spacing: 8) {
                ForEach(SaleOutcomeType.allCases) { opt in
                    OutcomeRow(label: opt.rawValue, isSelected: type == opt) { type = opt }
                }
            }
        }
    }

    private var clientCard: some View {
        OutcomeCard(title: "Client") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(contactName.isEmpty ? Color(.tertiaryLabel) : Color.accentColor)
                    if contactName.isEmpty {
                        Text("Select or add client").font(.system(size: 15)).foregroundStyle(.secondary)
                    } else {
                        Text(contactName).font(.system(size: 15, weight: .semibold))
                    }
                    Spacer()
                    if !contactName.isEmpty {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.tertiaryLabel))
                            .onTapGesture { contactName = "" }
                    } else {
                        Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { showContactPicker = true }

                if !matchingDeals.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Link to deal:").font(.caption).foregroundStyle(.secondary)
                        ForEach(matchingDeals) { deal in
                            HStack(spacing: 8) {
                                Image(systemName: selectedDealID == deal.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedDealID == deal.id ? Color.accentColor : .secondary)
                                    .font(.system(size: 14))
                                Text("\(deal.contactName) · \(deal.stage.rawValue)")
                                    .font(.system(size: 13))
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDealID = deal.id
                                if contactName.isEmpty { contactName = deal.contactName }
                                if property.isEmpty    { property = deal.propertyDescription }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $showContactPicker) {
            ClientPickerSheet(knownContacts: knownContacts, selected: $contactName)
        }
    }

    @ViewBuilder
    private var referralCards: some View {
        OutcomeCard(title: "Referral source") {
            VStack(spacing: 8) {
                ForEach(ReferralSource.allCases) { src in
                    OutcomeRow(label: src.rawValue, isSelected: referralSource == src) { referralSource = src }
                }
            }
        }
        OutcomeCard(title: "Source name") {
            ClientPickerRow(
                label: referralSource == .existingClient ? "Select referring client" : "Select referring person",
                name: referralSourceName,
                onClear: { referralSourceName = "" },
                onTap: { showSourcePicker = true }
            )
        }
        .sheet(isPresented: $showSourcePicker) {
            ClientPickerSheet(knownContacts: knownContacts, selected: $referralSourceName)
        }
        OutcomeCard(title: "Referred client") {
            ClientPickerRow(
                label: "Select new client",
                name: referredClientName,
                onClear: { referredClientName = "" },
                onTap: { showReferredPicker = true }
            )
        }
        .sheet(isPresented: $showReferredPicker) {
            ClientPickerSheet(knownContacts: knownContacts, selected: $referredClientName)
        }
    }

    @ViewBuilder
    private var priceAndRegionCards: some View {
        if type == .offerSent || type == .referralReceived {
            OutcomeCard(title: "Price range") {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Min (€)").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. 150000", text: $priceMinText)
                            .font(.system(size: 15)).textFieldStyle(.plain).keyboardType(.decimalPad)
                    }
                    Divider().frame(height: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Max (€)").font(.caption).foregroundStyle(.secondary)
                        TextField("e.g. 250000", text: $priceMaxText)
                            .font(.system(size: 15)).textFieldStyle(.plain).keyboardType(.decimalPad)
                    }
                }
            }
            OutcomeCard(title: "Regions / locations") {
                HStack {
                    Text(regionSummary).font(.system(size: 15))
                        .foregroundStyle(selectedRegions.isEmpty ? .secondary : .primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
                .onTapGesture { showRegionPicker = true }
            }
            .sheet(isPresented: $showRegionPicker) { RegionPickerSheet(selected: $selectedRegions) }
        } else if type == .showingDone {
            showingDoneCards
        } else if type == .closedDeal {
            closedDealCards
        } else {
            OutcomeCard(title: "Property & value") {
                VStack(spacing: 14) {
                    LabeledField(label: "Property", placeholder: "e.g. 2BR, Gornji Grad", text: $property)
                    Divider()
                    LabeledField(label: "Value (€)", placeholder: "e.g. 180000", text: $valueText)
                        .keyboardType(.decimalPad)
                }
            }
        }
    }

    @ViewBuilder
    private var showingDoneCards: some View {
        OutcomeCard(title: "Property shown") {
            LabeledField(label: "Address / description", placeholder: "e.g. 3BR Opatija, Ul. Maršala Tita 12",
                         text: $showingAddress)
        }
        OutcomeCard(title: "Client feedback") {
            VStack(spacing: 8) {
                ForEach(ShowingFeedback.allCases) { fb in
                    OutcomeRow(
                        icon: fb.icon, iconColor: fb.color,
                        label: fb.rawValue,
                        isSelected: showingFeedback == fb
                    ) { showingFeedback = fb }
                }
            }
        }
    }

    @ViewBuilder
    private var buyerContextCard: some View {
        OutcomeCard(title: "Buyer context (optional)") {
            VStack(alignment: .leading, spacing: 14) {
                // Months in market
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Months searching in market")
                            .font(.system(size: 13, weight: .medium))
                        Spacer()
                        Text(buyerMonthsInMarket == 0 ? "Not set" : "\(buyerMonthsInMarket) mo")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(buyerMonthsInMarket == 0 ? .secondary : .primary)
                    }
                    Slider(value: Binding(
                        get: { Double(buyerMonthsInMarket) },
                        set: { buyerMonthsInMarket = Int($0) }
                    ), in: 0...24, step: 1)
                    .tint(Color.accentColor)
                    HStack {
                        Text("0").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text("24 mo").font(.caption2).foregroundStyle(.tertiary)
                    }
                }

                Divider()

                // Urgency level
                VStack(alignment: .leading, spacing: 8) {
                    Text("Urgency level").font(.system(size: 13, weight: .medium))
                    ForEach(BuyerUrgency.allCases) { u in
                        OutcomeRow(
                            icon: u.icon, iconColor: u.color,
                            label: u.rawValue,
                            isSelected: buyerUrgency == u
                        ) { buyerUrgency = buyerUrgency == u ? nil : u }
                    }
                }

                if buyerUrgency != nil {
                    Divider()
                    LabeledField(
                        label: "Urgency note (optional)",
                        placeholder: "e.g. Expecting child, must move by April",
                        text: $buyerUrgencyNote
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var closedDealCards: some View {
        // Buyer
        OutcomeCard(title: "Buyer") {
            ClientPickerRow(
                label: "Select or add buyer",
                name: buyerName,
                onClear: { buyerName = "" },
                onTap: { showBuyerPicker = true }
            )
        }
        .sheet(isPresented: $showBuyerPicker) {
            ClientPickerSheet(knownContacts: knownContacts, selected: $buyerName)
        }

        // Seller
        OutcomeCard(title: "Seller") {
            ClientPickerRow(
                label: "Select or add seller",
                name: sellerName,
                onClear: { sellerName = "" },
                onTap: { showSellerPicker = true }
            )
        }
        .sheet(isPresented: $showSellerPicker) {
            ClientPickerSheet(knownContacts: knownContacts, selected: $sellerName)
        }

        // Prices
        OutcomeCard(title: "Price") {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Listed (€)").font(.caption).foregroundStyle(.secondary)
                    TextField("e.g. 200000", text: $listedPriceText)
                        .font(.system(size: 15)).textFieldStyle(.plain).keyboardType(.decimalPad)
                }
                Divider().frame(height: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sold (€)").font(.caption).foregroundStyle(.secondary)
                    TextField("e.g. 195000", text: $soldPriceText)
                        .font(.system(size: 15)).textFieldStyle(.plain).keyboardType(.decimalPad)
                }
            }
        }

        // Location
        OutcomeCard(title: "Location") {
            HStack {
                Text(regionSummary).font(.system(size: 15))
                    .foregroundStyle(selectedRegions.isEmpty ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
            .onTapGesture { showRegionPicker = true }
        }
        .sheet(isPresented: $showRegionPicker) { RegionPickerSheet(selected: $selectedRegions) }
    }

    private func saveSaleLog() {
        var log = SaleLog(type: type)
        log.date = Date()
        log.notes = notes
        log.dealID = selectedDealID
        // Buyer context (applies to showing + offer)
        if buyerMonthsInMarket > 0 { log.buyerMonthsInMarket = buyerMonthsInMarket }
        if let u = buyerUrgency { log.buyerUrgencyLevel = u }
        log.buyerUrgencyNote = buyerUrgencyNote
        switch type {
        case .listingSigned:
            log.contactName = contactName
            log.propertyDescription = property
            log.valueEUR = Double(valueText.replacingOccurrences(of: ",", with: "."))
        case .offerSent:
            log.contactName = contactName
            log.valuePriceMin = Double(priceMinText.replacingOccurrences(of: ",", with: "."))
            log.valuePriceMax = Double(priceMaxText.replacingOccurrences(of: ",", with: "."))
            log.selectedRegions = Array(selectedRegions)
        case .showingDone:
            log.contactName = contactName
            log.showingPropertyAddress = showingAddress
            log.showingFeedback = showingFeedback
        case .closedDeal:
            log.buyerName = buyerName
            log.sellerName = sellerName
            log.listedPriceEUR = Double(listedPriceText.replacingOccurrences(of: ",", with: "."))
            log.soldPriceEUR = Double(soldPriceText.replacingOccurrences(of: ",", with: "."))
            log.selectedRegions = Array(selectedRegions)
        case .referralReceived:
            log.referralSource = referralSource
            log.referralSourceName = referralSourceName
            log.referredClientName = referredClientName
        }
        if let dealID = selectedDealID,
           let idx = pipeline.deals.firstIndex(where: { $0.id == dealID }) {
            var deal = pipeline.deals[idx]
            let stage: DealStage? = {
                switch type {
                case .listingSigned:  return .listing
                case .offerSent:      return .proposal
                case .showingDone:    return .appointment
                case .closedDeal:     return .closed
                default:              return nil
                }
            }()
            if let s = stage { deal.stage = s; deal.updatedAt = Date(); pipeline.updateDeal(deal) }
        }
        pipeline.addSale(log)
        HapticManager.success()
        onSave?()
        dismiss()
    }
}

// MARK: - Region Picker Sheet
private struct RegionPickerSheet: View {
    @Binding var selected: Set<String>
    @Environment(\.dismiss) private var dismiss

    @State private var expandedRegion: String? = nil
    @State private var searchText = ""

    private let regionIcons: [String: String] = [
        "otok_krk":           "water.waves",
        "rijeka_i_okolica":   "building.2.fill",
        "crikvenicka_rivijera": "sun.horizon.fill",
        "opatija_i_okolica":  "leaf.fill",
        "istra":              "map.fill"
    ]

    private let regionColors: [String: Color] = [
        "otok_krk":           .blue,
        "rijeka_i_okolica":   .indigo,
        "crikvenicka_rivijera": .orange,
        "opatija_i_okolica":  .green,
        "istra":              .teal
    ]

    private var filteredRegions: [CroatianRegion] {
        guard !searchText.isEmpty else { return CroatianRegions.all }
        return CroatianRegions.all.compactMap { region in
            let matchingPlaces = region.places.filter {
                $0.localizedCaseInsensitiveContains(searchText)
            }
            guard !matchingPlaces.isEmpty ||
                  region.name.localizedCaseInsensitiveContains(searchText)
            else { return nil }
            return region
        }
    }

    private var totalSelected: Int { selected.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Search bar ────────────────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                    TextField("Search towns, villages…", text: $searchText)
                        .font(.system(size: 15))
                    if !searchText.isEmpty {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .onTapGesture { searchText = "" }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

                // ── Selected chips ────────────────────────────────────
                if !selected.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selected).sorted(), id: \.self) { place in
                                HStack(spacing: 5) {
                                    Text(place)
                                        .font(.system(size: 12, weight: .medium))
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .semibold))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.12))
                                .foregroundStyle(Color.accentColor)
                                .clipShape(Capsule())
                                .onTapGesture { selected.remove(place) }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                    }
                    .background(Color(.secondarySystemBackground))

                    Divider()
                }

                // ── Region accordion ──────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 10) {
                        ForEach(filteredRegions) { region in
                            let color = regionColors[region.id] ?? .accentColor
                            let icon  = regionIcons[region.id]  ?? "mappin.circle.fill"
                            let isExpanded = expandedRegion == region.id
                            let placesToShow: [String] = {
                                let base = region.places.sorted()
                                guard !searchText.isEmpty else { return base }
                                return base.filter { $0.localizedCaseInsensitiveContains(searchText) }
                            }()
                            let selectedCount = region.places.filter { selected.contains($0) }.count
                            let allSelected   = region.places.allSatisfy { selected.contains($0) }

                            VStack(spacing: 0) {
                                // ── Region header ─────────────────────
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(color.opacity(0.12))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: icon)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(color)
                                    }

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(region.name)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(.primary)
                                        Text("\(region.places.count) locations")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    // Select-all toggle
                                    if isExpanded {
                                        Text(allSelected ? "Deselect all" : "Select all")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(color)
                                            .onTapGesture {
                                                if allSelected {
                                                    region.places.forEach { selected.remove($0) }
                                                } else {
                                                    region.places.forEach { selected.insert($0) }
                                                }
                                            }
                                    }

                                    // Selected count badge
                                    if selectedCount > 0 {
                                        Text("\(selectedCount)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(minWidth: 22, minHeight: 22)
                                            .background(color)
                                            .clipShape(Circle())
                                    }

                                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        expandedRegion = isExpanded ? nil : region.id
                                    }
                                }

                                // ── Place grid ────────────────────────
                                if isExpanded {
                                    Divider().padding(.horizontal, 14)

                                    let columns = [
                                        GridItem(.flexible(), spacing: 8),
                                        GridItem(.flexible(), spacing: 8)
                                    ]

                                    LazyVGrid(columns: columns, spacing: 8) {
                                        ForEach(placesToShow, id: \.self) { place in
                                            let isOn = selected.contains(place)
                                            HStack(spacing: 6) {
                                                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundStyle(isOn ? color : Color(.tertiaryLabel))
                                                Text(place)
                                                    .font(.system(size: 13, weight: isOn ? .semibold : .regular))
                                                    .foregroundStyle(isOn ? .primary : .secondary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.85)
                                                Spacer(minLength: 0)
                                            }
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .background(isOn ? color.opacity(0.08) : Color(.tertiarySystemFill))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .animation(.easeInOut(duration: 0.15), value: isOn)
                                            .onTapGesture {
                                                if isOn { selected.remove(place) }
                                                else    { selected.insert(place) }
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 32)
                }
                .background(Color(.systemGroupedBackground))
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(totalSelected == 0
                ? "Select locations"
                : "\(totalSelected) selected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear") {
                        withAnimation { selected.removeAll() }
                    }
                        .foregroundStyle(selected.isEmpty ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
                    .disabled(selected.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Client Picker Sheet
private struct ClientPickerSheet: View {
    let knownContacts: [String]
    @Binding var selected: String
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var showingNewClientField = false
    @State private var newClientName = ""
    @FocusState private var newClientFocused: Bool

    private var filtered: [String] {
        guard !searchText.isEmpty else { return knownContacts }
        return knownContacts.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if knownContacts.isEmpty {
                    // ── Empty state — center "Add new" ─────────────────
                    VStack(spacing: 24) {
                        Spacer()
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.1))
                                    .frame(width: 72, height: 72)
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 32, weight: .medium))
                                    .foregroundStyle(Color.accentColor)
                            }
                            Text("No clients yet")
                                .font(.system(size: 20, weight: .bold))
                            Text("Add your first client to get started.")
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 40)

                        newClientInputCard

                        Spacer()
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
                    .onAppear { showingNewClientField = true; newClientFocused = true }

                } else {
                    // ── List with search ───────────────────────────────
                    VStack(spacing: 0) {
                        // Search bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                            TextField("Search clients…", text: $searchText)
                                .font(.system(size: 15))
                            if !searchText.isEmpty {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .onTapGesture { searchText = "" }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 8) {

                                // ── Add new client card ────────────────
                                if showingNewClientField {
                                    newClientInputCard
                                        .padding(.horizontal, 16)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                } else {
                                    addNewButton
                                        .padding(.horizontal, 16)
                                }

                                // ── Existing contacts ──────────────────
                                if filtered.isEmpty && !searchText.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "person.slash")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.secondary)
                                        Text("No match for \"\(searchText)\"")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 40)
                                } else {
                                    VStack(spacing: 0) {
                                        ForEach(Array(filtered.enumerated()), id: \.element) { idx, name in
                                            VStack(spacing: 0) {
                                                HStack(spacing: 12) {
                                                    ZStack {
                                                        Circle()
                                                            .fill(avatarColor(for: name).opacity(0.12))
                                                            .frame(width: 40, height: 40)
                                                        Text(initials(for: name))
                                                            .font(.system(size: 14, weight: .semibold))
                                                            .foregroundStyle(avatarColor(for: name))
                                                    }
                                                    Text(name)
                                                        .font(.system(size: 15, weight: .medium))
                                                        .foregroundStyle(.primary)
                                                    Spacer()
                                                    if selected == name {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundStyle(Color.accentColor)
                                                            .font(.system(size: 18))
                                                    }
                                                }
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 12)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    HapticManager.impact()
                                                    selected = name
                                                    dismiss()
                                                }

                                                if idx < filtered.count - 1 {
                                                    Divider().padding(.leading, 68)
                                                }
                                            }
                                        }
                                    }
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 18))
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 32)
                            .padding(.top, 4)
                        }
                        .background(Color(.systemGroupedBackground))
                        .scrollDismissesKeyboard(.interactively)
                    }
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
                }
            }
            .navigationTitle("Select client")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // ── Add new button ─────────────────────────────────────────────────
    private var addNewButton: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            Text("Add new client")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.accentColor)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.accentColor.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                showingNewClientField = true
                newClientFocused = true
            }
        }
    }

    // ── New client input card ──────────────────────────────────────────
    private var newClientInputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NEW CLIENT")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .kerning(0.5)
                Spacer()
                if !knownContacts.isEmpty {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(.tertiaryLabel))
                        .font(.system(size: 16))
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                showingNewClientField = false
                                newClientName = ""
                                newClientFocused = false
                            }
                        }
                }
            }

            HStack(spacing: 10) {
                TextField("Full name", text: $newClientName)
                    .font(.system(size: 16))
                    .textFieldStyle(.plain)
                    .focused($newClientFocused)
                    .submitLabel(.done)
                    .onSubmit { confirmNewClient() }

                if !newClientName.isEmpty {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color(.tertiaryLabel))
                        .onTapGesture { newClientName = "" }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                confirmNewClient()
            } label: {
                Text("Confirm")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(newClientName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color(.tertiarySystemFill)
                        : Color.accentColor)
                    .foregroundStyle(newClientName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color(.tertiaryLabel)
                        : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(newClientName.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.accentColor.opacity(0.08), radius: 8, x: 0, y: 2)
    }

    // ── Helpers ────────────────────────────────────────────────────────
    private func confirmNewClient() {
        let name = newClientName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        HapticManager.success()
        selected = name
        dismiss()
    }

    private func initials(for name: String) -> String {
        let parts = name.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }

    private let avatarColors: [Color] = [
        .blue, .indigo, .purple, .pink, .orange, .teal, .green, .cyan
    ]

    private func avatarColor(for name: String) -> Color {
        let idx = abs(name.hashValue) % avatarColors.count
        return avatarColors[idx]
    }
}

// MARK: - Shared subviews

private struct OutcomeCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .kerning(0.4)
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

private struct OutcomeRow: View {
    var icon: String? = nil
    var iconColor: Color = .accentColor
    let label: String
    let isSelected: Bool
    let onTap: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isSelected ? iconColor : iconColor.opacity(0.4))
                    .frame(width: 20)
            }
            Text(label).font(.system(size: 15)).foregroundStyle(isSelected ? .primary : .secondary)
            Spacer()
            ZStack {
                Circle().stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.2), lineWidth: 1.5).frame(width: 20, height: 20)
                if isSelected { Circle().fill(Color.accentColor).frame(width: 12, height: 12) }
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.07) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .onTapGesture { HapticManager.impact(); onTap() }
    }
}

private struct LabeledField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            TextField(placeholder, text: $text).font(.system(size: 15)).textFieldStyle(.plain)
        }
    }
}



private struct SaveButton: View {
    var enabled: Bool = true
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("Save")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enabled ? Color.accentColor : Color(.tertiarySystemFill))
                .foregroundStyle(enabled ? Color.white : Color(.tertiaryLabel))
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .padding(.top, 4)
    }
}

private struct ClientPickerRow: View {
    let label: String
    let name: String
    let onClear: () -> Void
    let onTap: () -> Void
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(name.isEmpty ? Color(.tertiaryLabel) : Color.accentColor)
            if name.isEmpty {
                Text(label).font(.system(size: 15)).foregroundStyle(.secondary)
            } else {
                Text(name).font(.system(size: 15, weight: .semibold))
            }
            Spacer()
            if name.isEmpty {
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(.tertiary)
            } else {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Color(.tertiaryLabel))
                    .onTapGesture { onClear() }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }
}
