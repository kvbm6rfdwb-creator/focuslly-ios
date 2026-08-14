import Foundation
import SwiftUI

// MARK: - Client Readiness Stage
enum BuyerReadinessStage: String, CaseIterable {
    case cold         = "Cold"
    case warmingUp    = "Warming Up"
    case engaged      = "Engaged"
    case hot          = "Hot"
    case readyToClose = "Ready to Close"

    var description: String {
        switch self {
        case .cold:         return "Early research phase. Needs education and trust-building."
        case .warmingUp:    return "Showing interest. Keep nurturing with listings and info."
        case .engaged:      return "Actively engaged. Prioritise showings and offers."
        case .hot:          return "High intent. Push for a decision — timing is critical."
        case .readyToClose: return "Ready to act. Do not lose momentum — close now."
        }
    }

    var nextAction: String {
        switch self {
        case .cold:         return "Send market info and build rapport"
        case .warmingUp:    return "Invite to a showing or send targeted listings"
        case .engaged:      return "Schedule a meeting and prepare an offer"
        case .hot:          return "Present an offer and address objections"
        case .readyToClose: return "Close the deal — initiate contract process"
        }
    }
}

// MARK: - Readiness Score Result
struct BuyerReadinessResult {
    let score: Int
    let previousScore: Int?             // ~7 days ago — for velocity display
    let stage: BuyerReadinessStage
    let topFactors: [ScoringFactor]
    let flags: [RiskFlag]
    let actionPlan: [ActionStep]
    let isSeller: Bool

    var scoreVelocity: Int? {
        guard let prev = previousScore else { return nil }
        return score - prev
    }

    struct ScoringFactor: Identifiable {
        let id = UUID()
        let label: String
        let points: Int
        let icon: String
    }

    struct RiskFlag: Identifiable {
        let id = UUID()
        let icon: String
        let color: Color
        let title: String
        let detail: String
    }

    struct ActionStep: Identifiable {
        let id = UUID()
        let number: Int
        let icon: String
        let action: String
        let reason: String
    }
}

// MARK: - Buyer Readiness Engine
struct BuyerReadinessEngine {

    static func score(
        contact: PipelineContact,
        saleLogs: [SaleLog],
        callLogs: [CallLog]
    ) -> BuyerReadinessResult {
        let ct = contact.metadata?.clientType
        let isSeller = ct == .sellerProspect || ct == .sellerListed
        return isSeller
            ? sellerScore(contact: contact, saleLogs: saleLogs, callLogs: callLogs)
            : buyerScore(contact: contact, saleLogs: saleLogs, callLogs: callLogs)
    }

    // MARK: - Buyer scoring

    private static func buyerScore(
        contact: PipelineContact,
        saleLogs: [SaleLog],
        callLogs: [CallLog]
    ) -> BuyerReadinessResult {

        let meta = contact.metadata
        let now  = Date()
        let cal  = Calendar.current
        var total   = 0
        var factors: [BuyerReadinessResult.ScoringFactor] = []
        var flags:   [BuyerReadinessResult.RiskFlag]      = []

        let contactCalls = callLogs.filter {
            let raw = $0.contactName.trimmingCharacters(in: .whitespaces)
            return !raw.isEmpty && PipelineStore.contactKey(raw) == contact.id
        }
        let contactSaleLogs = saleLogs.filter {
            let names = [$0.contactName, $0.buyerName, $0.sellerName, $0.referredClientName]
            return names.contains { PipelineStore.contactKey($0.trimmingCharacters(in: .whitespaces)) == contact.id }
        }

        // ── 1. PRE-APPROVAL — highest single predictor (max 25 pts) ──
        let preApproval = meta?.preApprovalStatus ?? .notStarted
        let preApprovalPoints: Int
        switch preApproval {
        case .approved:    preApprovalPoints = 25
        case .inProgress:  preApprovalPoints = 12
        case .notRequired: preApprovalPoints = 10
        case .notStarted:  preApprovalPoints = 0
        }
        total += preApprovalPoints
        factors.append(.init(
            label: preApproval == .notStarted ? "No pre-approval yet" : preApproval.shortLabel,
            points: preApprovalPoints,
            icon: preApproval == .notStarted ? "exclamationmark.triangle" : preApproval.icon))

        // ── 2. LAST POSITIVE OUTCOME recency (max 20 pts) ────────────
        let positiveOutcomeDates: [Date] = contactCalls.compactMap { call -> Date? in
            switch call.outcome {
            case .showingArranged, .meetingArranged, .gatheredInfoForOffer: return call.date
            case .callAppointmentArranged: return nil
            }
        } + contactSaleLogs.filter {
            $0.type == .showingDone || $0.type == .offerSent
        }.map { $0.date }

        let lastPositiveDate = positiveOutcomeDates.max()
        let daysSincePositive = lastPositiveDate.map {
            cal.dateComponents([.day], from: $0, to: now).day ?? 999
        } ?? 999

        let positiveRecencyPoints: Int
        switch daysSincePositive {
        case 0:       positiveRecencyPoints = 20
        case 1...3:   positiveRecencyPoints = 17
        case 4...7:   positiveRecencyPoints = 13
        case 8...14:  positiveRecencyPoints = 8
        case 15...30: positiveRecencyPoints = 3
        default:      positiveRecencyPoints = 0
        }
        total += positiveRecencyPoints
        if let _ = lastPositiveDate {
            let dLabel = daysSincePositive == 0 ? "today" : "\(daysSincePositive)d ago"
            factors.append(.init(label: "Last positive outcome \(dLabel)",
                                 points: positiveRecencyPoints, icon: "star.fill"))
        } else {
            let daysSinceAny = cal.dateComponents([.day], from: contact.lastCallDate, to: now).day ?? 999
            let fp: Int
            switch daysSinceAny {
            case 0...3:  fp = 10; case 4...7: fp = 7; case 8...14: fp = 4; case 15...30: fp = 1; default: fp = 0
            }
            total += fp
            if fp > 0 {
                let d = daysSinceAny == 0 ? "today" : "\(daysSinceAny)d ago"
                factors.append(.init(label: "Last contact \(d)", points: fp, icon: "clock.fill"))
            }
        }

        // ── 3. SHOWINGS + stall detection ────────────────────────────
        let showings = contactSaleLogs.filter { $0.type == .showingDone }
        let offers   = contactSaleLogs.filter { $0.type == .offerSent }

        let showingPoints = min(showings.count * 6, 18)
        total += showingPoints
        if showings.count > 0 {
            let intCount = showings.filter {
                $0.showingFeedback == .veryInterested || $0.showingFeedback == .interested
            }.count
            factors.append(.init(
                label: "\(showings.count) showing\(showings.count == 1 ? "" : "s")\(intCount > 0 ? ", \(intCount) positive" : "")",
                points: showingPoints, icon: "door.right.hand.open"))
        }

        let viCount = showings.filter { $0.showingFeedback == .veryInterested }.count
        let feedbackBonus = min(viCount * 5, 10)
        total += feedbackBonus
        if feedbackBonus > 0 {
            factors.append(.init(label: "Strong showing interest ×\(viCount)",
                                 points: feedbackBonus, icon: "flame.fill"))
        }

        if showings.count >= 4 && offers.isEmpty {
            let sp = -8; total += sp
            factors.append(.init(label: "\(showings.count) showings, no offer yet", points: sp, icon: "exclamationmark.triangle.fill"))
            flags.append(.init(icon: "exclamationmark.triangle.fill", color: .orange,
                title: "Showing stall detected",
                detail: "\(showings.count) showings with no offer. Possible price mismatch — address expectations directly."))
        } else if showings.count >= 2 && offers.isEmpty {
            flags.append(.init(icon: "magnifyingglass.circle", color: Color(red: 0.95, green: 0.78, blue: 0),
                title: "No offer after \(showings.count) showings",
                detail: "Discuss budget fit and must-haves to find the right property faster."))
        }

        // ── 4. OFFERS (max 12 pts) ────────────────────────────────────
        let offerPoints = min(offers.count * 7, 12)
        total += offerPoints
        if offerPoints > 0 {
            factors.append(.init(label: "\(offers.count) offer\(offers.count == 1 ? "" : "s") sent",
                                 points: offerPoints, icon: "envelope.badge.fill"))
        }

        // ── 5. URGENCY (max 15 pts) ───────────────────────────────────
        if let urgency = contactSaleLogs.compactMap({ $0.buyerUrgencyLevel }).last {
            let up = urgency.score * 3; total += up
            factors.append(.init(label: urgency.rawValue, points: up, icon: urgency.icon))
        }

        // ── 6. LIFE EVENT detection ───────────────────────────────────
        let urgencyNote = (contactSaleLogs.compactMap { $0.buyerUrgencyNote }.last ?? "").lowercased()
        let lifeKeywords = ["child","baby","pregnant","lease","evict","job","transfer",
                            "relocat","divorce","marry","wedding","retired","school"]
        let hasLifeEvent = lifeKeywords.contains { urgencyNote.contains($0) }
        if hasLifeEvent {
            let lb = 8; total += lb
            factors.append(.init(label: "Life event detected", points: lb,
                                 icon: "person.crop.circle.badge.exclamationmark"))
            flags.append(.init(icon: "person.crop.circle.badge.exclamationmark", color: .purple,
                title: "Life event — high motivation",
                detail: "Contact has a life circumstance driving urgency. Act quickly and be empathetic."))
        }

        // ── 7. BUDGET / MARKET FIT ────────────────────────────────────
        if let budgetMax = meta?.budgetMax, budgetMax > 0 {
            let offersInRange = offers.filter { log in
                guard let maxP = log.valuePriceMax else { return false }
                return maxP <= budgetMax * 1.10
            }.count
            if offersInRange > 0 {
                let bf = 8; total += bf
                factors.append(.init(label: "Budget fits market", points: bf, icon: "eurosign.circle.fill"))
            } else if !offers.isEmpty {
                flags.append(.init(icon: "eurosign.triangle.fill", color: .red,
                    title: "Budget may not match offers",
                    detail: "Offers sent exceeded stated budget. Discuss expectations and current market reality."))
            }
        }

        // ── 8. TIME IN MARKET PENALTY (up to -12 pts) ─────────────────
        let monthsInMarket = contactSaleLogs.compactMap { $0.buyerMonthsInMarket }.last ?? 0
        if monthsInMarket > 0 {
            let penalty: Int
            switch monthsInMarket {
            case 0...2: penalty = 0; case 3...6: penalty = -3; case 7...12: penalty = -7; default: penalty = -12
            }
            total += penalty
            if penalty < 0 {
                factors.append(.init(label: "\(monthsInMarket) months in market", points: penalty, icon: "calendar"))
            }
        }

        // ── 9. COMPETITOR RISK ────────────────────────────────────────
        let daysSinceAny = cal.dateComponents([.day], from: contact.lastCallDate, to: now).day ?? 999
        let hasCompetitorRisk = monthsInMarket >= 6 && daysSinceAny > 14 && daysSincePositive > 21
        if hasCompetitorRisk {
            let rp = -8; total += rp
            factors.append(.init(label: "At risk of going cold", points: rp, icon: "person.fill.xmark"))
            flags.append(.init(icon: "person.fill.xmark", color: .red,
                title: "Competitor risk — act now",
                detail: "6+ months searching, no recent positive outcome, contact going cold. High risk of losing to another agent."))
        }

        // ── 10. ACTIVITY VOLUME (max 8 pts) ───────────────────────────
        let volumePoints = min(contactCalls.count * 2, 8)
        total += volumePoints
        if volumePoints > 0 {
            factors.append(.init(label: "\(contactCalls.count) call\(contactCalls.count == 1 ? "" : "s") logged",
                                 points: volumePoints, icon: "phone.fill"))
        }

        // ── TAG BONUS ─────────────────────────────────────────────────
        if let tag = contact.tag {
            let tp: Int
            switch tag {
            case .hotLead: tp = 8; case .activeClient: tp = 6; case .warmLead: tp = 4
            case .coldLead: tp = -5; case .pastClient: tp = 2; default: tp = 0
            }
            if tp != 0 { total += tp; factors.append(.init(label: "Tagged: \(tag.rawValue)", points: tp, icon: tag.icon)) }
        }

        // ── APPOINTMENTS ──────────────────────────────────────────────
        let ap = min(contact.appointmentCount * 2, 4); total += ap
        if ap > 0 {
            factors.append(.init(label: "\(contact.appointmentCount) appointment\(contact.appointmentCount == 1 ? "" : "s")",
                                 points: ap, icon: "calendar.badge.checkmark"))
        }

        let finalScore = max(0, min(100, total))
        let previousScore = computePreviousScore(contact: contact, saleLogs: saleLogs, callLogs: callLogs, daysBack: 7, isSeller: false)

        let stage: BuyerReadinessStage
        switch finalScore {
        case 0...20: stage = .cold; case 21...40: stage = .warmingUp
        case 41...62: stage = .engaged; case 63...82: stage = .hot; default: stage = .readyToClose
        }

        let actionPlan = buyerActionPlan(
            stage: stage, preApproval: preApproval,
            showingCount: showings.count, offerCount: offers.count,
            hasCompetitorRisk: hasCompetitorRisk, hasLifeEvent: hasLifeEvent,
            lastCallDays: daysSinceAny, monthsInMarket: monthsInMarket)

        return BuyerReadinessResult(
            score: finalScore, previousScore: previousScore, stage: stage,
            topFactors: factors.sorted { abs($0.points) > abs($1.points) }.prefix(5).map { $0 },
            flags: flags, actionPlan: actionPlan, isSeller: false)
    }

    // MARK: - Seller scoring

    private static func sellerScore(
        contact: PipelineContact,
        saleLogs: [SaleLog],
        callLogs: [CallLog]
    ) -> BuyerReadinessResult {

        let meta = contact.metadata
        let now  = Date()
        let cal  = Calendar.current
        var total   = 0
        var factors: [BuyerReadinessResult.ScoringFactor] = []
        var flags:   [BuyerReadinessResult.RiskFlag]      = []

        let contactSaleLogs = saleLogs.filter {
            let names = [$0.contactName, $0.buyerName, $0.sellerName]
            return names.contains { PipelineStore.contactKey($0.trimmingCharacters(in: .whitespaces)) == contact.id }
        }
        let contactCalls = callLogs.filter {
            PipelineStore.contactKey($0.contactName.trimmingCharacters(in: .whitespaces)) == contact.id
        }

        // CMA
        let cmaDone = meta?.cmaDone ?? false
        let cmaPoints = cmaDone ? 20 : 0; total += cmaPoints
        factors.append(.init(label: cmaDone ? "CMA completed" : "CMA not done yet",
                             points: cmaPoints, icon: "doc.text.fill"))

        // Listing signed
        let listingSigned = contactSaleLogs.contains { $0.type == .listingSigned }
        let listingPoints = listingSigned ? 30 : 0; total += listingPoints
        if listingPoints > 0 {
            factors.append(.init(label: "Listing signed", points: 30, icon: "signature"))
        }

        // Recency
        let daysSince = cal.dateComponents([.day], from: contact.lastCallDate, to: now).day ?? 999
        let rp: Int
        switch daysSince {
        case 0: rp = 15; case 1...3: rp = 12; case 4...7: rp = 8; case 8...14: rp = 4; case 15...30: rp = 1; default: rp = 0
        }
        total += rp
        factors.append(.init(label: "Last contact \(daysSince == 0 ? "today" : "\(daysSince)d ago")", points: rp, icon: "clock.fill"))

        // Price reductions
        let reductions = meta?.priceReductionCount ?? 0
        if reductions > 0 {
            let pb = min(reductions * 5, 10); total += pb
            factors.append(.init(label: "\(reductions) price reduction\(reductions == 1 ? "" : "s") agreed",
                                 points: pb, icon: "arrow.down.circle.fill"))
        }

        // Days on market penalty
        if let dom = meta?.daysOnMarket, dom > 0 {
            let dp: Int
            switch dom {
            case 0...30: dp = 0; case 31...60: dp = -5; case 61...90: dp = -10; default: dp = -15
            }
            total += dp
            if dp < 0 {
                factors.append(.init(label: "\(dom) days on market", points: dp, icon: "calendar.badge.exclamationmark"))
                if dom > 60 {
                    flags.append(.init(icon: "calendar.badge.exclamationmark", color: .red,
                        title: "\(dom) days on market",
                        detail: "Listing is stalling. Discuss price adjustment and marketing strategy with the seller."))
                }
            }
        }

        // Tag
        if let tag = contact.tag {
            let tp: Int
            switch tag {
            case .hotLead, .activeClient: tp = 6; case .warmLead: tp = 3; case .coldLead: tp = -4; default: tp = 0
            }
            if tp != 0 { total += tp; factors.append(.init(label: "Tagged: \(tag.rawValue)", points: tp, icon: tag.icon)) }
        }

        let finalScore = max(0, min(100, total))
        let previousScore = computePreviousScore(contact: contact, saleLogs: saleLogs, callLogs: callLogs, daysBack: 7, isSeller: true)

        let stage: BuyerReadinessStage
        switch finalScore {
        case 0...20: stage = .cold; case 21...40: stage = .warmingUp
        case 41...62: stage = .engaged; case 63...82: stage = .hot; default: stage = .readyToClose
        }

        let actionPlan = sellerActionPlan(
            cmaDone: cmaDone, listingSigned: listingSigned,
            daysOnMarket: meta?.daysOnMarket ?? 0,
            priceReductions: meta?.priceReductionCount ?? 0,
            lastCallDays: daysSince)

        return BuyerReadinessResult(
            score: finalScore, previousScore: previousScore, stage: stage,
            topFactors: factors.sorted { abs($0.points) > abs($1.points) }.prefix(5).map { $0 },
            flags: flags, actionPlan: actionPlan, isSeller: true)
    }

    // MARK: - Score velocity helper

    private static func computePreviousScore(
        contact: PipelineContact,
        saleLogs: [SaleLog],
        callLogs: [CallLog],
        daysBack: Int,
        isSeller: Bool
    ) -> Int? {
        let cutoff = Date().addingTimeInterval(Double(-daysBack) * 86400)
        let oldCalls = callLogs.filter {
            PipelineStore.contactKey($0.contactName.trimmingCharacters(in: .whitespaces)) == contact.id && $0.date <= cutoff
        }
        let oldSales = saleLogs.filter {
            PipelineStore.contactKey($0.contactName.trimmingCharacters(in: .whitespaces)) == contact.id && $0.date <= cutoff
        }
        guard !oldCalls.isEmpty || !oldSales.isEmpty else { return nil }

        let lastOldCall = oldCalls.sorted { $0.date > $1.date }.first?.date ?? .distantPast
        let daysSince = Calendar.current.dateComponents([.day], from: lastOldCall, to: cutoff).day ?? 999
        let baseRecency: Int
        switch daysSince {
        case 0: baseRecency = isSeller ? 15 : 20; case 1...3: baseRecency = isSeller ? 12 : 17
        case 4...7: baseRecency = isSeller ? 8 : 13; case 8...14: baseRecency = isSeller ? 4 : 8
        default: baseRecency = 0
        }
        let oldShowings = oldSales.filter { $0.type == .showingDone }.count
        let oldOffers   = oldSales.filter { $0.type == .offerSent }.count
        let pre = contact.metadata?.preApprovalStatus ?? .notStarted
        let preBonus = isSeller ? 0 : (pre == .approved ? 25 : pre == .inProgress ? 12 : 0)
        return max(0, min(100, preBonus + baseRecency + min(oldCalls.count * 2, 8) + min(oldShowings * 6, 18) + min(oldOffers * 7, 12)))
    }

    // MARK: - Buyer action plan

    private static func buyerActionPlan(
        stage: BuyerReadinessStage,
        preApproval: PreApprovalStatus,
        showingCount: Int,
        offerCount: Int,
        hasCompetitorRisk: Bool,
        hasLifeEvent: Bool,
        lastCallDays: Int,
        monthsInMarket: Int
    ) -> [BuyerReadinessResult.ActionStep] {
        var steps: [BuyerReadinessResult.ActionStep] = []

        if hasCompetitorRisk {
            return [
                .init(number: 1, icon: "exclamationmark.triangle.fill", action: "Call immediately — don't lose this client", reason: "Long search + going cold = high competitor risk."),
                .init(number: 2, icon: "house.fill", action: "Find 2–3 fresh listings matching their criteria", reason: "Show renewed value and relevance right now."),
                .init(number: 3, icon: "person.2.fill", action: "Schedule a face-to-face meeting to re-engage", reason: "Re-establish trust before they speak to another agent.")
            ]
        }

        if preApproval == .notStarted {
            steps.append(.init(number: 1, icon: "checkmark.seal", action: "Discuss pre-approval — the first priority", reason: "Pre-approval is the single biggest readiness signal."))
        }

        switch stage {
        case .cold:
            steps.append(.init(number: steps.count + 1, icon: "envelope.fill", action: "Send a personalised market overview", reason: "Build trust with education before pushing listings."))
            steps.append(.init(number: steps.count + 1, icon: "phone.fill", action: "Schedule a discovery call to map needs", reason: "Identify must-haves and deal-breakers early."))
            steps.append(.init(number: steps.count + 1, icon: "leaf.fill", action: "Add to nurture — follow up in 7 days", reason: "Cold buyers need consistent gentle contact, not pressure."))
        case .warmingUp:
            if preApproval != .approved {
                steps.append(.init(number: steps.count + 1, icon: "checkmark.seal", action: "Push for pre-approval — refer a mortgage broker", reason: "Pre-approval converts warm buyers to hot fast."))
            }
            steps.append(.init(number: steps.count + 1, icon: "house.fill", action: "Invite to a property showing this week", reason: "First showing creates emotional connection and urgency."))
            steps.append(.init(number: steps.count + 1, icon: "envelope.badge.fill", action: "Send 2–3 targeted listings matching their brief", reason: "Targeted listings show you understand their needs."))
        case .engaged:
            if showingCount >= 4 && offerCount == 0 {
                steps.append(.init(number: steps.count + 1, icon: "eurosign.circle", action: "Have a direct conversation about price expectations", reason: "\(showingCount) showings without an offer suggests price or criteria mismatch."))
            } else {
                steps.append(.init(number: steps.count + 1, icon: "door.right.hand.open", action: "Book the next showing immediately", reason: "Momentum is building — keep it going."))
            }
            steps.append(.init(number: steps.count + 1, icon: "doc.text.fill", action: "Prepare a sample offer to show the process", reason: "Demystifying the offer process reduces buyer anxiety."))
            steps.append(.init(number: steps.count + 1, icon: "calendar.badge.checkmark", action: "Set a decision timeline with the buyer", reason: "Deadlines create focus and prevent indefinite searching."))
        case .hot:
            return [
                .init(number: 1, icon: "envelope.badge.fill", action: "Present a formal offer on their preferred property", reason: "They're ready — hesitation at this stage loses deals."),
                .init(number: 2, icon: "person.2.fill", action: "Address remaining objections in a 1-on-1 meeting", reason: "Hot buyers who stall usually have an unspoken concern."),
                .init(number: 3, icon: "checkmark.seal.fill", action: "Confirm financing and legal readiness", reason: "Remove every barrier to closing before they cool off.")
            ]
        case .readyToClose:
            return [
                .init(number: 1, icon: "signature", action: "Initiate the contract and signing process today", reason: "They are ready — every day of delay risks second thoughts."),
                .init(number: 2, icon: "person.crop.circle.badge.checkmark", action: "Introduce your notary / legal contact", reason: "A smooth handoff keeps the deal moving forward."),
                .init(number: 3, icon: "star.fill", action: "Ask for a referral while enthusiasm is at its peak", reason: "Ready-to-close buyers are your best source of referrals.")
            ]
        }
        return Array(steps.prefix(3))
    }

    // MARK: - Seller action plan

    private static func sellerActionPlan(
        cmaDone: Bool,
        listingSigned: Bool,
        daysOnMarket: Int,
        priceReductions: Int,
        lastCallDays: Int
    ) -> [BuyerReadinessResult.ActionStep] {
        var steps: [BuyerReadinessResult.ActionStep] = []
        if !cmaDone {
            steps.append(.init(number: steps.count + 1, icon: "doc.text.fill", action: "Complete and present the CMA", reason: "A CMA is the foundation of the seller relationship."))
        }
        if !listingSigned {
            steps.append(.init(number: steps.count + 1, icon: "signature", action: "Move toward signing the listing agreement", reason: "No listing = no deal. Focus every conversation on this."))
        }
        if daysOnMarket > 45 {
            steps.append(.init(number: steps.count + 1, icon: "arrow.down.circle", action: "Present a price reduction analysis", reason: "\(daysOnMarket) days on market — price is likely the barrier."))
        } else if daysOnMarket > 0 {
            steps.append(.init(number: steps.count + 1, icon: "megaphone.fill", action: "Review marketing plan — boost exposure", reason: "Active marketing reduces time on market significantly."))
        }
        if lastCallDays > 7 {
            steps.append(.init(number: steps.count + 1, icon: "phone.fill", action: "Call with a market update — stay visible", reason: "Sellers who don't hear from their agent look for another one."))
        }
        if steps.count < 3 {
            steps.append(.init(number: steps.count + 1, icon: "house.fill", action: "Arrange open house or private viewings", reason: "More viewings = more offers = faster close."))
        }
        if steps.count < 3 {
            steps.append(.init(number: steps.count + 1, icon: "star.fill", action: "Request a seller testimonial for your portfolio", reason: "Happy listed sellers are powerful social proof."))
        }
        return Array(steps.prefix(3))
    }
}
