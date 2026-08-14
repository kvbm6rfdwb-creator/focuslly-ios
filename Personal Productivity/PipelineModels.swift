import Foundation
import SwiftUI

// MARK: - Lead Source
enum LeadSource: String, CaseIterable, Codable, Identifiable {
    case coldCall        = "Cold Call"
    case referral        = "Referral"
    case portal          = "Real Estate Portal"
    case socialMedia     = "Social Media"
    case email           = "Email / Inquiry"
    case networking      = "Networking"
    case cafeRestaurant  = "Café / Restaurant"
    var id: String { rawValue }
}

// MARK: - Contact Tag
enum ContactTag: String, CaseIterable, Codable, Identifiable {
    case hotLead      = "Hot Lead"
    case warmLead     = "Warm Lead"
    case coldLead     = "Cold Lead"
    case activeClient = "Active Client"
    case pastClient   = "Past Client"
    case referral     = "Referral"
    case nurture      = "Nurture"
    var id: String { rawValue }

    var color: String {
        switch self {
        case .hotLead:      return "red"
        case .warmLead:     return "orange"
        case .coldLead:     return "blue"
        case .activeClient: return "green"
        case .pastClient:   return "purple"
        case .referral:     return "teal"
        case .nurture:      return "gray"
        }
    }

    var icon: String {
        switch self {
        case .hotLead:      return "flame.fill"
        case .warmLead:     return "thermometer.medium"
        case .coldLead:     return "snowflake"
        case .activeClient: return "star.fill"
        case .pastClient:   return "clock.fill"
        case .referral:     return "person.2.fill"
        case .nurture:      return "leaf.fill"
        }
    }
}

// MARK: - Client Type
enum ClientType: String, CaseIterable, Codable, Identifiable {
    case sellerProspect   = "Seller — Prospecting"
    case sellerListed     = "Seller — Listed"
    case buyerActive      = "Buyer — Active"
    case buyerOfferStage  = "Buyer — Offer Stage"
    case buyerNurture     = "Buyer — Nurture"
    case postSale         = "Post-Sale"

    var id: String { rawValue }

    /// Days before a follow-up is considered overdue (default; buyer saturation overrides buyerActive)
    var defaultOverdueDays: Int {
        switch self {
        case .sellerProspect:  return 3
        case .sellerListed:    return 30
        case .buyerActive:     return 3
        case .buyerOfferStage: return 1
        case .buyerNurture:    return 14
        case .postSale:        return 30
        }
    }

    var icon: String {
        switch self {
        case .sellerProspect:  return "megaphone.fill"
        case .sellerListed:    return "house.fill"
        case .buyerActive:     return "magnifyingglass"
        case .buyerOfferStage: return "doc.text.fill"
        case .buyerNurture:    return "leaf.fill"
        case .postSale:        return "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .sellerProspect:  return .orange
        case .sellerListed:    return .brg
        case .buyerActive:     return .blue
        case .buyerOfferStage: return .red
        case .buyerNurture:    return .teal
        case .postSale:        return .purple
        }
    }

    var shortLabel: String {
        switch self {
        case .sellerProspect:  return "Seller prospect"
        case .sellerListed:    return "Listed seller"
        case .buyerActive:     return "Active buyer"
        case .buyerOfferStage: return "Offer stage"
        case .buyerNurture:    return "Nurture buyer"
        case .postSale:        return "Post-sale"
        }
    }
}

// MARK: - Pre-Approval Status
enum PreApprovalStatus: String, CaseIterable, Codable, Identifiable {
    case notStarted  = "Not started"
    case inProgress  = "In progress"
    case approved    = "Pre-approved"
    case notRequired = "Not required"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .notStarted:  return "questionmark.circle"
        case .inProgress:  return "clock.badge"
        case .approved:    return "checkmark.seal.fill"
        case .notRequired: return "minus.circle"
        }
    }
    var color: Color {
        switch self {
        case .notStarted:  return .secondary
        case .inProgress:  return .orange
        case .approved:    return .brg
        case .notRequired: return .secondary
        }
    }
    var shortLabel: String {
        switch self {
        case .notStarted:  return "Not started"
        case .inProgress:  return "In progress"
        case .approved:    return "Pre-approved ✓"
        case .notRequired: return "Not required"
        }
    }
}

// MARK: - Contact Metadata (editable, persisted separately from call logs)
struct ContactMetadata: Identifiable, Codable {
    var id: String          // normalised name key — matches PipelineContact.id
    var displayName: String
    var phone: String = ""
    var email: String = ""
    var company: String = ""
    var tag: ContactTag? = nil
    var clientType: ClientType? = nil
    var buyerSaturated: Bool = false   // active buyer who has seen most available inventory
    var notes: String = ""
    var isPinned: Bool = false
    var isImported: Bool = false       // true when created via Apple Contacts import
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // ── Buyer intelligence fields ──────────────────────────────────────
    var preApprovalStatus: PreApprovalStatus = .notStarted
    var budgetMin: Double? = nil          // minimum budget in EUR
    var budgetMax: Double? = nil          // maximum budget in EUR
    var preferredRegions: [String] = []   // preferred neighbourhoods / areas
    var mustHaveFeatures: String = ""     // e.g. "3 bedrooms, garage, garden"
    var dealBreakers: String = ""         // e.g. "no top floor, busy roads"

    // ── Seller intelligence fields ─────────────────────────────────────
    var cmaDone: Bool = false
    var daysOnMarket: Int? = nil
    var askingPrice: Double? = nil
    var priceReductionCount: Int = 0
}

// MARK: - Call Outcome
enum CallOutcome: String, CaseIterable, Codable, Identifiable {
    case callAppointmentArranged  = "Call appointment arranged"
    case meetingArranged          = "Meeting arranged"
    case gatheredInfoForOffer     = "Gathered information to send an offer"
    case showingArranged          = "Showing arranged"
    var id: String { rawValue }

    var isMeaningful: Bool { true }

    var isConnected: Bool { true }
}

// MARK: - Next Step Type
enum NextStepType: String, CaseIterable, Codable, Identifiable {
    case retryCall        = "Retry call"
    case followUpCall     = "Follow-up call"
    case appointment      = "Appointment / Showing"
    case prepareCMA       = "Prepare CMA / VCMA"
    case sendOffer        = "Send offer / proposal"
    case sendListingInfo  = "Send listing info"
    case nurture          = "Nurture – call later"
    case openHouse        = "Invite to open house"
    case none             = "No next step"
    var id: String { rawValue }

    /// Default suggested duration in minutes
    var defaultDurationMinutes: Int {
        switch self {
        case .retryCall:       return 5
        case .followUpCall:    return 10
        case .appointment:     return 45
        case .prepareCMA:      return 35
        case .sendOffer:       return 60
        case .sendListingInfo: return 15
        case .nurture:         return 10
        case .openHouse:       return 5
        case .none:            return 0
        }
    }

    var icon: String {
        switch self {
        case .retryCall:       return "phone.arrow.up.right"
        case .followUpCall:    return "phone.fill"
        case .appointment:     return "calendar.badge.plus"
        case .prepareCMA:      return "doc.text.fill"
        case .sendOffer:       return "envelope.fill"
        case .sendListingInfo: return "house.fill"
        case .nurture:         return "clock.fill"
        case .openHouse:       return "person.3.fill"
        case .none:            return "checkmark.circle"
        }
    }
}

// MARK: - Call Log
struct CallLog: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var contactName: String = ""
    var leadSource: LeadSource = .coldCall
    var outcome: CallOutcome = .callAppointmentArranged
    var askedForAppointment: Bool = false   // must track – 100% target
    var nextStep: NextStepType = .none
    var responseTimeSeconds: Int? = nil     // seconds from lead arrival to this call
    var notes: String = ""
    var generatedTaskID: UUID? = nil        // the FocusTask auto-created
}

// MARK: - Pipeline Deal (opportunity / contact)
enum DealStage: String, CaseIterable, Codable, Identifiable {
    case lead        = "Lead"
    case contacted   = "Contacted"
    case appointment = "Appointment"
    case proposal    = "Proposal sent"
    case listing     = "Listing signed"
    case offer       = "Offer accepted"
    case closed      = "Closed"
    case lost        = "Lost"
    var id: String { rawValue }

    /// Returns the next stage in the pipeline progression, or nil if already at a terminal stage.
    var next: DealStage? {
        switch self {
        case .lead:        return .contacted
        case .contacted:   return .appointment
        case .appointment: return .proposal
        case .proposal:    return .listing
        case .listing:     return .offer
        case .offer:       return .closed
        case .closed, .lost: return nil
        }
    }
}

struct PipelineDeal: Identifiable, Codable {
    var id: UUID = UUID()
    var contactName: String = ""
    var leadSource: LeadSource = .coldCall
    var stage: DealStage = .lead
    var propertyDescription: String = ""
    var estimatedValue: Double? = nil
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var closedAt: Date? = nil
    var notes: String = ""

    // Counters for analytics — incremented by PipelineStore when activities are logged
    var callsCount: Int = 0
    var offersCount: Int = 0
    var listingsAddedCount: Int = 0
    var focusSessionsCount: Int = 0
    var activityLog: [DealActivityLog] = []
}

// MARK: - Sale / Outcome Log
enum SaleOutcomeType: String, CaseIterable, Codable, Identifiable {
    case listingSigned    = "Listing signed"
    case offerSent        = "Offer sent"
    case showingDone      = "Showing done"
    case closedDeal       = "Closed deal"
    case referralReceived = "Referral received"
    var id: String { rawValue }
}

enum ReferralSource: String, CaseIterable, Codable, Identifiable {
    case existingClient = "Existing client"
    case friend         = "Friend"
    case family         = "Family"
    case other          = "Other"
    var id: String { rawValue }
}

struct SaleLog: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: SaleOutcomeType
    var contactName: String = ""
    var dealID: UUID? = nil
    var propertyDescription: String = ""
    var valueEUR: Double? = nil
    // Price range (for offerSent & referralReceived)
    var valuePriceMin: Double? = nil
    var valuePriceMax: Double? = nil
    // Regions (for offerSent & referralReceived & closedDeal)
    var selectedRegions: [String] = []
    // Referral fields (for referralReceived)
    var referralSource: ReferralSource? = nil
    var referralSourceName: String = ""
    var referredClientName: String = ""
    // Closed deal fields
    var buyerName: String = ""
    var sellerName: String = ""
    var listedPriceEUR: Double? = nil
    var soldPriceEUR: Double? = nil
    // Showing done fields
    var showingPropertyAddress: String = ""
    var showingFeedback: ShowingFeedback? = nil
    // Buyer context (used for readiness score)
    var buyerMonthsInMarket: Int? = nil        // how long buyer has been searching
    var buyerUrgencyLevel: BuyerUrgency? = nil // how urgently they need to move
    var buyerUrgencyNote: String = ""          // free-text e.g. "expecting child, must move by April"
    var notes: String = ""
}

// MARK: - Showing Feedback
enum ShowingFeedback: String, CaseIterable, Codable, Identifiable {
    case veryInterested  = "Very interested"
    case interested      = "Interested"
    case neutral         = "Neutral"
    case notInterested   = "Not interested"
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .veryInterested: return "flame.fill"
        case .interested:     return "hand.thumbsup.fill"
        case .neutral:        return "minus.circle.fill"
        case .notInterested:  return "xmark.circle.fill"
        }
    }
    var color: Color {
        switch self {
        case .veryInterested: return .red
        case .interested:     return .orange
        case .neutral:        return .secondary
        case .notInterested:  return .blue
        }
    }
}

// MARK: - Buyer Urgency
enum BuyerUrgency: String, CaseIterable, Codable, Identifiable {
    case critical  = "Critical — must move ASAP"
    case high      = "High — within 1–2 months"
    case medium    = "Medium — within 3–6 months"
    case low       = "Low — no rush, exploring"
    var id: String { rawValue }
    var score: Int {
        switch self { case .critical: return 4; case .high: return 3; case .medium: return 2; case .low: return 1 }
    }
    var color: Color {
        switch self {
        case .critical: return .red
        case .high:     return .orange
        case .medium:   return .yellow
        case .low:      return .blue
        }
    }
    var icon: String {
        switch self {
        case .critical: return "exclamationmark.triangle.fill"
        case .high:     return "flame.fill"
        case .medium:   return "clock.fill"
        case .low:      return "leaf.fill"
        }
    }
}

// MARK: - Open House Log
struct OpenHouseLog: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var propertyAddress: String = ""
    var visitorsCount: Int = 0
    var contactsCaptured: Int = 0   // target: 10-20 per weekend
    var notes: String = ""
}

// MARK: - Content Log
enum ContentType: String, CaseIterable, Codable, Identifiable {
    case instagramReel  = "Instagram Reel"
    case tiktok         = "TikTok"
    case story          = "Story"
    case emailNewsletter = "Email Newsletter"
    case blogPost       = "Blog Post"
    case other          = "Other"
    var id: String { rawValue }
}

struct ContentLog: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: ContentType
    var title: String = ""
    var leadsGenerated: Int = 0
    var notes: String = ""
}

// MARK: - Training Log
struct TrainingLog: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var durationMinutes: Int = 30   // weekly target: 120 min
    var topic: String = ""
    var notes: String = ""
}

// MARK: - CSAT Survey Entry
struct CSATEntry: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var score: Double           // 1.0 – 5.0, target: 4.8+
    var clientName: String = ""
    var notes: String = ""
}

// MARK: - Daily Discipline Check
struct BigFourCheck: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var signedSomething: Int = 0
    var soldSomething: Int = 0
    var setAppointment: Int = 0
    var completedTraining: Int = 0   // physical or professional training sessions

    /// Passes if the user signed, sold, set an appointment, or completed training today.
    /// Card passes when at least one of the three tracked sales actions is done.
    /// Training is tracked separately on the Dashboard and does not count here.
    var passesRule: Bool {
        signedSomething > 0 || soldSomething > 0 || setAppointment > 0
    }

    var totalActions: Int {
        signedSomething + soldSomething + setAppointment
    }
}

// MARK: - Duration Learning Entry (for adaptive suggestions)
struct DurationLearningEntry: Codable {
    var nextStepType: NextStepType
    var suggestedMinutes: Int
    var actualMinutes: Int
    var date: Date = Date()
}

// MARK: - Pipeline Task Category
/// Tags a FocusTask as pipeline-relevant so completions can be auto-logged.
enum PipelineTaskCategory: String, CaseIterable, Codable, Identifiable {
    case followUps        = "Follow-Ups"
    case sendOffers       = "Send Offers"
    case addListing       = "Add New Listing"
    case answerInquiries  = "Answer Inquiries"
    case meeting          = "Meeting"
    case physicalTraining = "Physical Training"
    case reading          = "Reading"
    case coldCalls        = "Cold Calls"
    case cmaAdmin         = "CMA / Admin"
    var id: String { rawValue }

    var icon: String {
        switch self {
        case .followUps:        return "arrow.uturn.right"
        case .sendOffers:       return "doc.text.fill"
        case .addListing:       return "house.fill"
        case .answerInquiries:  return "message.fill"
        case .meeting:          return "person.2.fill"
        case .physicalTraining: return "figure.run"
        case .reading:          return "book.fill"
        case .coldCalls:        return "phone.fill"
        case .cmaAdmin:         return "doc.badge.gearshape.fill"
        }
    }

    var color: String { // stored as string for Codable simplicity
        switch self {
        case .followUps:        return "green"
        case .sendOffers:       return "blue"
        case .addListing:       return "orange"
        case .answerInquiries:  return "teal"
        case .meeting:          return "purple"
        case .physicalTraining: return "red"
        case .reading:          return "indigo"
        case .coldCalls:        return "cyan"
        case .cmaAdmin:         return "brown"
        }
    }
}

// MARK: - Deal Activity Log
/// A timestamped event attached to a PipelineDeal, auto-generated when
/// a FocusTask with a pipelineCategory completes or when a user logs an outcome.
struct DealActivityLog: Identifiable, Codable {
    var id: UUID = UUID()
    var dealID: UUID
    var date: Date = Date()
    var type: ActivityType
    var notes: String = ""
    var taskID: UUID? = nil        // linked FocusTask, if any
    var durationMinutes: Int? = nil

    enum ActivityType: String, CaseIterable, Codable, Identifiable {
        case call             = "Call"
        case followUpCall     = "Follow-Up Call"
        case offerSent        = "Offer Sent"
        case listingAdded     = "Listing Added"
        case meetingHeld      = "Meeting"
        case cmaPrepped       = "CMA Prepared"
        case appointmentSet   = "Appointment Set"
        case appointmentHeld  = "Appointment Held"
        case listingSigned    = "Listing Signed"
        case closedSale       = "Closed Sale"
        case focusSession     = "Focus Session"
        case stageAdvanced    = "Stage Advanced"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .call:            return "phone.fill"
            case .followUpCall:    return "arrow.uturn.right"
            case .offerSent:       return "doc.text.fill"
            case .listingAdded:    return "house.fill"
            case .meetingHeld:     return "person.2.fill"
            case .cmaPrepped:      return "doc.badge.gearshape.fill"
            case .appointmentSet:  return "calendar.badge.plus"
            case .appointmentHeld: return "calendar.badge.checkmark"
            case .listingSigned:   return "signature"
            case .closedSale:      return "checkmark.seal.fill"
            case .focusSession:    return "bolt.fill"
            case .stageAdvanced:   return "arrow.right.circle.fill"
            }
        }
    }
}

// MARK: - Hot Sheet Review
struct HotSheetReview: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()         // daily target: every morning
    var completed: Bool = true
}

// MARK: - CMA/VCMA Log
struct CMALog: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var contactName: String = ""
    var type: CMAType = .cma
    var sent: Bool = true
    var resultedInAppointment: Bool = false
    var resultedInListing: Bool = false
    var notes: String = ""

    enum CMAType: String, Codable, CaseIterable, Identifiable {
        case cma  = "CMA"
        case vcma = "VCMA"
        var id: String { rawValue }
    }
}
