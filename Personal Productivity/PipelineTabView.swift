import SwiftUI
import Charts

struct PipelineTabView: View {

    @StateObject private var pipeline = PipelineStore.shared
    @EnvironmentObject var taskStore: TaskStore

    // Use an enum value for navigation so NavigationLink(value:) is used
    // instead of isPresented — avoids the double-press bug with bool destinations.
    enum Destination: Hashable { case contacts }

    @State private var showCallWizard    = false
    @State private var showLogOutcome    = false
    @State private var showAllCalls      = false
    @State private var showDeals         = false
    @State private var showFollowUpDetail = false
    @State private var showSuccessBanner = false
    @State private var successMessage    = ""
    @State private var selectedRange: StatRange = .daily
    @State private var animateProgress   = false

    enum StatRange: String, CaseIterable, Identifiable {
        case daily = "Today"; case weekly = "Week"; case monthly = "Month"
        var id: String { rawValue }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        heroHeader
                            .padding(.bottom, 24)

                        VStack(spacing: 20) {
                            primaryActions

                            followUpCard
                            dialConsistencyCard

                            sectionLabel("PIPELINE HEALTH", icon: "arrow.triangle.merge")
                            funnelCard
                            predictionsCard

                            sectionLabel("MY NUMBERS", icon: "chart.bar.doc.horizontal")
                            myNumbersSection

                            sectionLabel("INSIGHTS", icon: "lightbulb.fill")
                            leadSourceROICard
                            sourceConversionCard
                            if !pipeline.deals.isEmpty {
                                pipelineVelocityCard
                            }

                            if !pipeline.deals.isEmpty {
                                sectionLabel("DEALS", icon: "house.fill")
                                dealsPreviewCard
                            }

                            sectionLabel("RECENT CALLS", icon: "clock.fill")
                            recentCallsCard
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 48)
                    }
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
                .onAppear {
                    withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                        animateProgress = true
                    }
                }

                if showSuccessBanner {
                    successBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(10)
                }
            }
            .navigationTitle("Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: Destination.contacts) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
            .navigationDestination(for: Destination.self) { dest in
                if dest == .contacts {
                    ContactHistoryView(pipeline: pipeline).environmentObject(taskStore)
                }
            }
            .navigationDestination(for: PipelineContact.self) { contact in
                ContactDetailView(contact: contact, pipeline: pipeline)
                    .environmentObject(taskStore)
            }
        }
        .sheet(isPresented: $showCallWizard) {
            CallWizardView(pipeline: pipeline)
                .environmentObject(taskStore)
                .onDisappear {
                    if let last = pipeline.callLogs.first,
                       abs(last.date.timeIntervalSinceNow) < 5 {
                        triggerSuccess("Call logged — \(pipeline.dialsToday) dials today 🎯")
                    }
                }
        }
        .sheet(isPresented: $showLogOutcome) {
            LogOutcomeView(pipeline: pipeline, onSave: { triggerSuccess("Outcome logged ✓") })
        }
        .sheet(isPresented: $showAllCalls) {
            AllCallsView(pipeline: pipeline).environmentObject(taskStore)
        }
        .sheet(isPresented: $showDeals) {
            DealsView(pipeline: pipeline)
        }
    }

    // MARK: - Hero header

    private var heroListingsToday: Int {
        pipeline.saleLogs.filter { Calendar.current.isDateInToday($0.date) && $0.type == .listingSigned }.count
    }
    private var heroOffersToday: Int {
        pipeline.saleLogs.filter { Calendar.current.isDateInToday($0.date) && $0.type == .offerSent }.count
    }

    private var dialProgress: Double {
        guard pipeline.dailyDialTarget > 0 else { return 0 }
        return min(1.0, Double(pipeline.dialsToday) / Double(pipeline.dailyDialTarget))
    }

    private var weekProgress: Double {
        let weeklyTarget = pipeline.dailyDialTarget * 5
        guard weeklyTarget > 0 else { return 0 }
        let weekDone = weeklyTarget - max(0, pipeline.remainingDialsThisWeek)
        return min(1.0, Double(weekDone) / Double(weeklyTarget))
    }

    private var heroHeader: some View {
        let dailyRemaining  = max(0, pipeline.dailyDialTarget - pipeline.dialsToday)
        let weekRemaining   = max(0, pipeline.remainingDialsThisWeek)
        let dailyDone       = dialProgress >= 1
        let weeklyDone      = weekRemaining == 0

        return VStack(spacing: 0) {
            // ── Top section: rings + labels ─────────────────────────
            HStack(alignment: .center, spacing: 18) {

                // Double-ring: outer = weekly, inner = daily
                ZStack {
                    // Weekly ring (outer)
                    Circle()
                        .stroke(Color.brg.opacity(0.15), lineWidth: 5)
                        .frame(width: 96, height: 96)
                    Circle()
                        .trim(from: 0, to: animateProgress ? weekProgress : 0)
                        .stroke(
                            weeklyDone ? Color.brg : Color(uiColor: .secondaryLabel),
                            style: StrokeStyle(lineWidth: 5, lineCap: .round)
                        )
                        .frame(width: 96, height: 96)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 1.0, dampingFraction: 0.75).delay(0.05), value: animateProgress)

                    // Daily ring (inner)
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                        .frame(width: 76, height: 76)
                    Circle()
                        .trim(from: 0, to: animateProgress ? dialProgress : 0)
                        .stroke(
                            dailyDone ? Color.brg : Color.brg.opacity(0.4),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round)
                        )
                        .frame(width: 76, height: 76)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.9, dampingFraction: 0.75).delay(0.15), value: animateProgress)

                    // Centre count
                    VStack(spacing: 0) {
                        Text("\(pipeline.dialsToday)")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text("/ \(pipeline.dailyDialTarget)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                // Label stack
                VStack(alignment: .leading, spacing: 6) {
                    Text("Dials Today")
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(.primary)

                    // Daily status
                    HStack(spacing: 5) {
                        Image(systemName: dailyDone ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(dailyDone ? Color.brg : Color(uiColor: .secondaryLabel))
                        Text(dailyDone ? "Daily target hit!" : "\(dailyRemaining) remaining today")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(dailyDone ? Color(uiColor: .label) : .secondary)
                    }

                    // Weekly status — matches daily style exactly
                    HStack(spacing: 5) {
                        Image(systemName: weeklyDone ? "checkmark.circle.fill" : "circle.dotted")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(weeklyDone ? Color.brg : Color(uiColor: .secondaryLabel))
                        Text(weeklyDone ? "Weekly target hit!" : "\(weekRemaining) remaining this week")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(weeklyDone ? Color(uiColor: .label) : .secondary)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // ── Divider ──────────────────────────────────────────────
            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)
                .padding(.horizontal, 16)

            // ── Bottom: 4 stats ──────────────────────────────────────
            HStack(spacing: 0) {
                heroBottomStat(value: "\(heroListingsToday)",        label: "Listings",  icon: "building.2.fill",         color: .brg,      atTarget: heroListingsToday > 0)
                Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1, height: 28)
                heroBottomStat(value: "\(heroOffersToday)",          label: "Offers",    icon: "envelope.badge.fill",      color: .brg,      atTarget: heroOffersToday > 0)
                Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1, height: 28)
                heroBottomStat(value: "\(pipeline.meetingsToday)",   label: "Meetings",  icon: "calendar.badge.checkmark", color: .brgMuted, atTarget: pipeline.meetingsToday > 0)
                Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1, height: 28)
                heroBottomStat(value: "\(pipeline.newContactsToday)",label: "Contacts",  icon: "person.badge.plus",        color: .secondary, atTarget: pipeline.newContactsToday > 0)
            }
            .padding(.vertical, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    private func heroBottomStat(value: String, label: String, icon: String, color: Color, atTarget: Bool) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(atTarget ? color : Color(uiColor: .secondaryLabel))
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section label

    private func sectionLabel(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.brgBright)
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .kerning(0.5)
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Success banner

    private var successBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.brg).font(.system(size: 16, weight: .semibold))
            Text(successMessage)
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
        .padding(.top, 8)
    }

    private func triggerSuccess(_ message: String) {
        successMessage = message
        withAnimation(.spring(response: 0.4)) { showSuccessBanner = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.3)) { showSuccessBanner = false }
        }
    }

    private var primaryActions: some View {
        HStack(spacing: 12) {
            // New Call — full-bleed CTA
            Button {
                HapticManager.impact(.medium)
                showCallWizard = true
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(.white.opacity(0.18)).frame(width: 36, height: 36)
                        Image(systemName: "phone.arrow.up.right")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                    }
                    Text("New Call")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 16).padding(.vertical, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(
                    LinearGradient(colors: [Color.brg, Color.brgMuted],
                                   startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.brg.opacity(0.30), radius: 10, x: 0, y: 5)
            }
            .buttonStyle(.plain)

            // Log Outcome — wide enough for single-line label
            Button {
                HapticManager.impact()
                showLogOutcome = true
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(Color.brg.opacity(0.12)).frame(width: 28, height: 28)
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold)).foregroundStyle(Color.brg)
                    }
                    Text("Log Activity")
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .frame(width: 112)
                .frame(maxHeight: .infinity)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .buttonStyle(.plain)
        }
        .frame(height: 70)
    }

    // MARK: - Hot Sheet tile (referenced by HotSheetView)

    private var hotSheetTile: some View {
        NavigationLink {
            HotSheetView(pipeline: pipeline).environmentObject(taskStore)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(pipeline.hotSheetReviewedToday ? Color.brg.opacity(0.10) : Color(uiColor: .tertiarySystemFill))
                            .frame(width: 30, height: 30)
                        Image(systemName: pipeline.hotSheetReviewedToday ? "checkmark.circle.fill" : "newspaper.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(pipeline.hotSheetReviewedToday ? Color.brgBright : Color(uiColor: .secondaryLabel))
                    }
                    Text("Hot Sheet").font(.system(size: 12, weight: .semibold)).foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                Spacer()
                Text(pipeline.hotSheetReviewedToday ? "Reviewed ✓" : "–")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(pipeline.hotSheetReviewedToday ? Color.brg : Color(uiColor: .secondaryLabel))
                    .minimumScaleFactor(0.5).lineLimit(1)
                Text(pipeline.hotSheetReviewedToday ? "done for today" : "tap to review leads")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Funnel card

    private var funnelCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.merge")
                    .font(.system(size: 14, weight: .bold)).foregroundStyle(Color.brgBright)
                Text("Conversion Funnel")
                    .font(.system(size: 15, weight: .bold))
                TooltipButton(text: "How well your calls convert at each stage. Green = above benchmark, orange = below.")
                Spacer()
                Text("All-time data")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.secondary.opacity(0.10))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16).padding(.top, 16)

            // Funnel rows
            VStack(spacing: 4) {
                FunnelRow(
                    icon: "calendar.badge.checkmark", iconColor: .brg,
                    label: "Calls → Appointment",
                    rate: pipeline.callToAppointmentRate, benchmark: 0.01,
                    isEstimated: pipeline.callToAppointmentRateIsEstimated, animate: animateProgress)
                FunnelRow(
                    icon: "doc.text.fill", iconColor: .brg,
                    label: "Appointment → Proposal",
                    rate: pipeline.appointmentToProposalRate, benchmark: 0.20,
                    isEstimated: pipeline.appointmentToProposalRateIsEstimated, animate: animateProgress)
                FunnelRow(
                    icon: "house.fill", iconColor: .brg,
                    label: "Proposal → Listing",
                    rate: pipeline.proposalToListingRate, benchmark: 0.20,
                    isEstimated: pipeline.proposalToListingRateIsEstimated, animate: animateProgress)
                FunnelRow(
                    icon: "checkmark.seal.fill", iconColor: .brg,
                    label: "Lead → Closed",
                    rate: pipeline.overallLeadToClientRate, benchmark: 0.005,
                    isEstimated: pipeline.overallLeadToClientRateIsEstimated, animate: animateProgress)
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - Predictions card

    private var predictionsCard: some View {
        let callsAppt = pipeline.predictedCallsPerAppointment
        let callsSale = pipeline.predictedCallsPerSale
        let apptEstimated = pipeline.callToAppointmentRateIsEstimated
        let saleEstimated = pipeline.overallLeadToClientRateIsEstimated

        return VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9).fill(Color.brg.opacity(0.12)).frame(width: 32, height: 32)
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.brgBright)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text("Predictions")
                        .font(.system(size: 15, weight: .bold))
                    Text(apptEstimated || saleEstimated ? "Based on industry benchmarks" : "Based on your pace")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                TooltipButton(text: "How many calls you typically need to get an appointment or close a sale.")
            }
            .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1).padding(.horizontal, 16)

            // Calls per appointment
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color(uiColor: .tertiarySystemFill)).frame(width: 44, height: 44)
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.brgBright)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calls to get an appointment")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(callsAppt)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text("calls")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                        if apptEstimated {
                            Text("est.")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.45))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1).padding(.horizontal, 16)

            // Calls per sale
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.brg.opacity(0.10)).frame(width: 44, height: 44)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.brgBright)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Calls to close a sale")
                        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text("\(callsSale)")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.primary)
                            .contentTransition(.numericText())
                        Text("calls")
                            .font(.system(size: 14, weight: .medium)).foregroundStyle(.secondary)
                        if saleEstimated {
                            Text("est.")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.45))
                                .clipShape(Capsule())
                        }
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 14)

            // Bottom insight strip
            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1).padding(.horizontal, 16)
            HStack(spacing: 6) {
                Image(systemName: "lightbulb.fill").font(.system(size: 11)).foregroundStyle(Color.brg)
                Text("At \(pipeline.dailyDialTarget) dials/day, expect ~\(max(1, pipeline.dailyDialTarget / max(1, callsAppt))) appointments and ~\(max(0, pipeline.dailyDialTarget / max(1, callsSale))) sales per week.")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    // MARK: - My Numbers

    private var myNumbersSection: some View {
        TrackerCard(title: "My Numbers", icon: "chart.bar.doc.horizontal", iconColor: .brgBright,
            tooltip: "Win rate, revenue, and deal journey from your closed deals.") {
            VStack(spacing: 0) {
                MyNumHeader(icon: "trophy.fill", title: "Win & Revenue")
                if let rate = pipeline.winRate {
                    MyNumWinRow(rate: rate)
                } else {
                    MyNumPlaceholder(icon: "trophy.fill", iconColor: .brg,
                        title: "Win rate", detail: "Mark deals Closed or Lost to see this.")
                }
                Divider().padding(.leading, 56)
                MyNumRevenueRow(value: pipeline.totalRevenueClosed)

                MyNumHeader(icon: "chart.bar.xaxis", title: "Deal Journey")
                if let v = pipeline.avgCallsBeforeContact {
                    MyNumDoubleRow(icon: "phone.arrow.up.right", iconColor: .brg,
                        title: "Calls before first contact", value: v, unit: "calls",
                        detail: "Avg calls per deal before Contacted stage.")
                } else {
                    MyNumPlaceholder(icon: "phone.arrow.up.right", iconColor: .brg,
                        title: "Calls before first contact", detail: "Complete more deals to see this.")
                }
                Divider().padding(.leading, 56)
                if let v = pipeline.avgDaysToClose {
                    MyNumDoubleRow(icon: "calendar", iconColor: .brgMuted,
                        title: "Avg days to close", value: v, unit: "days",
                        detail: "Calendar days from deal creation to closed.")
                } else {
                    MyNumPlaceholder(icon: "calendar", iconColor: .brgMuted,
                        title: "Avg days to close", detail: "Close your first deal to see cycle length.")
                }
            }
        }
    }

    // MARK: - Insight Cards

    private var leadSourceROICard: some View {
        let data = pipeline.leadSourceROI
        let best = data.first
        return TrackerCard(title: "Lead Source ROI", icon: "chart.bar.fill", iconColor: .brgBright,
            tooltip: "Which lead sources produce the most appointments per dial.") {
            VStack(spacing: 0) {
                if data.isEmpty {
                    InsightEmptyRow(message: "Log calls to see which sources convert best.")
                } else {
                    ForEach(Array(data.enumerated()), id: \.element.source) { idx, stat in
                        if idx > 0 { Divider().padding(.leading, 52) }
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill((stat.source == best?.source ? Color.brg : Color.secondary).opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(stat.source == best?.source ? Color.brgBright : Color(uiColor: .secondaryLabel))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(stat.source.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(stat.calls) calls · \(stat.appointments) appts")
                                    .font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f%%", stat.rate * 100))
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(stat.rate > 0.05 ? Color.brg : stat.rate > 0.02 ? Color.brgMuted : Color.red)
                                Text("conv. rate")
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                    }
                    if let best = best, data.count > 1 {
                        Divider()
                        HStack(spacing: 8) {
                            Image(systemName: "lightbulb.fill").font(.system(size: 12, weight: .semibold)).foregroundStyle(Color.brgBright)
                            Text("Focus more on \(best.source.rawValue) — your best converting source.")
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private var sourceConversionCard: some View {
        let data = pipeline.contactToAppointmentBySource
        return TrackerCard(title: "Source Conversion", icon: "calendar.badge.checkmark", iconColor: .brgBright,
            tooltip: "Appointment and sale conversion rate per lead source.") {
            VStack(spacing: 0) {
                if data.isEmpty {
                    InsightEmptyRow(message: "Log calls to see conversion rates by source.")
                } else {
                    ForEach(Array(data.enumerated()), id: \.element.source) { idx, stat in
                        if idx > 0 { Divider().padding(.leading, 16) }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(stat.source.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 16).padding(.top, 11)

                            // Appointment bar
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Appointment")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(stat.appointments)/\(stat.calls)")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    Text(stat.ratePercent)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(stat.rate > 0.05 ? Color.brg : stat.rate > 0.01 ? Color.brgMuted : Color.red)
                                        .frame(width: 44, alignment: .trailing)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.primary.opacity(0.06)).frame(height: 5)
                                        Capsule().fill(LinearGradient(colors: [Color.brg.opacity(0.7), Color.brg], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * min(1, stat.rate / 0.15), height: 5)
                                            .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1), value: animateProgress)
                                    }
                                }
                                .frame(height: 5)
                            }
                            .padding(.horizontal, 16)

                            // Sale bar
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text("Sale")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    Spacer()
                                    Text("\(stat.sales)/\(stat.calls)")
                                        .font(.system(size: 11)).foregroundStyle(.secondary)
                                    Text(stat.saleRatePercent)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(stat.saleRate > 0.02 ? Color.brg : stat.saleRate > 0.005 ? Color.brgMuted : Color.secondary)
                                        .frame(width: 44, alignment: .trailing)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.primary.opacity(0.06)).frame(height: 5)
                                        Capsule().fill(LinearGradient(colors: [Color.brgMuted.opacity(0.7), Color.brgMuted], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * min(1, stat.saleRate / 0.05), height: 5)
                                            .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15), value: animateProgress)
                                    }
                                }
                                .frame(height: 5)
                            }
                            .padding(.horizontal, 16).padding(.bottom, 11)
                        }
                    }
                }
            }
        }
    }

    private var followUpCard: some View {
        let all      = pipeline.smartFollowUps
        let overdue  = all.filter { $0.isOverdue }
        let cal      = Calendar.current
        let dueToday = all.filter { !$0.isOverdue && cal.isDateInToday(
            cal.date(byAdding: .day, value: $0.overdueDays - $0.daysSince, to: $0.lastCallDate) ?? .distantFuture
        )}
        let dueWeek  = all.filter { c in
            guard !c.isOverdue else { return false }
            let daysLeft = c.overdueDays - c.daysSince
            return daysLeft > 0 && daysLeft <= 7
        }
        let urgentColor: Color = overdue.isEmpty ? (dueToday.isEmpty ? Color.brg : .orange) : .red
        let headerIcon = overdue.isEmpty ? (dueToday.isEmpty ? "checkmark.circle.fill" : "clock.badge.exclamationmark") : "exclamationmark.circle.fill"

        return NavigationLink(destination: FollowUpDetailView(pipeline: pipeline).environmentObject(taskStore)) {
            VStack(spacing: 0) {
                // ── Header ───────────────────────────────────────────
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10).fill(urgentColor.opacity(0.12)).frame(width: 36, height: 36)
                        Image(systemName: headerIcon)
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(urgentColor)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Follow-Up Tracker")
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.primary)
                        Text(all.isEmpty ? "All caught up" : "\(all.count) contact\(all.count == 1 ? "" : "s") need attention")
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(uiColor: .secondaryLabel))
                }
                .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 14)

                if all.isEmpty {
                    // Empty state
                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1).padding(.horizontal, 16)
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.brg).font(.system(size: 16))
                        Text("All follow-ups are current. Great work.")
                            .font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                } else {
                    // ── 4-stat row ───────────────────────────────────
                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1).padding(.horizontal, 16)
                    HStack(spacing: 0) {
                        followUpStat(value: overdue.count, label: "Overdue", color: overdue.isEmpty ? .secondary : .red)
                        Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 1, height: 32)
                        followUpStat(value: dueToday.count, label: "Due today", color: dueToday.isEmpty ? .secondary : .orange)
                        Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 1, height: 32)
                        followUpStat(value: dueWeek.count, label: "This week", color: dueWeek.isEmpty ? .secondary : Color(red: 0.8, green: 0.65, blue: 0))
                        Rectangle().fill(Color.primary.opacity(0.06)).frame(width: 1, height: 32)
                        followUpStat(value: all.count, label: "Total open", color: .secondary)
                    }
                    .padding(.vertical, 12)

                    // ── Preview: top 3 most urgent ───────────────────
                    Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1).padding(.horizontal, 16)
                    VStack(spacing: 0) {
                        ForEach(Array(all.prefix(3).enumerated()), id: \.element.name) { idx, c in
                            if idx > 0 { Divider().padding(.leading, 52) }
                            followUpPreviewRow(c)
                        }
                        if all.count > 3 {
                            Divider().padding(.leading, 52)
                            HStack {
                                Text("+ \(all.count - 3) more · tap to see all")
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(uiColor: .secondaryLabel))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 10)
                        }
                    }
                }
            }
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private func followUpStat(value: Int, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundStyle(value > 0 ? color : .secondary)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func followUpPreviewRow(_ c: PipelineStore.FollowUpContact) -> some View {
        let daysLeft = c.overdueDays - c.daysSince
        let rowColor: Color = c.isOverdue ? .red : daysLeft <= 0 ? .orange : .secondary
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill((c.clientType?.color ?? Color.brgMuted).opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: c.clientType?.icon ?? "person.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(c.clientType?.color ?? Color.brgBright)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(c.name.isEmpty ? "Unknown" : c.name)
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.primary)
                Text(c.nextStep.rawValue)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(c.isOverdue ? "\(c.daysSince - c.overdueDays)d late" : daysLeft <= 0 ? "Today" : "in \(daysLeft)d")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(rowColor)
                if let ct = c.clientType {
                    Text(ct.shortLabel)
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var dialConsistencyCard: some View {
        let (hit, total) = pipeline.weeklyDialConsistency
        let pct = total > 0 ? Double(hit) / Double(total) : 0
        let color: Color = pct >= 0.8 ? Color.brg : pct >= 0.5 ? Color.brgMuted : .red
        let label = pct >= 0.8 ? "On fire 🔥" : pct >= 0.5 ? "Building 💪" : "Needs work"
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) // 1=Sun
        let daysElapsed = weekday == 1 ? 7 : weekday - 1
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        let dayData: [(name: String, isToday: Bool, isPast: Bool, dials: Int, didHit: Bool)] = (0..<7).map { i in
            let isPast = i < daysElapsed
            let isToday = i == daysElapsed - 1
            let dayDate = cal.date(byAdding: .day, value: -(daysElapsed - 1 - i), to: today) ?? today
            let dials = isPast ? pipeline.callLogs.filter { cal.isDate($0.date, inSameDayAs: dayDate) }.count : 0
            let didHit = dials >= pipeline.dailyDialTarget
            return (dayNames[i], isToday, isPast, dials, didHit)
        }
        return TrackerCard(title: "Dial Consistency", icon: "calendar.badge.checkmark", iconColor: color,
            tooltip: "How many days this week you hit your daily dial target. Consistency beats volume.") {
            VStack(spacing: 14) {
                HStack(alignment: .bottom, spacing: 6) {
                    Text("\(hit)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text("/ \(total) days")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(color)
                        Text("this week")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 4)

                HStack(spacing: 0) {
                    ForEach(dayData.indices, id: \.self) { i in
                        let d = dayData[i]
                        VStack(spacing: 4) {
                            ZStack {
                                Circle()
                                    .fill(d.isPast ? (d.didHit ? Color.brg.opacity(0.15) : Color.red.opacity(0.10)) : Color.secondary.opacity(0.07))
                                    .frame(width: 34, height: 34)
                                Image(systemName: d.isPast ? (d.didHit ? "checkmark" : "xmark") : "minus")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(d.isPast ? (d.didHit ? Color.brg : Color.red) : Color.secondary)
                            }
                            Text(d.isToday ? "Now" : d.name)
                                .font(.system(size: 9, weight: d.isToday ? .bold : .regular))
                                .foregroundStyle(d.isToday ? color : .secondary)
                            if d.isPast {
                                Text("\(d.dials)")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(d.didHit ? Color.brg : Color.red)
                            } else {
                                Text(" ").font(.system(size: 9))
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8).padding(.bottom, 16)
            }
        }
    }

    private var pipelineVelocityCard: some View {
        let stages = pipeline.pipelineVelocityByStage
        let maxDays = stages.map { $0.avgDays }.max() ?? 1
        return TrackerCard(title: "Pipeline Velocity", icon: "gauge.with.dots.needle.67percent", iconColor: .brgMuted,
            tooltip: "Average days your deals spend in each stage. Shorter = faster pipeline.") {
            VStack(spacing: 0) {
                if stages.isEmpty {
                    InsightEmptyRow(message: "Add deals and log activity to track velocity per stage.")
                } else {
                    ForEach(Array(stages.enumerated()), id: \.element.stage) { idx, s in
                        if idx > 0 { Divider().padding(.leading, 52) }
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 9)
                                    .fill(Color.brgMuted.opacity(0.10))
                                    .frame(width: 36, height: 36)
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 15, weight: .bold)).foregroundStyle(Color.brgBright)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(s.stage.rawValue)
                                        .font(.system(size: 13, weight: .semibold))
                                    Spacer()
                                    Text(s.avgDays < 1 ? "<1 day" : String(format: "%.1f days", s.avgDays))
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(s.avgDays <= 7 ? Color.brg : s.avgDays <= 21 ? Color.brgMuted : Color.red)
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.primary.opacity(0.06)).frame(height: 5)
                                        Capsule()
                                            .fill(LinearGradient(colors: [Color.brgMuted.opacity(0.6), Color.brgMuted], startPoint: .leading, endPoint: .trailing))
                                            .frame(width: geo.size.width * CGFloat(s.avgDays / maxDays), height: 5)
                                            .animation(.spring(response: 0.7, dampingFraction: 0.8).delay(Double(idx) * 0.05), value: animateProgress)
                                    }
                                }
                                .frame(height: 5)
                                Text("\(s.dealCount) deal\(s.dealCount == 1 ? "" : "s")")
                                    .font(.system(size: 10)).foregroundStyle(.tertiary)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                    }
                }
            }
        }
    }

    // MARK: - Deals preview

    private var dealsPreviewCard: some View {
        TrackerCard(title: "Pipeline Deals", icon: "house.fill", iconColor: .brgMuted, tooltip: "Your active deals by stage.") {
            VStack(spacing: 0) {
                let active = pipeline.deals.filter { $0.stage != .closed && $0.stage != .lost }.prefix(4)
                if active.isEmpty {
                    Text("No active deals")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                } else {
                    ForEach(Array(active.enumerated()), id: \.element.id) { i, deal in
                        if i > 0 { Divider().padding(.leading, 16) }
                        DealPreviewRow(deal: deal)
                    }
                }
                Divider()
                Button { showDeals = true } label: {
                    Text("Manage all deals →")
                        .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.brg)
                        .frame(maxWidth: .infinity).padding(.vertical, 14)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Recent calls

    private var recentCallsCard: some View {
        let recent = Array(pipeline.callLogs.prefix(10))
        return TrackerCard(title: "Recent Calls", icon: "clock.arrow.circlepath", iconColor: .brgBright, tooltip: nil) {
            if recent.isEmpty {
                Text("No calls logged yet.\nTap New Call to get started.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recent.enumerated()), id: \.element.id) { idx, log in
                        if idx > 0 { Divider().padding(.leading, 16) }
                        RecentCallRow(log: log, pipeline: pipeline)
                    }
                    if pipeline.callLogs.count > 10 {
                        Divider()
                        Button { showAllCalls = true } label: {
                            Text("See all \(pipeline.callLogs.count) calls →")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.brg)
                                .frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Insight helpers

private struct InsightEmptyRow: View {
    let message: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 14)).foregroundStyle(.tertiary)
            Text(message)
                .font(.system(size: 13)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16).padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - TrackerCard

private struct TrackerCard<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    var tooltip: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(iconColor == .secondary ? Color.brgBright : iconColor)
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                if let tooltip { TooltipButton(text: tooltip) }
                Spacer()
            }
            .padding(.horizontal, 16).padding(.top, 16)

            content
                .padding(.bottom, 4)
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - TrackerStatCard (progress bar card)

private struct TrackerStatCard: View {
    let title: String
    let subtitle: String
    var tooltip: String? = nil
    let value: String
    let target: Int
    let current: Int
    let color: Color
    let icon: String
    var projectedValue: String? = nil
    var animate: Bool = false

    private var progress: Double { min(1.0, Double(current) / Double(max(1, target))) }
    private var progressColor: Color { progress >= 1 ? Color.brg : progress >= 0.6 ? color : Color.brgMuted }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
                Text(title).font(.system(size: 15, weight: .bold))
                if let tooltip { TooltipButton(text: tooltip) }
                Spacer()
                Text(value).font(.system(size: 15, weight: .bold)).foregroundStyle(progressColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.10)).frame(height: 8)
                    Capsule().fill(
                        LinearGradient(colors: [progressColor.opacity(0.8), progressColor],
                                       startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: geo.size.width * (animate ? progress : 0), height: 8)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: animate)
                }
            }
            .frame(height: 8)
            HStack {
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if let p = projectedValue { Text(p).font(.caption).foregroundStyle(color.opacity(0.8)) }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - TrackerTile (small stat)

private struct TrackerTile: View {
    let label: String
    let value: String
    var target: String? = nil
    let icon: String
    let color: Color
    var tooltip: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).lineLimit(1)
                if let tooltip { TooltipButton(text: tooltip) }
            }
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(.primary).minimumScaleFactor(0.6).lineLimit(1)
            if let t = target {
                Text("target: \(t)").font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - FunnelRow

private struct FunnelRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let rate: Double
    let benchmark: Double
    let isEstimated: Bool
    var animate: Bool = false

    private var barColor: Color { isEstimated ? .secondary : (rate >= benchmark ? Color.brg : Color.brg) }
    private var fillFraction: Double { min(1, rate / max(benchmark * 3, 0.001)) }
    private var pct: String { String(format: "%.1f%%", rate * 100) }

    var body: some View {
        HStack(spacing: 12) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(barColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(barColor == .secondary ? Color.brgBright : barColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    if isEstimated {
                        Text("est.")
                            .font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.5)).clipShape(Capsule())
                    }
                    Spacer()
                    Text(pct)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(barColor)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.06))
                            .frame(height: 5)
                        Capsule()
                            .fill(LinearGradient(colors: [barColor.opacity(0.7), barColor],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * (animate ? fillFraction : 0), height: 5)
                            .animation(.spring(response: 0.8, dampingFraction: 0.75).delay(0.05), value: animate)
                    }
                }
                .frame(height: 5)
                Text("benchmark \(String(format: "%.1f%%", benchmark * 100))")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(Color.primary.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - PredTile + PredRow

private struct PredTile: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let isEstimated: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(iconColor.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(iconColor == .secondary ? Color.brgBright : iconColor)
                }
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(isEstimated ? .secondary : .primary)
            if isEstimated {
                Text("benchmark")
                    .font(.system(size: 10)).foregroundStyle(.orange)
            } else {
                Text("calls needed")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct PredRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let isEstimated: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(iconColor.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(iconColor == .secondary ? Color.brgBright : iconColor)
            }
            Text(label)
                .font(.system(size: 13, weight: .medium))
            Spacer()
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(isEstimated ? .secondary : Color.brg)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - My Numbers rows

private struct MyNumHeader: View {
    let icon: String; let title: String
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11, weight: .bold)).foregroundStyle(Color(uiColor: .secondaryLabel))
            Text(title.uppercased()).font(.system(size: 11, weight: .bold)).foregroundStyle(Color(uiColor: .secondaryLabel)).kerning(0.5)
        }
        .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MyNumIcon: View {
    let icon: String; let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9).fill(color.opacity(0.16)).frame(width: 36, height: 36)
            Image(systemName: icon).font(.system(size: 15, weight: .bold)).foregroundStyle(color == .secondary ? Color.brgBright : (color == .brgMuted ? Color.brg : color))
        }
    }
}

private struct MyNumWinRow: View {
    let rate: Double
    var body: some View {
        HStack(spacing: 14) {
            MyNumIcon(icon: "trophy.fill", color: .brg)
            VStack(alignment: .leading, spacing: 2) {
                Text("Win rate").font(.system(size: 15, weight: .semibold))
                Text("Closed / (Closed + Lost)").font(.system(size: 12)).foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            Spacer()
            Text("\(Int(rate * 100))%")
                .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(Color.brg)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}

private struct MyNumRevenueRow: View {
    let value: Double
    var body: some View {
        HStack(spacing: 14) {
            MyNumIcon(icon: "eurosign.circle.fill", color: value > 0 ? .brg : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Total closed revenue").font(.system(size: 15, weight: .semibold))
                Text("Sum of closed deal values").font(.system(size: 12)).foregroundStyle(Color(uiColor: .secondaryLabel))
            }
            Spacer()
            Text(value == 0 ? "—" : "€\(Int(value).formatted())")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(value > 0 ? Color.brg : .secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}

private struct MyNumDoubleRow: View {
    let icon: String; let iconColor: Color
    let title: String; let value: Double; let unit: String; let detail: String
    var body: some View {
        HStack(spacing: 14) {
            MyNumIcon(icon: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(Color(uiColor: .secondaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: value >= 10 ? "%.0f" : "%.1f", value))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text(unit).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}

private struct MyNumPlaceholder: View {
    let icon: String; let iconColor: Color; let title: String; let detail: String
    var body: some View {
        HStack(spacing: 14) {
            MyNumIcon(icon: icon, color: iconColor.opacity(0.4))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold)).foregroundStyle(Color(uiColor: .secondaryLabel))
                Text(detail).font(.system(size: 12)).foregroundStyle(Color(uiColor: .tertiaryLabel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text("—").font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}


// MARK: - All Calls View (bug 7)
struct AllCallsView: View {
    @ObservedObject var pipeline: PipelineStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var editingLog: CallLog? = nil

    private var filtered: [CallLog] {
        if searchText.isEmpty { return pipeline.callLogs }
        let q = searchText.lowercased()
        return pipeline.callLogs.filter {
            $0.contactName.lowercased().contains(q) ||
            $0.outcome.rawValue.lowercased().contains(q) ||
            $0.nextStep.rawValue.lowercased().contains(q)
        }
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { log in
                    CallHistoryRow(log: log)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pipeline.deleteCall(id: log.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingLog = log
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $searchText, prompt: "Search by name or outcome")
            .navigationTitle("All Calls (\(pipeline.callLogs.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingLog) { log in
                EditCallView(pipeline: pipeline, log: log)
                    .environmentObject(taskStore)
            }
        }
    }
}

// MARK: - Edit Call View (bug 6)
struct EditCallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var taskStore: TaskStore
    @ObservedObject var pipeline: PipelineStore

    @State var log: CallLog
    @FocusState private var isAnyFieldFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Name", text: $log.contactName)
                    Picker("Lead Source", selection: $log.leadSource) {
                        ForEach(LeadSource.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                }
                Section("Outcome") {
                    Picker("Outcome", selection: $log.outcome) {
                        ForEach(CallOutcome.allCases) { o in Text(o.rawValue).tag(o) }
                    }
                }
                Section("Next Step") {
                    Picker("Next Step", selection: $log.nextStep) {
                        ForEach(NextStepType.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $log.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button(role: .destructive) {
                        pipeline.deleteCall(id: log.id)
                        dismiss()
                    } label: {
                        Label("Delete this call", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Edit Call")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        pipeline.updateCall(log)
                        dismiss()
                    }
                }
            }
        }
        .floatingKeyboardDismiss(isVisible: isAnyFieldFocused)
    }
}

// MARK: - Deals View (bug 5)
struct DealsView: View {
    @ObservedObject var pipeline: PipelineStore
    @Environment(\.dismiss) private var dismiss
    @State private var showAddDeal = false
    @State private var editingDeal: PipelineDeal? = nil

    private var dealsByStage: [(stage: DealStage, deals: [PipelineDeal])] {
        DealStage.allCases.compactMap { stage in
            let d = pipeline.deals.filter { $0.stage == stage }
            return d.isEmpty ? nil : (stage, d)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(dealsByStage, id: \.stage) { group in
                    Section(group.stage.rawValue) {
                        ForEach(group.deals) { deal in
                            DealRow(deal: deal)
                                .contentShape(Rectangle())
                                .onTapGesture { editingDeal = deal }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        pipeline.deleteDeal(id: deal.id)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    // Advance to next stage
                                    if let nextStage = deal.stage.next {
                                        Button {
                                            var updated = deal
                                            updated.stage = nextStage
                                            updated.updatedAt = Date()
                                            pipeline.updateDeal(updated)
                                        } label: {
                                            Label("Advance", systemImage: "arrow.right.circle.fill")
                                        }
                                        .tint(.brgMuted)
                                    }
                                }
                        }
                    }
                }
                if pipeline.deals.isEmpty {
                    Section {
                        Text("No deals yet. Tap + to add your first pipeline deal.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity).multilineTextAlignment(.center)
                            .padding(.vertical, 20)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Pipeline Deals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAddDeal = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showAddDeal) {
                EditDealView(deal: PipelineDeal(), pipeline: pipeline, isNew: true)
            }
            .sheet(item: $editingDeal) { deal in
                EditDealView(deal: deal, pipeline: pipeline, isNew: false)
            }
        }
    }
}

private struct DealRow: View {
    let deal: PipelineDeal
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(deal.contactName.isEmpty ? "Unnamed contact" : deal.contactName)
                .font(.system(size: 15, weight: .semibold))
            if !deal.propertyDescription.isEmpty {
                Text(deal.propertyDescription)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            if let val = deal.estimatedValue {
                Text("€\(Int(val).formatted())")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct DealPreviewRow: View {
    let deal: PipelineDeal
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(deal.contactName.isEmpty ? "Unnamed" : deal.contactName)
                    .font(.system(size: 14, weight: .semibold)).lineLimit(1
                    )
                Text(deal.stage.rawValue)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Spacer()
            if let val = deal.estimatedValue {
                Text("€\(Int(val).formatted())")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}

struct EditDealView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var pipeline: PipelineStore
    @State var deal: PipelineDeal
    let isNew: Bool
    @FocusState private var isAnyFieldFocused: Bool

    init(deal: PipelineDeal, pipeline: PipelineStore, isNew: Bool) {
        self._deal = State(initialValue: deal)
        self.pipeline = pipeline
        self.isNew = isNew
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Contact") {
                    TextField("Contact name", text: $deal.contactName)
                    Picker("Lead Source", selection: $deal.leadSource) {
                        ForEach(LeadSource.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                }
                Section("Deal") {
                    Picker("Stage", selection: $deal.stage) {
                        ForEach(DealStage.allCases) { s in Text(s.rawValue).tag(s) }
                    }
                    TextField("Property description", text: $deal.propertyDescription)
                    TextField("Estimated value (€)", value: $deal.estimatedValue, format: .number)
                        .keyboardType(.decimalPad)
                }
                Section("Notes") {
                    TextField("Notes", text: $deal.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                if !isNew {
                    Section {
                        Button(role: .destructive) {
                            pipeline.deleteDeal(id: deal.id)
                            dismiss()
                        } label: {
                            Label("Delete deal", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New Deal" : "Edit Deal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        deal.updatedAt = Date()
                        if isNew { pipeline.addDeal(deal) } else { pipeline.updateDeal(deal) }
                        dismiss()
                    }
                    .disabled(deal.contactName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .floatingKeyboardDismiss(isVisible: isAnyFieldFocused)
    }
}

// MARK: - Hot Sheet View (bug 11)
struct HotSheetView: View {
    @ObservedObject var pipeline: PipelineStore
    @EnvironmentObject var taskStore: TaskStore
    @Environment(\.dismiss) private var dismiss

    // Hot sheet = contacts with appointments, meetings, showings or open next steps
    private var hotLeads: [CallLog] {
        pipeline.callLogs
            .filter { $0.outcome == .callAppointmentArranged || $0.outcome == .meetingArranged || $0.outcome == .showingArranged || $0.nextStep == .appointment }
            .filter { !Calendar.current.isDateInToday($0.date) }
            .sorted { $0.date > $1.date }
            .prefix(20)
            .map { $0 }
    }

    private var followUpsDue: [CallLog] {
        pipeline.callLogs
            .filter {
                $0.nextStep != .none &&
                $0.nextStep != .nurture &&
                !Calendar.current.isDateInToday($0.date) &&
                ($0.generatedTaskID == nil)
            }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                if !hotLeads.isEmpty {
                    Section("Hot & Warm Leads") {
                        ForEach(hotLeads) { log in
                            HotSheetRow(log: log, icon: log.outcome == .showingArranged ? "house.fill" : "calendar.badge.checkmark", color: log.outcome == .showingArranged ? .brgMuted : .brg)
                        }
                    }
                }

                if !followUpsDue.isEmpty {
                    Section("Follow-Ups Needed") {
                        ForEach(followUpsDue) { log in
                            HotSheetRow(log: log, icon: log.nextStep.icon, color: .brg)
                        }
                    }
                }

                if hotLeads.isEmpty && followUpsDue.isEmpty {
                    Section {
                        Text("All clear — no hot leads or pending follow-ups.\nLog your first call to populate the hot sheet.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity).padding(.vertical, 24)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Hot Sheet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark Reviewed") {
                        pipeline.logHotSheetReview()
                        HapticManager.success()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

private struct HotSheetRow: View {
    let log: CallLog
    let icon: String
    let color: Color

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .short; f.timeStyle = .short; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.16)).frame(width: 36, height: 36)
                Image(systemName: icon).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(log.contactName.isEmpty ? "Unknown" : log.contactName)
                    .font(.system(size: 14, weight: .semibold))
                Text(log.outcome.rawValue)
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                if log.nextStep != .none {
                    Text("Next: \(log.nextStep.rawValue)")
                        .font(.system(size: 11)).foregroundStyle(Color.brg)
                }
            }
            Spacer()
            Text(Self.fmt.string(from: log.date))
                .font(.system(size: 11)).foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Call rows

struct CallHistoryRow: View {
    let log: CallLog

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(log.contactName.isEmpty ? "Unknown" : log.contactName)
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text(Self.fmt.string(from: log.date))
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            }
            Text(log.outcome.rawValue)
                .font(.system(size: 12)).foregroundStyle(Color(uiColor: .secondaryLabel))
            if log.nextStep != .none {
                Text("Next: \(log.nextStep.rawValue)")
                    .font(.system(size: 11)).foregroundStyle(Color.brg)
            }
            if !log.notes.isEmpty {
                Text(log.notes)
                    .font(.system(size: 12)).foregroundStyle(Color(uiColor: .secondaryLabel)).lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct RecentCallRow: View {
    let log: CallLog
    @ObservedObject var pipeline: PipelineStore

    private static let fmt: DateFormatter = {
        let f = DateFormatter(); f.timeStyle = .short; f.dateStyle = .none; return f
    }()

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(outcomeColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: outcomeIcon).font(.system(size: 13, weight: .bold)).foregroundStyle(outcomeColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(log.contactName.isEmpty ? "Unknown" : log.contactName)
                    .font(.system(size: 14, weight: .semibold)).lineLimit(1
                    )
                Text(log.outcome.rawValue).font(.system(size: 12)).foregroundStyle(Color(uiColor: .secondaryLabel)).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Self.fmt.string(from: log.date)).font(.system(size: 11)).foregroundStyle(.tertiary)
                if log.nextStep != .none {
                    Text(log.nextStep.rawValue).font(.system(size: 10)).foregroundStyle(Color.brg).lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private var outcomeColor: Color {
        switch log.outcome {
        case .callAppointmentArranged: return .brgBright
        case .meetingArranged:         return .brg
        case .gatheredInfoForOffer:    return .brg
        case .showingArranged:         return .brg
        }
    }

    private var outcomeIcon: String {
        switch log.outcome {
        case .callAppointmentArranged: return "phone.badge.checkmark"
        case .meetingArranged:         return "person.2.fill"
        case .gatheredInfoForOffer:    return "doc.text.fill"
        case .showingArranged:         return "house.fill"
        }
    }
}

// MARK: - Tooltip button (bug 23)
struct TooltipButton: View {
    let text: String
    @State private var showPopover = false

    var body: some View {
        Button {
            showPopover = true
        } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(uiColor: .secondaryLabel))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPopover) {
            Text(text)
                .font(.system(size: 14))
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .padding(18)
                .frame(minWidth: 220, maxWidth: 320, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .presentationCompactAdaptation(.popover)
        }
    }
}
