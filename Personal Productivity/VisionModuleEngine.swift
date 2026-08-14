import Foundation

// MARK: - Vision Module Engine
// Research-backed adaptive daily question engine.
// Implements: values-first, BHAG, SMART, WOOP, sensory visualization,
// 7-day anti-repetition, skip-resurfacing in 3–5 days.

struct VisionModuleEngine {

    // MARK: - Cross-Category Module Question Bank

    /// Questions that belong to research modules (Values, IdealDay, Sensory, etc.)
    /// and apply across ALL categories. These are layered on top of the per-category
    /// question bank in VisionAIService.
    nonisolated static func moduleQuestions(for categoryId: UUID, categoryName: String) -> [VisionQuestion] {
        let cat = categoryName
        var questions: [VisionQuestion] = []

        // ── MODULE 1: VALUES ─────────────────────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "What must be true about your \(cat.lowercased()) for your life to feel genuinely successful — not just impressive?",
              type: .northStar, module: .values, timeframe: 5,
              options: [
                "I feel proud of how I got there, not just what I have",
                "The people I love are part of the journey",
                "It aligns with what I value most — integrity, freedom, impact",
                "It's sustainable — I could live this way for decades",
              ]),
            q(cat: categoryId, text: "What is one thing you absolutely refuse to compromise on in your \(cat.lowercased()) — no matter the cost?",
              type: .constraint, module: .values, timeframe: 5,
              options: [
                "My health and energy — everything else depends on that",
                "My relationships — success means nothing without the right people",
                "My integrity — I won't get there by cutting corners",
                "My time freedom — I won't trade all of it for money",
              ]),
            q(cat: categoryId, text: "If you could only describe your \(cat.lowercased()) vision in three words, what would they be?",
              type: .identity, module: .values, timeframe: 5,
              options: [
                "Free. Proud. Present.",
                "Earned. Real. Lasting.",
                "Bold. Grounded. Mine.",
                "Clear. Purposeful. Strong.",
              ]),
        ]

        // ── MODULE 2: IDEAL DAY ──────────────────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "Walk me through your ideal Tuesday in the world where your \(cat.lowercased()) vision is fully real. What happens from the moment you wake up?",
              type: .vivid, module: .idealDay, timeframe: 5,
              options: [
                "I wake up without an alarm, have a slow morning, then do work I actually chose",
                "I wake early, train, then spend the morning on the most important things",
                "The morning belongs to me — creative work, learning, then people in the afternoon",
                "I wake up knowing exactly what matters today and I do it — nothing wasted",
              ]),
            q(cat: categoryId, text: "In your ideal \(cat.lowercased()) life, what does your environment look like — the space you work, rest, and live in?",
              type: .environment, module: .idealDay, timeframe: 5,
              options: [
                "Calm, light-filled, designed for focus — every detail intentional",
                "A home that feels like a reward — beautiful, functional, completely mine",
                "Close to the people and places I love — geography chosen, not settled",
                "Spacious enough to breathe — no clutter, no obligations I didn't choose",
              ]),
            q(cat: categoryId, text: "In your \(cat.lowercased()) vision, what does an ordinary evening look like — after the work is done?",
              type: .vivid, module: .idealDay, timeframe: 5,
              options: [
                "I'm present with the people I love — no phone, no half-attention",
                "I'm doing something I genuinely enjoy — reading, creating, moving",
                "I'm reflecting on a day that actually mattered — not just a busy one",
                "I'm at peace — no anxiety about tomorrow, no regret about today",
              ]),
        ]

        // ── MODULE 3: SENSORY VISUALIZATION ──────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "Close your eyes for a moment: in the world where your \(cat.lowercased()) vision is fully real, what do you see around you right now?",
              type: .vivid, module: .sensory, timeframe: 5,
              options: [
                "The exact space I always wanted — every detail reflects who I've become",
                "The faces of people I love, doing something ordinary together",
                "Evidence of the work — a result, a number, a view that tells me I made it",
                "Something I built — physical proof that it happened",
              ]),
            q(cat: categoryId, text: "In your \(cat.lowercased()) vision, what does it feel like in your body on a great day — your energy, your posture, how you carry yourself?",
              type: .vivid, module: .sensory, timeframe: 5,
              options: [
                "Light and capable — like I have more energy than I know what to do with",
                "Calm and grounded — no background hum of anxiety or regret",
                "Strong — physically and mentally ready for whatever the day asks",
                "Fully present — in my body, not in my head",
              ]),
            q(cat: categoryId, text: "When you imagine your \(cat.lowercased()) vision becoming real, what emotion hits you first — and what triggered it?",
              type: .vivid, module: .sensory, timeframe: 5,
              options: [
                "Pride — quiet, not performed — like I finally kept the promise I made myself",
                "Relief — the version of this that used to keep me up at night is now just life",
                "Gratitude — I can't believe this is real and it is",
                "Excitement — not just for what I have, but for what's next from here",
              ]),
        ]

        // ── MODULE 4: VISION STATEMENT ────────────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "Write your \(cat.lowercased()) vision in 1–2 sentences, present tense, as if it's already true. Start with 'I am' or 'I have'.",
              type: .structured, module: .visionStatement, timeframe: 5,
              options: [
                "I am [who I've become], living [what my day looks like], because [why this matters].",
                "I have [the specific outcome] and it feels like [the emotion] — earned through [how].",
                "Every day I [the behaviour], and as a result, I [the outcome that follows].",
                "I am the version of myself I always knew was possible in [this area].",
              ]),
            q(cat: categoryId, text: "If a trusted friend read your \(cat.lowercased()) vision statement, would they say it sounds like you — or like a generic aspiration? What makes it specifically yours?",
              type: .identity, module: .visionStatement, timeframe: 5,
              options: [
                "It names something specific to my life — not just a category of success",
                "It includes how I want to feel, not just what I want to have",
                "It reflects a tradeoff I've consciously made — something I chose over something else",
                "It's written the way I actually talk, not the way I think I should sound",
              ]),
        ]

        // ── MODULE 5: BHAG ────────────────────────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "In 10 years, if everything goes better than you're currently daring to believe, what does your \(cat.lowercased()) look like?",
              type: .northStar, module: .bhag, timeframe: 10,
              options: [
                "I have built something that outlasts me — a business, a body of work, a legacy",
                "I have reached a level of mastery or success in this area that most people consider unreachable",
                "I am fully free in this area — no constraints, no compromises, just choice",
                "I am a reference point for others — people look to me in this area",
              ]),
            q(cat: categoryId, text: "What is the boldest version of your \(cat.lowercased()) goal — the one you've never said out loud because it feels too big?",
              type: .northStar, module: .bhag, timeframe: 10,
              options: [
                "Complete financial independence — no alarm clock, no obligation I didn't choose",
                "A level of recognition or mastery in my field that I currently consider elite",
                "To have genuinely changed something for the people around me — family, community, industry",
                "To have built something I'm deeply proud of — not proud because others are impressed, but because I know what it took",
              ]),
        ]

        // ── MODULE 6: SMART MILESTONES ────────────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "What specific, measurable outcome in \(cat.lowercased()) do you want to achieve in the next 12 months — and how will you know you've hit it?",
              type: .milestone, module: .smart, timeframe: 1, horizonTag: "1y",
              options: [
                "A specific number I can track — income, net worth, fitness metric, or a clear result",
                "A capability or skill I've demonstrably built — I can prove it, not just claim it",
                "A decision I've made and acted on — a purchase, a commitment, a launch",
                "A habit so embedded I don't think about it — it's just who I am now",
              ]),
            q(cat: categoryId, text: "What needs to be true in your \(cat.lowercased()) by the end of this quarter for you to be on track for your 1-year goal?",
              type: .milestone, module: .smart, timeframe: 1, horizonTag: "quarter",
              options: [
                "I've taken the first real step — not planned it, done it",
                "I've built the foundation: the habit, the system, the first result",
                "I've removed the biggest blocker — I know what it is and I've addressed it",
                "I have a clear, committed plan with specific next actions for each week",
              ]),
            q(cat: categoryId, text: "In 3–5 years, where do you need to be in \(cat.lowercased()) for your 10-year vision to still be on track?",
              type: .milestone, module: .smart, timeframe: 5, horizonTag: "3-5y",
              options: [
                "The foundation is solid: the skills, the assets, the relationships are in place",
                "I've reached a level where momentum carries me — I'm no longer pushing uphill",
                "I've hit the first major milestone that proves this isn't just a dream",
                "I look back and see consistent action — not a sprint, a sustained climb",
              ]),
            q(cat: categoryId, text: "What is one weekly action — small enough to do even in a hard week — that would compound into your \(cat.lowercased()) goal over 12 months?",
              type: .habits, module: .smart, timeframe: 1, horizonTag: "week",
              options: [
                "30 minutes on the most important thing, before anything else",
                "One intentional review: what did I do this week and what did it build?",
                "One conversation, one connection, one relationship invested in",
                "One concrete action toward the goal — however small — that is non-negotiable",
              ]),
        ]

        // ── MODULE 7: WOOP ────────────────────────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "What is your most important \(cat.lowercased()) goal right now — the one that matters most?",
              type: .northStar, module: .woop, timeframe: 5,
              options: [
                "The goal I've been circling around for years but not fully committed to",
                "The one that would change the most about my life if I actually achieved it",
                "The goal that scares me slightly — which means it's the right one",
                "The one that, if I'm honest, I already know what I need to do",
              ]),
            q(cat: categoryId, text: "If you achieved your main \(cat.lowercased()) goal, what would your life look and feel like? Be specific — paint the picture.",
              type: .vivid, module: .woop, timeframe: 5,
              options: [
                "My daily life looks fundamentally different — not just the outcome, the whole texture of it",
                "I feel the weight of this goal lifting — replaced by the quiet pride of having done it",
                "The people around me are impacted — their lives are better because I followed through",
                "I have options I don't have now — doors that were closed are open",
              ]),
            q(cat: categoryId, text: "What is the single biggest internal obstacle standing between you and your \(cat.lowercased()) goal — the one that lives inside you, not outside?",
              type: .premortem, module: .woop, timeframe: 5,
              options: [
                "Fear of starting — I wait for perfect conditions that never arrive",
                "Inconsistency — I start strong and fade; I haven't figured out how to sustain",
                "Distraction — I know what matters but I keep filling my time with what's easier",
                "Self-doubt — a quiet voice that says this isn't really for people like me",
              ]),
            q(cat: categoryId, text: "When that obstacle appears — and it will — what is your if-then plan? Complete: 'If [obstacle], then I will [specific action].'",
              type: .structured, module: .woop, timeframe: 5,
              options: [
                "If I feel resistance, then I will do the smallest possible version — 5 minutes counts",
                "If I miss a day, then I will not miss two — one miss is an accident, two is a pattern",
                "If I feel like quitting, then I will review why I started — and do one small thing",
                "If I'm overwhelmed, then I will pick the single next action and do only that",
              ]),
        ]

        // ── MODULE 8: HABITS & SYSTEMS ────────────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "What weekly routine, if you followed it consistently for 6 months, would make your \(cat.lowercased()) goal feel inevitable rather than hoped for?",
              type: .habits, module: .habits, timeframe: 1,
              options: [
                "A non-negotiable morning block for the most important work — before distractions",
                "A weekly review: what moved forward, what didn't, and what I'll do differently",
                "A regular commitment to the relationship or community that makes this goal possible",
                "An automated system so the important thing happens without relying on willpower",
              ]),
            q(cat: categoryId, text: "What needs to change in your environment to make progress in \(cat.lowercased()) easier — so the right choice becomes the default, not an effort?",
              type: .environment, module: .habits, timeframe: 1,
              options: [
                "Remove the thing that competes for my attention during the time that should go to this",
                "Add a visible cue or trigger that reminds me of the goal when I'm about to drift",
                "Restructure my calendar so this gets time before it gets stolen by other things",
                "Put myself in a different environment — different people, different inputs, different standard",
              ]),
        ]

        // ── MODULE 9: ACCOUNTABILITY ──────────────────────────────────────────────
        questions += [
            q(cat: categoryId, text: "Who in your life will you tell about this \(cat.lowercased()) goal — and what specifically will you ask them to hold you to?",
              type: .support, module: .accountability, timeframe: 1,
              options: [
                "Someone who has done what I want to do — I'll ask them to be honest when I'm making excuses",
                "A peer at a similar stage — we'll check in monthly and neither of us can hide from it",
                "My partner or someone close — I'll ask them to notice when I'm drifting and say something",
                "A coach or mentor — I'll invest in accountability because I know I need it",
              ]),
            q(cat: categoryId, text: "How often will you review your \(cat.lowercased()) progress — and what exactly will you look at when you do?",
              type: .accountability, module: .accountability, timeframe: 1,
              options: [
                "Monthly: did I do the things I said I would, and did they move the needle?",
                "Quarterly: am I still on track for the 1-year goal, and what needs to change?",
                "Weekly: one honest question — did today move me closer or further from where I want to be?",
                "Whenever I feel off track — I won't wait for a scheduled review to course-correct",
              ]),
        ]

        return questions
    }

    // MARK: - Adaptive Priority Selection
    // Deterministic algorithm — fills the 3-question daily set with the highest-priority
    // unanswered module questions before falling back to the existing discovery bank.

    static func priorityPickedQuestions(
        from pool: [VisionQuestion],
        answers: [VisionAnswer],
        dailyLogs: [DailyQuestionLog],
        needed: Int,
        excludedCategoryIds: Set<UUID> = []
    ) -> [VisionQuestion] {
        guard needed > 0, !pool.isEmpty else { return [] }

        let answeredTexts = Set(answers.map { $0.questionText.lowercased() })
        let sevenDaysAgo  = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let threeDaysAgo  = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()

        // Build set of question IDs asked in last 7 days across all logs
        let recentlyAsked: Set<UUID> = Set(
            dailyLogs
                .filter { $0.date >= sevenDaysAgo }
                .flatMap { $0.todayQuestionIds + $0.answeredQuestionIds + $0.skippedQuestionIds }
        )

        // Build set of skipped question IDs in the last 3 days (resurface after that)
        let recentlySkipped: Set<UUID> = Set(
            dailyLogs
                .filter { $0.date >= threeDaysAgo }
                .flatMap { $0.skippedQuestionIds }
        )

        // Eligible: unanswered, not recently asked, not recently skipped, not excluded
        let eligible = pool.filter { q in
            !q.isReview
            && !answeredTexts.contains(q.questionText.lowercased())
            && !recentlyAsked.contains(q.id)
            && !recentlySkipped.contains(q.id)
            && !excludedCategoryIds.contains(q.categoryId)
            && !q.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        if eligible.isEmpty { return [] }

        // Which modules have been covered in answers?
        let coveredModules: Set<VisionModule> = Set(
            pool.filter { q in answeredTexts.contains(q.questionText.lowercased()) }
                .compactMap { $0.module }
        )

        // How many answers per category (for core-first ordering).
        let answerCountByCategory: [UUID: Int] = answers.reduce(into: [:]) { dict, ans in
            dict[ans.categoryId, default: 0] += 1
        }

        let coreModules: Set<VisionModule> = [.values, .visionStatement]

        // Sort: core questions for under-answered categories first, then by module priority.
        let sorted = eligible.sorted { a, b in
            let aCount = answerCountByCategory[a.categoryId] ?? 0
            let bCount = answerCountByCategory[b.categoryId] ?? 0
            let aIsCore = (a.module.map { coreModules.contains($0) } ?? false) && aCount < visionCategoryCoreMin
            let bIsCore = (b.module.map { coreModules.contains($0) } ?? false) && bCount < visionCategoryCoreMin
            if aIsCore != bIsCore { return aIsCore }               // core first
            let ap = a.module?.priority ?? VisionModule.discovery.priority
            let bp = b.module?.priority ?? VisionModule.discovery.priority
            if ap != bp { return ap < bp }
            return a.createdAt < b.createdAt
        }

        // Filter: if the top-priority missing module is values, only return values questions first
        // until values is covered — same for visionStatement, WOOP etc.
        let missingModules = VisionModule.allCases
            .filter { $0 != .discovery && !coveredModules.contains($0) }
            .sorted { $0.priority < $1.priority }

        var picked: [VisionQuestion] = []
        var usedCats = Set<UUID>()
        var usedModules = Set<VisionModule>()

        // Pass 1: fill from the highest-priority missing module, 1 per category for variety
        if let topModule = missingModules.first {
            let modulePool = sorted.filter { $0.module == topModule }
            for q in modulePool {
                guard picked.count < needed else { break }
                if usedCats.contains(q.categoryId) { continue }
                picked.append(q)
                usedCats.insert(q.categoryId)
                if let m = q.module { usedModules.insert(m) }
            }
        }

        // Pass 2: fill remaining slots from next-priority modules, still 1 per category
        for q in sorted {
            guard picked.count < needed else { break }
            if usedCats.contains(q.categoryId) { continue }
            if picked.contains(where: { $0.id == q.id }) { continue }
            picked.append(q)
            usedCats.insert(q.categoryId)
            if let m = q.module { usedModules.insert(m) }
        }

        // Pass 3: relax category constraint if still not enough
        for q in sorted {
            guard picked.count < needed else { break }
            if picked.contains(where: { $0.id == q.id }) { continue }
            picked.append(q)
        }

        return Array(picked.prefix(needed))
    }

    // MARK: - Which modules are still missing answers?

    static func missingModules(from answers: [VisionAnswer], questions: [VisionQuestion]) -> [VisionModule] {
        let answeredTexts = Set(answers.map { $0.questionText.lowercased() })
        let coveredModules: Set<VisionModule> = Set(
            questions
                .filter { answeredTexts.contains($0.questionText.lowercased()) }
                .compactMap { $0.module }
        )
        return VisionModule.allCases
            .filter { $0 != .discovery && !coveredModules.contains($0) }
            .sorted { $0.priority < $1.priority }
    }

    // MARK: - Progress summary for UI

    struct ModuleProgress {
        let module: VisionModule
        let answeredCount: Int
        let totalCount: Int
        var isComplete: Bool { answeredCount > 0 }
        var completionFraction: Double { totalCount == 0 ? 0 : min(Double(answeredCount) / Double(totalCount), 1) }
    }

    static func moduleProgress(from answers: [VisionAnswer], questions: [VisionQuestion]) -> [ModuleProgress] {
        let answeredTexts = Set(answers.map { $0.questionText.lowercased() })
        return VisionModule.allCases.filter { $0 != .discovery }.map { module in
            let moduleQs = questions.filter { $0.module == module }
            let answered  = moduleQs.filter { answeredTexts.contains($0.questionText.lowercased()) }.count
            return ModuleProgress(module: module, answeredCount: answered, totalCount: moduleQs.count)
        }
    }

    // MARK: - Private factory

    nonisolated private static func q(
        cat: UUID,
        text: String,
        type: QuestionType,
        module: VisionModule,
        timeframe: Int,
        horizonTag: String? = nil,
        options: [String] = []
    ) -> VisionQuestion {
        VisionQuestion(
            categoryId: cat,
            questionText: text,
            timeframeYears: timeframe,
            isAiGenerated: false,
            answerOptions: options.isEmpty ? nil : options + ["Other — write my own"],
            questionType: type,
            module: module,
            horizonTag: horizonTag
        )
    }
}
