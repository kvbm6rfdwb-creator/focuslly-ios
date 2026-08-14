import SwiftUI

// MARK: - MyNumbers View
struct MyNumbersView: View {

    @ObservedObject private var pipeline = PipelineStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {

                // ── Funnel Averages ──────────────────────────────────────
                Section {
                    MyNumberRow(
                        icon: "phone.fill",
                        iconColor: .blue,
                        title: "Calls per appointment",
                        value: pipeline.predictedCallsPerAppointment,
                        unit: "calls",
                        isEstimated: pipeline.callToAppointmentRateIsEstimated,
                        detail: "How many dials you typically need before setting one appointment."
                    )
                    MyNumberRow(
                        icon: "calendar.badge.checkmark",
                        iconColor: .green,
                        title: "Appointments per listing",
                        value: pipeline.predictedAppointmentsPerListing,
                        unit: "appts",
                        isEstimated: pipeline.appointmentToProposalRateIsEstimated,
                        detail: "Average appointments needed before a listing is signed."
                    )
                    MyNumberRow(
                        icon: "checkmark.seal.fill",
                        iconColor: .orange,
                        title: "Calls per closed sale",
                        value: pipeline.predictedCallsPerSale,
                        unit: "calls",
                        isEstimated: pipeline.overallLeadToClientRateIsEstimated,
                        detail: "Total dials from first contact to closed deal."
                    )
                } header: {
                    SectionHeader(icon: "arrow.triangle.pull", title: "Funnel Averages")
                }

                // ── Deal Journey Averages ────────────────────────────────
                Section {
                    if let v = pipeline.avgCallsBeforeContact {
                        MyNumberDoubleRow(
                            icon: "phone.arrow.up.right",
                            iconColor: .blue,
                            title: "Calls before first contact",
                            value: v,
                            unit: "calls",
                            detail: "Average calls logged per deal before reaching Contacted stage."
                        )
                    } else {
                        MyNumberPlaceholderRow(
                            icon: "phone.arrow.up.right",
                            iconColor: .blue,
                            title: "Calls before first contact",
                            detail: "Complete more deals to see this number."
                        )
                    }

                    if let v = pipeline.avgOffersBeforeListing {
                        MyNumberDoubleRow(
                            icon: "doc.text.fill",
                            iconColor: .purple,
                            title: "Offers sent before listing",
                            value: v,
                            unit: "offers",
                            detail: "Average offers needed before a listing is signed."
                        )
                    } else {
                        MyNumberPlaceholderRow(
                            icon: "doc.text.fill",
                            iconColor: .purple,
                            title: "Offers sent before listing",
                            detail: "Close your first deal with offer data to see this."
                        )
                    }

                    if let v = pipeline.avgListingsBeforeSale {
                        MyNumberDoubleRow(
                            icon: "house.fill",
                            iconColor: .orange,
                            title: "Listings added before sale",
                            value: v,
                            unit: "listings",
                            detail: "Average new listings added per deal before closing."
                        )
                    } else {
                        MyNumberPlaceholderRow(
                            icon: "house.fill",
                            iconColor: .orange,
                            title: "Listings added before sale",
                            detail: "Close your first sale with listing data to see this."
                        )
                    }

                    if let v = pipeline.avgFocusSessionsPerDeal {
                        MyNumberDoubleRow(
                            icon: "bolt.fill",
                            iconColor: .yellow,
                            title: "Focus sessions per deal",
                            value: v,
                            unit: "sessions",
                            detail: "Average focus sessions invested per closed deal."
                        )
                    } else {
                        MyNumberPlaceholderRow(
                            icon: "bolt.fill",
                            iconColor: .yellow,
                            title: "Focus sessions per deal",
                            detail: "Tag focus sessions as pipeline tasks to track this."
                        )
                    }

                    if let v = pipeline.avgDaysToClose {
                        MyNumberDoubleRow(
                            icon: "calendar",
                            iconColor: .teal,
                            title: "Average days to close",
                            value: v,
                            unit: "days",
                            detail: "Average calendar days from deal creation to closed stage."
                        )
                    } else {
                        MyNumberPlaceholderRow(
                            icon: "calendar",
                            iconColor: .teal,
                            title: "Average days to close",
                            detail: "Close your first deal to see how long your cycle is."
                        )
                    }
                } header: {
                    SectionHeader(icon: "chart.bar.xaxis", title: "Deal Journey")
                }

                // ── Win / Revenue ────────────────────────────────────────
                Section {
                    if let rate = pipeline.winRate {
                        HStack(spacing: 14) {
                            BadgeIcon(icon: "trophy.fill", color: .green)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Win rate")
                                    .font(.system(size: 15, weight: .medium))
                                Text("Closed / (Closed + Lost)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(Int(rate * 100))%")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                        .padding(.vertical, 4)
                    } else {
                        MyNumberPlaceholderRow(
                            icon: "trophy.fill",
                            iconColor: .green,
                            title: "Win rate",
                            detail: "Mark deals as Closed or Lost to see your win rate."
                        )
                    }

                    HStack(spacing: 14) {
                        BadgeIcon(icon: "eurosign.circle.fill", color: .mint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Total closed revenue")
                                .font(.system(size: 15, weight: .medium))
                            Text("Sum of estimated values on closed deals")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(pipeline.totalRevenueClosed == 0
                             ? "—"
                             : "€\(Int(pipeline.totalRevenueClosed).formatted())")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(pipeline.totalRevenueClosed > 0 ? .mint : .secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    SectionHeader(icon: "trophy.fill", title: "Win & Revenue")
                }

                // ── Conversion Rates ─────────────────────────────────────
                Section {
                    ConversionRateRow(
                        title: "Call → Conversation",
                        rate: pipeline.callToConversationRate,
                        isEstimated: pipeline.callToConversationRateIsEstimated
                    )
                    ConversionRateRow(
                        title: "Call → Appointment",
                        rate: pipeline.callToAppointmentRate,
                        isEstimated: pipeline.callToAppointmentRateIsEstimated
                    )
                    ConversionRateRow(
                        title: "Appointment → Proposal",
                        rate: pipeline.appointmentToProposalRate,
                        isEstimated: pipeline.appointmentToProposalRateIsEstimated
                    )
                    ConversionRateRow(
                        title: "Proposal → Listing",
                        rate: pipeline.proposalToListingRate,
                        isEstimated: pipeline.proposalToListingRateIsEstimated
                    )
                    ConversionRateRow(
                        title: "Lead → Closed Sale",
                        rate: pipeline.overallLeadToClientRate,
                        isEstimated: pipeline.overallLeadToClientRateIsEstimated
                    )
                } header: {
                    SectionHeader(icon: "percent", title: "Conversion Rates (90-day)")
                } footer: {
                    Text("Based on your last 90 days of activity. Estimated values shown when data is insufficient.")
                        .font(.caption)
                }

                // ── Stage Velocity ───────────────────────────────────────
                let stageVelocity = pipeline.avgDaysPerStage
                if !stageVelocity.isEmpty {
                    Section {
                        ForEach(Array(stageVelocity.sorted { $0.key.rawValue < $1.key.rawValue }), id: \.key) { stage, days in
                            HStack {
                                Text(stage.rawValue)
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                Text(String(format: "%.1f days", days))
                                    .font(.system(size: 14, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        SectionHeader(icon: "clock.arrow.2.circlepath", title: "Avg Days Per Stage")
                    }
                }

                // ── Data quality note ────────────────────────────────────
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                            .font(.system(size: 16))
                            .padding(.top, 1)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("How data is collected")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Call logs, offer outcomes, and listing tasks feed this screen automatically. Link deals to outcomes and tag Quick Start sessions to build richer data over time.")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color(uiColor: .tertiarySystemFill))
            }
            .listStyle(.insetGrouped)
            .navigationTitle("My Numbers")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Sub-views

private struct SectionHeader: View {
    let icon: String; let title: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
            .textCase(nil)
    }
}

private struct BadgeIcon: View {
    let icon: String; let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.12))
                .frame(width: 34, height: 34)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

private struct MyNumberRow: View {
    let icon: String; let iconColor: Color
    let title: String; let value: Int; let unit: String
    let isEstimated: Bool; let detail: String

    var body: some View {
        HStack(spacing: 14) {
            BadgeIcon(icon: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                    if isEstimated {
                        Text("est.")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.8))
                            .clipShape(Capsule())
                    }
                }
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(value)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isEstimated ? .secondary : .primary)
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MyNumberDoubleRow: View {
    let icon: String; let iconColor: Color
    let title: String; let value: Double; let unit: String; let detail: String

    var body: some View {
        HStack(spacing: 14) {
            BadgeIcon(icon: icon, color: iconColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(String(format: value >= 10 ? "%.0f" : "%.1f", value))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MyNumberPlaceholderRow: View {
    let icon: String; let iconColor: Color
    let title: String; let detail: String

    var body: some View {
        HStack(spacing: 14) {
            BadgeIcon(icon: icon, color: iconColor.opacity(0.5))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Text("—")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct ConversionRateRow: View {
    let title: String; let rate: Double; let isEstimated: Bool

    private var pct: String { "\(Int((rate * 100).rounded()))%" }
    private var barColor: Color {
        rate > 0.15 ? .green : rate > 0.05 ? .orange : .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                if isEstimated {
                    Text("est.")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.8))
                        .clipShape(Capsule())
                }
                Spacer()
                Text(pct)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(isEstimated ? .secondary : barColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(height: 6)
                    Capsule()
                        .fill(isEstimated ? Color.secondary.opacity(0.4) : barColor)
                        .frame(width: geo.size.width * min(1.0, CGFloat(rate)), height: 6)
                        .animation(.easeInOut(duration: 0.6), value: rate)
                }
            }
            .frame(height: 6)
        }
        .padding(.vertical, 4)
    }
}
