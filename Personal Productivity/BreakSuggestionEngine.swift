import Foundation

/// Break Suggestion Engine — produces a full-break plan with multiple steps that
/// together fill the entire available break duration.
struct BreakSuggestionEngine {

    // MARK: - Ultradian phase (Kleitman BRAC — ~90 min cycle)
    // Alert phase: 0–70 min into a work cycle. Rest phase: 70–90+ min.
    // Source: Kleitman 1963, Lavie 1979 pupillometric evidence (~75–125 min oscillations)
    enum UltradianPhase {
        case alertPeak      // 0–55 min: full cognitive capacity
        case alertLate      // 55–70 min: still productive, mild fatigue accumulating
        case restRequired   // 70–90+ min: brain signals genuine need for rest phase
    }

    private static func ultradianPhase(continuousWorkMin: Int) -> UltradianPhase {
        switch continuousWorkMin {
        case 0..<55:  return .alertPeak
        case 55..<70: return .alertLate
        default:      return .restRequired  // 70+ min — Lavie's rest-phase window
        }
    }

    // MARK: - Break category (used for rotation logic)
    enum BreakCategory: String, Codable {
        case cognitiveReset
        case meditation
        case physicalActivation
    }

    // MARK: - Types
    enum BreakType: String, Codable {
        case sensoryShift, physicalReset, intentionalPause
        case playfulMovement, cognitiveOffload, trueRest, switchRitual
        case breathingMeditation, bodyScan, openAwareness, relaxationAudio
        // Tier 1 research additions
        case napRest                    // NASA 26-min nap — Rosekind et al. 1995
        case physiologicalSigh          // Balban et al. 2023 — cyclic sighing
        case nsdRest                    // Kjaer 2002 / Huberman NSDR — dopamine restoration
        case focusedAttentionMeditation // Colzato 2012 — FA for convergent/analytical tasks
        // Tier 2 research additions
        case morningSunlight            // Czeisler 1986 / Huberman — ipRGC circadian anchoring
        case caffeineWarning            // Walker / Huberman — adenosine / 90-120 min delay
        case coldWaterReset             // Shevchuk 2008 — norepinephrine spike via cold exposure
        case natureWalk                 // Kaplan & Kaplan 1989 / Berto 2014 — ART + optic flow
        // Tier 3 research additions
        case goalSwitchBreak            // Ariga & Lleras 2011 — task-switch prevents vigilance decrement
        case pleasurableRest            // Van Hooff 2011 — pleasure > effort for recovery
    }
    enum BreakActivity: String, Codable, Hashable {
        case hydrate, stretch, walk, breathe, eyes, music, snack, social, rest, focusBreak
    }
    enum EnergyLevel: String, Codable { case low, medium, high }
    enum CognitiveLoad: Int { case easy = 1, medium = 2, hard = 3 }
    struct LegacySuggestion {
        let breakType: BreakType
        var activity: BreakActivity { .rest }
        var title: String { breakType.rawValue }
    }

    // MARK: - A single step inside a break plan
    struct BreakStep {
        let icon: String
        let action: String
        let instruction: String
        let minutes: Int
        var isMeditation: Bool = false
    }

    // MARK: - Full break plan
    struct BreakPlan {
        let steps: [BreakStep]
        let rationale: String
        let category: BreakCategory
        var primaryStep: BreakStep { steps[0] }
    }

    // MARK: - Decision output
    struct Decision {
        let breakType: BreakType
        let headline: String
        let goal: String
        let plan: BreakPlan
        let breakMin: Int
        let timeOfDayNote: String?
        let isEndOfDay: Bool
        let energyLevel: EnergyLevel
        let cognitiveLoad: CognitiveLoad
        /// Alternative break choices offered to the user.
        /// Trougakos et al. (2014): break autonomy (choosing your own break activity)
        /// is a key moderator — restorative effects are significantly stronger when
        /// the user selects their own break. Present these in the UI so the user can
        /// switch to a preferred option rather than always accepting the primary.
        var breakChoices: [Decision] = []

        var durationRange: String { breakMin == 1 ? "1 min" : "\(breakMin) min" }
        var category: BreakCategory { plan.category }
        var primarySuggestion: LegacySuggestion { LegacySuggestion(breakType: breakType) }
        var overallMessage: String { goal }
        var activity: BreakStep { plan.primaryStep }
    }

    // MARK: - Main entry
    static func decide(
        completedTask: FocusTask,
        engine: FocusSessionEngine,
        breakDuration: Int,
        taskStore: TaskStore?,
        previousBreakCategory: BreakCategory? = nil,
        continuousWorkMinutes: Int = 0
    ) -> Decision {
        let hour       = Calendar.current.component(.hour, from: Date())
        let timeOfDay  = classifyTimeOfDay(hour: hour)
        let doneLoad   = inferCognitiveLoad(task: completedTask, taskStore: taskStore)
        let focusSec   = completedTask.focusPlan.blocks
                           .filter { $0.type == .focus }.reduce(0) { $0 + $1.duration }
        let nextTask   = findNextTask(after: completedTask, in: taskStore)
        let nextLoad   = nextTask.map { inferCognitiveLoad(task: $0, taskStore: taskStore) }
        let focusedMin = totalFocusToday(taskStore: taskStore)
        let isEndOfDay = nextTask == nil && (hour >= 17 || focusedMin >= 360)
        var energy     = assessEnergy(focusedMinutes: focusedMin, load: doneLoad, hour: hour)
        let breakMin   = max(1, breakDuration / 60)

        // ── Meal-aware energy adjustment ──────────────────────────────────────
        let meals = MealStore.shared
        // Hungry (4+ hours since last meal) → drop energy level one notch
        if meals.isHungry && energy == .high { energy = .medium }
        else if meals.isHungry && energy == .medium { energy = .low }
        // Has not eaten at all today → treat as low energy regardless
        if meals.hasNotEatenToday && hour >= 10 { energy = .low }

        return buildDecision(
            doneLoad: doneLoad, focusSec: focusSec, nextLoad: nextLoad,
            breakMin: breakMin, timeOfDay: timeOfDay, isEndOfDay: isEndOfDay,
            energy: energy, hour: hour, nextTask: nextTask,
            previousCategory: previousBreakCategory,
            continuousWorkMin: continuousWorkMinutes,
            isPostLunchDip: meals.isInPostLunchDip,
            isHungry: meals.isHungry
        )
    }

    // MARK: - Core decision logic
    private static func buildDecision(
        doneLoad: CognitiveLoad, focusSec: Int,
        nextLoad: CognitiveLoad?, breakMin: Int,
        timeOfDay: TimeOfDay, isEndOfDay: Bool,
        energy: EnergyLevel, hour: Int, nextTask: FocusTask?,
        previousCategory: BreakCategory?,
        continuousWorkMin: Int,
        isPostLunchDip: Bool = false,
        isHungry: Bool = false
    ) -> Decision {

        let isNight   = hour >= 21 || hour < 6
        let isMorning = hour >= 6 && hour < 9

        // ── End of day → wind-down ritual ─────────────────────────────────
        if isEndOfDay { return switchRitual(energy: energy, breakMin: breakMin, hour: hour) }

        // ── Hungry → eat first ────────────────────────────────────────────
        if isHungry && breakMin >= 5 {
            return snackReminderBreak(breakMin: breakMin, isNight: isNight)
        }

        // ── Micro break (≤2 min) ──────────────────────────────────────────
        // Physiological sigh is the fastest evidence-based reset (Balban 2023)
        if breakMin <= 2 {
            return physiologicalSighBreak(doneLoad: doneLoad, breakMin: breakMin)
        }

        // ── MORNING ROUTING (Tier 2: Czeisler/Huberman + Walker/Huberman) ─
        // Both suggestions fire at most once per calendar day.
        let todayKey = Self.todayDateKey()
        let shownSunlight  = UserDefaults.standard.bool(forKey: "bse_sunlight_shown_\(todayKey)")
        let shownCaffeine  = UserDefaults.standard.bool(forKey: "bse_caffeine_shown_\(todayKey)")

        if isMorning && breakMin >= 5 && continuousWorkMin < 90 && !shownSunlight {
            UserDefaults.standard.set(true, forKey: "bse_sunlight_shown_\(todayKey)")
            return morningSunlightBreak(breakMin: breakMin)
        }
        if isMorning && breakMin >= 3 && continuousWorkMin < 60 && !shownCaffeine {
            UserDefaults.standard.set(true, forKey: "bse_caffeine_shown_\(todayKey)")
            return caffeineWarningBreak(breakMin: breakMin, hour: hour)
        }

        // ── BRAC phase (Kleitman/Lavie) — computed once, used throughout ──
        let bracPhase = ultradianPhase(continuousWorkMin: continuousWorkMin)

        // ── BRAC alertLate phase (Lavie 55–70 min — fatigue accumulating) ──
        // Not yet rest-required, but continued hard work will compound fatigue.
        // Steer toward lower-intensity breaks and prime for the upcoming rest phase.
        if bracPhase == .alertLate && !isNight {
            // If next task is hard, prime for it now before the rest phase hits
            if nextLoad == .hard && breakMin >= 4 {
                return primeForHard(breakMin: breakMin)
            }
            // Prefer a meditation or gentle cognitive break — avoid intense physical
            if breakMin >= 4 {
                return pickMeditationBreak(breakMin: breakMin, doneLoad: doneLoad,
                                           energy: energy, nextLoad: nextLoad)
            }
            // Short: physiological sigh to ease into the rest phase
            return physiologicalSighBreak(doneLoad: doneLoad, breakMin: breakMin)
        }

        // ── BRAC rest-phase override (70+ continuous min) ─────────────────
        if bracPhase == .restRequired && !isNight {
            if breakMin >= 10 && breakMin <= 20 {
                return napBreak(breakMin: breakMin, energy: energy)
            }
            if breakMin >= 10 && energy == .low {
                return nsdRestBreak(breakMin: breakMin)
            }
            return deepRestoration(breakMin: breakMin, doneLoad: doneLoad, nextLoad: nextLoad)
        }

        // ── Short break (3 min) ───────────────────────────────────────────
        if breakMin <= 3 {
            let forceMed = continuousWorkMin >= 90 && previousCategory != .meditation
            if forceMed { return breathingMeditation(breakMin: breakMin) }
            // Ariga & Lleras 2011: goal-switch after 10–20 continuous min of focused work
            // prevents vigilance decrement better than passive or no break.
            // Target: alertPeak phase (< 55 min) after moderate focused session.
            if bracPhase == .alertPeak && continuousWorkMin >= 10 && doneLoad != .easy {
                return goalSwitchBreak(breakMin: breakMin, doneLoad: doneLoad)
            }
            return microReset(doneLoad: doneLoad, nextLoad: nextLoad, energy: energy, breakMin: breakMin)
        }

        // ── Post-lunch dip ────────────────────────────────────────────────
        if isPostLunchDip && !isNight {
            if breakMin >= 10 && breakMin <= 20 {
                return napBreak(breakMin: breakMin, energy: energy)
            }
            return postLunchMovement(breakMin: breakMin, nextLoad: nextLoad)
        }

        // ── Low energy ────────────────────────────────────────────────────
        if energy == .low {
            // Cold water reset: fast NE spike for short-to-medium breaks (Shevchuk 2008)
            if breakMin >= 3 && breakMin <= 7 && !isNight {
                return coldWaterResetBreak(breakMin: breakMin, doneLoad: doneLoad)
            }
            // NSDR for 10+ min breaks (Kjaer 2002)
            if breakMin >= 10 && !isNight {
                return nsdRestBreak(breakMin: breakMin)
            }
            return deepRestoration(breakMin: breakMin, doneLoad: doneLoad, nextLoad: nextLoad)
        }

        // ── Early afternoon fatigue ───────────────────────────────────────
        if timeOfDay == .earlyAfternoon && focusSec >= 25 * 60 && !isNight {
            if breakMin >= 10 && breakMin <= 20 {
                return napBreak(breakMin: breakMin, energy: energy)
            }
            return postLunchMovement(breakMin: breakMin, nextLoad: nextLoad)
        }

        // ── Standard routing ──────────────────────────────────────────────
        let forceMeditation   = continuousWorkMin >= 90 && previousCategory != .meditation
        let meditationAllowed = previousCategory != .meditation

        let category: BreakCategory
        if forceMeditation {
            category = .meditation
        } else {
            let roll = Int.random(in: 1...100)
            if meditationAllowed && roll <= 30 {
                category = .meditation
            } else if roll <= 62 {
                category = decideCategoryByLoad(doneLoad: doneLoad, focusSec: focusSec,
                                                nextLoad: nextLoad, breakMin: breakMin)
            } else {
                category = isNight ? .cognitiveReset : .physicalActivation
            }
        }

        // Build primary decision
        var primary: Decision
        switch category {
        case .meditation:
            primary = pickMeditationBreak(breakMin: breakMin, doneLoad: doneLoad,
                                          energy: energy, nextLoad: nextLoad)
        case .physicalActivation:
            if !isNight && breakMin >= 5 {
                primary = natureWalkBreak(breakMin: breakMin, nextLoad: nextLoad, energy: energy)
            } else {
                let sl: SessionLen = focusSec < 30*60 ? .short : focusSec < 60*60 ? .medium : .long
                switch sl {
                case .short: primary = sensoryShift(nextLoad: nextLoad, breakMin: breakMin, isNight: isNight)
                case .medium, .long: primary = physicalReset(breakMin: breakMin, nextLoad: nextLoad, isNight: isNight)
                }
            }
        case .cognitiveReset:
            let sl: SessionLen = focusSec < 30*60 ? .short : focusSec < 60*60 ? .medium : .long
            switch (doneLoad, sl) {
            case (.easy, .short):
                primary = sensoryShift(nextLoad: nextLoad, breakMin: breakMin, isNight: isNight)
            case (.easy, .medium), (.easy, .long):
                primary = !isNight && breakMin >= 5
                    ? natureWalkBreak(breakMin: breakMin, nextLoad: nextLoad, energy: energy)
                    : physicalReset(breakMin: breakMin, nextLoad: nextLoad, isNight: isNight)
            case (.medium, .short):
                primary = intentionalPause(nextLoad: nextLoad, breakMin: breakMin)
            case (.medium, .medium):
                primary = nextLoad == .hard
                    ? primeForHard(breakMin: breakMin)
                    : (energy == .medium
                        ? pleasurableRest(breakMin: breakMin, energy: energy)
                        : playfulMovement(breakMin: breakMin, isNight: isNight))
            case (.medium, .long):
                primary = !isNight && breakMin >= 5
                    ? natureWalkBreak(breakMin: breakMin, nextLoad: nextLoad, energy: energy)
                    : playfulMovement(breakMin: breakMin, isNight: isNight)
            case (.hard, .short):
                primary = cognitiveOffload(nextLoad: nextLoad, breakMin: breakMin)
            case (.hard, .medium):
                primary = breakMin >= 8
                    ? fullCognitiveReset(breakMin: breakMin)
                    : cognitiveOffload(nextLoad: nextLoad, breakMin: breakMin)
            case (.hard, .long):
                primary = trueRest(breakMin: breakMin, nextLoad: nextLoad, isNight: isNight)
            }
        }

        // ── Autonomy choices (Trougakos 2014 + Bosch 2018) ───────────────
        // Offering 2 alternative break options significantly improves restoration
        // because the user choosing their own activity (autonomy) is a key moderator.
        // Build a small set of credible alternatives that differ from the primary.
        var choices: [Decision] = []
        // Always include a pleasurable option (Van Hooff 2011: pleasure predicts recovery)
        if primary.breakType != .pleasurableRest {
            choices.append(pleasurableRest(breakMin: breakMin, energy: energy))
        }
        // Add a meditation alternative if not already meditation
        if primary.category != .meditation && breakMin >= 3 {
            choices.append(pickMeditationBreak(breakMin: breakMin, doneLoad: doneLoad,
                                               energy: energy, nextLoad: nextLoad))
        }
        // Add a nature walk if daytime and primary is not already a walk
        if !isNight && breakMin >= 5
            && primary.breakType != .natureWalk
            && primary.breakType != .playfulMovement {
            choices.append(natureWalkBreak(breakMin: breakMin, nextLoad: nextLoad, energy: energy))
        }
        // Add a goal-switch if alert phase and primary is not already a switch
        if bracPhase == .alertPeak && primary.breakType != .goalSwitchBreak && breakMin <= 5 {
            choices.append(goalSwitchBreak(breakMin: breakMin, doneLoad: doneLoad))
        }
        primary.breakChoices = Array(choices.prefix(3))
        return primary
    }

    private static func decideCategoryByLoad(
        doneLoad: CognitiveLoad, focusSec: Int,
        nextLoad: CognitiveLoad?, breakMin: Int
    ) -> BreakCategory {
        switch doneLoad {
        case .easy:   return .physicalActivation
        case .medium: return breakMin >= 5 ? .physicalActivation : .cognitiveReset
        case .hard:   return .cognitiveReset
        }
    }

    // Colzato et al. 2012: OM → divergent/creative tasks; FA → convergent/analytical tasks
    private static func pickMeditationBreak(breakMin: Int, doneLoad: CognitiveLoad,
                                            energy: EnergyLevel,
                                            nextLoad: CognitiveLoad? = nil) -> Decision {
        let nextIsAnalytical = nextLoad == .hard || nextLoad == .medium
        if breakMin <= 4 {
            return nextIsAnalytical ? focusedAttentionMeditationBreak(breakMin: breakMin)
                                    : breathingMeditation(breakMin: breakMin)
        } else if breakMin <= 7 {
            if energy == .low { return bodyScanMeditation(breakMin: breakMin) }
            return nextIsAnalytical ? focusedAttentionMeditationBreak(breakMin: breakMin)
                                    : openAwarenessMeditation(breakMin: breakMin)
        } else {
            if doneLoad == .hard { return bodyScanMeditation(breakMin: breakMin) }
            let nextIsCreative = nextLoad == .easy || nextLoad == nil
            return nextIsCreative ? openAwarenessMeditation(breakMin: breakMin)
                                  : relaxationAudio(breakMin: breakMin)
        }
    }

    // MARK: - NEW: Physiological Sigh (Balban et al. 2023, Cell Reports Medicine)
    // Double inhale + long exhale: fastest evidence-based stress/arousal reset.
    // 4-week RCT: outperformed box breathing, cyclic hyperventilation & mindfulness
    // on positive affect and respiratory rate reduction.
    private static func physiologicalSighBreak(doneLoad: CognitiveLoad, breakMin: Int) -> Decision {
        let rounds = breakMin == 1 ? 5 : 10
        return Decision(
            breakType: .physiologicalSigh,
            headline: "Physiological Sigh",
            goal: "Fastest evidence-based reset: drop stress and lift mood in under \(breakMin == 1 ? "60 seconds" : "\(breakMin) minutes").",
            plan: BreakPlan(
                steps: [BreakStep(
                    icon: "lungs.fill",
                    action: "Physiological sigh — \(rounds) rounds",
                    instruction: "Double inhale: breathe in through your nose until full, then sniff in a second short burst to fully inflate your lungs. Then exhale slowly and completely through your mouth — longer than both inhales combined. Repeat \(rounds) times. This deflates collapsed alveoli and activates your parasympathetic nervous system faster than any other breathing technique.",
                    minutes: breakMin, isMeditation: false)],
                rationale: "Balban et al. (2023, Cell Reports Medicine): in a 4-week RCT, cyclic sighing produced the largest increase in positive affect and the greatest drop in respiratory rate — outperforming box breathing, cyclic hyperventilation, and mindfulness meditation.",
                category: .cognitiveReset),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: doneLoad)
    }

    // MARK: - NEW: Power Nap (NASA/Rosekind 1995 + Dinges sleep inertia research)
    // 10–20 min sweet spot: avoids SWS entry, no meaningful inertia, ~54% alertness boost.
    private static func napBreak(breakMin: Int, energy: EnergyLevel) -> Decision {
        let napMin    = min(max(breakMin - 2, 10), 20)
        let returnMin = max(breakMin - napMin, 1)
        return Decision(
            breakType: .napRest,
            headline: "Power Nap",
            goal: "Restore alertness by ~54% and clear accumulated sleep pressure — the most time-efficient recovery available.",
            plan: BreakPlan(
                steps: [
                    BreakStep(
                        icon: "moon.zzz.fill",
                        action: "Set a \(napMin)-min timer — lie down or fully recline",
                        instruction: "Set a timer for exactly \(napMin) minutes NOW before you close your eyes. Lie flat or recline as far back as possible. Cover your eyes. Put your phone face-down. You do not need to fully fall asleep — even a hypnagogic (drowsy) state delivers significant restoration. When the timer goes off, get up immediately.",
                        minutes: napMin, isMeditation: false),
                    BreakStep(
                        icon: "bolt.fill",
                        action: "Stand up immediately — shake out your hands",
                        instruction: "Sleep inertia dissipates within 5–10 minutes if you move on waking. Stand up, shake out your hands and arms, then do 5 physiological sighs (double inhale + long exhale). You will feel fully alert within minutes.",
                        minutes: returnMin, isMeditation: false)],
                rationale: "NASA/Rosekind et al. (1995): pilots given ~26-min naps showed 54% higher alertness and near-elimination of microsleeps. Dinges et al.: naps under 20 min avoid slow-wave sleep entry and its 20–30 min inertia window. At \(napMin) minutes you are in the proven sweet spot.",
                category: .cognitiveReset),
            breakMin: breakMin,
            timeOfDayNote: energy == .low
                ? "Your energy is depleted — this nap will have maximum impact right now."
                : "You are in your ultradian rest phase — your brain is signalling it needs this.",
            isEndOfDay: false, energyLevel: energy, cognitiveLoad: .easy)
    }

    // MARK: - NEW: NSDR / Non-Sleep Deep Rest (Kjaer et al. 2002 + Huberman protocol)
    // Yoga Nidra raises endogenous dopamine ~65% (PET imaging, Kjaer 2002).
    // Shifts brain into theta-dominant parasympathetic state. Zero sleep inertia.
    private static func nsdRestBreak(breakMin: Int) -> Decision {
        let practiceMin = max(breakMin - 2, 8)
        let returnMin   = max(breakMin - practiceMin, 1)
        return Decision(
            breakType: .nsdRest,
            headline: "NSDR — Deep Rest",
            goal: "Restore depleted dopamine reserves and shift into theta-wave recovery — the most powerful non-sleep reset available.",
            plan: BreakPlan(
                steps: [
                    BreakStep(
                        icon: "figure.mind.and.body",
                        action: "Lie down or fully recline — close your eyes",
                        instruction: "Find the most horizontal position you can. Let your arms rest heavily at your sides, palms up. Take two slow breaths and consciously let your body become heavy. You are staying awake — this is not a nap.",
                        minutes: 1, isMeditation: true),
                    BreakStep(
                        icon: "person.fill",
                        action: "NSDR body scan — feet to crown, ~20 seconds per area",
                        instruction: "Breathe slowly throughout. Bring complete attention to the soles of your feet — notice sensation without changing anything. Move slowly upward: heels → calves → knees → thighs → hips → lower back → belly (notice it rise and fall) → chest → hands (feel them become heavy) → forearms → upper arms → shoulders (let them drop) → neck → jaw (unclench) → eyes (soften) → forehead (smooth). Spend ~20 seconds on each area. If you lose the thread, return to your breath and continue from where you drifted.",
                        minutes: practiceMin - 1, isMeditation: true),
                    BreakStep(
                        icon: "arrow.up.circle",
                        action: "Emerge slowly — wiggle fingers, three deep breaths",
                        instruction: "Gently wiggle fingers and toes. Take three slow deep breaths. Open your eyes and rest them on something at mid-distance. Allow 30–60 seconds before returning to your screen.",
                        minutes: returnMin, isMeditation: false)],
                rationale: "Kjaer et al. (2002, NeuroReport): PET imaging during Yoga Nidra showed a 65% rise in endogenous dopamine in the ventral striatum — replenishing the motivation depleted by sustained focus. Huberman Lab's NSDR body-scan protocol reproducibly induces this theta-dominant state in 10–20 minutes with zero sleep inertia.",
                category: .meditation),
            breakMin: breakMin,
            timeOfDayNote: "NSDR is most potent when dopamine is genuinely depleted from sustained effort — which it is right now.",
            isEndOfDay: false, energyLevel: .low, cognitiveLoad: .hard)
    }

    // MARK: - NEW: Focused Attention Meditation (Colzato et al. 2012)
    // FA = anchor on breath counting, return when distracted.
    // Best before convergent/analytical tasks. Distinct from OM (creative/divergent).
    private static func focusedAttentionMeditationBreak(breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        if remaining >= 4 {
            steps.append(BreakStep(
                icon: "figure.mind.and.body",
                action: "Sit upright, spine tall — close your eyes",
                instruction: "Sit with your spine naturally upright. Hands on your thighs. Take one deliberate breath to settle. This upright posture supports the attentional precision FA meditation requires.",
                minutes: 1, isMeditation: true))
            remaining -= 1
        }
        let countMin = remaining >= 2 ? remaining - 1 : remaining
        steps.append(BreakStep(
            icon: "1.circle.fill",
            action: "Count each exhale 1→10 — restart every time you drift",
            instruction: "Breathe naturally. On each exhale, count silently: 1… 2… 3… up to 10, then restart. The instant any thought pulls your attention away — even briefly — return to 1. Every return to 1 is the training. Your only goal is to hold the count as the single object in your awareness.",
            minutes: countMin, isMeditation: true))
        remaining -= countMin
        if remaining >= 1 {
            steps.append(BreakStep(
                icon: "scope",
                action: "Hold that narrow focus for 10 seconds with eyes open",
                instruction: "Before doing anything else, hold the precise attentional quality you just trained — eyes open, fixed on a single point — for 10 more seconds. Then re-engage your next task from that focused state.",
                minutes: 1, isMeditation: false))
        }
        return Decision(
            breakType: .focusedAttentionMeditation,
            headline: "Focus Reset",
            goal: "Narrow your attention and clear mental noise — priming the convergent, single-solution thinking your next task demands.",
            plan: BreakPlan(
                steps: steps,
                rationale: "Colzato et al. (2012, Frontiers in Psychology): Focused Attention meditation produces a distinct convergent cognitive control state — best suited before analytical, hard-focus tasks. Open Monitoring meditation is better before creative or generative work.",
                category: .meditation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .medium)
    }

    // MARK: - NEW Tier 2: Morning Sunlight (Czeisler et al. 1986 / Huberman ipRGC protocol)
    // 5–10 min outside within first hour of waking advances circadian phase,
    // boosts cortisol, primes alertness and anchors sleep–wake rhythm.
    // Melanopsin/ipRGC cells maximally sensitive to blue-rich daylight → SCN entrainment.
    private static func morningSunlightBreak(breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        steps.append(BreakStep(
            icon: "sun.horizon.fill",
            action: "Go outside — face toward the sky, no sunglasses",
            instruction: "Step outside within the first hour of waking and face toward the sun or open sky. No sunglasses — the melanopsin cells in your eyes need direct daylight wavelengths to fire. You do not need to stare at the sun; simply face that direction with eyes open and relaxed. Even on an overcast day this is 10–50× more light than indoor lighting.",
            minutes: min(remaining, breakMin >= 10 ? 8 : breakMin),
            isMeditation: false))
        remaining -= steps[0].minutes
        if remaining >= 2 {
            steps.append(BreakStep(
                icon: "figure.walk",
                action: "Walk while you're out — panoramic gaze, no phone",
                instruction: "Walk at a relaxed pace. Use a wide, diffuse gaze — look at the horizon or distant scenery rather than down at the ground. This panoramic vision suppresses amygdala activity (optic flow effect) and compounds the circadian benefit of the sunlight.",
                minutes: remaining,
                isMeditation: false))
        }
        return Decision(
            breakType: .morningSunlight,
            headline: "Morning Light",
            goal: "Anchor your circadian clock, spike morning cortisol, and prime full-day alertness — in \(breakMin) minutes.",
            plan: BreakPlan(
                steps: steps,
                rationale: "Czeisler et al. (1986): bright morning light reliably advances circadian phase by hours. Huberman's ipRGC protocol: 5–10 min of outdoor light within the first hour of waking activates melanopsin retinal ganglion cells, entraining the SCN master clock, boosting cortisol and alertness, and stabilising the entire sleep–wake cycle. Crowley & Eastman confirmed even 30 min of bright light on waking produces robust phase advances.",
                category: .physicalActivation),
            breakMin: breakMin,
            timeOfDayNote: "Morning light is most powerful in the first 1–2 hours after waking. Do this every day for compounding circadian benefits.",
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .easy)
    }

    // MARK: - NEW Tier 2: Caffeine Warning (Walker / Huberman adenosine timing)
    // Caffeine blocks adenosine receptors — it does not clear adenosine.
    // Drinking coffee immediately on waking blunts natural cortisol peak and
    // causes an adenosine rebound crash when caffeine wears off (~6–8 h later).
    // Optimal: delay caffeine 90–120 min after waking.
    private static func caffeineWarningBreak(breakMin: Int, hour: Int) -> Decision {
        let isVeryEarly = hour < 8
        let steps: [BreakStep] = [
            BreakStep(
                icon: "drop.fill",
                action: "Drink a large glass of water — not coffee yet",
                instruction: "Your cortisol is naturally peaking right now. Drinking coffee in the first 90–120 minutes after waking blunts this cortisol spike and does little to increase alertness — but it does mean all the adenosine caffeine blocked will flood your receptors later, causing a crash. Drink water now. Wait until at least 90 minutes after you woke up before your first coffee.",
                minutes: 1,
                isMeditation: false),
            BreakStep(
                icon: "sun.horizon.fill",
                action: isVeryEarly ? "Go outside for natural light — face the sky" : "Stand near a bright window or step outside",
                instruction: isVeryEarly
                    ? "Instead of caffeine, use light as your alertness tool. Step outside and face the sky for 5 minutes. Morning sunlight activates the same wakefulness circuits as caffeine — without the adenosine rebound."
                    : "Move toward the brightest natural light available. Open a window or step outside briefly. Light activates the same wakefulness circuits as caffeine — and stacks with your natural cortisol peak rather than fighting it.",
                minutes: max(breakMin - 1, 1),
                isMeditation: false)
        ]
        return Decision(
            breakType: .caffeineWarning,
            headline: "Skip the Coffee — For Now",
            goal: "Protect your natural cortisol peak and prevent the afternoon adenosine crash.",
            plan: BreakPlan(
                steps: steps,
                rationale: "Walker (Why We Sleep) and Huberman: caffeine blocks adenosine receptors but doesn't clear adenosine. Drinking coffee immediately on waking wastes the alerting benefit (cortisol is already doing that job) and causes an adenosine rebound crash ~6–8 h later when caffeine metabolises. Delaying caffeine 90–120 min after waking maximises its benefit and minimises the crash.",
                category: .cognitiveReset),
            breakMin: breakMin,
            timeOfDayNote: "Save your coffee for 90–120 minutes after waking. Your cortisol is doing the alerting work right now.",
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .easy)
    }

    // MARK: - NEW Tier 2: Cold Water Reset (Shevchuk 2008 — norepinephrine via cold)
    // Brief cold exposure spikes norepinephrine and β-endorphin via sympathetic activation.
    // Shevchuk: even a 20°C shower for 2–3 min produces an "overwhelming" NE surge.
    // Practical shortcut: cold water on face/hands/wrists — achieves a measurable NE bump.
    private static func coldWaterResetBreak(breakMin: Int, doneLoad: CognitiveLoad) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        steps.append(BreakStep(
            icon: "drop.fill",
            action: "Cold water on your face, wrists and back of neck",
            instruction: "Go to a sink and run the cold tap fully. Splash cold water on your face 5–10 times, then hold both wrists under cold running water for 30 seconds, then apply cold water to the back of your neck. The cold triggers a sympathetic nervous system response — spiking norepinephrine — which sharpens alertness and elevates mood within 2–3 minutes. No need for a cold shower; peripheral cold exposure on high-pulse-point areas is sufficient.",
            minutes: min(remaining, 2),
            isMeditation: false))
        remaining -= steps[0].minutes
        if remaining >= 2 {
            steps.append(BreakStep(
                icon: "lungs.fill",
                action: "Three physiological sighs to consolidate the reset",
                instruction: "Double inhale through the nose, long exhale through the mouth. Repeat three times. The cold spiked your norepinephrine — the breathing now activates the parasympathetic system to balance it, leaving you alert but calm rather than anxious.",
                minutes: remaining,
                isMeditation: false))
        }
        return Decision(
            breakType: .coldWaterReset,
            headline: "Cold Reset",
            goal: "Spike norepinephrine and sharpen alertness — without caffeine, in under \(breakMin) minutes.",
            plan: BreakPlan(
                steps: steps,
                rationale: "Shevchuk (2008, Medical Hypotheses): brief cold exposure drastically raises circulating norepinephrine and β-endorphin via sympathetic activation, producing rapid improvements in alertness, mood, and pain tolerance. Cold applied to high-pulse-point areas (face, wrists, neck) achieves a measurable catecholamine surge comparable to a full cold shower.",
                category: .cognitiveReset),
            breakMin: breakMin,
            timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: doneLoad)
    }

    // MARK: - NEW Tier 2: Nature Walk (Kaplan & Kaplan 1989 / Berto 2014 / Huberman optic flow)
    // Combines three evidence streams:
    // 1. ART (Kaplan): natural environments restore directed attention via involuntary engagement
    // 2. Berto 2014: nature > urban for attention/mood restoration
    // 3. Huberman optic flow: panoramic gaze + self-motion suppresses amygdala
    private static func natureWalkBreak(breakMin: Int, nextLoad: CognitiveLoad?,
                                        energy: EnergyLevel) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        if remaining >= 5 {
            steps.append(BreakStep(
                icon: "drop.fill",
                action: "Drink water before you leave",
                instruction: "Drink a full glass of water. Movement dehydrates and even mild dehydration compounds mental fatigue.",
                minutes: 1, isMeditation: false))
            remaining -= 1
        }
        let walkMin = remaining >= 3 ? remaining - 1 : remaining
        steps.append(BreakStep(
            icon: "leaf.fill",
            action: "Walk in nature — wide gaze, no phone, no destination",
            instruction: "Walk outside, ideally near trees, a park, open sky, or any green/blue space. Leave your phone behind or keep it in your pocket with the screen off. Use a wide, panoramic gaze: look at the horizon, trees, sky — not the ground in front of you. This diffuse 'optic flow' gaze while moving through natural scenery activates two powerful recovery mechanisms simultaneously: Attention Restoration (natural environments replenish directed attention) and amygdala downregulation (optic flow suppresses the brain's threat/stress circuits). Do not direct your thoughts. Let your mind wander.",
            minutes: walkMin, isMeditation: false))
        remaining -= walkMin
        if remaining >= 1 {
            steps.append(BreakStep(
                icon: "lungs.fill",
                action: "Three slow breaths before re-entering",
                instruction: "Before going back inside, stop, stand still, and take three slow breaths (inhale 4 counts, exhale 6). This marks the transition back to focused work.",
                minutes: 1, isMeditation: false))
        }
        return Decision(
            breakType: .natureWalk,
            headline: "Nature Walk",
            goal: nextLoad == .hard
                ? "Restore directed attention capacity before deep work — the most evidence-backed pre-focus reset available."
                : "Replenish attention and lower stress through the combined power of natural scenery and movement.",
            plan: BreakPlan(
                steps: steps,
                rationale: "Kaplan & Kaplan (1989) Attention Restoration Theory: natural environments engage involuntary attention, allowing directed attention to recover. Berto (2014): actual nature exposure produces greater attention and mood restoration than urban environments. Huberman: panoramic optic flow during movement suppresses amygdala activity, reducing anxiety. Walking in nature without a phone combines all three mechanisms simultaneously.",
                category: .physicalActivation),
            breakMin: breakMin,
            timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: energy, cognitiveLoad: .easy)
    }

    // MARK: - NEW Tier 3: Goal-Switch Break (Ariga & Lleras 2011, Cognition)
    // Brief task-switch deactivates then reactivates goal representation,
    // preventing the vigilance decrement that continuous work causes.
    // Only 3 switches per hour were sufficient to keep A′ sensitivity flat.
    // The switch must be a *different* cognitive task — passive or ignored breaks fail.
    private static func goalSwitchBreak(breakMin: Int, doneLoad: CognitiveLoad) -> Decision {
        // All content is generated fresh each call — no static strings repeat.
        // Word pool for memory challenge (drawn at random each time)
        let wordPool = ["LANTERN","COPPER","THEORY","BASIN","DRIFT","CINDER","MARGIN",
                        "VESSEL","TIMBER","RIDDLE","COBALT","FLICKER","PRISM","ANCHOR",
                        "MORTAR","CIPHER","FALLOW","KINDLE","TORQUE","SPLINT","CANVAS",
                        "MANTLE","FERRET","COBBLE","RAMBLE","PLINTH","QUARRY","DAGGER"]
        let memWords = Array(wordPool.shuffled().prefix(5))
        let memWordStr = memWords.joined(separator: " — ")

        // Starting word for association sprint (drawn at random)
        let assocStarters = ["OCEAN","STORM","EMBER","BRIDGE","FOREST","MARBLE",
                             "CLOCK","TOWER","CANDLE","MIRROR","RABBIT","ANCHOR"]
        let starter = assocStarters.randomElement() ?? "OCEAN"

        // Arithmetic: pick a random starting number and step
        let startNum  = Int.random(in: 85...120)
        let step      = [6, 7, 8, 9].randomElement()!
        let ex1 = startNum; let ex2 = startNum - step; let ex3 = ex2 - step

        let challenges: [(icon: String, action: String, instruction: String)] = [
            ("brain.head.profile",
             "Memory challenge — 5 words",
             "Read these 5 words once, cover them, then recall them in order: \(memWordStr). Say them aloud. This brief goal-switch deactivates your current task goal and reactivates it on return, resetting attentional sensitivity (Ariga & Lleras 2011)."),
            ("puzzlepiece.fill",
             "Spatial mini-puzzle — fold it mentally",
             "Visualise a square piece of paper. Fold it in half left-to-right, then fold it in half again top-to-bottom. Punch a hole in the bottom-left corner. Unfold it — where are the holes and how many? (Answer: 4 holes, one per quadrant.) This 60-second goal-switch is enough to prevent the vigilance decrement."),
            ("number.circle.fill",
             "Reverse countdown — \(startNum) by \(step)s",
             "Count backwards from \(startNum) in steps of \(step): \(ex1), \(ex2), \(ex3)… Go as far as you can in \(breakMin == 1 ? "30 seconds" : "\(breakMin) minutes"). This arithmetic task fully switches your cognitive goal and prevents habitual suppression of your primary task."),
            ("textformat.abc",
             "Word association sprint from '\(starter)'",
             "Starting with the word \(starter), chain 10 words by association — each new word must relate only to the previous one. \(starter) → ? → ? → … Go for 10 links. The semantic goal-switch and mild engagement are all that's needed to reset attentional sensitivity.")
        ]
        let challenge = challenges.randomElement()!
        return Decision(
            breakType: .goalSwitchBreak,
            headline: "Goal Switch",
            goal: "Reset attentional sensitivity and prevent the vigilance decrement — in \(breakMin == 1 ? "60 seconds" : "\(breakMin) minutes").",
            plan: BreakPlan(
                steps: [BreakStep(
                    icon: challenge.icon,
                    action: challenge.action,
                    instruction: challenge.instruction,
                    minutes: breakMin,
                    isMeditation: false)],
                rationale: "Ariga & Lleras (2011, Cognition): only the group that briefly switched to a different cognitive task (3 times during 40 min) maintained constant attentional sensitivity. All non-switching groups showed significant performance decline. The mechanism: continuous goal activation causes 'goal habituation'; a brief task-switch deactivates and reactivates the goal representation, restoring its signal strength.",
                category: .cognitiveReset),
            breakMin: breakMin,
            timeOfDayNote: "Best used after 10–20 minutes of focused continuous work, before the vigilance decrement sets in.",
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: doneLoad)
    }

    // MARK: - NEW Tier 3: Pleasurable Rest (Van Hooff et al. 2011, Work & Stress)
    // Pleasure of the break activity predicts recovery better than whether it was
    // effortful or restful. Enjoyable breaks replenish resources even if active.
    // Bosch 2018: detachment alone is not sufficient — must also feel in control
    // and do refreshing activities. This break type prioritises genuine enjoyment.
    private static func pleasurableRest(breakMin: Int, energy: EnergyLevel) -> Decision {
        let options: [(icon: String, action: String, instruction: String)] = [
            ("music.note",
             "Listen to music you genuinely love — full attention",
             "Put on a song you truly love — not background music, not a podcast. Sit back, close your eyes, and give it your complete attention for \(breakMin) minutes. No scrolling. Van Hooff (2011): the pleasure of a break activity predicts recovery better than its effort level or type. Genuine enjoyment replenishes emotional resources that sustained work depletes."),
            ("photo.fill",
             "Look at photos or content that makes you happy",
             "Open your camera roll, a favourite account, or a collection that genuinely delights you. Let yourself smile. Don't consume passively — notice what you actually enjoy. This is not wasted time: pleasurable breaks restore affective resources more effectively than neutral rest."),
            ("bubble.left.and.bubble.right.fill",
             "Message someone you enjoy talking to — no work",
             "Send a message to a friend, family member, or anyone whose reply will make you smile. Keep it completely off-work. Trougakos et al. (2014): social breaks reduce fatigue when they are freely chosen and genuinely enjoyable. Don't force it — only do this if it feels good."),
            ("gamecontroller.fill",
             "Play a short game you enjoy — fully commit for \(breakMin) min",
             "Open a simple game you find genuinely fun — even 2 minutes of something enjoyable counts. Don't pick something competitive or stressful. Van Hooff (2011): enjoyable leisure activities restore energy and reduce fatigue regardless of their effort level. The pleasure is the mechanism.")
        ]
        let opt = options[Int.random(in: 0..<options.count)]
        return Decision(
            breakType: .pleasurableRest,
            headline: "Enjoy Your Break",
            goal: "Replenish emotional resources through genuine pleasure — the most reliable recovery mechanism available.",
            plan: BreakPlan(
                steps: [BreakStep(
                    icon: opt.icon,
                    action: opt.action,
                    instruction: opt.instruction,
                    minutes: breakMin,
                    isMeditation: false)],
                rationale: "Van Hooff et al. (2011, Work & Stress): in a diary study of 120 employees, the pleasure of off-job activities — not their effort level or type — was the strongest predictor of daily recovery (lower fatigue, higher vigor). High-pleasure leisure strongly predicted lower fatigue. Bosch et al. (2018): detachment alone had no direct benefit; relaxation and control (autonomy) were the active ingredients. Pleasurable breaks naturally induce detachment while adding positive affect — a dual mechanism.",
                category: .cognitiveReset),
            breakMin: breakMin,
            timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: energy, cognitiveLoad: .easy)
    }

    // MARK: - Plan builders

    private static func microReset(doneLoad: CognitiveLoad, nextLoad: CognitiveLoad?,
                                   energy: EnergyLevel, breakMin: Int) -> Decision {
        let m = max(1, breakMin)
        switch doneLoad {
        case .easy:
            return Decision(
                breakType: .sensoryShift, headline: "Quick Sensory Reset",
                goal: "Shift your nervous system out of task-mode in under \(m) minutes.",
                plan: BreakPlan(
                    steps: [BreakStep(icon: "drop.fill", action: "Drink a full glass of cold water",
                                      instruction: "Stand up, walk to the kitchen and drink a full glass of cold water slowly. The temperature change and brief movement give your brain a fast, clean reset.",
                                      minutes: m)],
                    rationale: "Cold water triggers a mild alerting response — the fastest reset available between easy tasks.",
                    category: .cognitiveReset),
                breakMin: m, timeOfDayNote: nil,
                isEndOfDay: false, energyLevel: energy, cognitiveLoad: doneLoad)
        case .medium:
            let breathMin = min(m, 2)
            let restMin   = m - breathMin
            var steps = [BreakStep(icon: "lungs.fill",
                                   action: "4-7-8 breathing — \(breathMin == 1 ? "once" : "twice")",
                                   instruction: "Inhale for 4 counts, hold for 7, exhale for 8. Repeat \(breathMin == 1 ? "once" : "twice") with your eyes closed.",
                                   minutes: breathMin)]
            if restMin > 0 {
                steps.append(BreakStep(icon: "eye.slash.fill", action: "Eyes closed — do nothing",
                                       instruction: "Keep your eyes closed and focus only on the sounds around you until the time is up.",
                                       minutes: restMin))
            }
            return Decision(
                breakType: .intentionalPause, headline: "Breath Reset",
                goal: "Drop cortisol and clear the mental boundary between tasks in \(m) minutes.",
                plan: BreakPlan(steps: steps,
                                rationale: "4-7-8 breathing activates the parasympathetic nervous system — reducing mental noise faster than any other \(m)-minute technique.",
                                category: .cognitiveReset),
                breakMin: m, timeOfDayNote: nil,
                isEndOfDay: false, energyLevel: energy, cognitiveLoad: doneLoad)
        case .hard:
            return Decision(
                breakType: .cognitiveOffload, headline: "Brain Dump",
                goal: "Empty your working memory in \(m) minutes so hard-task residue doesn't bleed into the break.",
                plan: BreakPlan(
                    steps: [BreakStep(icon: "pencil.and.list.clipboard", action: "Write every open thought on paper",
                                      instruction: "Grab any piece of paper and write every thought, worry, or next step — no organisation, no filtering. Stop when nothing new comes, then put the paper face-down.",
                                      minutes: m)],
                    rationale: "Hard tasks leave open loops in working memory. Writing them out externalises the storage so your brain stops holding them.",
                    category: .cognitiveReset),
                breakMin: m, timeOfDayNote: nil,
                isEndOfDay: false, energyLevel: energy, cognitiveLoad: doneLoad)
        }
    }

    private static func postLunchMovement(breakMin: Int, nextLoad: CognitiveLoad?) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        if remaining >= 5 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink a glass of water",
                                   instruction: "Go to the kitchen and drink a full glass of water before you walk. Dehydration worsens the post-lunch dip significantly.",
                                   minutes: 1)); remaining -= 1
        }
        steps.append(BreakStep(icon: "leaf.fill", action: "Walk outside — wide gaze, no phone",
                               instruction: "Leave your phone behind. Head outside or toward the nearest green/natural space. Use a wide, panoramic gaze — look at the horizon, trees, or sky rather than down at the ground. This optic flow (visual motion from moving through the environment) suppresses amygdala activity and compounds the attention restoration of natural scenery. Natural light also directly resets your circadian rhythm.",
                               minutes: remaining))
        return Decision(
            breakType: .playfulMovement, headline: "Post-Lunch Reset",
            goal: "Counteract the afternoon energy dip with blood flow — not caffeine.",
            plan: BreakPlan(steps: steps,
                            rationale: "The post-lunch cortisol dip peaks around 1–2 PM. Movement is the only thing that reliably reverses it without causing a later crash.",
                            category: .physicalActivation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .medium)
    }

    private static func deepRestoration(breakMin: Int, doneLoad: CognitiveLoad,
                                        nextLoad: CognitiveLoad?) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        if remaining >= 8 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink water before you rest",
                                   instruction: "Get a full glass of water. Dehydration amplifies fatigue — this single step noticeably reduces the depth of your energy dip.",
                                   minutes: 1)); remaining -= 1
            steps.append(BreakStep(icon: "moon.zzz.fill", action: "Leave your desk completely",
                                   instruction: "Go somewhere with no screen and no work context — outside, a different room, or a quiet corner. If thoughts intrude, redirect to what you can physically see or hear.",
                                   minutes: remaining))
        } else {
            steps.append(BreakStep(icon: "eye.slash.fill", action: "Eyes closed — do nothing",
                                   instruction: "Sit back, close your eyes, and focus only on sounds around you. When thoughts arrive, label them 'thinking' and return to listening.",
                                   minutes: remaining))
        }
        return Decision(
            breakType: .trueRest, headline: "Full Disengagement",
            goal: "Your focus reserves are depleted — only genuine rest restores them.",
            plan: BreakPlan(steps: steps,
                            rationale: "Bosch et al. (2018): psychological detachment alone (just 'not thinking about work') had no direct benefit on afternoon recovery. What worked was relaxation combined with a sense of control — activities that naturally produce detachment while replenishing personal resources. Physical distance from your desk and screen is the fastest way to achieve both simultaneously.",
                            category: .cognitiveReset),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .low, cognitiveLoad: doneLoad)
    }

    private static func sensoryShift(nextLoad: CognitiveLoad?, breakMin: Int, isNight: Bool = false) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        let envMin = min(remaining, max(2, remaining / 2))
        steps.append(BreakStep(icon: "lightbulb.fill", action: "Change rooms — look at something distant",
                               instruction: "Walk to a different area with different lighting. Stand for \(envMin) min and look at objects in the distance to reset your visual focus.",
                               minutes: envMin)); remaining -= envMin
        if remaining >= 2 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink water",
                                   instruction: "Drink a full glass of water. Mild dehydration subtly degrades focus even before you feel thirsty.",
                                   minutes: 1)); remaining -= 1
        }
        if remaining >= 2 {
            steps.append(BreakStep(icon: "figure.flexibility", action: "Stretch — shoulders and neck",
                                   instruction: "Roll your shoulders back 10 times, tilt your neck left and right for 5 seconds each, then reach both arms overhead and hold for 10 seconds.",
                                   minutes: remaining))
        } else if remaining == 1 {
            steps.append(BreakStep(icon: "lungs.fill", action: "Three slow deep breaths",
                                   instruction: "Inhale for 4 counts, exhale for 6. Repeat three times with your eyes closed.",
                                   minutes: 1))
        }
        return Decision(
            breakType: .sensoryShift, headline: "Sensory Shift",
            goal: nextLoad == .hard ? "Clear your palate before a demanding task — a brief environment change primes attention."
                                    : "Gently refresh your attention and prevent boredom-driven errors.",
            plan: BreakPlan(steps: steps,
                            rationale: "A physical environment change signals 'mode shift' to your brain. The stretch and hydration ensure you return physically ready, not just mentally reset.",
                            category: .physicalActivation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .high, cognitiveLoad: .easy)
    }

    private static func physicalReset(breakMin: Int, nextLoad: CognitiveLoad?, isNight: Bool = false) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        if remaining >= 4 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink a full glass of water",
                                   instruction: "Go get water before you stretch. Hydration directly affects muscle flexibility and alertness.",
                                   minutes: 1)); remaining -= 1
        }
        let stretchMin = min(remaining, remaining >= 6 ? 4 : remaining)
        steps.append(BreakStep(icon: "figure.flexibility", action: "Full-body stretch sequence",
                               instruction: "Roll shoulders back 10x. Stretch arms overhead 10 sec. Neck tilts left/right/forward 5 sec each. Hip circles 10x each direction. End with 3 slow deep breaths with arms wide.",
                               minutes: stretchMin)); remaining -= stretchMin
        if remaining >= 3 {
            if isNight {
                steps.append(BreakStep(icon: "figure.walk.motion", action: "Walk around your home — no phone",
                                       instruction: "Walk slowly around your home. Keep lights dim. Let your mind wander. No phone, no screens.",
                                       minutes: remaining))
            } else {
                steps.append(BreakStep(icon: "leaf.fill", action: "Walk outside — panoramic gaze, no phone",
                                       instruction: "Go outside toward any natural space — even a street with trees counts. Keep your phone pocketed. Use a wide, diffuse gaze: look at the horizon, sky, or distant trees rather than near objects. This panoramic optic flow suppresses amygdala stress circuits while natural scenery restores directed attention capacity (Kaplan ART / Berto 2014).",
                                       minutes: remaining))
            }
        } else if remaining >= 1 {
            steps.append(BreakStep(icon: "eye.slash.fill", action: "Eyes closed — decompress",
                                   instruction: "Sit or stand with your eyes closed. Listen to ambient sounds and let your thoughts settle.",
                                   minutes: remaining))
        }
        return Decision(
            breakType: .physicalReset, headline: "Physical Reset",
            goal: nextLoad == .hard ? "Blood flow to the prefrontal cortex improves with movement — prime it before deep work."
                                    : "Counteract the physical stagnation that accumulates during long seated sessions.",
            plan: BreakPlan(steps: steps,
                            rationale: "Prolonged sitting compresses the spine and reduces blood flow. This sequence measurably improves alertness and readiness for the next task.",
                            category: .physicalActivation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .easy)
    }

    private static func intentionalPause(nextLoad: CognitiveLoad?, breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        let breathMin = min(remaining, max(2, remaining / 2))
        steps.append(BreakStep(icon: "lungs.fill", action: "Box breathing — \(breathMin * 2) rounds",
                               instruction: "Inhale 4 counts, hold 4, exhale 4, hold 4. That is one round. Do \(breathMin * 2) rounds with eyes closed. No phone until you're done.",
                               minutes: breathMin)); remaining -= breathMin
        if remaining >= 3 {
            steps.append(BreakStep(icon: "figure.flexibility", action: "Gentle neck and shoulder stretch",
                                   instruction: "Slowly tilt your neck left and right (5 sec each), then roll your shoulders backward 10 times. Release tension before the next task.",
                                   minutes: min(remaining, 2))); remaining -= min(remaining, 2)
        }
        if remaining >= 2 && nextLoad == .hard {
            steps.append(BreakStep(icon: "scope", action: "Write your first action for the next task",
                                   instruction: "On paper: 'The very first physical thing I will do is ___.' One sentence only — this eliminates startup friction.",
                                   minutes: remaining))
        } else if remaining >= 1 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink water",
                                   instruction: "Drink a full glass of water. The short walk to get it reinforces the mental break.",
                                   minutes: remaining))
        }
        return Decision(
            breakType: .intentionalPause, headline: "Intentional Pause",
            goal: nextLoad == .hard ? "Quiet your mind before demanding work — entering a hard task with mental noise reduces performance by up to 20%."
                                    : "Create a clean mental boundary between tasks to reduce carry-over errors.",
            plan: BreakPlan(steps: steps,
                            rationale: "Box breathing reduces cortisol and narrows attention. It is the most time-efficient mental reset available — used before high-stakes work.",
                            category: .cognitiveReset),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .medium)
    }

    private static func playfulMovement(breakMin: Int, isNight: Bool = false) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        if remaining >= 5 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink water first",
                                   instruction: "Grab a full glass of water before your walk. Movement dehydrates faster than sitting.",
                                   minutes: 1)); remaining -= 1
        }
        let walkMin = remaining >= 4 ? remaining - 1 : remaining
        if isNight {
            steps.append(BreakStep(icon: "moon.stars.fill", action: "Slow indoor walk — dim lights, no phone",
                                   instruction: "Walk slowly around your home with the lights dimmed. Leave your phone behind. Let your mind decompress at night's pace — no goals, no destination.",
                                   minutes: walkMin))
        } else {
            steps.append(BreakStep(icon: "leaf.fill", action: "Walk — panoramic gaze, no phone, no destination",
                                   instruction: "Leave your phone at your desk. Head outside or toward any natural setting. Use a wide, diffuse gaze — look at the horizon, open sky, or trees rather than down at the ground. Moving through the environment with this panoramic view creates optic flow that suppresses amygdala activity and lowers stress. Natural scenes simultaneously restore your directed attention through involuntary engagement (ART). Let your mind wander freely.",
                                   minutes: walkMin))
        }
        remaining -= walkMin
        if remaining >= 1 {
            steps.append(BreakStep(icon: "lungs.fill", action: "Three slow breaths before you sit back down",
                                   instruction: "Stand still, inhale for 4 counts, exhale for 6. Repeat three times before returning to your desk.",
                                   minutes: 1))
        }
        return Decision(
            breakType: .playfulMovement, headline: "Reactivation Walk",
            goal: "Restore mild cognitive function and lift your mood after sustained medium-effort work.",
            plan: BreakPlan(steps: steps,
                            rationale: "Unstructured, phone-free walking activates the brain's default mode network — the same state behind creative thinking and problem solving.",
                            category: .physicalActivation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .medium)
    }

    private static func cognitiveOffload(nextLoad: CognitiveLoad?, breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        let dumpMin = min(remaining, 4)
        steps.append(BreakStep(icon: "pencil.and.list.clipboard", action: "Write every thought down — unfiltered, on paper",
                               instruction: "Pen and paper only — not your phone. Write every thought, concern, or next step without organising or judging. Keep writing until nothing new comes. Then close the notebook.",
                               minutes: dumpMin)); remaining -= dumpMin
        if remaining >= 3 {
            steps.append(BreakStep(icon: "figure.walk", action: "Walk — leave your phone behind",
                                   instruction: "Walk at whatever pace feels right. Don't listen to anything. Let your mind stay empty after the brain dump.",
                                   minutes: remaining))
        } else if remaining >= 2 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink water",
                                   instruction: "Get a full glass of water. The short walk to get it and the act of drinking give your brain a moment of pure sensory focus.",
                                   minutes: 1)); remaining -= 1
            if remaining >= 1 {
                steps.append(BreakStep(icon: "eye.slash.fill", action: "Eyes closed — do nothing",
                                       instruction: "Sit back and close your eyes for \(remaining) minute\(remaining > 1 ? "s" : ""). Focus on sounds around you.",
                                       minutes: remaining))
            }
        } else if remaining == 1 {
            steps.append(BreakStep(icon: "lungs.fill", action: "Three slow deep breaths",
                                   instruction: "Inhale 4 counts, exhale 6. Repeat three times. Closes the loop after the brain dump.",
                                   minutes: 1))
        }
        return Decision(
            breakType: .cognitiveOffload, headline: "Cognitive Offload",
            goal: nextLoad == .hard ? "Empty your working memory before the next demanding task — you cannot fill a full cup."
                                    : "Release the mental residue of a hard task so you can rest properly.",
            plan: BreakPlan(steps: steps,
                            rationale: "Hard tasks leave multiple open loops in working memory. Writing them externalises the storage — your brain stops trying to hold them.",
                            category: .cognitiveReset),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .hard)
    }

    private static func fullCognitiveReset(breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        let dumpMin = min(remaining, 4)
        steps.append(BreakStep(icon: "pencil.and.list.clipboard", action: "Brain dump on paper",
                               instruction: "Write every open thought unfiltered for \(dumpMin) minutes. No phone. No organising. When nothing new comes, put the paper face-down.",
                               minutes: dumpMin)); remaining -= dumpMin
        if remaining >= 4 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink water",
                                   instruction: "Drink a full glass before your walk.",
                                   minutes: 1)); remaining -= 1
        }
        if remaining >= 2 {
            steps.append(BreakStep(icon: "leaf.fill", action: "Walk outside — no phone, no messages",
                                   instruction: "Walk without your phone. Head toward any natural space. Don't check anything between the brain dump and the walk — the mind needs to stay empty. Use a wide, panoramic gaze: look at the horizon or sky. The combination of optic flow and natural scenery accelerates the attention restoration the brain dump started.",
                                   minutes: remaining))
        } else if remaining == 1 {
            steps.append(BreakStep(icon: "lungs.fill", action: "Three slow deep breaths",
                                   instruction: "Inhale 4 counts, exhale 6. Repeat three times with eyes closed.",
                                   minutes: 1))
        }
        return Decision(
            breakType: .cognitiveOffload, headline: "Offload + Move",
            goal: "First clear your working memory, then use movement to re-oxygenate before the next hard task.",
            plan: BreakPlan(steps: steps,
                            rationale: "Cognitive offloading combined with light movement produces greater working-memory restoration than either alone — confirmed by multiple fatigue studies.",
                            category: .cognitiveReset),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .hard)
    }

    private static func trueRest(breakMin: Int, nextLoad: CognitiveLoad?, isNight: Bool = false) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        if remaining >= 6 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink water first",
                                   instruction: "Get a full glass of water. After a long hard session, hydration is the single fastest physical recovery step.",
                                   minutes: 1)); remaining -= 1
        }
        if nextLoad == .hard {
            if isNight {
                // At night — body scan instead of outdoor walk
                let scanMin = remaining >= 3 ? remaining - 1 : remaining
                steps.append(BreakStep(icon: "person.fill", action: "Body scan — lie back, eyes closed",
                                       instruction: "Lie down or sit back fully. Slowly scan from feet to head, releasing tension in each area. Breathe into any tightness you find. This is the most effective night-time reset for a tired brain.",
                                       minutes: scanMin, isMeditation: true)); remaining -= scanMin
                if remaining >= 1 {
                    steps.append(BreakStep(icon: "scope", action: "Write your first action for the next task",
                                           instruction: "On paper: 'The very first physical thing I will do is ___.' One sentence — eliminates startup friction for the hard task ahead.",
                                           minutes: 1))
                }
            } else {
                let walkMin = remaining >= 4 ? remaining - 2 : remaining
                steps.append(BreakStep(icon: "figure.walk.circle.fill", action: "Walk outside — no phone",
                                       instruction: "Leave your phone at your desk. Walk outside toward any natural space — park, trees, open sky. Use a wide, panoramic gaze: look at the horizon or distant scenery rather than down. Moving through the environment with this diffuse view creates optic flow that suppresses amygdala activity. Natural scenery simultaneously restores directed attention (Kaplan ART). No destination needed.",
                                       minutes: walkMin)); remaining -= walkMin
                if remaining >= 2 {
                    steps.append(BreakStep(icon: "scope", action: "Write your first action for the next task",
                                           instruction: "On paper: 'The very first physical thing I will do is ___.' One sentence — eliminates startup friction for the hard task ahead.",
                                           minutes: remaining))
                } else if remaining == 1 {
                    steps.append(BreakStep(icon: "lungs.fill", action: "Three slow deep breaths",
                                           instruction: "Inhale 4 counts, exhale 6. Repeat three times to prime focus before returning.",
                                           minutes: 1))
                }
            }
        } else {
            let musicMin = remaining >= 4 ? remaining - 1 : remaining
            steps.append(BreakStep(icon: "music.note", action: "Listen to music you love — no multitasking",
                                   instruction: "Put on headphones with music you genuinely enjoy — not a podcast or background noise. Sit back, close your eyes, and just listen. No scrolling.",
                                   minutes: musicMin)); remaining -= musicMin
            if remaining >= 1 {
                steps.append(BreakStep(icon: "figure.flexibility", action: "Gentle stretch",
                                       instruction: "While the music finishes, do slow shoulder rolls and a neck stretch to release the physical tension from the long session.",
                                       minutes: 1))
            }
        }
        return Decision(
            breakType: .trueRest, headline: "True Rest",
            goal: "Fully disengage to replenish cognitive resources that sustained hard focus has depleted.",
            plan: BreakPlan(
                steps: steps,
                rationale: nextLoad == .hard
                    ? "After a long hard session, only genuine disengagement fully resets the prefrontal cortex for another demanding task."
                    : "Long high-intensity sessions deplete dopamine and working memory. Music without multitasking is one of the few passive activities that genuinely restores both.",
                category: .cognitiveReset),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .low, cognitiveLoad: .hard)
    }

    private static func primeForHard(breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        let writeMin = min(remaining, 2)
        steps.append(BreakStep(icon: "scope", action: "Write the first action of your next task",
                               instruction: "Complete this sentence on paper: 'The very first physical thing I will do on my next task is ___.' One sentence. Make it concrete and specific.",
                               minutes: writeMin)); remaining -= writeMin
        if remaining >= 2 {
            let breathMin = min(remaining, 3)
            steps.append(BreakStep(icon: "lungs.fill", action: "Box breathing to lock in focus",
                                   instruction: "Inhale 4 counts, hold 4, exhale 4, hold 4. That is one round. Do \(breathMin * 2) rounds with eyes closed.",
                                   minutes: breathMin)); remaining -= breathMin
        }
        if remaining >= 2 {
            steps.append(BreakStep(icon: "drop.fill", action: "Drink water",
                                   instruction: "Drink a full glass of water. Optimal hydration improves working memory capacity measurably.",
                                   minutes: 1)); remaining -= 1
        }
        if remaining >= 2 {
            steps.append(BreakStep(icon: "figure.flexibility", action: "Quick stretch — stand and move",
                                   instruction: "Roll shoulders back 10x, stretch arms overhead, neck tilts left and right. Return to your desk ready.",
                                   minutes: remaining))
        } else if remaining == 1 {
            steps.append(BreakStep(icon: "eye.slash.fill", action: "One final minute — eyes closed",
                                   instruction: "Close your eyes and visualise the first 5 minutes of your next task going smoothly.",
                                   minutes: 1))
        }
        return Decision(
            breakType: .intentionalPause, headline: "Focus Primer",
            goal: "Deliberately prime your brain for the hard task coming next — don't just passively wait for it to start.",
            plan: BreakPlan(steps: steps,
                            rationale: "Specifying the first concrete action eliminates the startup cost of hard tasks and reduces the anxiety that causes procrastination when they begin.",
                            category: .cognitiveReset),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .medium)
    }

    // MARK: - Snack reminder break (triggered when user is hungry)
    private static func snackReminderBreak(breakMin: Int, isNight: Bool) -> Decision {
        var steps: [BreakStep] = []
        var remaining = breakMin
        steps.append(BreakStep(
            icon: "fork.knife",
            action: "Grab a snack or a proper meal",
            instruction: "It has been over 4 hours since you last ate. Low blood sugar directly hurts focus and mood. Step away from the screen, eat something real, and give your body a few minutes to absorb it.",
            minutes: min(remaining, 8)
        ))
        remaining -= steps[0].minutes
        if remaining >= 2 {
            steps.append(BreakStep(
                icon: "drop.fill",
                action: "Drink a full glass of water",
                instruction: "Pair your snack with water. Even mild dehydration degrades concentration by up to 20%.",
                minutes: min(remaining, 2)
            ))
            remaining -= steps[1].minutes
        }
        if remaining >= 2 && !isNight {
            steps.append(BreakStep(
                icon: "figure.walk",
                action: "Short walk while eating if you can",
                instruction: "Even 2 minutes of movement post-meal improves glucose regulation and helps you return to focus faster.",
                minutes: remaining
            ))
        } else if remaining >= 2 {
            steps.append(BreakStep(
                icon: "moon.stars.fill",
                action: "Slow down, no screens",
                instruction: "Eat without looking at your phone or screen. Let your nervous system actually register the break.",
                minutes: remaining
            ))
        }
        return Decision(
            breakType: .trueRest,
            headline: "Time to eat 🍽️",
            goal: "Your body is signalling low fuel. Step away, eat something, and return energised.",
            plan: BreakPlan(steps: steps, rationale: "Blood sugar management", category: .cognitiveReset),
            breakMin: breakMin,
            timeOfDayNote: isNight ? "Keep it light this late in the evening." : nil,
            isEndOfDay: false,
            energyLevel: .low,
            cognitiveLoad: .medium
        )
    }

    private static func switchRitual(energy: EnergyLevel, breakMin: Int, hour: Int = 18) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        let isNight = hour >= 21 || hour < 6
        if energy == .low {
            if remaining >= 6 {
                steps.append(BreakStep(icon: "cup.and.saucer.fill", action: "Brew a warm caffeine-free drink",
                                       instruction: "Make a herbal tea or warm water with lemon. The ritual of brewing signals 'work is done' to your nervous system.",
                                       minutes: min(remaining, 5))); remaining -= min(remaining, 5)
            }
            if remaining >= 2 {
                steps.append(BreakStep(icon: "list.bullet", action: "Write tomorrow's 3 most important tasks",
                                       instruction: "On paper, write the 3 most important things to do tomorrow — nothing more. Then close all work apps and put your phone face-down.",
                                       minutes: remaining))
            } else if remaining >= 1 {
                steps.append(BreakStep(icon: "moon.stars.fill", action: "Close all work apps",
                                       instruction: "Close every work app and notification source. Physically putting the phone face-down reinforces the boundary.",
                                       minutes: 1))
            }
        } else {
            let walkMin = remaining >= 5 ? remaining - 3 : remaining - 1
            if walkMin >= 1 {
                if isNight {
                    steps.append(BreakStep(icon: "moon.stars.fill", action: "Slow walk indoors — dim the lights",
                                           instruction: "Walk slowly around your home with the lights low. Leave your phone at your desk. Breathe slowly and let the day settle.",
                                           minutes: walkMin))
                } else {
                    steps.append(BreakStep(icon: "figure.walk", action: "Walk outside — no phone",
                                           instruction: "Leave your phone at your desk. Walk outside for \(walkMin) minutes. Feel the air. You don't need to think about anything.",
                                           minutes: walkMin))
                }
                remaining -= walkMin
            }
            if remaining >= 2 {
                steps.append(BreakStep(icon: "list.bullet", action: "Write tomorrow's 3 most important tasks",
                                       instruction: "On paper, write the 3 most important things to do tomorrow. Then close all work apps.",
                                       minutes: remaining - 1)); remaining = 1
            }
            if remaining >= 1 {
                steps.append(BreakStep(icon: "moon.stars.fill", action: "Close all work apps",
                                       instruction: "Close every work app. Put your phone face-down. The workday is over.",
                                       minutes: 1))
            }
        }
        return Decision(
            breakType: .switchRitual, headline: "Wind-Down Ritual",
            goal: "Signal to your body and mind that the workday is genuinely over — not just paused.",
            plan: BreakPlan(steps: steps,
                            rationale: "A consistent end-of-day ritual anchors the psychological transition out of work mode — which improves sleep quality and next-day focus.",
                            category: .cognitiveReset),
            breakMin: breakMin,
            timeOfDayNote: "This is your last break of the day. The goal is recovery from work, not recovery for more work.",
            isEndOfDay: true, energyLevel: energy, cognitiveLoad: .easy)
    }

    // MARK: - Meditation builders

    private static func breathingMeditation(breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        if remaining >= 4 {
            steps.append(BreakStep(icon: "figure.mind.and.body", action: "Sit comfortably and close your eyes",
                                   instruction: "Find a comfortable position. Rest your hands on your thighs. Take one slow breath to settle, letting your shoulders drop.",
                                   minutes: 1, isMeditation: true)); remaining -= 1
        }
        let meditateMin = remaining >= 2 ? remaining - 1 : remaining
        steps.append(BreakStep(icon: "lungs.fill", action: "Follow your breath — count each exhale",
                               instruction: "Breathe naturally. On each exhale, silently count: 1, 2, 3 up to 10, then restart. When your mind wanders, gently return to 1. Keep your jaw and forehead soft.",
                               minutes: meditateMin, isMeditation: true)); remaining -= meditateMin
        if remaining >= 1 {
            steps.append(BreakStep(icon: "sparkles", action: "Slowly open your eyes and notice the room",
                                   instruction: "Before reaching for your phone, take 3 slow blinks and look around the room for 30 seconds. This anchors you back before re-engaging.",
                                   minutes: 1, isMeditation: false))
        }
        return Decision(
            breakType: .breathingMeditation, headline: "Breathing Meditation",
            goal: "Reduce cognitive noise and restore calm attention through structured breath awareness.",
            plan: BreakPlan(steps: steps,
                            rationale: "Even a 3-minute breath-counting meditation measurably improves attention, mood, and emotional regulation — with effects lasting 30-40 minutes after the session.",
                            category: .meditation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .medium)
    }

    private static func bodyScanMeditation(breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        steps.append(BreakStep(icon: "figure.mind.and.body", action: "Lie down or sit back — close your eyes",
                               instruction: "If you can lie down, do it. Otherwise sit back fully in your chair. Let your arms rest heavily. Take two deep breaths and let your body go limp.",
                               minutes: 1, isMeditation: true)); remaining -= 1
        let scanMin = remaining >= 2 ? remaining - 1 : remaining
        steps.append(BreakStep(icon: "person.fill", action: "Scan your body from feet to head — feel, don't fix",
                               instruction: "Start at the soles of your feet. Notice any sensation — warmth, tingling, tension, or nothing. Move slowly upward: calves, knees, thighs, hips, belly, chest, hands, shoulders, neck, face. Spend equal time on each area. When you find tension, breathe into it once and move on.",
                               minutes: scanMin, isMeditation: true)); remaining -= scanMin
        if remaining >= 1 {
            steps.append(BreakStep(icon: "arrow.up.circle", action: "Wiggle fingers and toes — return slowly",
                                   instruction: "Gently wiggle your fingers and toes. Take a deep breath. Open your eyes slowly and look at something in the middle distance before returning to work.",
                                   minutes: 1, isMeditation: false))
        }
        return Decision(
            breakType: .bodyScan, headline: "Body Scan",
            goal: "Release accumulated physical tension and restore deep calm after sustained mental effort.",
            plan: BreakPlan(steps: steps,
                            rationale: "Body scan meditation activates the parasympathetic nervous system and reduces muscle tension that builds unnoticed during focus sessions. Research shows it improves subsequent cognitive performance more than passive rest.",
                            category: .meditation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .low, cognitiveLoad: .hard)
    }

    private static func openAwarenessMeditation(breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        steps.append(BreakStep(icon: "figure.mind.and.body", action: "Sit upright, eyes soft or closed",
                               instruction: "Sit in a natural upright posture — not rigid, not slouched. You can leave your eyes slightly open with a soft downward gaze, or close them.",
                               minutes: 1, isMeditation: true)); remaining -= 1
        let awarenessMin = remaining >= 2 ? remaining - 1 : remaining
        steps.append(BreakStep(icon: "eye", action: "Notice whatever arises — thoughts, sounds, sensations",
                               instruction: "Allow your attention to rest open without focusing on anything in particular. When a thought, sound, or feeling arises, simply notice it without following it or pushing it away. No effort needed.",
                               minutes: awarenessMin, isMeditation: true)); remaining -= awarenessMin
        if remaining >= 1 {
            steps.append(BreakStep(icon: "sparkles", action: "Take one deep breath and re-enter",
                                   instruction: "One slow inhale, one full exhale. Notice how you feel. Return to work with the same open, unhurried quality of attention.",
                                   minutes: 1, isMeditation: false))
        }
        return Decision(
            breakType: .openAwareness, headline: "Open Awareness",
            goal: "Let the mind rest without direction — restoring the broad, creative attention that focused work depletes.",
            plan: BreakPlan(steps: steps,
                            rationale: "Open monitoring meditation activates the brain's default mode network more effectively than focused attention practices. This restores the broad associative thinking needed for creative and strategic work.",
                            category: .meditation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .medium)
    }

    private static func relaxationAudio(breakMin: Int) -> Decision {
        var steps: [BreakStep] = []; var remaining = breakMin
        let frequencies: [(hz: String, icon: String, instruction: String)] = [
            ("432 Hz", "waveform",
             "Search '432 Hz relaxing' on YouTube or a music app. Put on headphones. Sit back with your eyes closed. Let the tone wash over you — no analysing, just listening."),
            ("528 Hz", "waveform.path",
             "Search '528 Hz calm' on YouTube or a music app. Put on headphones. Close your eyes and breathe naturally. Allow the sound to be your only point of awareness."),
            ("Alpha waves", "dot.radiowaves.left.and.right",
             "Search 'alpha wave music 10Hz' on YouTube or a music app. Put on headphones at a comfortable volume. Breathe slowly. Alpha-wave entrainment works best when you remain still and passive."),
        ]
        let freq = frequencies[Int.random(in: 0..<frequencies.count)]
        steps.append(BreakStep(icon: "headphones", action: "Put on headphones and find \(freq.hz) audio",
                               instruction: freq.instruction,
                               minutes: 1, isMeditation: true)); remaining -= 1
        let listenMin = remaining >= 2 ? remaining - 1 : remaining
        steps.append(BreakStep(icon: freq.icon, action: "Listen fully — eyes closed, no phone",
                               instruction: "Stay still. Breathe naturally. If thoughts arise, return attention to the sound. This is not background music — give it your full passive attention.",
                               minutes: listenMin, isMeditation: true)); remaining -= listenMin
        if remaining >= 1 {
            steps.append(BreakStep(icon: "arrow.up.circle", action: "Remove headphones — sit quietly for 30 seconds",
                                   instruction: "Take the headphones off and sit in the ambient silence for 30 seconds before opening any app. Let the transition be gradual.",
                                   minutes: 1, isMeditation: false))
        }
        return Decision(
            breakType: .relaxationAudio, headline: "\(freq.hz) Relaxation",
            goal: "Use acoustic relaxation to restore calm and reduce stress hormones after intense work.",
            plan: BreakPlan(steps: steps,
                            rationale: "Binaural and tonal audio in the alpha range promotes relaxation and reduces cortisol. Studies show 10-15 minutes of passive acoustic stimulation produces measurable reductions in self-reported stress and improved subsequent focus.",
                            category: .meditation),
            breakMin: breakMin, timeOfDayNote: nil,
            isEndOfDay: false, energyLevel: .medium, cognitiveLoad: .medium)
    }

    // MARK: - Cognitive Load Inference
    static func inferCognitiveLoad(task: FocusTask, taskStore: TaskStore?) -> CognitiveLoad {
        let title = task.title.lowercased()
        let words = title.components(separatedBy: CharacterSet.whitespacesAndNewlines
            .union(.punctuationCharacters)).filter { !$0.isEmpty }
        var score = 0.0
        let hardVerbs   = ["analyze","design","architect","strategize","build","develop",
                           "create","write","research","solve","plan","structure",
                           "negotiate","present","pitch","evaluate","draft","formulate",
                           "implement","debug","refactor","model","forecast"]
        let mediumVerbs = ["prepare","review","update","edit","compile","organize",
                           "compare","summarize","track","follow","coordinate",
                           "schedule","arrange","process","check","respond","handle"]
        let easyVerbs   = ["send","call","email","log","file","forward","confirm",
                           "acknowledge","skim","browse","scan","sort","tag","mark","label"]
        for w in words {
            if hardVerbs.contains(w)   { score += 2.5 }
            if mediumVerbs.contains(w) { score += 1.2 }
            if easyVerbs.contains(w)   { score += 0.4 }
        }
        let hardObjects   = ["strategy","proposal","presentation","architecture","framework",
                             "database","schema","algorithm","contract","negotiation",
                             "analysis","forecast","model","system","pipeline","report",
                             "campaign","brief","script","code","feature","redesign"]
        let mediumObjects = ["document","spreadsheet","email","message","summary","list",
                             "agenda","meeting","data","feedback","notes",
                             "calendar","schedule","template","offer","quote","invoice"]
        let easyObjects   = ["inbox","inquiries","messages","notifications","replies",
                             "updates","tickets","requests","approvals","forms",
                             "checklist","voicemail","calls","dials"]
        for w in words {
            if hardObjects.contains(w)   { score += 2.0 }
            if mediumObjects.contains(w) { score += 1.0 }
            if easyObjects.contains(w)   { score += 0.3 }
        }
        let easyPatterns   = ["go through","catch up","check on","look into","follow up",
                              "get back to","reply to","respond to","all inquiries",
                              "all messages","all emails","all calls","touch base",
                              "check in with","quick call","brief call","update the",
                              "log the","fill in","fill out","submit the","send the","forward the"]
        let mediumPatterns = ["prepare for","get ready for","set up","put together",
                              "review the","go over","walk through","run through",
                              "compare the","check the numbers","update report",
                              "weekly review","monthly review","team meeting",
                              "client meeting","sync with","align on"]
        let hardPatterns   = ["build the","create the","write the","design the",
                              "solve the","figure out","work out how","come up with",
                              "deep dive","complete the","finish the","close the",
                              "quarterly","annual","strategic","from scratch",
                              "full","entire","overhaul","rework","rewrite"]
        for p in easyPatterns   where title.contains(p) { score += 0.5 }
        for p in mediumPatterns where title.contains(p) { score += 1.2 }
        for p in hardPatterns   where title.contains(p) { score += 2.0 }
        let heavyScope = ["all","entire","complete","full","every","whole",
                          "comprehensive","detailed","in-depth","thorough"]
        let lightScope = ["quick","brief","short","fast","simple",
                          "just","only","small","minor","basic"]
        for w in words {
            if heavyScope.contains(w) { score += 1.0 }
            if lightScope.contains(w) { score -= 0.8 }
        }
        let focusSec = task.focusPlan.blocks.filter { $0.type == .focus }.reduce(0) { $0 + $1.duration }
        if focusSec >= 75 * 60      { score += 1.5 }
        else if focusSec >= 45 * 60 { score += 0.8 }
        else if focusSec <= 20 * 60 { score -= 0.5 }
        if score < 3.0 { return .easy }
        if score < 6.0 { return .medium }
        return .hard
    }

    // MARK: - Private helpers
    private enum SessionLen { case short, medium, long }
    private enum TimeOfDay  { case morning, earlyAfternoon, lateAfternoon, evening, night }

    private static func classifyTimeOfDay(hour: Int) -> TimeOfDay {
        switch hour {
        case 6..<12:  return .morning
        case 12..<15: return .earlyAfternoon
        case 15..<18: return .lateAfternoon
        case 18..<22: return .evening
        default:      return .night
        }
    }

    private static func assessEnergy(focusedMinutes: Int, load: CognitiveLoad, hour: Int) -> EnergyLevel {
        // Start at 8 (medium baseline). Add upward bonus for early, fresh sessions.
        // Subtract for accumulated focus, heavy load, afternoon dip, and night hours.
        var s = 8
        // Upward bonus — early hour with little focus yet → genuinely high energy
        if hour >= 6 && hour < 11 && focusedMinutes < 30 { s += 3 }
        else if hour >= 6 && hour < 13 && focusedMinutes < 60 { s += 1 }
        // Downward — accumulated focus load
        if focusedMinutes >= 180 { s -= 3 } else if focusedMinutes >= 120 { s -= 2 } else if focusedMinutes >= 60 { s -= 1 }
        // Downward — task cognitive load
        if load == .hard { s -= 2 } else if load == .medium { s -= 1 }
        // Downward — afternoon dip window
        if hour >= 13 && hour <= 15 { s -= 1 }
        // Downward — late evening
        if hour >= 20 { s -= 2 }
        // .high requires s ≥ 10, .medium s ≥ 7, else .low
        return s >= 10 ? .high : s >= 7 ? .medium : .low
    }

    private static func totalFocusToday(taskStore: TaskStore?) -> Int {
        guard let store = taskStore else { return 0 }
        let today = Calendar.current.startOfDay(for: Date())
        return store.sessionLogs
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: today) && $0.exitReason == .completed }
            .reduce(0) { $0 + Int($1.endDate.timeIntervalSince($1.startDate)) } / 60
    }

    private static func findNextTask(after completedTask: FocusTask, in taskStore: TaskStore?) -> FocusTask? {
        guard let store = taskStore else { return nil }
        let now = Date()
        return store.tasks
            .filter { $0.status == .pending && $0.id != completedTask.id }
            .sorted { ($0.scheduledTime ?? $0.startDate) < ($1.scheduledTime ?? $1.startDate) }
            .first { ($0.scheduledTime ?? $0.startDate) >= now }
    }

    /// Returns a compact date string used as part of UserDefaults keys for once-per-day guards.
    private static func todayDateKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Break Category Memory
// Persists the most recently shown break category so the engine can avoid
// repeating it even when a new FocusSessionEngine is created for the next task.

struct BreakCategoryMemory {

    private static let categoryKey = "bse_last_category"
    private static let dateKey     = "bse_last_category_date"

    /// The last category that was shown, if it was recorded today.
    static var lastCategoryToday: BreakSuggestionEngine.BreakCategory? {
        let today = todayKey()
        guard UserDefaults.standard.string(forKey: dateKey) == today,
              let raw = UserDefaults.standard.string(forKey: categoryKey)
        else { return nil }
        return BreakSuggestionEngine.BreakCategory(rawValue: raw)
    }

    /// Record that a break of the given category was just shown.
    static func record(_ category: BreakSuggestionEngine.BreakCategory) {
        UserDefaults.standard.set(category.rawValue, forKey: categoryKey)
        UserDefaults.standard.set(todayKey(),        forKey: dateKey)
    }

    private static func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

