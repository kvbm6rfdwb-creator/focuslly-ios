import Foundation
import Combine
import SwiftUI

// MARK: - MotivationMessageEngine
//
// Generates a single, personalised motivation message using OpenAI.
// • On first call for a 3-hour block: shows a fallback immediately,
//   fires an async AI request, then updates the message when it arrives.
// • If AI is unavailable (no key, offline, error): the fallback is kept.
// • The AI message is cached for the rest of the 3-hour block (~8 per day).
// • Fallbacks are seeded by date — consistent within the same day,
//   changes daily without repeating patterns.

final class MotivationMessageEngine: ObservableObject {

    // MARK: - Singleton
    static let shared = MotivationMessageEngine()
    private init() {}

    // MARK: - Published message (observed by DashboardView)
    @Published private(set) var currentMessage: String = ""

    // MARK: - Persistence keys
    private let cachedMsgKey   = "motivation_ai_msg_v4"
    private let cachedBlockKey = "motivation_ai_block_v4"
    private let cachedCtxKey   = "motivation_ai_ctx_v4"

    // MARK: - State
    private var isRequesting = false

    // 3-hour block index (0-7, changes 8 times/day)
    private func blockIndex(for hour: Int) -> Int { max(0, min(7, hour / 3)) }

    // MARK: - Context
    struct Context {
        // Focus / productivity
        let hour:               Int
        let streak:             Int
        let focusMinsToday:     Int
        let sessionsToday:      Int
        let tasksRemaining:     Int
        let totalTasksToday:    Int
        let weeklyMins:         Int
        let isInFocusSession:   Bool

        // Pipeline / sales
        let dialsToday:         Int
        let dialTarget:         Int
        let dialsThisWeek:      Int
        let weeklyDialTarget:   Int
        let hotLeadsCount:      Int
        let meetingsToday:      Int
        let offersToday:        Int       // offerSent logs today
        let listingsToday:      Int       // listingSigned logs today
        let newContactsToday:   Int
        let appointmentsThisWeek: Int

        // Derived helpers
        var dialPacePercent: Double {
            guard dialTarget > 0 else { return 0 }
            // Compare dials vs. expected pace at this time of day
            let workdayStart  = 8.0   // 08:00
            let workdayEnd    = 19.0  // 19:00
            let workdayLength = workdayEnd - workdayStart
            let elapsed       = max(0, min(Double(hour) - workdayStart, workdayLength))
            let expectedFraction = elapsed / workdayLength
            let expected      = Double(dialTarget) * expectedFraction
            guard expected > 0 else { return Double(dialsToday) > 0 ? 1.5 : 0 }
            return Double(dialsToday) / expected
        }

        var dialCompletionPercent: Double {
            guard dialTarget > 0 else { return 0 }
            return Double(dialsToday) / Double(dialTarget)
        }

        var weeklyDialCompletionPercent: Double {
            guard weeklyDialTarget > 0 else { return 0 }
            return Double(dialsThisWeek) / Double(weeklyDialTarget)
        }

        var remainingDialsToday: Int { max(0, dialTarget - dialsToday) }

        /// A lightweight hash so we detect meaningful context changes mid-block.
        var stateHash: String {
            let block = max(0, min(7, hour / 3))
            return "\(block)|\(streak)|\(focusMinsToday / 15)|\(sessionsToday)|\(tasksRemaining)|\(isInFocusSession)|\(dialsToday / 5)|\(hotLeadsCount)"
        }
    }

    // MARK: - Public entry point
    func message(context: Context) -> String {
        let block   = blockIndex(for: context.hour)
        let defaults = UserDefaults.standard
        let lastBlock = defaults.integer(forKey: cachedBlockKey)
        let lastCtx   = defaults.string(forKey: cachedCtxKey) ?? ""

        if lastBlock == block,
           lastCtx == context.stateHash,
           let cached = defaults.string(forKey: cachedMsgKey), !cached.isEmpty {
            if currentMessage.isEmpty { currentMessage = cached }
            return cached
        }

        let fb = fallback(context: context)
        if currentMessage.isEmpty { currentMessage = fb }

        if !isRequesting {
            isRequesting = true
            Task { await requestAIMessage(context: context, block: block) }
        }

        return currentMessage.isEmpty ? fb : currentMessage
    }

    func freshMessage(context: Context) -> String { message(context: context) }

    // MARK: - Local fallback request
    private func requestAIMessage(context: Context, block: Int) async {
        let fallbackMessage = fallback(context: context)
        saveAndPublish(fallbackMessage, block: block, ctx: context)
    }

    private func saveAndPublish(_ message: String, block: Int, ctx: Context) {
        let defaults = UserDefaults.standard
        defaults.set(block,           forKey: cachedBlockKey)
        defaults.set(ctx.stateHash,   forKey: cachedCtxKey)
        defaults.set(message,         forKey: cachedMsgKey)
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.6)) { self.currentMessage = message }
            self.isRequesting = false
        }
    }

    // MARK: - Prompt builder (7 principles)
    private func buildPrompt(context: Context) -> String {
        var facts: [String] = []

        // ── 1. Role & time of day ──────────────────────────────────────────
        let timeLabel: String
        switch context.hour {
        case 0..<6:   timeLabel = "late night / early morning (\(context.hour):xx)"
        case 6..<9:   timeLabel = "early morning (\(context.hour):xx)"
        case 9..<12:  timeLabel = "mid-morning (\(context.hour):xx)"
        case 12..<14: timeLabel = "lunchtime (\(context.hour):xx)"
        case 14..<17: timeLabel = "afternoon (\(context.hour):xx)"
        case 17..<20: timeLabel = "early evening (\(context.hour):xx)"
        default:      timeLabel = "evening (\(context.hour):xx)"
        }
        facts.append("It is \(timeLabel).")

        // ── 2. Current state ───────────────────────────────────────────────
        if context.isInFocusSession {
            facts.append("The agent is currently in an active focus session.")
        }

        // ── 3. Dial performance (tiered, specific) ─────────────────────────
        let pace = context.dialPacePercent
        let completion = context.dialCompletionPercent
        let remaining = context.remainingDialsToday

        if context.dialsToday == 0 && context.hour >= 9 {
            facts.append("They have made ZERO dials today despite it being \(timeLabel). The day is losing momentum.")
        } else if context.dialsToday == 0 {
            facts.append("No dials yet today. The day is just starting.")
        } else if completion >= 1.0 {
            facts.append("Dial target hit: \(context.dialsToday) of \(context.dialTarget) dials done. Target is complete.")
        } else if pace < 0.6 && context.hour >= 12 {
            facts.append("Behind pace: \(context.dialsToday) dials done, \(remaining) still needed to hit today\'s target of \(context.dialTarget). Significantly behind.")
        } else if pace < 0.85 {
            facts.append("Slightly behind pace: \(context.dialsToday)/\(context.dialTarget) dials done, \(remaining) remaining.")
        } else if pace >= 1.2 {
            facts.append("Ahead of pace: \(context.dialsToday)/\(context.dialTarget) dials done — running hot today.")
        } else {
            facts.append("On pace: \(context.dialsToday)/\(context.dialTarget) dials done, \(remaining) to go.")
        }

        // ── 4. Hot leads (urgency) ─────────────────────────────────────────
        if context.hotLeadsCount >= 3 {
            facts.append("There are \(context.hotLeadsCount) HOT LEADS in the pipeline right now. These people are ready.")
        } else if context.hotLeadsCount == 2 {
            facts.append("2 hot leads in the pipeline — both need attention today.")
        } else if context.hotLeadsCount == 1 {
            facts.append("1 hot lead in the pipeline.")
        }

        // ── 5. Meetings & offers ───────────────────────────────────────────
        if context.meetingsToday > 0 {
            facts.append("\(context.meetingsToday) meeting\(context.meetingsToday == 1 ? "" : "s") done today.")
        }
        if context.offersToday > 0 {
            facts.append("\(context.offersToday) offer\(context.offersToday == 1 ? "" : "s") sent today.")
        }
        if context.listingsToday > 0 {
            facts.append("\(context.listingsToday) listing\(context.listingsToday == 1 ? "" : "s") signed today.")
        }

        // ── 6. Weekly dial momentum ───────────────────────────────────────
        let weeklyCompletion = context.weeklyDialCompletionPercent
        if weeklyCompletion >= 1.0 {
            facts.append("Weekly dial target already met (\(context.dialsThisWeek)/\(context.weeklyDialTarget)).")
        } else if context.dialsThisWeek > 0 {
            let weekRemaining = max(0, context.weeklyDialTarget - context.dialsThisWeek)
            facts.append("\(context.dialsThisWeek)/\(context.weeklyDialTarget) dials this week. \(weekRemaining) to go for the week.")
        }

        // ── 7. Focus sessions & streak ────────────────────────────────────
        if context.sessionsToday == 0 && context.dialsToday == 0 {
            facts.append("No focus sessions and no dials yet — the day hasn\'t started in any meaningful way.")
        } else if context.sessionsToday > 0 {
            let h = context.focusMinsToday / 60
            let m = context.focusMinsToday % 60
            let label = h > 0 ? (m > 0 ? "\(h)h \(m)m" : "\(h)h") : "\(m) min"
            facts.append("\(context.sessionsToday) focus session\(context.sessionsToday == 1 ? "" : "s") completed today (\(label) total).")
        }

        if context.streak >= 7 {
            facts.append("On a \(context.streak)-day focus streak — strong consistency.")
        } else if context.streak >= 3 {
            facts.append("\(context.streak)-day streak building.")
        } else if context.streak == 0 && context.sessionsToday == 0 {
            facts.append("No active streak.")
        }

        if context.tasksRemaining == 0 && context.totalTasksToday > 0 {
            facts.append("All \(context.totalTasksToday) tasks for today are complete.")
        } else if context.tasksRemaining > 0 {
            facts.append("\(context.tasksRemaining) task\(context.tasksRemaining == 1 ? "" : "s") still to do today.")
        }

        return """
        Here is the real estate sales agent\'s situation right now:

        \(facts.joined(separator: "\n"))

        Write one coaching message (1–3 sentences, often just 1) for this exact moment.
        It must feel personal and true to this specific situation.
        Do not list stats back to them.
        Do not start with "You\'ve" or "You\'re" every time — vary the opening word.
        If they are behind on dials, be honest and direct — not harsh, but real.
        If they have hot leads, make those feel urgent.
        If they are crushing it, acknowledge it fast and point to what\'s next.
        Write like a sharp sales manager who knows this person\'s day.
        """
    }

    // MARK: - Fallback pool — attributed quotes adapted to each situation
    func fallback(context: Context) -> String {

        let cal       = Calendar.current
        let dayOfYear = cal.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let seed      = dayOfYear + context.hour

        // ── Active focus session ───────────────────────────────────────────
        if context.isInFocusSession {
            let opts = [
                "Wherever you are, be all there.\n— Jim Elliot",
                "The successful warrior is the average person with laser-like focus.\n— Bruce Lee",
                "Concentrate all your thoughts upon the work at hand. The sun's rays do not burn until brought to a focus.\n— Alexander Graham Bell",
                "If you're going through hell, keep going.\n— Winston Churchill",
                "You have to fight to reach your dream. You have to sacrifice and work hard for it.\n— Lionel Messi"
            ]
            return opts[seed % opts.count]
        }

        // ── All tasks done ─────────────────────────────────────────────────
        if context.tasksRemaining == 0 && context.totalTasksToday > 0 {
            let opts = [
                "It always seems impossible until it's done.\n— Nelson Mandela",
                "The secret of getting ahead is getting started. You got started. And you finished.\n— Mark Twain (adapted)",
                "Well done is better than well said.\n— Benjamin Franklin",
                "You did the thing. Most people only plan to.\n— David Goggins (adapted)",
                "The reward of a thing well done is to have done it.\n— Ralph Waldo Emerson"
            ]
            return opts[seed % opts.count]
        }

        // ── Dial target hit ────────────────────────────────────────────────
        if context.dialCompletionPercent >= 1.0 {
            let opts = [
                "Standards are not a ceiling. They're a floor.\n— Kobe Bryant (adapted)",
                "The target is what everyone reaches. The standard is what separates you.\n— Bill Belichick (adapted)",
                "Once you've done the work, the work is never really done.\n— Ernest Hemingway (adapted)",
                "Discipline is doing what needs to be done, even after the number is hit.\n— Jocko Willink (adapted)",
                "Champions aren't made when they hit their number. They're made by what they do next.\n— Any Given Sunday (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Early morning, no dials yet ────────────────────────────────────
        if context.dialsToday == 0 && context.hour < 10 {
            let opts = [
                "Lose an hour in the morning and you will spend the rest of the day searching for it.\n— Richard Whately",
                "The morning is the rudder of the day. Set it now.\n— Henry Ward Beecher (adapted)",
                "Either you run the day, or the day runs you.\n— Jim Rohn",
                "Own the morning. The competition is still asleep.\n— Jocko Willink (adapted)",
                "What you do in the morning determines what kind of day you're going to have.\n— Tony Robbins (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Zero dials, late afternoon / evening ───────────────────────────
        if context.dialsToday == 0 && context.hour >= 14 {
            let opts = [
                "You don't have to be great to start, but you have to start to be great.\n— Zig Ziglar",
                "The danger is not that we aim too high and miss, but that we aim too low and hit nothing at all.\n— Michelangelo (adapted)",
                "It does not matter how slowly you go, as long as you do not stop. But you have to go.\n— Confucius (adapted)",
                "At some point, the pain of not doing it becomes greater than the pain of doing it.\n— Steven Pressfield, The War of Art",
                "The clock is the only thing in this room that doesn't care about your excuses.\n— David Goggins (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Zero dials, mid-morning ────────────────────────────────────────
        if context.dialsToday == 0 {
            let opts = [
                "The secret of getting ahead is getting started.\n— Mark Twain",
                "You don't have to see the whole staircase. Just take the first step.\n— Martin Luther King Jr.",
                "The beginning is the most important part of the work.\n— Plato",
                "Action is the foundational key to all success.\n— Pablo Picasso",
                "Stop thinking. Start dialing.\n— Alec Baldwin, Glengarry Glen Ross (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Significantly behind pace ──────────────────────────────────────
        if context.dialPacePercent < 0.6 && context.hour >= 12 {
            let r = context.remainingDialsToday
            let opts = [
                "It's not about how hard you hit. It's about how hard you can get hit and keep moving.\n— Rocky Balboa, Rocky Balboa (2006)",
                "The obstacle is the way. \(r) dials is the obstacle.\n— Marcus Aurelius (adapted)",
                "When you think about giving up, think about why you started.\n— Michael Jordan (attributed)",
                "Fatigue makes cowards of us all. Don't let the afternoon do that to you.\n— Vince Lombardi (adapted)",
                "We don't rise to the level of our expectations; we fall to the level of our training. Train yourself to finish.\n— Archilochus (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Slightly behind pace ───────────────────────────────────────────
        if context.dialPacePercent < 0.85 {
            let r = context.remainingDialsToday
            let opts = [
                "A small daily task, if it be really daily, will beat the labours of a spasmodic Hercules.\n— Anthony Trollope",
                "\(r) dials. Inch by inch, life's a cinch. Yard by yard, life is hard.\n— John Bytheway (adapted)",
                "The race is not always to the swift, but to those who keep running.\n— Ecclesiastes (adapted)",
                "Continuous effort — not strength or intelligence — is the key to unlocking our potential.\n— Winston Churchill",
                "You are closer than you think. Close is not done. Do the \(r).\n— Naval Ravikant (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Ahead of pace ──────────────────────────────────────────────────
        if context.dialPacePercent >= 1.2 {
            let opts = [
                "The standard you walk past is the standard you accept.\n— David Morrison",
                "Hard work beats talent when talent doesn't work hard. You're proving it today.\n— Tim Notke (adapted)",
                "The way to a championship is to never stop at good enough.\n— Ayrton Senna (adapted)",
                "Success is never owned. It's rented — and the rent is due every day.\n— Rory Vaden",
                "You've earned the right to go harder. Use it.\n— Kobe Bryant (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Hot leads waiting ──────────────────────────────────────────────
        if context.hotLeadsCount >= 2 {
            let opts = [
                "Speed is irrelevant if you're going in the wrong direction. Your hot leads are the right direction.\n— Mahatma Gandhi (adapted)",
                "Strike while the iron is hot. Leads go cold faster than you think.\n— Geoffrey Chaucer (adapted)",
                "Opportunities multiply as they are seized.\n— Sun Tzu",
                "The early bird gets the worm. You have \(context.hotLeadsCount) worms waiting.\n— William Camden (adapted)",
                "In the middle of every difficulty lies opportunity — and right now, \(context.hotLeadsCount) opportunities have raised their hand.\n— Albert Einstein (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Streak at risk ─────────────────────────────────────────────────
        if context.streak >= 5 && context.sessionsToday == 0 {
            let opts = [
                "We are what we repeatedly do. Excellence, then, is not an act but a habit.\n— Aristotle",
                "Don't break the chain. \(context.streak) days is worth protecting.\n— Jerry Seinfeld (adapted)",
                "The chains of habit are too light to be felt until they're too heavy to be broken.\n— Warren Buffett",
                "A \(context.streak)-day streak is a form of identity. Guard it.\n— James Clear, Atomic Habits (adapted)",
                "First forget inspiration. Habit is more dependable.\n— Octavia Butler"
            ]
            return opts[seed % opts.count]
        }

        // ── Evening wind-down ──────────────────────────────────────────────
        if context.hour >= 20 {
            let opts = [
                "Finish what you started. The night doesn't care about excuses.\n— Ernest Hemingway (adapted)",
                "The most courageous act is still to think for yourself. Aloud. And then act.\n— Coco Chanel (adapted)",
                "You can't cross the sea merely by standing and staring at the water.\n— Rabindranath Tagore",
                "Even if you're on the right track, you'll get run over if you just sit there.\n— Will Rogers",
                "End the day better than it started. That's the whole job.\n— Ryan Holiday (adapted)"
            ]
            return opts[seed % opts.count]
        }

        // ── Steady, on-pace baseline ───────────────────────────────────────
        let steadyOpts = [
            "We are what we repeatedly do. Today's dials are tomorrow's closings.\n— Aristotle (adapted)",
            "It's not the mountain we conquer, but ourselves.\n— Edmund Hillary",
            "Absorb what is useful, reject what is useless, add what is specifically your own.\n— Bruce Lee",
            "The only way to do great work is to love what you do. Or at least to dial while you find it.\n— Steve Jobs (adapted)",
            "Perfection is not attainable, but if we chase perfection we can catch excellence.\n— Vince Lombardi",
            "Your work is going to fill a large part of your life. Make today's part count.\n— Steve Jobs (adapted)",
            "Pain is temporary. Quitting lasts forever.\n— Lance Armstrong",
            "He who is not courageous enough to take risks will accomplish nothing in life.\n— Muhammad Ali",
            "The details are not the details. They make the design.\n— Charles Eames",
            "Do what you can, with what you have, where you are.\n— Theodore Roosevelt",
            "The man who moves a mountain begins by carrying away small stones.\n— Confucius",
            "Vision without execution is just hallucination.\n— Thomas Edison (attributed)",
            "Fall seven times, stand up eight.\n— Japanese Proverb",
            "You miss 100% of the shots you don't take.\n— Wayne Gretzky",
            "The best time to plant a tree was 20 years ago. The second best time is now.\n— Chinese Proverb"
        ]
        return steadyOpts[seed % steadyOpts.count]
    }
}
