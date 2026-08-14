import Foundation
import SwiftUI
import Combine

// MARK: - Vision Constants

nonisolated let visionTargetQuestionCount = 100

/// Questions shown in the last N days are excluded from the daily pool (anti-repetition).
nonisolated let visionQuestionRepeatCooldownDays = 7

// MARK: - Progressive Disclosure / Soft-Cap constants

/// Maximum questions served to the user per category before clarity is checked.
/// The full bank is kept; only this many are *offered*.
nonisolated let visionCategorySoftCap = 15

/// Minimum "core" questions (Values / Identity module) per category before deep-dives unlock.
nonisolated let visionCategoryCoreMin = 3

/// After this many answers in a category the engine runs a clarity check.
nonisolated let visionClarityCheckAfter = 5

/// A category is considered "clear enough" when its answers average ≥ this many words.
/// Short answers (MCQ ≈ 3–5 words) keep the bar low; real sentences push it up.
nonisolated let visionClarityWordThreshold = 8

// MARK: - Category Clarity

/// Snapshot of how much useful data a category has supplied for story generation.
struct CategoryClarity: Equatable {
    let categoryId: UUID
    /// Number of non-empty answers in this category.
    let answerCount: Int
    /// Average word count across all answers (short MCQ answers count).
    let avgWordCount: Double
    /// `true` when the category has enough data to generate a coherent Vision Card
    /// and questions should stop unless the user asks for more depth.
    var isClear: Bool {
        answerCount >= visionClarityCheckAfter && avgWordCount >= Double(visionClarityWordThreshold)
    }
    /// `true` when the soft cap of served questions has been reached for this category.
    var atSoftCap: Bool { answerCount >= visionCategorySoftCap }
    /// `true` when the minimum core questions have been answered (unlock deep-dives).
    var coreComplete: Bool { answerCount >= visionCategoryCoreMin }
}

// MARK: - Timeline Event Models

enum DailyEventAction: String, Codable {
    case picked      // question was selected into today's set
    case answered    // user submitted an answer
    case reviewed    // user revisited a previous answer
    case milestone   // a readiness threshold was crossed
    case nextStep    // daily "what to do next" guidance
}

/// One persisted event in a day's activity log.
struct DailyEvent: Identifiable, Codable, Equatable {
    let id: UUID
    /// The calendar day this event belongs to (startOfDay).
    let date: Date
    /// Exact time the event occurred.
    let timestamp: Date
    let action: DailyEventAction
    var questionId: UUID?
    var categoryId: UUID?
    var module: VisionModule?
    /// Human-readable explanation — e.g. "Picked: module priority (Values)", "Milestone: 20 answers".
    var note: String?
    /// For review events: how much confidence changed (positive = grew, negative = reset).
    var confidenceDelta: Double?

    init(
        id: UUID = UUID(),
        date: Date,
        timestamp: Date = Date(),
        action: DailyEventAction,
        questionId: UUID? = nil,
        categoryId: UUID? = nil,
        module: VisionModule? = nil,
        note: String? = nil,
        confidenceDelta: Double? = nil
    ) {
        self.id = id; self.date = date; self.timestamp = timestamp
        self.action = action; self.questionId = questionId
        self.categoryId = categoryId; self.module = module
        self.note = note; self.confidenceDelta = confidenceDelta
    }
}

// MARK: - Voice Anchors

struct VisionVoiceAnchors: Codable, Equatable {
    enum Tone: String, Codable, CaseIterable, Identifiable {
        case calm, ambitious, playful, minimal, reflective
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .calm: return "Calm & Grounded"
            case .ambitious: return "Bold & Ambitious"
            case .playful: return "Light & Playful"
            case .minimal: return "Short & Direct"
            case .reflective: return "Thoughtful & Personal"
            }
        }
    }

    var tone: Tone
    var audience: String   // "me", "my future self", etc.
    var valuesWhy: String  // "freedom, health, family"

    static let `default` = VisionVoiceAnchors(tone: .reflective, audience: "", valuesWhy: "")

    /// Anchors are "set" once the user has provided a meaningful why.
    var isSet: Bool {
        valuesWhy.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10
    }
}

// MARK: - Story Quality Contract

/// All thresholds the system checks before it can generate a worthy story.
struct VisionNarrativeReadiness: Equatable {
    var answeredCount: Int
    var uniqueCategoryCount: Int
    var richAnswerCount: Int      // answers with ≥15 words
    var characterCount: Int       // total chars across all relevant answers
    var anchorsSet: Bool

    // ── Thresholds ──────────────────────────────────────────────────────
    static let targetAnswered: Int   = 20  // 20 answers (MCQ count too)
    static let targetCategories: Int = 4   // spread across 4+ categories
    static let targetChars: Int      = 300 // low bar — MCQ answers are short

    // ── Gate (no richAnswerCount gate — MCQ answers are valid) ──────────
    var isReady: Bool {
        anchorsSet
        && answeredCount       >= Self.targetAnswered
        && uniqueCategoryCount >= Self.targetCategories
        && characterCount      >= Self.targetChars
    }

    // ── 0…1 composite progress ──────────────────────────────────────────
    var progress: Double {
        let v = anchorsSet ? 1.0 : 0.0
        let a = min(Double(answeredCount)       / Double(Self.targetAnswered),   1)
        let c = min(Double(uniqueCategoryCount) / Double(Self.targetCategories), 1)
        let t = min(Double(characterCount)      / Double(Self.targetChars),      1)
        return (v + a + c + t) / 4
    }

    // ── Single top-priority CTA ─────────────────────────────────────────
    var nextActionLabel: String {
        if !anchorsSet                                 { return "Set your voice to unlock your story" }
        if uniqueCategoryCount < Self.targetCategories { return "Answer in \(Self.targetCategories - uniqueCategoryCount) more categor\(Self.targetCategories - uniqueCategoryCount == 1 ? "y" : "ies")" }
        if answeredCount       < Self.targetAnswered   { return "\(Self.targetAnswered - answeredCount) more answer\(Self.targetAnswered - answeredCount == 1 ? "" : "s") to go" }
        if characterCount      < Self.targetChars      { return "Add a few more answers" }
        return "Your story is ready"
    }

    /// Full breakdown used by the seedling detail rows.
    var missingSummary: String { nextActionLabel }
}

// MARK: - Vision Module

enum VisionModule: String, Codable, CaseIterable {
    case values, idealDay, sensory, visionStatement, bhag, smart, woop, habits, accountability, discovery

    var priority: Int {
        switch self {
        case .values: return 0; case .idealDay: return 1; case .sensory: return 2
        case .visionStatement: return 3; case .bhag: return 4; case .smart: return 5
        case .woop: return 6; case .habits: return 7; case .accountability: return 8
        case .discovery: return 9
        }
    }

    var label: String {
        switch self {
        case .values: return "Values"; case .idealDay: return "Ideal Day"; case .sensory: return "Visualise"
        case .visionStatement: return "Vision"; case .bhag: return "North Star"; case .smart: return "Milestone"
        case .woop: return "Obstacle Plan"; case .habits: return "Habits"
        case .accountability: return "Accountability"; case .discovery: return "Explore"
        }
    }

    var icon: String {
        switch self {
        case .values: return "heart.fill"; case .idealDay: return "sun.max.fill"; case .sensory: return "eye.fill"
        case .visionStatement: return "text.quote"; case .bhag: return "star.fill"; case .smart: return "checklist"
        case .woop: return "shield.fill"; case .habits: return "arrow.clockwise"
        case .accountability: return "person.2.fill"; case .discovery: return "sparkles"
        }
    }
}

// MARK: - Vision Models

struct VisionCategory: Identifiable, Codable {
    let id: UUID
    let name: String
    let emoji: String
    let isCustom: Bool
    let createdAt: Date
    var isSelected: Bool = true
    /// User explicitly said "I'm happy here — stop asking". Excludes category from the daily pool.
    var isSatisfied: Bool = false

    init(id: UUID = UUID(), name: String, emoji: String, isCustom: Bool = false, createdAt: Date = Date()) {
        self.id = id; self.name = name; self.emoji = emoji
        self.isCustom = isCustom; self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try  c.decode(UUID.self,   forKey: .id)
        name        = try  c.decode(String.self, forKey: .name)
        emoji       = try  c.decode(String.self, forKey: .emoji)
        isCustom    = try  c.decode(Bool.self,   forKey: .isCustom)
        createdAt   = try  c.decode(Date.self,   forKey: .createdAt)
        isSelected  = (try? c.decode(Bool.self,  forKey: .isSelected))  ?? true
        isSatisfied = (try? c.decode(Bool.self,  forKey: .isSatisfied)) ?? false
    }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, isCustom, createdAt, isSelected, isSatisfied
    }
}

struct VisionAnswer: Identifiable, Codable {
    let id: UUID
    let categoryId: UUID
    let questionText: String
    var answerText: String
    let timeframeYears: Int
    let answeredAt: Date
    var imageURLs: [URL]
    var confidence: Double
    var lastReviewedAt: Date?
    var hasBeenRevisited: Bool
    // NEW optional fields (backward compatible)
    var excitementRating: Int?   // 1–5 how exciting this answer feels
    var confidenceRating: Int?   // 1–5 how realistic/achievable

    init(id: UUID = UUID(), categoryId: UUID, questionText: String, answerText: String,
         timeframeYears: Int = 5, answeredAt: Date = Date(), imageURLs: [URL] = [],
         confidence: Double = 0.5, excitementRating: Int? = nil, confidenceRating: Int? = nil) {
        self.id = id; self.categoryId = categoryId; self.questionText = questionText
        self.answerText = answerText; self.timeframeYears = timeframeYears
        self.answeredAt = answeredAt; self.imageURLs = imageURLs; self.confidence = confidence
        self.lastReviewedAt = nil; self.hasBeenRevisited = false
        self.excitementRating = excitementRating; self.confidenceRating = confidenceRating
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try  c.decode(UUID.self,   forKey: .id)
        categoryId       = try  c.decode(UUID.self,   forKey: .categoryId)
        questionText     = try  c.decode(String.self, forKey: .questionText)
        answerText       = try  c.decode(String.self, forKey: .answerText)
        timeframeYears   = try  c.decode(Int.self,    forKey: .timeframeYears)
        answeredAt       = try  c.decode(Date.self,   forKey: .answeredAt)
        imageURLs        = (try? c.decode([URL].self,  forKey: .imageURLs))    ?? []
        confidence       = (try? c.decode(Double.self, forKey: .confidence))   ?? 0.5
        lastReviewedAt   = try? c.decode(Date.self,    forKey: .lastReviewedAt)
        hasBeenRevisited = (try? c.decode(Bool.self,   forKey: .hasBeenRevisited)) ?? false
        excitementRating = try? c.decode(Int.self,     forKey: .excitementRating)
        confidenceRating = try? c.decode(Int.self,     forKey: .confidenceRating)
    }

    enum CodingKeys: String, CodingKey {
        case id, categoryId, questionText, answerText, timeframeYears
        case answeredAt, imageURLs, confidence, lastReviewedAt, hasBeenRevisited
        case excitementRating, confidenceRating
    }
}

struct VisionStatement: Identifiable, Codable {
    let id: UUID
    let categoryId: UUID
    let timeframeYears: Int
    let synthesizedText: String
    let relatedAnswerIds: [UUID]
    let generatedAt: Date
    var moodboardImages: [URL] = []

    init(id: UUID = UUID(), categoryId: UUID, timeframeYears: Int, synthesizedText: String,
         relatedAnswerIds: [UUID], generatedAt: Date = Date()) {
        self.id = id; self.categoryId = categoryId; self.timeframeYears = timeframeYears
        self.synthesizedText = synthesizedText; self.relatedAnswerIds = relatedAnswerIds
        self.generatedAt = generatedAt
    }
}

struct DailyQuestionLog: Identifiable, Codable {
    let id: UUID
    let date: Date
    var answeredQuestionIds: [UUID]
    var skippedQuestionIds: [UUID]
    var todayQuestionIds: [UUID]
    var answeredCount: Int
    /// Persisted event stream — every pick / answer / review / milestone for this day.
    var events: [DailyEvent]
    /// Maps questionId → why it was chosen today ("Picked: module priority (Values)").
    var pickReasonsByQuestionId: [String: String]   // String keys for JSON compat

    init(id: UUID = UUID(), date: Date = Date()) {
        self.id = id; self.date = date
        answeredQuestionIds = []; skippedQuestionIds = []
        todayQuestionIds = []; answeredCount = 0
        events = []; pickReasonsByQuestionId = [:]
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                       = try  c.decode(UUID.self,   forKey: .id)
        date                     = try  c.decode(Date.self,   forKey: .date)
        answeredQuestionIds      = (try? c.decode([UUID].self,        forKey: .answeredQuestionIds))      ?? []
        skippedQuestionIds       = (try? c.decode([UUID].self,        forKey: .skippedQuestionIds))       ?? []
        todayQuestionIds         = (try? c.decode([UUID].self,        forKey: .todayQuestionIds))         ?? []
        answeredCount            = (try? c.decode(Int.self,           forKey: .answeredCount))            ?? 0
        events                   = (try? c.decode([DailyEvent].self,  forKey: .events))                   ?? []
        pickReasonsByQuestionId  = (try? c.decode([String: String].self, forKey: .pickReasonsByQuestionId)) ?? [:]
    }

    enum CodingKeys: String, CodingKey {
        case id, date, answeredQuestionIds, skippedQuestionIds, todayQuestionIds, answeredCount
        case events, pickReasonsByQuestionId
    }
}

// MARK: - Question Type

/// Every question belongs to one of these intent types.
/// This drives UI enforcement (sentence gate), story weighting, and SMART hints.
enum QuestionType: String, Codable, CaseIterable {
    /// The single most important outcome for this category
    case northStar
    /// Why this matters *right now*, not later
    case whyNow
    /// Identity — who the user is becoming
    case identity
    /// Observable evidence that success has happened
    case observable
    /// Constraint — what's ruled out to keep focus
    case constraint
    /// Tradeoff — what the user will say no to
    case tradeoff
    /// Milestone ladder — stepping stone toward the north star
    case milestone
    /// Pre-mortem — biggest risk + prevention plan
    case premortem
    /// Values → concrete behaviour on a normal day
    case valueBehavior
    /// Decision rule / principle for future choices
    case decisionRule
    /// SMART measurable metric
    case measurable
    /// Qualitative signal when measurement isn't possible
    case qualitative
    /// Environment design — what to change in surroundings
    case environment
    /// Support network — who and what to ask of them
    case support
    /// Counterfactual — what worsens if nothing changes
    case counterfactual
    /// Vivid narrative scene — sensory/story detail
    case vivid
    /// Structured template answer (fill-in-the-blank)
    case structured
    /// General discovery / preference question (MCQ-friendly)
    case discovery
    /// Weekly habits and systems
    case habits
    /// Accountability and review cadence
    case accountability

    /// Whether this type requires a sentence-level answer (≥12 words, ≥60 chars).
    var requiresSentence: Bool {
        switch self {
        case .northStar, .whyNow, .identity, .observable,
             .premortem, .vivid, .structured, .valueBehavior,
             .counterfactual: return true
        default: return false
        }
    }

    /// A short coaching hint shown below the text input for this type.
    var smartHint: String? {
        switch self {
        case .northStar:      return "Make it Specific and Time-bound — name the outcome and when."
        case .measurable:     return "Include a number or metric you can track."
        case .observable:     return "Describe what someone else would *see* that proves it's true."
        case .milestone:      return "What must be true 12 months before your end goal?"
        case .premortem:      return "Name the most likely obstacle and your prevention plan."
        case .constraint:     return "Be honest — what are you ruling out to stay focused?"
        case .tradeoff:       return "What will you say no to so this can happen?"
        case .environment:    return "Think: apps, calendar, home, people around you."
        case .support:        return "Name a specific person and what you'll ask of them."
        case .counterfactual: return "What will get worse in 12 months if you do nothing?"
        case .vivid:          return "Write it like a scene — include senses and details."
        case .structured:     return "Complete the sentence fully — be specific."
        default:              return nil
        }
    }
}

// MARK: - Vision Question

struct VisionQuestion: Identifiable, Codable {
    let id: UUID
    let categoryId: UUID
    let questionText: String
    let timeframeYears: Int
    let isAiGenerated: Bool
    let createdAt: Date
    let relatedAnswerIds: [UUID]
    let answerOptions: [String]?
    let questionType: QuestionType
    var isReview: Bool
    var previousAnswerText: String?
    var reviewAnswerId: UUID?
    // NEW optional fields (backward compatible)
    var module: VisionModule?        // which research module this belongs to
    var horizonTag: String?          // "3-5y", "1y", "quarter", "month", "week"
    var lastAskedDate: Date?         // for 7-day anti-repetition

    init(id: UUID = UUID(), categoryId: UUID, questionText: String, timeframeYears: Int = 5,
         isAiGenerated: Bool = true, createdAt: Date = Date(), relatedAnswerIds: [UUID] = [],
         answerOptions: [String]? = nil, questionType: QuestionType = .discovery,
         isReview: Bool = false, previousAnswerText: String? = nil, reviewAnswerId: UUID? = nil,
         module: VisionModule? = nil, horizonTag: String? = nil) {
        self.id = id; self.categoryId = categoryId; self.questionText = questionText
        self.timeframeYears = timeframeYears; self.isAiGenerated = isAiGenerated
        self.createdAt = createdAt; self.relatedAnswerIds = relatedAnswerIds
        self.answerOptions = answerOptions; self.questionType = questionType
        self.isReview = isReview; self.previousAnswerText = previousAnswerText
        self.reviewAnswerId = reviewAnswerId
        self.module = module; self.horizonTag = horizonTag; self.lastAskedDate = nil
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try  c.decode(UUID.self,         forKey: .id)
        categoryId        = try  c.decode(UUID.self,         forKey: .categoryId)
        questionText      = try  c.decode(String.self,       forKey: .questionText)
        timeframeYears    = try  c.decode(Int.self,          forKey: .timeframeYears)
        isAiGenerated     = try  c.decode(Bool.self,         forKey: .isAiGenerated)
        createdAt         = try  c.decode(Date.self,         forKey: .createdAt)
        relatedAnswerIds  = (try? c.decode([UUID].self,      forKey: .relatedAnswerIds)) ?? []
        answerOptions     = try? c.decode([String].self,     forKey: .answerOptions)
        questionType      = (try? c.decode(QuestionType.self,forKey: .questionType)) ?? .discovery
        isReview          = (try? c.decode(Bool.self,        forKey: .isReview))          ?? false
        previousAnswerText = try? c.decode(String.self,      forKey: .previousAnswerText)
        reviewAnswerId    = try? c.decode(UUID.self,         forKey: .reviewAnswerId)
        module            = try? c.decode(VisionModule.self, forKey: .module)
        horizonTag        = try? c.decode(String.self,       forKey: .horizonTag)
        lastAskedDate     = try? c.decode(Date.self,         forKey: .lastAskedDate)
    }

    enum CodingKeys: String, CodingKey {
        case id, categoryId, questionText, timeframeYears, isAiGenerated
        case createdAt, relatedAnswerIds, answerOptions, questionType
        case isReview, previousAnswerText, reviewAnswerId
        case module, horizonTag, lastAskedDate
    }
}

// MARK: - Background snapshot loader (no actor isolation)

private struct StorageSnapshot {
    var categories: [VisionCategory] = []
    var answers: [VisionAnswer] = []
    var statements: [VisionStatement] = []
    var questions: [VisionQuestion] = []
    var dailyLogs: [DailyQuestionLog] = []
    var voiceAnchors: VisionVoiceAnchors = .default
    var cachedStories: [Int: String] = [:]
    var isFirstTime: Bool = true
}

// Isolated in a nonisolated enum so -default-isolation MainActor doesn't apply.
private enum SnapshotLoader {
    nonisolated static func load() -> StorageSnapshot {
        let ud = UserDefaults.standard
        let dec = JSONDecoder()
        func decode<T: Decodable>(_ type: T.Type, key: String) -> T? {
            guard let d = ud.data(forKey: key) else { return nil }
            return try? dec.decode(type, from: d)
        }
        var s = StorageSnapshot()
        if let v = decode([VisionCategory].self,    key: "visionCategories")   { s.categories   = v }
        if let v = decode([VisionAnswer].self,       key: "visionAnswers")      { s.answers       = v }
        if let v = decode([VisionStatement].self,    key: "visionStatements")   { s.statements    = v }
        if let v = decode([VisionQuestion].self,     key: "visionQuestions")    { s.questions     = v }
        if let v = decode([DailyQuestionLog].self,   key: "visionDailyLogs")    { s.dailyLogs     = v }
        if let v = decode(VisionVoiceAnchors.self,   key: "visionVoiceAnchors") { s.voiceAnchors  = v }
        if let v = decode([Int: String].self,        key: "visionCachedStories"){ s.cachedStories = v }
        s.isFirstTime = !ud.bool(forKey: "visionBoardFirstTime")
        return s
    }
}

// MARK: - Main Store

@MainActor
class VisionBoardStore: ObservableObject {
    @Published var categories: [VisionCategory] = []
    @Published var answers: [VisionAnswer] = []
    @Published var statements: [VisionStatement] = []
    @Published var questions: [VisionQuestion] = []
    @Published var dailyLogs: [DailyQuestionLog] = []
    @Published var isFirstTime: Bool = true
    @Published var voiceAnchors: VisionVoiceAnchors = .default
    @Published var isLoading: Bool = true   // true until background init completes

    @Published private(set) var cachedStories: [Int: String] = [:]
    private var cacheAnswerCount: [Int: Int] = [:]

    private let ud = UserDefaults.standard
    private enum K {
        static let categories = "visionCategories"
        static let answers    = "visionAnswers"
        static let statements = "visionStatements"
        static let questions  = "visionQuestions"
        static let dailyLogs  = "visionDailyLogs"
        static let firstTime  = "visionBoardFirstTime"
        static let anchors    = "visionVoiceAnchors"
        static let stories    = "visionCachedStories"
    }

    init() {
        // Kick off all heavy work asynchronously so init() returns immediately.
        // Using Task (not detached) so it runs on @MainActor — but each await
        // suspends and lets the run-loop / UI breathe between steps.
        Task { @MainActor [weak self] in
            guard let self else { return }

            // 1. Decode from UserDefaults — off-actor. Capture loader as a
            //    @Sendable closure so Swift 6 concurrency checks are satisfied.
            let loader: @Sendable () -> StorageSnapshot = { SnapshotLoader.load() }
            let snapshot = await Task.detached(priority: .userInitiated) {
                loader()
            }.value

            // 2. Apply snapshot (we're on MainActor here).
            self.categories    = snapshot.categories
            self.answers       = snapshot.answers
            self.statements    = snapshot.statements
            self.questions     = snapshot.questions
            self.dailyLogs     = snapshot.dailyLogs
            self.voiceAnchors  = snapshot.voiceAnchors
            self.cachedStories = snapshot.cachedStories
            self.isFirstTime   = snapshot.isFirstTime

            // 3. Default categories if brand new.
            if self.categories.isEmpty { self.initializeDefaultCategories() }

            // 4. Generate question bank if missing — off-actor.
            let needsGeneration = self.questions.count < max(self.categories.count * 10, 10)
            if needsGeneration {
                let cats = self.categories          // value copy
                let newQuestions = await Task.detached(priority: .userInitiated) {
                    var result: [VisionQuestion] = []
                    for cat in cats {
                        let qs = VisionAIService.shared.getInitialQuestions(for: cat.id, categoryName: cat.name)
                        result.append(contentsOf: qs)
                    }
                    return result
                }.value
                self.questions = newQuestions
                self.sanitizeQuestionBank()
                self.saveToStorage()
            }

            // 5. Inject module questions — off-actor.
            let existingTexts = Set(self.questions.map { $0.questionText.lowercased() })
            let cats = self.categories              // value copy
            let fresh = await Task.detached(priority: .userInitiated) {
                var result: [VisionQuestion] = []
                for cat in cats {
                    let moduleQs = VisionModuleEngine.moduleQuestions(for: cat.id, categoryName: cat.name)
                    result.append(contentsOf: moduleQs.filter {
                        !existingTexts.contains($0.questionText.lowercased())
                    })
                }
                return result
            }.value
            if !fresh.isEmpty {
                self.questions.append(contentsOf: fresh)
                self.sanitizeQuestionBank()
                self.saveToStorage()
            }

            // 6. Final setup.
            self.sanitizeQuestionBank()
            self.ensureDailySet()
            self.isLoading = false
        }
    }

    // MARK: Categories

    func addCategory(name: String, emoji: String) {
        categories.append(VisionCategory(name: name, emoji: emoji, isCustom: true))
        saveToStorage()
    }

    func removeCategory(_ id: UUID) {
        categories.removeAll { $0.id == id }
        answers.removeAll    { $0.categoryId == id }
        questions.removeAll  { $0.categoryId == id }
        statements.removeAll { $0.categoryId == id }
        invalidateAllStories()
        saveToStorage()
    }

    func updateCategory(id: UUID, name: String, emoji: String) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        let old = categories[idx]
        categories[idx] = VisionCategory(id: old.id, name: name, emoji: emoji,
                                          isCustom: old.isCustom, createdAt: old.createdAt)
        saveToStorage()
    }

    /// Mark a category as satisfied ("I'm happy here — stop asking about it").
    /// Questions for this category are excluded from the daily pool until un-marked.
    func markCategorySatisfied(_ id: UUID, satisfied: Bool = true) {
        guard let idx = categories.firstIndex(where: { $0.id == id }) else { return }
        categories[idx].isSatisfied = satisfied
        addEvent(
            action: .milestone,
            categoryId: id,
            note: satisfied
                ? "✅ Category marked complete — no more questions here"
                : "🔄 Category reopened for new questions"
        )
        saveToStorage()
    }

    /// Clarity snapshot for a single category.
    func categoryClarity(for categoryId: UUID) -> CategoryClarity {
        let catAnswers = answers.filter {
            $0.categoryId == categoryId &&
            !$0.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let avg = catAnswers.isEmpty ? 0.0 :
            Double(catAnswers.reduce(0) { $0 + $1.answerText.split(whereSeparator: \.isWhitespace).count }) /
            Double(catAnswers.count)
        return CategoryClarity(categoryId: categoryId, answerCount: catAnswers.count, avgWordCount: avg)
    }

    /// Categories that still need questions: not satisfied, not at soft cap, not yet clear
    /// (or clear but user hasn't hit the cap yet — allows optional depth).
    var categoriesNeedingQuestions: [VisionCategory] {
        categories.filter { cat in
            guard !cat.isSatisfied else { return false }
            let clarity = categoryClarity(for: cat.id)
            return !clarity.atSoftCap
        }
    }

    /// IDs of satisfied or soft-capped categories — excluded from the daily pool.
    var excludedCategoryIds: Set<UUID> {
        Set(categories.compactMap { cat -> UUID? in
            if cat.isSatisfied { return cat.id }
            if categoryClarity(for: cat.id).atSoftCap { return cat.id }
            return nil
        })
    }

    // MARK: - Streaks

    /// Number of consecutive calendar days the user has answered ≥1 question.
    var currentStreak: Int {
        guard !dailyLogs.isEmpty else { return 0 }
        let cal = Calendar.current
        let sortedDates = dailyLogs
            .filter { $0.answeredQuestionIds.count > 0 }
            .map { cal.startOfDay(for: $0.date) }
            .sorted(by: >)
        guard let latest = sortedDates.first else { return 0 }
        let today = cal.startOfDay(for: Date())
        // Latest must be today or yesterday to count as active streak
        guard cal.dateComponents([.day], from: latest, to: today).day ?? 2 <= 1 else { return 0 }
        var streak = 1
        var prev = latest
        for date in sortedDates.dropFirst() {
            let diff = cal.dateComponents([.day], from: date, to: prev).day ?? 2
            if diff == 1 { streak += 1; prev = date } else { break }
        }
        return streak
    }

    /// Best streak ever recorded.
    var bestStreak: Int {
        guard !dailyLogs.isEmpty else { return 0 }
        let cal = Calendar.current
        let activeDates = dailyLogs
            .filter { $0.answeredQuestionIds.count > 0 }
            .map { cal.startOfDay(for: $0.date) }
            .sorted()
        var best = 0, current = 1
        for i in 1..<activeDates.count {
            let diff = cal.dateComponents([.day], from: activeDates[i-1], to: activeDates[i]).day ?? 2
            if diff == 1 { current += 1; best = max(best, current) } else { current = 1 }
        }
        return max(best, current)
    }

    /// Total questions answered across all time.
    var totalAnsweredAllTime: Int { answers.count }

    /// Consecutive days where the user answered in ≥2 unique categories.
    var categoryVarietyStreak: Int {
        guard !dailyLogs.isEmpty else { return 0 }
        let cal = Calendar.current
        let qualifying = dailyLogs.compactMap { log -> Date? in
            let ids = Set(log.answeredQuestionIds)
            guard !ids.isEmpty else { return nil }
            let cats = Set(questions.filter { ids.contains($0.id) }.map(\.categoryId))
            return cats.count >= 2 ? cal.startOfDay(for: log.date) : nil
        }.sorted(by: >)
        guard let latest = qualifying.first else { return 0 }
        let today = cal.startOfDay(for: Date())
        guard cal.dateComponents([.day], from: latest, to: today).day ?? 2 <= 1 else { return 0 }
        var streak = 1; var prev = latest
        for date in qualifying.dropFirst() {
            let diff = cal.dateComponents([.day], from: date, to: prev).day ?? 2
            if diff == 1 { streak += 1; prev = date } else { break }
        }
        return streak
    }

    /// Consecutive days where the user answered at least one question from a specific module.
    func moduleStreak(for module: VisionModule) -> Int {
        guard !dailyLogs.isEmpty else { return 0 }
        let cal = Calendar.current
        let qualifying = dailyLogs.compactMap { log -> Date? in
            let ids = Set(log.answeredQuestionIds)
            guard !ids.isEmpty else { return nil }
            let has = questions.contains { ids.contains($0.id) && $0.module == module }
            return has ? cal.startOfDay(for: log.date) : nil
        }.sorted(by: >)
        guard let latest = qualifying.first else { return 0 }
        let today = cal.startOfDay(for: Date())
        guard cal.dateComponents([.day], from: latest, to: today).day ?? 2 <= 1 else { return 0 }
        var streak = 1; var prev = latest
        for date in qualifying.dropFirst() {
            let diff = cal.dateComponents([.day], from: date, to: prev).day ?? 2
            if diff == 1 { streak += 1; prev = date } else { break }
        }
        return streak
    }

    /// The module with the longest active streak (nil if no streak exists).
    var topModuleStreak: (module: VisionModule, streak: Int)? {
        let pairs = VisionModule.allCases.map { (module: $0, streak: moduleStreak(for: $0)) }
        return pairs.max(by: { $0.streak < $1.streak }).flatMap { $0.streak > 0 ? $0 : nil }
    }

    // MARK: - Answer Drafts

    // MARK: - Timeline / Event Helpers (private)

    private func todayStart() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    /// Finds or creates today's log entry and returns its index.
    private func getOrCreateTodaysLogIndex() -> Int {
        let today = todayStart()
        if let idx = dailyLogs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            return idx
        }
        dailyLogs.append(DailyQuestionLog(date: today))
        return dailyLogs.count - 1
    }

    /// Appends one event to today's log (non-saving — callers save when ready).
    private func addEvent(
        action: DailyEventAction,
        questionId: UUID? = nil,
        categoryId: UUID? = nil,
        module: VisionModule? = nil,
        note: String? = nil,
        confidenceDelta: Double? = nil
    ) {
        let idx = getOrCreateTodaysLogIndex()
        let dayStart = Calendar.current.startOfDay(for: dailyLogs[idx].date)
        dailyLogs[idx].events.append(
            DailyEvent(
                date: dayStart,
                action: action,
                questionId: questionId,
                categoryId: categoryId,
                module: module,
                note: note,
                confidenceDelta: confidenceDelta
            )
        )
    }

    /// Fires milestone events when readiness thresholds are crossed between `before` and `after`,
    /// then always writes/replaces today's nextStep guidance event.
    private func ensureMilestonesAndNextStep(before: VisionNarrativeReadiness, timeframe: Int) {
        let catOrder = categories.map(\.id)
        let after = narrativeReadiness(timeframe: timeframe, categoryOrder: catOrder)

        func cross(_ old: Bool, _ new: Bool, note: String) {
            if !old && new { addEvent(action: .milestone, note: note) }
        }

        cross(before.anchorsSet, after.anchorsSet,
              note: "🎯 Milestone: voice anchors set — your story has a tone")
        cross(
            before.uniqueCategoryCount >= VisionNarrativeReadiness.targetCategories,
            after.uniqueCategoryCount  >= VisionNarrativeReadiness.targetCategories,
            note: "🗂 Milestone: answered across \(VisionNarrativeReadiness.targetCategories) categories"
        )
        cross(
            before.answeredCount >= VisionNarrativeReadiness.targetAnswered,
            after.answeredCount  >= VisionNarrativeReadiness.targetAnswered,
            note: "✅ Milestone: \(VisionNarrativeReadiness.targetAnswered) questions answered"
        )
        cross(
            before.characterCount >= VisionNarrativeReadiness.targetChars,
            after.characterCount  >= VisionNarrativeReadiness.targetChars,
            note: "📝 Milestone: your answers have real depth now"
        )
        cross(before.isReady, after.isReady,
              note: "🌟 Milestone: story unlocked — vision is ready to generate")

        // Replace today's nextStep event so it always reflects current state.
        let idx = getOrCreateTodaysLogIndex()
        dailyLogs[idx].events.removeAll { $0.action == .nextStep }
        addEvent(action: .nextStep, note: after.nextActionLabel)
    }

    private let draftsKey = "visionAnswerDrafts"

    /// Load persisted draft text for a question.
    func loadDraft(for questionId: UUID) -> String {
        let drafts = (ud.dictionary(forKey: draftsKey) as? [String: String]) ?? [:]
        return drafts[questionId.uuidString] ?? ""
    }

    /// Save draft text for a question (called on every keystroke).
    func saveDraft(_ text: String, for questionId: UUID) {
        var drafts = (ud.dictionary(forKey: draftsKey) as? [String: String]) ?? [:]
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drafts.removeValue(forKey: questionId.uuidString)
        } else {
            drafts[questionId.uuidString] = text
        }
        ud.set(drafts, forKey: draftsKey)
    }

    /// Clear draft after successful submission.
    func clearDraft(for questionId: UUID) {
        var drafts = (ud.dictionary(forKey: draftsKey) as? [String: String]) ?? [:]
        drafts.removeValue(forKey: questionId.uuidString)
        ud.set(drafts, forKey: draftsKey)
    }

    // MARK: Answers

    func addAnswer(categoryId: UUID, questionText: String, answerText: String,
                   timeframeYears: Int, imageURLs: [URL] = [], confidence: Double = 0.5) {
        answers.append(VisionAnswer(categoryId: categoryId, questionText: questionText,
                                    answerText: answerText, timeframeYears: timeframeYears,
                                    imageURLs: imageURLs, confidence: confidence))
        invalidateStory(for: timeframeYears)
        saveToStorage()
    }

    func updateAnswer(_ id: UUID, newAnswerText: String, newConfidence: Double? = nil) {
        guard let idx = answers.firstIndex(where: { $0.id == id }) else { return }
        var a = answers[idx]
        a.answerText = newAnswerText
        if let c = newConfidence { a.confidence = c }
        a.lastReviewedAt = Date(); a.hasBeenRevisited = true
        answers[idx] = a
        invalidateStory(for: a.timeframeYears)
        saveToStorage()
    }

    func deleteAnswer(_ id: UUID) {
        guard let idx = answers.firstIndex(where: { $0.id == id }) else { return }
        let timeframe = answers[idx].timeframeYears
        answers.remove(at: idx)
        invalidateStory(for: timeframe)
        saveToStorage()
    }

    // MARK: - Module Question Injection

    /// Adds VisionModuleEngine questions for each category if they haven't been injected yet.
    /// Safe to call on every launch — skips questions whose text already exists in the bank.
    func injectModuleQuestionsIfNeeded() {
        let existingTexts = Set(questions.map { $0.questionText.lowercased() })
        var newQuestions: [VisionQuestion] = []
        for cat in categories {
            let moduleQs = VisionModuleEngine.moduleQuestions(for: cat.id, categoryName: cat.name)
            let fresh = moduleQs.filter { !existingTexts.contains($0.questionText.lowercased()) }
            newQuestions.append(contentsOf: fresh)
        }
        guard !newQuestions.isEmpty else { return }
        questions.append(contentsOf: newQuestions)
        saveToStorage()
    }

    // MARK: - Module Progress (for UI)

    func moduleProgress() -> [VisionModuleEngine.ModuleProgress] {
        VisionModuleEngine.moduleProgress(from: answers, questions: questions)
    }

    func missingModules() -> [VisionModule] {
        VisionModuleEngine.missingModules(from: answers, questions: questions)
    }

    // MARK: Daily Questions

    // MARK: - Active daily set (simple, in-memory, no stale ID issues)

    /// The 3 question IDs currently shown in Daily.
    /// Persisted only for the current session — repicked fresh every launch.
    private(set) var activeDailyIds: [UUID] = []

    func getTodaysLog() -> DailyQuestionLog? {
        dailyLogs.first { Calendar.current.isDate($0.date, inSameDayAs: Date()) }
    }

    /// When the unanswered pool is empty, enqueue review questions (re-asks of
    /// previously answered questions, oldest first) WITHOUT marking old answers
    /// as unanswered. The review questions carry the previous answer so the UI
    /// can compare and update confidence or adapt the vision.
    /// Removes blank / duplicate questions so they can never appear in Daily.
    func sanitizeQuestionBank() {
        guard !questions.isEmpty else { return }
        // Remove blank questionText entries
        questions.removeAll {
            $0.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        // De-duplicate by (categoryId, lowercased questionText), keeping first occurrence
        var seen = Set<String>()
        questions = questions.filter { q in
            let key = "\(q.categoryId.uuidString)|\(q.questionText.lowercased())"
            return seen.insert(key).inserted
        }
    }

    /// Enqueues review questions ONLY when:
    ///   1. The full intended question bank has been built (categories × target).
    ///   2. There are no normal unanswered questions left.
    ///   3. The user has at least one answer to review.
    func ensureNonEmptyQuestions() {
        // Sanitize first so blank/duplicate questions don't pollute the pool.
        sanitizeQuestionBank()

        let answeredTexts = Set(answers.map { $0.questionText })
        let hasNormalUnanswered = questions.contains {
            !$0.isReview && !answeredTexts.contains($0.questionText)
        }

        // If there are still normal unanswered questions, do nothing.
        guard !hasNormalUnanswered, !answers.isEmpty else { return }

        // Only start review cycle once the intended bank is fully built.
        let targetTotal = categories.count * visionTargetQuestionCount
        guard questions.filter({ !$0.isReview }).count >= targetTotal else { return }

        // Don't double-queue review questions already in the bank.
        let reviewTexts = Set(questions.filter { $0.isReview }.map { $0.questionText })

        let oldestAnswers = answers
            .filter { !reviewTexts.contains($0.questionText) }
            .sorted { $0.answeredAt < $1.answeredAt }
            .prefix(12)

        let reviewQuestions: [VisionQuestion] = oldestAnswers.compactMap { ans in
            let qt = ans.questionText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !qt.isEmpty,
                  let template = questions.first(where: {
                      !$0.isReview && $0.questionText == ans.questionText
                  }) else { return nil }
            return VisionQuestion(
                id: UUID(),
                categoryId: ans.categoryId,
                questionText: qt,
                timeframeYears: ans.timeframeYears,
                isAiGenerated: false,
                answerOptions: template.answerOptions,
                questionType: template.questionType,
                isReview: true,
                previousAnswerText: ans.answerText,
                reviewAnswerId: ans.id
            )
        }

        guard !reviewQuestions.isEmpty else { return }
        questions.append(contentsOf: reviewQuestions)
        saveToStorage()
    }

    /// Called when the user answers a review question.
    /// - Same answer → boosts confidence on the original VisionAnswer.
    /// - Different answer → updates the original answer text and resets confidence
    ///   slightly upward (vision adapted), then invalidates the story cache.
    func recordReviewAnswer(reviewQuestion: VisionQuestion, newAnswerText: String) {
        let catOrder = categories.map(\.id)
        let before   = narrativeReadiness(timeframe: reviewQuestion.timeframeYears, categoryOrder: catOrder)

        guard let answerId = reviewQuestion.reviewAnswerId,
              let idx = answers.firstIndex(where: { $0.id == answerId }) else {
            // Fallback: treat as a brand-new answer
            addAnswer(categoryId: reviewQuestion.categoryId,
                      questionText: reviewQuestion.questionText,
                      answerText: newAnswerText,
                      timeframeYears: reviewQuestion.timeframeYears)
            addEvent(
                action: .reviewed,
                questionId: reviewQuestion.id,
                categoryId: reviewQuestion.categoryId,
                module: reviewQuestion.module,
                note: "Revisited — new answer recorded"
            )
            saveToStorage()
            ensureMilestonesAndNextStep(before: before, timeframe: reviewQuestion.timeframeYears)
            saveToStorage()
            return
        }

        var a            = answers[idx]
        let prevConf     = a.confidence
        let previous     = a.answerText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let incoming     = newAnswerText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let isSame       = previous == incoming || similarity(previous, incoming) > 0.75

        let eventNote: String
        if isSame {
            // Same answer → confidence grows (capped at 1.0), answer unchanged
            a.confidence = min(1.0, a.confidence + 0.15)
            eventNote = "Revisited: still feels right — confidence +\(String(format: "%.0f", (a.confidence - prevConf) * 100))%"
        } else {
            // Different answer → vision adapts: update text, bump confidence modestly
            a.answerText = newAnswerText
            a.confidence = min(1.0, max(a.confidence, 0.5) + 0.05)
            invalidateStory(for: a.timeframeYears)
            eventNote = "Revisited: vision updated — answer changed"
        }
        a.lastReviewedAt   = Date()
        a.hasBeenRevisited = true
        answers[idx]       = a

        let delta = a.confidence - prevConf
        addEvent(
            action: .reviewed,
            questionId: reviewQuestion.id,
            categoryId: reviewQuestion.categoryId,
            module: reviewQuestion.module,
            note: eventNote,
            confidenceDelta: delta
        )

        // Remove the review question from the pool — it's been handled
        questions.removeAll { $0.id == reviewQuestion.id }
        saveToStorage()
        ensureMilestonesAndNextStep(before: before, timeframe: reviewQuestion.timeframeYears)
        saveToStorage()
    }

    // MARK: - String similarity helper (Dice coefficient)
    private func similarity(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return a == b ? 1 : 0 }
        func bigrams(_ s: String) -> [String] {
            let chars = Array(s)
            return (0..<max(0, chars.count - 1)).map { String([chars[$0], chars[$0+1]]) }
        }
        let ba = bigrams(a), bb = bigrams(b)
        let intersection = ba.filter { bb.contains($0) }.count
        return Double(2 * intersection) / Double(ba.count + bb.count)
    }

    /// Returns the current active set of 3 daily questions.
    /// Always non-empty as long as the question bank exists.
    func getDailyQuestions() -> [VisionQuestion] {
        ensureDailySet()
        let byId = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0) })
        return activeDailyIds.compactMap { byId[$0] }
    }

    /// Ensures `activeDailyIds` contains 1–3 unanswered questions chosen by the
    /// Progressive Disclosure algorithm:
    ///   1. Skip categories the user marked satisfied or that hit the soft cap.
    ///   2. Serve core (Values/Identity) questions first per category.
    ///   3. Once core is done, run a clarity check — if clear, skip unless gaps exist.
    ///   4. If gaps exist in the narrative, prioritise the question that fills them.
    ///   5. Apply 7-day anti-repetition cooldown.
    ///   6. Never show more than 3 questions per day.
    func ensureDailySet() {
        guard !questions.isEmpty else { return }

        let today          = todayStart()
        let log            = getTodaysLog()
        let answeredIds    = Set(log?.answeredQuestionIds ?? [])

        // Drop answered questions from the active set.
        activeDailyIds = activeDailyIds.filter { !answeredIds.contains($0) }
        guard activeDailyIds.count < 3 else { return }

        let answeredTexts  = Set(answers.map { $0.questionText.lowercased() })
        let activeSet      = Set(activeDailyIds)
        let cal            = Calendar.current
        let cooldownCutoff = cal.date(byAdding: .day, value: -visionQuestionRepeatCooldownDays, to: today) ?? today

        // IDs of satisfied / soft-capped categories — excluded from pool.
        let excludedCats = excludedCategoryIds

        // Core modules that must be answered first in each category.
        let coreModules: Set<VisionModule> = [.values, .visionStatement]

        // Base pool: all eligible non-review questions respecting hard constraints.
        let basePool = questions.filter { q in
            !q.isReview
            && !answeredIds.contains(q.id)
            && !answeredTexts.contains(q.questionText.lowercased())
            && !activeSet.contains(q.id)
            && !q.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !excludedCats.contains(q.categoryId)          // satisfied / soft-capped
            && (q.lastAskedDate == nil || q.lastAskedDate! < cooldownCutoff)
        }

        // ── PASS A: Gap detection ───────────────────────────────────────────
        // For each category that has core answers but is not yet clear, find
        // the module most under-represented in its answers and prioritise that.
        var gapQuestions: [VisionQuestion] = []
        for cat in categories where !excludedCats.contains(cat.id) {
            let clarity = categoryClarity(for: cat.id)
            guard clarity.coreComplete && !clarity.isClear else { continue }

            // Find which module has 0 answers for this category → biggest gap.
            let catAnswerModules = Set(
                answers
                    .filter { $0.categoryId == cat.id }
                    .compactMap { ans in
                        questions.first(where: {
                            !$0.isReview && $0.questionText.lowercased() == ans.questionText.lowercased()
                        })?.module
                    }
            )
            let missingModule = VisionModule.allCases
                .filter { $0 != .discovery && !catAnswerModules.contains($0) }
                .sorted { $0.priority < $1.priority }
                .first

            if let gap = missingModule,
               let gapQ = basePool.first(where: { $0.categoryId == cat.id && $0.module == gap }) {
                gapQuestions.append(gapQ)
            }
        }

        // ── PASS B: Core-first ordering ─────────────────────────────────────
        // Categories where core is NOT yet done get their core questions first.
        let corePool = basePool.filter { q in
            guard let mod = q.module else { return false }
            let clarity = categoryClarity(for: q.categoryId)
            return !clarity.coreComplete && coreModules.contains(mod)
        }

        // ── PASS C: Module-priority picker ──────────────────────────────────
        let needed = 3 - activeDailyIds.count

        // Combine gap questions + core questions + module-priority fallback.
        let priorityPool = (gapQuestions + corePool + basePool)
            .reduce(into: [VisionQuestion]()) { acc, q in
                if !acc.contains(where: { $0.id == q.id }) { acc.append(q) }
            }

        var picked = VisionModuleEngine.priorityPickedQuestions(
            from: priorityPool,
            answers: answers,
            dailyLogs: dailyLogs,
            needed: needed,
            excludedCategoryIds: excludedCats
        )

        // ── PASS D: Category-variety fallback ───────────────────────────────
        if picked.count < needed {
            let pickedIds = Set(picked.map(\.id))
            let remaining = basePool.filter { !pickedIds.contains($0.id) }.shuffled()
            var usedCats  = Set<UUID>(picked.map(\.categoryId))
            for q in remaining {
                guard picked.count < needed else { break }
                if usedCats.contains(q.categoryId) { continue }
                picked.append(q); usedCats.insert(q.categoryId)
            }
            for q in remaining {
                guard picked.count < needed else { break }
                if picked.contains(where: { $0.id == q.id }) { continue }
                picked.append(q)
            }
        }

        // ── PASS E: Last resort — ignore cooldown if pool is empty ───────────
        if picked.count < needed {
            let pickedIds    = Set(picked.map(\.id))
            let fallbackPool = questions.filter { q in
                !q.isReview
                && !answeredIds.contains(q.id)
                && !answeredTexts.contains(q.questionText.lowercased())
                && !activeSet.contains(q.id)
                && !pickedIds.contains(q.id)
                && !excludedCats.contains(q.categoryId)
                && !q.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }.shuffled()
            for q in fallbackPool {
                guard picked.count < needed else { break }
                picked.append(q)
            }
        }

        guard !picked.isEmpty else { return }

        // Stamp lastAskedDate.
        for i in 0..<questions.count where picked.contains(where: { $0.id == questions[i].id }) {
            questions[i].lastAskedDate = today
        }

        activeDailyIds.append(contentsOf: picked.map(\.id))

        // Persist today set and fire pick events.
        let logIdx = getOrCreateTodaysLogIndex()
        dailyLogs[logIdx].todayQuestionIds = activeDailyIds

        for q in picked {
            let clarity = categoryClarity(for: q.categoryId)
            let reason: String
            if q.isReview {
                reason = "Picked for review — revisiting an old answer"
            } else if gapQuestions.contains(where: { $0.id == q.id }), let m = q.module {
                reason = "Picked: filling gap in \(m.label) for this category"
            } else if corePool.contains(where: { $0.id == q.id }), let m = q.module {
                reason = "Picked: core \(m.label) question (\(clarity.answerCount)/\(visionCategoryCoreMin) core done)"
            } else if let m = q.module {
                reason = "Picked: \(m.label) module (priority \(m.priority + 1))"
            } else {
                reason = "Picked: variety / discovery"
            }
            dailyLogs[logIdx].pickReasonsByQuestionId[q.id.uuidString] = reason
            addEvent(action: .picked, questionId: q.id, categoryId: q.categoryId, module: q.module, note: reason)
        }

        // Auto-fire clarity milestone events.
        for cat in categories where !excludedCats.contains(cat.id) {
            let clarity = categoryClarity(for: cat.id)
            if clarity.isClear {
                let alreadyFired = (getTodaysLog()?.events ?? []).contains {
                    $0.action == .milestone && $0.categoryId == cat.id &&
                    ($0.note?.contains("clarity") == true)
                }
                if !alreadyFired {
                    addEvent(
                        action: .milestone,
                        categoryId: cat.id,
                        note: "💡 \(cat.emoji) \(cat.name): clarity reached — enough to write your story"
                    )
                }
            }
        }

        saveToStorage()
    }

    func getTodaysQuestions() -> [VisionQuestion] { getDailyQuestions() }

    func setTodaysQuestions(_ batch: [VisionQuestion]) {
        activeDailyIds = batch.map { $0.id }
    }

    /// Why a question was chosen today — shown below the question card.
    func pickReason(for questionId: UUID) -> String? {
        getTodaysLog()?.pickReasonsByQuestionId[questionId.uuidString]
    }

    /// All events logged so far today, newest first.
    var todaysEvents: [DailyEvent] {
        (getTodaysLog()?.events ?? []).sorted { $0.timestamp > $1.timestamp }
    }

    /// Events grouped by calendar day, newest day first (for history / timeline UI).
    var eventsByDay: [(date: Date, events: [DailyEvent])] {
        let cal = Calendar.current
        var groups: [Date: [DailyEvent]] = [:]
        for log in dailyLogs {
            let day = cal.startOfDay(for: log.date)
            groups[day, default: []].append(contentsOf: log.events)
        }
        return groups.map { (date: $0.key, events: $0.value.sorted { $0.timestamp > $1.timestamp }) }
                     .sorted { $0.date > $1.date }
    }

    func markQuestionAnswered(_ questionId: UUID) {
        let catOrder = categories.map(\.id)
        let before   = narrativeReadiness(timeframe: 5, categoryOrder: catOrder)

        let today = todayStart()
        if let idx = dailyLogs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            dailyLogs[idx].answeredQuestionIds.append(questionId)
            dailyLogs[idx].answeredCount += 1
        } else {
            var log = DailyQuestionLog(date: today)
            log.answeredQuestionIds.append(questionId)
            log.answeredCount = 1
            dailyLogs.append(log)
        }

        // Fire answered event with pick reason (why this question was chosen).
        let q = questions.first(where: { $0.id == questionId })
        let logIdx = getOrCreateTodaysLogIndex()
        let pickReason = dailyLogs[logIdx].pickReasonsByQuestionId[questionId.uuidString]
        addEvent(
            action: .answered,
            questionId: questionId,
            categoryId: q?.categoryId,
            module: q?.module,
            note: pickReason.map { "Answered — \($0)" } ?? "Answered"
        )

        // Refresh active set so answered question is replaced immediately.
        ensureDailySet()
        saveToStorage()

        // Check milestones after saving.
        ensureMilestonesAndNextStep(before: before, timeframe: 5)
        saveToStorage()
    }

    func markQuestionSkipped(_ questionId: UUID) {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = dailyLogs.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            dailyLogs[idx].skippedQuestionIds.append(questionId)
        } else {
            var log = DailyQuestionLog(date: today)
            log.skippedQuestionIds.append(questionId)
            dailyLogs.append(log)
        }
        saveToStorage()
    }

    // MARK: Voice Anchors

    func updateVoiceAnchors(tone: VisionVoiceAnchors.Tone? = nil, audience: String? = nil, valuesWhy: String? = nil) {
        let catOrder = categories.map(\.id)
        let before   = narrativeReadiness(timeframe: 5, categoryOrder: catOrder)

        var a = voiceAnchors
        if let t  = tone      { a.tone = t }
        if let au = audience  { a.audience = au }
        if let v  = valuesWhy { a.valuesWhy = v }
        voiceAnchors = a
        invalidateAllStories()   // voice change invalidates every story
        saveToStorage()

        ensureMilestonesAndNextStep(before: before, timeframe: 5)
        saveToStorage()
    }

    // MARK: Progress Helpers

    func overallProgress(timeframe: Int, categoryOrder: [UUID]) -> Double {
        let ids   = Set(categoryOrder)
        let count = answers.filter { ids.contains($0.categoryId) && $0.timeframeYears == timeframe }.count
        let total = max(1, categoryOrder.count * visionCategorySoftCap)
        return min(Double(count) / Double(total), 1)
    }

    func overallAnsweredCount(timeframe: Int, categoryOrder: [UUID]) -> Int {
        let ids = Set(categoryOrder)
        return answers.filter { ids.contains($0.categoryId) && $0.timeframeYears == timeframe }.count
    }

    // MARK: Per-Category Narrative (for grid cards)

    /// Minimum answers per category before a mini-story is shown.
    static let categoryStoryMinAnswers = 3

    func categoryNarrativeState(category: VisionCategory, timeframe: Int) -> NarrativeState {
        let relevant = answers.filter {
            $0.categoryId == category.id &&
            $0.timeframeYears == timeframe &&
            !$0.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let readiness = VisionNarrativeReadiness(
            answeredCount:       relevant.count,
            uniqueCategoryCount: relevant.isEmpty ? 0 : 1,
            richAnswerCount:     0,
            characterCount:      relevant.reduce(0) { $0 + $1.answerText.count },
            anchorsSet:          voiceAnchors.isSet
        )
        guard relevant.count >= VisionBoardStore.categoryStoryMinAnswers else {
            return .seedling(readiness: readiness)
        }
        // Use the shared story composer scoped to this one category.
        let text = storyComposer(
            categoryOrder: [category.id],
            allAnswers: relevant,
            anchors: voiceAnchors
        )
        return .story(text: text)
    }

    // MARK: Narrative Readiness

    func narrativeReadiness(timeframe: Int, categoryOrder: [UUID]) -> VisionNarrativeReadiness {
        let ids      = Set(categoryOrder)
        let relevant = answers.filter {
            ids.contains($0.categoryId) && $0.timeframeYears == timeframe
            && !$0.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let charCount = relevant.reduce(0) { $0 + $1.answerText.trimmingCharacters(in: .whitespacesAndNewlines).count }

        return VisionNarrativeReadiness(
            answeredCount:       relevant.count,
            uniqueCategoryCount: Set(relevant.map(\.categoryId)).count,
            richAnswerCount:     0,   // unused — kept for struct compat
            characterCount:      charCount,
            anchorsSet:          voiceAnchors.isSet
        )
    }

    // MARK: Narrative State (with caching)

    enum NarrativeState {
        case seedling(readiness: VisionNarrativeReadiness)
        case story(text: String)
    }

    func narrativeState(timeframe: Int, categoryOrder: [UUID]) -> NarrativeState {
        let readiness = narrativeReadiness(timeframe: timeframe, categoryOrder: categoryOrder)
        guard readiness.isReady else { return .seedling(readiness: readiness) }

        // Cache hit — only rebuild when answer count changes
        let currentCount = readiness.answeredCount
        if let cached = cachedStories[timeframe], cacheAnswerCount[timeframe] == currentCount {
            return .story(text: cached)
        }

        let ids = Set(categoryOrder)
        let relevant = answers.filter {
            ids.contains($0.categoryId) && $0.timeframeYears == timeframe
            && !$0.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let text = storyComposer(categoryOrder: categoryOrder, allAnswers: relevant, anchors: voiceAnchors)
        cachedStories[timeframe]    = text
        cacheAnswerCount[timeframe] = currentCount
        saveCachedStories()
        return .story(text: text)
    }

    // MARK: ── Story Composer v3 ─────────────────────────────────────────
    // Includes: Now→Next→Why arc, sensory vividness, SMART milestones, WOOP obstacle plan

    private func storyComposer(categoryOrder: [UUID], allAnswers: [VisionAnswer], anchors: VisionVoiceAnchors) -> String {

        let ordered = categoryOrder.compactMap { id in categories.first(where: { $0.id == id }) }
        var snippets: [(catName: String, text: String, role: SnippetRole)] = []

        // ── PASS A: pick best snippet per category ───────────────────────
        for cat in ordered {
            let catAnswers = allAnswers
                .filter { $0.categoryId == cat.id }
                .sorted {
                    let wa = $0.answerText.split(whereSeparator: \.isWhitespace).count
                    let wb = $1.answerText.split(whereSeparator: \.isWhitespace).count
                    return wa != wb ? wa > wb : $0.confidence > $1.confidence
                }
            guard let best = catAnswers.first else { continue }
            let expanded = expandIfNeeded(answer: best.answerText, question: best.questionText)
            var combined = expanded
            if let second = catAnswers.dropFirst().first {
                let s2 = expandIfNeeded(answer: second.answerText, question: second.questionText)
                if expanded.split(whereSeparator: \.isWhitespace).count +
                   s2.split(whereSeparator: \.isWhitespace).count <= 30, !s2.isEmpty {
                    combined = expanded + " " + s2
                }
            }
            let role = inferRole(catName: cat.name, questionText: best.questionText)
            snippets.append((catName: cat.name, text: combined, role: role))
            if snippets.count == 6 { break }
        }
        guard !snippets.isEmpty else { return "Keep answering questions — your story is taking shape." }

        // ── PASS B: normalize ────────────────────────────────────────────
        let normalized = snippets.map { s -> (catName: String, text: String, role: SnippetRole) in
            var t = normalize(s.text)
            t = stripOpener(t)
            t = cap(t, maxChars: 180)
            t = ensurePeriod(t)
            return (catName: s.catName, text: t, role: s.role)
        }

        // ── PASS C: Now → Next → Why arc ────────────────────────────────
        let arcOrder: [SnippetRole] = [.now, .next, .why]
        let sorted = normalized.sorted {
            (arcOrder.firstIndex(of: $0.role) ?? 1) < (arcOrder.firstIndex(of: $1.role) ?? 1)
        }
        let connectors = ["", "Right now, ", "At the same time, ", "Beyond that, ", "Most importantly, ", "And above all, "]
        var sentences: [String] = []
        for (idx, s) in sorted.enumerated() {
            let prefix = idx < connectors.count ? connectors[idx] : ""
            var line = s.text
            if !prefix.isEmpty, let first = line.first { line = first.lowercased() + line.dropFirst() }
            sentences.append(prefix + line)
        }
        var paragraphs: [String] = [sentences.joined(separator: " ")]

        // ── PASS D: SMART milestone snippet ─────────────────────────────
        let milestoneAnswers = allAnswers.filter { a in
            let qText = a.questionText.lowercased()
            return qText.contains("12 months") || qText.contains("1-year") || qText.contains("milestone") || qText.contains("quarterly")
        }
        if let milestone = milestoneAnswers.sorted(by: { $0.answeredAt > $1.answeredAt }).first {
            let mText = normalize(expandIfNeeded(answer: milestone.answerText, question: milestone.questionText))
            if !mText.isEmpty {
                paragraphs.append("Next milestone: \(ensurePeriod(cap(stripOpener(mText), maxChars: 140)))")
            }
        }

        // ── PASS E: WOOP obstacle/plan snippet ──────────────────────────
        let woopAnswers = allAnswers.filter { a in
            let qText = a.questionText.lowercased()
            return qText.contains("obstacle") || qText.contains("if-then") || qText.contains("if ") && qText.contains("then ")
        }
        if let woop = woopAnswers.sorted(by: { $0.answeredAt > $1.answeredAt }).first {
            let wText = normalize(expandIfNeeded(answer: woop.answerText, question: woop.questionText))
            if !wText.isEmpty {
                paragraphs.append("If I drift: \(ensurePeriod(cap(stripOpener(wText), maxChars: 140)))")
            }
        }

        // ── PASS F: Values "why" coda ────────────────────────────────────
        let why = anchors.valuesWhy.trimmingCharacters(in: .whitespacesAndNewlines)
        if !why.isEmpty {
            paragraphs.append("All of it grounded in \(why).")
        }

        return paragraphs.joined(separator: "\n\n")
    }

    // MARK: Snippet Helpers

    private enum SnippetRole { case now, next, why }

    private func inferRole(catName: String, questionText: String) -> SnippetRole {
        let q = questionText.lowercased()
        if q.contains("why") || q.contains("value") || q.contains("matters") || q.contains("meaning") { return .why }
        if q.contains("step") || q.contains("plan") || q.contains("action") || q.contains("next") { return .next }
        return .now
    }

    /// Expands a short MCQ answer into a natural prose sentence using the question as context.
    /// If the answer is already sentence-length (≥8 words) it's returned unchanged.
    private func expandMCQ(answer: String, question: String) -> String {
        let wordCount = answer.split(whereSeparator: \.isWhitespace).count
        guard wordCount < 8 else { return answer }

        let a = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "?", with: "")

        // Map common question patterns to natural sentence templates.
        if q.contains("type of car") || q.contains("car appeals") {
            return "I've always been drawn to \(a.lowercased()) cars."
        }
        if q.contains("purpose of") || q.contains("primary purpose") {
            return "For me, the car is primarily for \(a.lowercased())."
        }
        if q.contains("feel when you drive") || q.contains("want to feel") {
            return "When I'm behind the wheel I want to feel \(a.lowercased())."
        }
        if q.contains("budget") {
            return "My budget for this sits around \(a)."
        }
        if q.contains("type of home") || q.contains("home setting") {
            return "I picture myself living in a \(a.lowercased()) setting."
        }
        if q.contains("architectural style") || q.contains("style") && q.contains("home") {
            return "The home I see for myself is \(a.lowercased()) in style."
        }
        if q.contains("bedrooms") {
            return "I'm looking for a place with \(a) bedrooms."
        }
        if q.contains("career") || q.contains("role") || q.contains("position") {
            return "Career-wise, I see myself in \(a.lowercased())."
        }
        if q.contains("fitness") || q.contains("sport") || q.contains("active") || q.contains("exercise") {
            return "I stay active through \(a.lowercased())."
        }
        if q.contains("relationship") && (q.contains("status") || q.contains("partner")) {
            return "Personally, I'm building a life that includes \(a.lowercased())."
        }
        if q.contains("travel") && q.contains("often") || q.contains("how often") && q.contains("travel") {
            return "I travel \(a.lowercased()), and I want to keep it that way."
        }
        if q.contains("saving") || q.contains("invest") || q.contains("financial goal") {
            return "Financially, I'm focused on \(a.lowercased())."
        }
        if q.contains("learning") || q.contains("studying") || q.contains("skill") {
            return "I'm actively working on \(a.lowercased())."
        }

        // Generic fallback: turn "Question? → Answer" into "I am focused on <answer>."
        // First try to detect the subject of the question and flip it.
        if q.hasPrefix("what") || q.hasPrefix("which") {
            return "When it comes to \(q.replacingOccurrences(of: "what ", with: "").replacingOccurrences(of: "which ", with: "")), my answer is \(a.lowercased())."
        }
        if q.hasPrefix("do you") || q.hasPrefix("would you") {
            let subject = q.replacingOccurrences(of: "do you ", with: "").replacingOccurrences(of: "would you ", with: "")
            return "Yes — \(subject): \(a.lowercased())."
        }
        if q.hasPrefix("how important") {
            return "\(a) to me."
        }

        // Last resort: simple conjunction
        return "\(a)."
    }

    /// Public alias used in Pass A so the naming is clear at the call site.
    private func expandIfNeeded(answer: String, question: String) -> String {
        expandMCQ(answer: answer, question: question)
    }

    private func normalize(_ s: String) -> String {
        s.replacingOccurrences(of: "\n", with: " ")
         .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func stripOpener(_ s: String) -> String {
        var t = s
        let openers = [
            "i want to ", "i want ", "my goal is to ", "my goal is ",
            "i will ", "i'm going to ", "i am going to ",
            "i hope to ", "i plan to ", "i'd like to ", "i would like to ",
            "i wish to ", "i am aiming to ", "i aim to "
        ]
        let lower = t.lowercased()
        for o in openers where lower.hasPrefix(o) {
            let rest = String(t.dropFirst(o.count)).trimmingCharacters(in: .whitespaces)
            if let first = rest.first { t = first.uppercased() + rest.dropFirst() }
            break
        }
        return t
    }

    private func cap(_ s: String, maxChars: Int) -> String {
        guard s.count > maxChars else { return s }
        let prefix = String(s.prefix(maxChars))
        if let cut = prefix.lastIndex(of: " ") { return String(prefix[..<cut]) + "…" }
        return prefix + "…"
    }

    private func ensurePeriod(_ s: String) -> String {
        guard let last = s.last else { return s }
        return ".!?…".contains(last) ? s : s + "."
    }

    // MARK: Cache management

    private func invalidateStory(for timeframe: Int) {
        cachedStories.removeValue(forKey: timeframe)
        cacheAnswerCount.removeValue(forKey: timeframe)
    }

    private func invalidateAllStories() {
        cachedStories = [:]
        cacheAnswerCount = [:]
    }

    private func saveCachedStories() {
        if let encoded = try? JSONEncoder().encode(cachedStories) {
            ud.set(encoded, forKey: K.stories)
        }
    }

    // MARK: Persistence

    func forceRegenerateInitialQuestions() {
        answers = []; questions = []
        generateInitialQuestions()
        saveToStorage()
    }

    private func initializeDefaultCategories() {
        categories = [
            VisionCategory(name: "Cars",          emoji: "🚗"),
            VisionCategory(name: "Houses",        emoji: "🏠"),
            VisionCategory(name: "Career",        emoji: "💼"),
            VisionCategory(name: "Health",        emoji: "💪"),
            VisionCategory(name: "Relationships", emoji: "❤️"),
            VisionCategory(name: "Finances",      emoji: "💰"),
            VisionCategory(name: "Travel",        emoji: "✈️"),
            VisionCategory(name: "Learning",      emoji: "📚"),
        ]
        isFirstTime = false
        saveToStorage()
    }

    private func generateInitialQuestions() {
        var newQuestions: [VisionQuestion] = []
        for cat in categories {
            newQuestions.append(contentsOf: VisionAIService.shared.getInitialQuestions(for: cat.id, categoryName: cat.name))
        }
        questions.append(contentsOf: newQuestions)
        saveToStorage()   // single save after all questions are built
    }

    private func saveToStorage() {
        let enc = JSONEncoder()
        func save<T: Encodable>(_ value: T, key: String) {
            if let d = try? enc.encode(value) { ud.set(d, forKey: key) }
        }
        save(categories,   key: K.categories)
        save(answers,      key: K.answers)
        save(statements,   key: K.statements)
        // Never overwrite a non-empty stored question bank with an empty array.
        // The background generation task will save once it completes.
        if !questions.isEmpty {
            save(questions, key: K.questions)
        }
        save(dailyLogs,    key: K.dailyLogs)
        save(voiceAnchors, key: K.anchors)
        ud.set(!isFirstTime, forKey: K.firstTime)
        saveCachedStories()
    }

    private func loadFromStorage() {
        let dec = JSONDecoder()
        func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
            guard let d = ud.data(forKey: key) else { return nil }
            return try? dec.decode(type, from: d)
        }
        if let v = load([VisionCategory].self,    key: K.categories)  { categories  = v }
        if let v = load([VisionAnswer].self,       key: K.answers)     { answers     = v }
        if let v = load([VisionStatement].self,    key: K.statements)  { statements  = v }
        if let v = load([VisionQuestion].self,     key: K.questions)   { questions   = v }
        if let v = load([DailyQuestionLog].self,   key: K.dailyLogs)   { dailyLogs   = v }
        if let v = load(VisionVoiceAnchors.self,   key: K.anchors)     { voiceAnchors = v }
        if let v = load([Int: String].self,        key: K.stories)     { cachedStories = v }
        isFirstTime = !ud.bool(forKey: K.firstTime)
    }
}
