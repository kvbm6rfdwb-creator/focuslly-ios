import Foundation
import SwiftUI

// MARK: - Momentum Direction
enum MomentumDirection: String {
    case heating  = "Heating"
    case stable   = "Stable"
    case cooling  = "Cooling"

    var icon: String {
        switch self {
        case .heating: return "arrow.up.right"
        case .stable:  return "arrow.right"
        case .cooling: return "arrow.down.right"
        }
    }

    var color: Color {
        switch self {
        case .heating: return .brg
        case .stable:  return .orange
        case .cooling: return .red
        }
    }

    var label: String {
        switch self {
        case .heating: return "Heating up"
        case .stable:  return "Stable"
        case .cooling: return "Cooling"
        }
    }
}

// MARK: - Momentum Result
struct MomentumResult {
    let direction: MomentumDirection
    /// Score delta vs. 2 weeks ago (positive = improving, negative = declining)
    let weeklyDelta: Int
    /// Human-readable reason for this momentum reading
    let reason: String
    /// Days since last contact
    let daysSinceContact: Int
}

// MARK: - Relationship Momentum Engine
struct RelationshipMomentumEngine {

    /// Computes the momentum direction and weekly delta for a contact.
    static func momentum(
        contact: PipelineContact,
        allCallLogs: [CallLog]
    ) -> MomentumResult {

        let now = Date()
        let cal = Calendar.current

        // All calls for this contact, sorted newest-first
        let calls = allCallLogs
            .filter { normalise($0.contactName.trimmingCharacters(in: .whitespaces)) == contact.id }
            .sorted { $0.date > $1.date }

        let daysSince = cal.dateComponents([.day], from: contact.lastCallDate, to: now).day ?? 999

        // ── 1. Frequency trend ────────────────────────────────────────
        // Compare calls in the last 14 days vs. the 14 days before that
        let cutoff14  = now.addingTimeInterval(-14 * 86400)
        let cutoff28  = now.addingTimeInterval(-28 * 86400)
        let recentCalls = calls.filter { $0.date >= cutoff14 }.count
        let prevCalls   = calls.filter { $0.date >= cutoff28 && $0.date < cutoff14 }.count

        // ── 2. Outcome quality trend ──────────────────────────────────
        // Score each call outcome: higher = better
        func outcomeScore(_ outcome: CallOutcome) -> Int {
            switch outcome {
            case .callAppointmentArranged: return 2
            case .meetingArranged:         return 3
            case .gatheredInfoForOffer:    return 3
            case .showingArranged:         return 4
            }
        }

        let recentOutcomeScore = calls.prefix(3).reduce(0) { $0 + outcomeScore($1.outcome) }
        let olderOutcomeScore  = calls.dropFirst(3).prefix(3).reduce(0) { $0 + outcomeScore($1.outcome) }

        // ── 3. Next-step staleness penalty ───────────────────────────
        var stalenessPenalty = 0
        if let latestCall = calls.first, latestCall.nextStep != .none {
            let daysSinceStep = cal.dateComponents([.day], from: latestCall.date, to: now).day ?? 0
            let overdueThreshold = contact.metadata.map { meta -> Int in
                meta.clientType.map { ct -> Int in
                    ct == .buyerOfferStage ? 1 :
                    ct == .buyerActive || ct == .sellerProspect ? 3 :
                    7
                } ?? 7
            } ?? 7
            if daysSinceStep > overdueThreshold * 2 {
                stalenessPenalty = -2
            } else if daysSinceStep > overdueThreshold {
                stalenessPenalty = -1
            }
        }

        // ── 4. Compute delta score ────────────────────────────────────
        let frequencyDelta  = recentCalls - prevCalls
        let outcomeDelta    = recentOutcomeScore - olderOutcomeScore
        let rawDelta        = (frequencyDelta * 3) + outcomeDelta + stalenessPenalty

        // ── 5. Determine direction ────────────────────────────────────
        let direction: MomentumDirection
        if calls.isEmpty {
            // Imported contact with no calls yet — show as stable/neutral, not cooling
            return MomentumResult(
                direction: .stable,
                weeklyDelta: 0,
                reason: "Not yet contacted — log your first call",
                daysSinceContact: daysSince
            )
        }

        // Long silence overrides everything
        if daysSince > 30 {
            return MomentumResult(
                direction: .cooling,
                weeklyDelta: rawDelta,
                reason: "\(daysSince) days without contact",
                daysSinceContact: daysSince
            )
        }

        if rawDelta >= 2 {
            direction = .heating
        } else if rawDelta <= -2 {
            direction = .cooling
        } else {
            direction = .stable
        }

        // ── 6. Build human reason ─────────────────────────────────────
        let reason: String
        switch direction {
        case .heating:
            if recentCalls > prevCalls {
                reason = "Call frequency up — \(recentCalls) call\(recentCalls == 1 ? "" : "s") in last 14 days"
            } else {
                reason = "Outcome quality improving"
            }
        case .stable:
            if daysSince == 0 {
                reason = "Contacted today"
            } else if daysSince <= 7 {
                reason = "Consistent contact — \(daysSince)d ago"
            } else {
                reason = "No change in activity"
            }
        case .cooling:
            if stalenessPenalty < 0 {
                reason = "Next step overdue — follow through"
            } else if recentCalls < prevCalls && prevCalls > 0 {
                reason = "Call frequency dropped vs. last fortnight"
            } else {
                reason = "No recent activity"
            }
        }

        return MomentumResult(
            direction: direction,
            weeklyDelta: rawDelta,
            reason: reason,
            daysSinceContact: daysSince
        )
    }

    private static func normalise(_ name: String) -> String {
        let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
        let tokens = lower.components(separatedBy: .whitespaces).filter { $0.count > 1 }
        return tokens.max(by: { $0.count < $1.count }) ?? lower
    }
}

// MARK: - Agent Accountability Engine
struct AccountabilityResult {
    /// Number of next steps logged this week that had a follow-up call within their due window
    let completedThisWeek: Int
    /// Total next steps that were due this week
    let dueThisWeek: Int
    /// 0–100 follow-through rate
    var followThroughRate: Int {
        guard dueThisWeek > 0 else { return 100 }
        return Int(Double(completedThisWeek) / Double(dueThisWeek) * 100)
    }
    var rateLabel: String {
        switch followThroughRate {
        case 80...100: return "Excellent"
        case 60...79:  return "Good"
        case 40...59:  return "Needs work"
        default:       return "Critical"
        }
    }
    var rateColor: Color {
        switch followThroughRate {
        case 80...100: return .brg
        case 60...79:  return .orange
        case 40...59:  return .red
        default:       return Color(red: 0.8, green: 0.1, blue: 0.1)
        }
    }
    var rateIcon: String {
        switch followThroughRate {
        case 80...100: return "checkmark.seal.fill"
        case 60...79:  return "clock.badge.checkmark.fill"
        default:       return "exclamationmark.triangle.fill"
        }
    }
}

struct AgentAccountabilityEngine {

    /// Computes how many next steps whose due window has already closed were actually followed up.
    /// Only steps where `dueDate < now` are counted — steps still within their window are excluded
    /// entirely so they don't count as missed.
    static func weeklyAccountability(allCallLogs: [CallLog]) -> AccountabilityResult {
        let now = Date()
        let lookback = now.addingTimeInterval(-30 * 86400) // look back 30 days for context

        // All calls sorted oldest-first for sequential analysis
        let sorted = allCallLogs.sorted { $0.date < $1.date }

        var due = 0
        var completed = 0

        for (i, call) in sorted.enumerated() {
            // Only consider calls within our lookback window
            guard call.date >= lookback else { continue }
            guard call.nextStep != .none else { continue }

            // Due window in days for this step type
            let dueDays: Double
            switch call.nextStep {
            case .retryCall:                        dueDays = 1
            case .followUpCall:                     dueDays = 3
            case .sendOffer, .sendListingInfo:       dueDays = 2
            case .appointment, .prepareCMA:          dueDays = 5
            default:                                 dueDays = 7
            }
            let dueDate = call.date.addingTimeInterval(dueDays * 86400)

            // ── KEY FIX: only count this step if its window has already closed ──
            guard dueDate < now else { continue }

            due += 1

            // Look for any subsequent call to the same contact made before the due date
            let contactKey = normalise(call.contactName.trimmingCharacters(in: .whitespaces))
            let followedUp = sorted.dropFirst(i + 1).contains { subsequent in
                normalise(subsequent.contactName.trimmingCharacters(in: .whitespaces)) == contactKey
                && subsequent.date <= dueDate
            }

            if followedUp { completed += 1 }
        }

        return AccountabilityResult(completedThisWeek: completed, dueThisWeek: due)
    }

    /// Returns contacts with overdue next steps, sorted by most overdue first.
    static func overdueNextSteps(contacts: [PipelineContact], allCallLogs: [CallLog]) -> [(contact: PipelineContact, daysOverdue: Int)] {
        let now = Date()
        let cal = Calendar.current

        return contacts.compactMap { contact -> (PipelineContact, Int)? in
            guard let latestCall = contact.calls.first, latestCall.nextStep != .none else { return nil }

            let dueDays: Int
            switch latestCall.nextStep {
            case .retryCall:       dueDays = 1
            case .followUpCall:    dueDays = 3
            case .sendOffer, .sendListingInfo: dueDays = 2
            case .appointment, .prepareCMA:    dueDays = 5
            default:               dueDays = 7
            }

            let dueDate = latestCall.date.addingTimeInterval(Double(dueDays) * 86400)
            let daysOver = cal.dateComponents([.day], from: dueDate, to: now).day ?? 0
            guard daysOver > 0 else { return nil }
            return (contact, daysOver)
        }
        .sorted { $0.1 > $1.1 }
    }

    private static func normalise(_ name: String) -> String {
        let lower = name.lowercased().trimmingCharacters(in: .whitespaces)
        let tokens = lower.components(separatedBy: .whitespaces).filter { $0.count > 1 }
        return tokens.max(by: { $0.count < $1.count }) ?? lower
    }
}

// MARK: - Prescriptive Hint Engine
struct PrescriptiveHintEngine {

    /// Returns a single actionable coaching sentence for a contact card.
    static func hint(for contact: PipelineContact, momentum: MomentumResult) -> (text: String, color: Color, icon: String) {
        // ── No calls yet — imported contact ──────────────────────────
        if contact.calls.isEmpty {
            return ("New contact — log your first call", Color(.secondaryLabel), "person.crop.circle.badge.plus")
        }

        let days = momentum.daysSinceContact
        let clientType = contact.metadata?.clientType
        let tag = contact.tag
        let buyerSaturated = contact.metadata?.buyerSaturated ?? false

        // ── Next step — ALWAYS shown first if one exists ─────────────
        // Whether overdue or still within window, the agent must see it.
        if let step = contact.latestNextStep, let latestCall = contact.calls.first {
            let dueDays: Int
            switch step {
            case .retryCall:                        dueDays = 1
            case .followUpCall:                     dueDays = 3
            case .sendOffer, .sendListingInfo:       dueDays = 2
            case .appointment, .prepareCMA:          dueDays = 5
            default:                                 dueDays = 7
            }
            let stepAge = Calendar.current.dateComponents([.day], from: latestCall.date, to: Date()).day ?? 0
            let daysRemaining = dueDays - stepAge

            if daysRemaining < 0 {
                // Overdue
                return ("⚠️ \(step.rawValue) overdue by \(-daysRemaining)d", .red, "exclamationmark.triangle.fill")
            } else if daysRemaining == 0 {
                // Due today
                return ("Due today — \(step.rawValue)", .orange, step.icon)
            } else {
                // Still within window — show countdown so card is never green
                return ("Due in \(daysRemaining)d — \(step.rawValue)", .orange, step.icon)
            }
        }

        // ── Offer stage — extremely time-sensitive ────────────────────
        if clientType == .buyerOfferStage {
            if days == 0 {
                return ("Offer stage — good, contacted today", .green, "doc.text.fill")
            } else if days == 1 {
                return ("Offer stage — call today to maintain momentum", .orange, "doc.text.fill")
            } else {
                return ("⚠️ Offer stage — \(days)d without contact is critical", .red, "exclamationmark.triangle.fill")
            }
        }

        // ── Active buyer ──────────────────────────────────────────────
        if clientType == .buyerActive {
            let threshold = buyerSaturated ? 14 : 3
            if days == 0 {
                return ("Active buyer — great, stay in touch every \(threshold)d", .green, "magnifyingglass")
            } else if days > threshold * 2 {
                return ("Active buyer \(days)d silent — call today", .red, "magnifyingglass")
            } else if days > threshold {
                return ("Due for a follow-up — \(days)d since last contact", .orange, "phone.fill")
            }
        }

        // ── Seller listed ─────────────────────────────────────────────
        if clientType == .sellerListed {
            if days > 7 {
                return ("Listed seller — update them on market activity", .orange, "house.fill")
            } else if days == 0 {
                return ("Seller contacted today — great client care", .green, "house.fill")
            }
        }

        // ── Seller prospecting ────────────────────────────────────────
        if clientType == .sellerProspect {
            if days > 3 {
                return ("Prospect cooling — reach out before they go cold", .orange, "megaphone.fill")
            }
        }

        // ── Hot lead ──────────────────────────────────────────────────
        if tag == .hotLead {
            if days == 0 {
                return ("Hot lead — contacted today, keep momentum", .green, "flame.fill")
            } else if days <= 2 {
                return ("Hot lead — follow up today to stay top of mind", .orange, "flame.fill")
            } else {
                return ("Hot lead going cold — call immediately", .red, "flame.fill")
            }
        }

        // ── Warm lead ─────────────────────────────────────────────────
        if tag == .warmLead && days > 5 {
            return ("Warm lead — \(days)d gap, check in to keep warm", .orange, "thermometer.medium")
        }

        // ── Momentum-driven hints ─────────────────────────────────────
        switch momentum.direction {
        case .heating:
            return ("Relationship heating — keep the energy going", .green, "arrow.up.right")
        case .cooling:
            if days > 14 {
                return ("Relationship cooling — \(days)d since last contact", .red, "arrow.down.right")
            } else {
                return ("Momentum dropping — re-engage soon", .orange, "arrow.down.right")
            }
        case .stable:
            if days == 0 {
                return ("Contacted today — great consistency", .green, "checkmark.circle.fill")
            } else if days <= 7 {
                return ("Steady contact — \(days)d ago", Color(.secondaryLabel), "checkmark.circle")
            } else {
                return ("No recent activity — schedule a check-in", .secondary, "clock")
            }
        }
    }
}

// MARK: - Upcoming Step Item
struct UpcomingStepItem: Identifiable {
    let id: UUID
    let contactName: String
    let contactID: String         // PipelineContact.id key, empty for task-sourced items
    let stepType: NextStepType
    let dueDate: Date
    let source: UpcomingStepSource

    /// Negative = overdue, 0 = today, positive = days remaining
    var daysUntilDue: Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: dueDate)
        ).day ?? 0
    }

    var urgencyColor: Color {
        switch daysUntilDue {
        case ..<0:  return .red
        case 0:     return .orange
        default:    return .accentColor
        }
    }

    var urgencyLabel: String {
        switch daysUntilDue {
        case ..<0:  return "Overdue by \(-daysUntilDue)d"
        case 0:     return "Due today"
        case 1:     return "Due tomorrow"
        default:    return "Due in \(daysUntilDue)d"
        }
    }

    /// Maps `source` to a simpler enum name used in views
    var sourceType: UpcomingStepSource { source }

    /// SF Symbol icon for the step type
    var icon: String { stepType.icon }

    /// Human-readable label shown in the sheet row
    var stepLabel: String {
        switch stepType {
        case .sendOffer:        return "Send offer"
        case .sendListingInfo:  return "Send listing info"
        case .appointment:      return "Arrange showing / meeting"
        case .prepareCMA:       return "Prepare CMA"
        case .followUpCall:     return "Follow-up call"
        case .retryCall:        return "Retry call"
        case .nurture:          return "Nurture"
        case .openHouse:        return "Open house"
        case .none:             return "Follow up"
        }
    }
}

enum UpcomingStepSource {
    case contactNextStep    // from a CallLog.nextStep on a PipelineContact
    case focusTask          // from a pending FocusTask linked via pipelineCategory
}

// MARK: - Upcoming Steps Engine
struct UpcomingStepsEngine {

    /// Warning-window days: how many days BEFORE the due date we start surfacing the step.
    static func warningWindowDays(for step: NextStepType) -> Int {
        switch step {
        case .sendOffer, .sendListingInfo:  return 2
        case .appointment, .prepareCMA:     return 7
        case .retryCall:                    return 1
        case .followUpCall:                 return 3
        case .nurture, .openHouse:          return 3
        case .none:                         return 0
        }
    }

    /// Due-window days: number of days after the triggering call/event that the step is due.
    static func dueDays(for step: NextStepType) -> Int {
        switch step {
        case .retryCall:                    return 1
        case .followUpCall:                 return 3
        case .sendOffer, .sendListingInfo:  return 2
        case .appointment, .prepareCMA:     return 5
        case .nurture:                      return 14
        case .openHouse:                    return 7
        case .none:                         return 0
        }
    }

    /// Returns all upcoming or overdue steps from contacts and FocusTasks,
    /// filtered to only those inside their warning window (or already overdue).
    static func upcomingSteps(
        contacts: [PipelineContact],
        tasks: [FocusTask]
    ) -> [UpcomingStepItem] {
        let now = Date()
        var items: [UpcomingStepItem] = []

        // ── 1. Contact next steps ─────────────────────────────────────
        for contact in contacts {
            guard let latestCall = contact.calls.first,
                  latestCall.nextStep != .none else { continue }

            let step = latestCall.nextStep
            let due  = latestCall.date.addingTimeInterval(Double(dueDays(for: step)) * 86400)
            let warnDate = due.addingTimeInterval(Double(-warningWindowDays(for: step)) * 86400)

            guard now >= warnDate else { continue }   // not in warning window yet

            items.append(UpcomingStepItem(
                id: latestCall.id,
                contactName: contact.displayName,
                contactID: contact.id,
                stepType: step,
                dueDate: due,
                source: .contactNextStep
            ))
        }

        // ── 2. Pipeline FocusTasks ────────────────────────────────────
        let pipelineCategories: Set<PipelineTaskCategory> = [
            .followUps, .sendOffers, .meeting, .coldCalls, .cmaAdmin, .answerInquiries
        ]
        for task in tasks where task.status == .pending {
            guard let cat = task.pipelineCategory, pipelineCategories.contains(cat) else { continue }

            let due = task.scheduledTime ?? task.startDate

            let step: NextStepType
            switch cat {
            case .sendOffers:       step = .sendOffer
            case .meeting:          step = .appointment
            case .cmaAdmin:         step = .prepareCMA
            case .followUps:        step = .followUpCall
            case .coldCalls:        step = .retryCall
            case .answerInquiries:  step = .followUpCall
            default:                step = .followUpCall
            }

            let warnDate = due.addingTimeInterval(Double(-warningWindowDays(for: step)) * 86400)
            guard now >= warnDate else { continue }

            items.append(UpcomingStepItem(
                id: task.id,
                contactName: task.title,
                contactID: "",
                stepType: step,
                dueDate: due,
                source: .focusTask
            ))
        }

        // Overdue first, then by due date ascending
        return items.sorted { a, b in
            if a.daysUntilDue < 0 && b.daysUntilDue >= 0 { return true }
            if a.daysUntilDue >= 0 && b.daysUntilDue < 0 { return false }
            return a.dueDate < b.dueDate
        }
    }
}
