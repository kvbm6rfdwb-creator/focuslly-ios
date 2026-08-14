import Foundation

// MARK: - AI Question Generation Service

final class VisionAIService: @unchecked Sendable {
    nonisolated static let shared = VisionAIService()
    
    // MARK: - Initial Questions (Pre-built)
    
    /// Internal question data tuple — text, timeframe (years), MCQ options, question type.
    private typealias Q = (text: String, timeframe: Int, options: [String], type: QuestionType)

    nonisolated func getInitialQuestions(for categoryId: UUID, categoryName: String) -> [VisionQuestion] {
        let allQuestions = generateComprehensiveQuestions(for: categoryName)
        return allQuestions.map { q in
            VisionQuestion(
                categoryId: categoryId,
                questionText: q.text,
                timeframeYears: q.timeframe,
                isAiGenerated: false,
                answerOptions: q.options.isEmpty ? nil : q.options + ["Other — write my own"],
                questionType: q.type
            )
        }
    }

    private func generateComprehensiveQuestions(for categoryName: String) -> [Q] {
        switch categoryName {
        case "Cars":          return generateCarsQuestions()
        case "Houses":        return generateHousesQuestions()
        case "Career":        return generateCareerQuestions()
        case "Health":        return generateHealthQuestions()
        case "Relationships": return generateRelationshipsQuestions()
        case "Finances":      return generateFinancesQuestions()
        case "Travel":        return generateTravelQuestions()
        case "Learning":      return generateLearningQuestions()
        default:              return generateGenericQuestions(for: categoryName)
        }
    }
    
    // MARK: - Category-Specific Question Generators

    private func generateCarsQuestions() -> [Q] {
        return [
            // ── North Star ────────────────────────────────────────────────────────
            ("What is the single car that, in your mind, represents where you're headed in life?", 5,
             ["a sleek luxury sedan", "a powerful sports car", "a fully electric vehicle", "a spacious family SUV", "an open-top convertible", "a capable luxury truck", "something rare and bespoke"], .northStar),
            ("Describe the exact moment you first sit in your dream car — what do you see, feel, and hear?", 5, ["The smell of leather and the hum of the engine makes everything feel earned", "I feel a sense of calm — like I finally made it", "I grip the wheel and think 'this is exactly who I am now'", "I call someone I love just to share the moment"], .vivid),
            // ── Why Now ───────────────────────────────────────────────────────────
            ("Why does having this car matter to you in the next 3–5 years specifically, not later?", 5, ["I'm at a point in my life where I want my surroundings to match my ambition", "I've been delaying things for myself and this is where that stops", "It will mark a clear turning point — before and after", "My income is reaching the level where this is the right next step"], .whyNow),
            ("What changes in your life right now make this the right time to pursue this car goal?", 5,
             ["my income is growing and this feels achievable", "I want it to reflect who I'm becoming", "I've delayed this long enough and I'm ready", "it will support a specific lifestyle shift I'm making"], .whyNow),
            // ── Identity ─────────────────────────────────────────────────────────
            ("What kind of person owns a car like this, and how are you becoming that person?", 5, ["Someone who earns well and isn't apologetic about enjoying it", "A person with taste who values craft and detail", "Someone who worked hard and chose to reward themselves properly", "A driven professional who uses symbols to reinforce their standards"], .identity),
            ("In your life where you own this car, how do you describe yourself to someone new?", 5,
             ["someone who made it and doesn't apologise for it", "a person who values craftsmanship and detail", "someone who loves the freedom of the road", "a professional who invests in what matters", "a collector with a genuine passion for cars"], .identity),
            // ── Observable Evidence ───────────────────────────────────────────────
            ("What would someone you respect see that proves you've achieved this car goal?", 5, ["They see me pull up in it — that's the moment", "My lifestyle overall reflects the level the car represents", "My finances are solid enough that the car didn't stretch me", "I talk about it with pride, not stress"], .observable),
            ("What specific metric tells you this goal is on track — a savings number, a date, a first test drive?", 5, ["A dedicated savings account hitting a specific target", "A test drive booked — even if I can't buy yet", "My monthly income consistently covering the payment comfortably", "A finance pre-approval in hand"], .measurable),
            // ── Constraint ───────────────────────────────────────────────────────
            ("What are you ruling out in order to focus on this goal?", 5,
             ["buying a cheaper car 'for now' that delays the real one", "spending on things that don't move me toward it", "upgrading other things before this is sorted", "keeping a car that no longer reflects who I am"], .constraint),
            // ── Tradeoff ─────────────────────────────────────────────────────────
            ("What will you say no to so this car becomes a reality?", 5, ["Impulse purchases and lifestyle inflation on things that don't matter to me", "Upgrading other things before this is sorted", "Settling for 'good enough' in my income when I can grow it", "Delaying one more year 'until the time is right'"], .tradeoff),
            // ── Milestone Ladder ─────────────────────────────────────────────────
            ("What must be true 12 months from now for this car goal to stay on track?", 5,
             ["I've test driven it at least once", "I have a clear savings plan and am on it", "I've decided exactly which model and spec I want", "I've sorted the financing or purchase structure"], .milestone),
            ("What's the first concrete step you can take in the next 30 days toward this?", 5, ["Research the exact spec and get a real price figure", "Open a dedicated savings account and set up an automatic transfer", "Book a test drive to make it feel real", "Talk to a finance broker about the best structure"], .structured),
            // ── Pre-mortem ────────────────────────────────────────────────────────
            ("What is the most likely thing that derails this goal, and what is your prevention plan?", 5, ["Lifestyle creep eating my savings — I'll automate savings before spending", "A financial emergency — I'll build a buffer so this doesn't get raided", "Losing motivation over time — I'll keep the vision visible daily", "Changing my mind about the model — I'll decide now and commit"], .premortem),
            // ── Values → Behaviour ───────────────────────────────────────────────
            ("How will owning this car change how you behave on a random Tuesday?", 5,
             ["I'll drive to work feeling sharp and confident", "I'll take the long way home because I enjoy it", "I'll be more intentional about where and how I show up", "I'll appreciate craftsmanship in everything I own"], .valueBehavior),
            // ── Decision Rule ─────────────────────────────────────────────────────
            ("What rule will guide you when choosing between two cars at a similar price?", 5, ["The one I'd still be excited about in five years wins", "The one with lower total cost of ownership", "The one that better reflects who I'm becoming, not who I was", "The one I'd be proudest to own, not just drive"], .decisionRule),
            // ── Qualitative Signal ────────────────────────────────────────────────
            ("If you can't measure progress with a number, what feeling or situation tells you you're on track?", 5,
             ["I stop looking at other cars with envy", "I know exactly what I want and feel patient", "conversations about the car excite rather than stress me", "my financial plan has a clear line item for it"], .qualitative),
            // ── Environment Design ────────────────────────────────────────────────
            ("What will you change in your surroundings to make this goal easier to achieve?", 5,
             ["follow creators and communities around this car", "put a photo of it somewhere I see daily", "restructure my budget so the savings happen automatically", "spend time with people who have already achieved this"], .environment),
            // ── Support Network ───────────────────────────────────────────────────
            ("Who in your life can support this goal, and what specifically will you ask them for?", 5, ["A financially savvy friend — I'll ask for honest feedback on my plan", "A mentor who's already achieved this level — I'll ask how they approached it", "My partner — I'll ask them to be patient with the savings period", "A car community — I'll ask for real ownership insights before buying"], .support),
            // ── Counterfactual ────────────────────────────────────────────────────
            ("If you do nothing about this car goal for 12 months, what gets worse in your life?", 5, ["I keep driving something that doesn't reflect where I am anymore", "The gap between my ambitions and my surroundings stays embarrassing", "The cost of the car keeps rising while I wait", "I prove to myself that I can't follow through on big personal goals"], .counterfactual),
            // ── Discovery ─────────────────────────────────────────────────────────
            ("What role does this car play in your life — daily driver, weekend escape, or statement piece?", 5,
             ["my main car for everyday life", "a weekend and special occasion car", "a statement about where I've arrived", "a weekend escape from routine", "part of a growing collection"], .discovery),
            ("What's your preferred ownership model?", 5,
             ["own it outright with no payment", "finance it with a smart structure", "lease and upgrade every 2–3 years", "a subscription or sharing model"], .discovery),
            ("What category of car fits your life best?", 5,
             ["a performance sports car", "a luxury executive sedan", "an electric vehicle", "a luxury SUV", "a convertible or roadster", "a high-performance truck", "a supercar"], .discovery),
            ("Electric, hybrid, or combustion — what do you want to drive?", 5,
             ["fully electric", "plug-in hybrid for range flexibility", "traditional combustion for the experience", "hybrid for efficiency", "flexible, depends on the car"], .discovery),
            ("How soon are you aiming to have this car?", 5,
             ["within the next 12 months", "within 2–3 years", "within 5 years", "it's a long-term aspiration beyond 5 years"], .milestone),
            ("What's the honest budget range you're working toward?", 5,
             ["under $40k", "$40k–$70k", "$70k–$120k", "$120k–$250k", "over $250k"], .measurable),
            ("Brand matters to you — which one?", 5,
             ["BMW", "Mercedes-Benz", "Porsche", "Audi", "Ferrari", "Lamborghini", "Tesla", "Range Rover", "Rolls-Royce", "McLaren"], .discovery),
            ("What colour and finish best represents you?", 5,
             ["matte black — understated and sharp", "gloss white — clean and confident", "a deep metallic — refined and unique", "red — bold and unapologetic", "a custom bespoke colour that no one else has"], .discovery),
            ("Interior — what material and feel do you want?", 5,
             ["full leather in a dark, rich tone", "light leather for an airy, premium feel", "Alcantara for a performance edge", "sustainable materials done beautifully", "fully bespoke interior I designed"], .discovery),
            ("What technology inside the car is non-negotiable for you?", 5,
             ["the best sound system available", "a large seamless display with full integration", "driver assistance and safety tech", "a heads-up display", "track-ready performance tech"], .discovery),
            ("Single car or building a collection over time?", 10,
             ["one perfect car that does everything I need", "a daily driver plus a weekend car", "a growing collection with different personalities", "an evolving fleet that changes with my life"], .discovery),
            ("How do you want your car to make other people feel when they see it?", 5,
             ["impressed by the achievement it represents", "curious about who I am", "inspired to pursue their own goals", "comfortable — I'm not trying to show off"], .identity),
            ("On a scale of purpose, how do you see this car?", 5,
             ["pure performance — I want to feel the machine", "pure luxury — I want to be transported in comfort", "a balance of both that does neither poorly", "a tool that looks exceptional while being practical"], .discovery),
            ("What would a trusted friend who knows you well say about this car goal?", 5,
             ["'That is exactly the car for you'", "'Bold choice — I love it'", "'It makes total sense given where you're heading'", "'I'd be surprised if you didn't end up with that'"], .identity),
        ]
    }

    private func generateHousesQuestions() -> [Q] {
        return [
            // ── North Star ────────────────────────────────────────────────────────
            ("Describe the home you are building toward — not just features, but the feeling it gives you every day.", 5, ["It feels like a sanctuary — calm, spacious, and completely mine", "It energises me — every room is designed for how I actually live", "It feels like I've truly arrived — it matches who I've become", "It gives me pride every time I walk through the door"], .northStar),
            ("If you could only keep one thing about your ideal home, what would it be and why?", 5, ["The location — everything flows from being in the right place", "The light — natural light in every room changes everything", "The space — room to breathe, work, and host without compromise", "The quality — materials and finishes that last and feel premium"], .northStar),
            // ── Why Now ───────────────────────────────────────────────────────────
            ("Why does having this home matter to you in the next 3–5 years specifically?", 5, ["Renting feels like paying for someone else's asset and I'm done with that", "My life is evolving and my home needs to evolve with it", "I want to build equity and stability before too much more time passes", "The people I care about deserve a real home, not a temporary one"], .whyNow),
            ("What is shifting in your life right now that makes this home goal urgent?", 5,
             ["my income has grown enough to make it real", "my current living situation no longer fits who I'm becoming", "I want to create a foundation before other life goals", "I'm ready to stop renting and start building something"], .whyNow),
            // ── Identity ─────────────────────────────────────────────────────────
            ("What kind of person lives in a home like this, and how are you becoming that person?", 5, ["Someone with financial discipline who made long-term choices", "A person who values quality of life and invests in their environment", "Someone grounded — the home reflects stability and intention", "A professional who has built something real, not just a career"], .identity),
            ("When a guest walks into your ideal home, what do they immediately understand about you?", 5,
             ["that I value quality and craftsmanship above trends", "that warmth and family are central to my life", "that I have refined taste and a clear point of view", "that I've built something that reflects my real success", "that this is a place of calm and intentional living"], .identity),
            // ── Observable Evidence ───────────────────────────────────────────────
            ("What would someone you admire see in your home that proves you've arrived?", 5, ["A home that's been designed thoughtfully, not just furnished quickly", "A location that signals where I've positioned myself in life", "The calm and order of a person who has their life together", "Ownership — no landlord, no uncertainty, just mine"], .observable),
            ("What specific, measurable milestone marks real progress toward this home goal?", 5,
             ["I've saved a specific down payment amount", "I've been pre-approved for the mortgage I need", "I've identified the exact neighbourhood and street type", "I've toured at least five homes in my target range"], .measurable),
            // ── Constraint ───────────────────────────────────────────────────────
            ("What are you deliberately ruling out to keep this home goal focused?", 5,
             ["buying something 'for now' that anchors me to the wrong place", "spending on décor before the right home is secured", "compromising on location just to own sooner", "renovating a property that doesn't match my vision"], .constraint),
            // ── Tradeoff ─────────────────────────────────────────────────────────
            ("What will you say no to — in lifestyle or spending — so this home becomes real?", 5, ["Spending on experiences and things that feel good now but don't build equity", "Moving to a better rental instead of saving for ownership", "Delaying the down payment for one more year each year", "Letting lifestyle inflation eat my deposit savings"], .tradeoff),
            // ── Milestone Ladder ─────────────────────────────────────────────────
            ("What must be true 12 months from now for this home goal to stay on track?", 5,
             ["my down payment savings are growing on a clear schedule", "I know exactly which suburb or city I want to be in", "I've spoken to a mortgage broker and know my numbers", "I've visited the area at different times of day"], .milestone),
            // ── Pre-mortem ────────────────────────────────────────────────────────
            ("What is the most likely thing that delays or derails this home goal, and what is your plan?", 5, ["Interest rates or market timing — I'll buy when I'm ready, not when it's perfect", "Not saving the deposit fast enough — I'll automate it with no exceptions", "Losing focus when other things compete for the money — I'll keep the goal visible", "Fear of commitment — I'll remind myself that waiting costs more than deciding"], .premortem),
            // ── Values → Behaviour ───────────────────────────────────────────────
            ("How will living in this home change how you behave and invest your time on a daily basis?", 5,
             ["I'll cook more at home because the kitchen inspires me", "I'll host people I care about more often", "I'll wake up calm because the space is exactly right", "I'll work better because my environment supports focus", "I'll spend more time outdoors because the setting invites it"], .valueBehavior),
            // ── Decision Rule ─────────────────────────────────────────────────────
            ("When you're choosing between two homes and both feel close — what principle decides it?", 5, ["The one in the better long-term location always wins", "The one I'd still love in 10 years, not just today", "The one with the best bones — structure over surface finishes", "The one my gut says yes to, when the numbers are roughly equal"], .decisionRule),
            // ── Qualitative Signal ────────────────────────────────────────────────
            ("If you can't measure home-goal progress with numbers, what feeling tells you you're on track?", 5,
             ["I feel excited rather than anxious when I think about it", "I've stopped compromising in how I imagine the place", "conversations about it energise rather than drain me", "my daily choices are starting to reflect the life I want to live in that home"], .qualitative),
            // ── Environment Design ────────────────────────────────────────────────
            ("What will you change in your current environment to make the home goal easier to achieve?", 5,
             ["set up automatic savings so the down payment builds itself", "create a vision board or folder of homes I'm aiming for", "spend time in the neighbourhoods I want to live in", "connect with people who have already done this"], .environment),
            // ── Support Network ───────────────────────────────────────────────────
            ("Who do you need on your team to make this home a reality, and what will you ask of them?", 5, ["A mortgage broker — I'll ask for a realistic pre-approval and borrowing plan", "A buyer's agent — I'll ask them to find what I can't find myself", "My partner or family — I'll ask for alignment on the vision and timeline", "A financial advisor — I'll ask how to structure savings and reduce tax"], .support),
            // ── Counterfactual ────────────────────────────────────────────────────
            ("If you do nothing toward this home goal for 12 months, what specifically gets harder?", 5, ["Property prices rise further and my deposit loses ground", "Another year of rent with nothing to show for it", "The window for my preferred location closes as the market moves", "I stay in a home that doesn't fit my life and resent it longer"], .counterfactual),
            // ── Vivid Scene ───────────────────────────────────────────────────────
            ("Describe a specific morning in your ideal home — from the moment you wake up to when you leave.", 5, ["I wake up to natural light, make coffee in a kitchen I love, and leave feeling ready", "I work out at home, shower in a bathroom that feels like a hotel, then head out sharp", "The morning is quiet — no noise, no rush — my home gives me that buffer", "I look around before I leave and think 'I built this' — then I go win the day"], .vivid),
            // ── Discovery ─────────────────────────────────────────────────────────
            ("Where do you picture your home?", 5,
             ["in the heart of a vibrant city", "in a quiet suburb with great schools nearby", "somewhere rural with privacy and land", "on or near the water", "in the mountains or elevated terrain", "a warm coastal or island setting"], .discovery),
            ("What style of architecture and interior speaks to you most?", 5,
             ["modern and minimal — clean lines, no clutter", "warm and traditional — character, wood, texture", "industrial with raw materials and high ceilings", "Mediterranean or Hamptons — relaxed and refined", "a custom design that doesn't fit a category"], .discovery),
            ("How large does this home need to be?", 5,
             ["intimate and cosy — under 1,500 sq ft", "comfortable family scale — around 2,000–2,500 sq ft", "spacious — 3,000–4,500 sq ft", "a large estate — over 5,000 sq ft"], .discovery),
            ("What number of bedrooms fits your vision?", 5, ["2", "3", "4", "5", "6+"], .discovery),
            ("Pool — essential, nice-to-have, or not relevant?", 5,
             ["essential — it's part of the lifestyle", "nice to have if the home is right otherwise", "I'd add one after purchasing", "not relevant to what I want"], .discovery),
            ("What outdoor space matters most to you?", 5,
             ["a large garden or yard for privacy and space", "an entertainer's patio or terrace", "a rooftop or balcony with a view", "land — I want acreage", "proximity to parks or nature rather than private land"], .discovery),
            ("How do you feel about smart home technology?", 5,
             ["fully automated — I want control of everything from my phone", "selective — security, climate, and lighting", "minimal — I prefer simple and reliable", "I'll add it over time as the budget allows"], .discovery),
            ("Do you want to buy, build from scratch, or renovate?", 5,
             ["buy an existing home that's already right", "buy and renovate to make it exactly mine", "build from scratch on the right land", "flexible — depends on what the market offers"], .discovery),
            ("What's the honest price range you're targeting?", 5,
             ["under $500k", "$500k–$800k", "$800k–$1.2M", "$1.2M–$2M", "$2M–$5M", "over $5M"], .measurable),
            ("Garage — how important, and how many cars?", 5,
             ["essential — I need at least a double garage", "a single garage is fine", "I want a full multi-car garage or workshop", "I don't need a garage"], .discovery),
            ("How do you feel about home maintenance and upkeep?", 5,
             ["I want a low-maintenance property so I can focus on life", "I enjoy maintaining and improving a home", "I'll hire someone for everything — I want the home, not the work", "I want to build equity through my own improvements"], .discovery),
            ("What view or setting do you wake up to in your ideal home?", 5,
             ["a private garden with mature trees", "the city skyline", "water — ocean, river, or lake", "mountains or hills", "a quiet street with good neighbours"], .discovery),
            ("Is this a forever home or a stepping stone?", 10,
             ["my forever home — I intend to raise a family and stay", "a 5–7 year home that builds equity for the next one", "a stepping stone toward something larger", "I'm open — the right home will tell me"], .discovery),
            ("What is the single room or space you're most excited to design?", 5,
             ["the kitchen — it's the heart of everything", "the master suite — my private sanctuary", "the living area — where life happens", "a dedicated home office", "outdoor entertaining space", "a home gym or wellness space"], .northStar),
        ]
    }

    private func generateCareerQuestions() -> [Q] {
        return [
            // ── North Star ────────────────────────────────────────────────────────
            ("What is the single career outcome that, if you achieved it, would make everything feel worth it?", 5, ["Leading a team or organisation at the level I know I'm capable of", "Building something I own — a business, a product, a brand", "Being recognised as one of the best in my field", "Earning enough that money is no longer a constraint on my life"], .northStar),
            ("Describe what a perfect professional day looks like for you five years from now.", 5, ["I work on problems that genuinely challenge me with people I respect", "I have full control over my time and I use it deliberately", "I do deep, meaningful work in the morning and lead or connect in the afternoon", "I finish the day knowing I moved something important forward"], .vivid),
            // ── Why Now ───────────────────────────────────────────────────────────
            ("Why does this career goal matter to you right now, not in five more years?", 5, ["The window for this specific opportunity is open now — it won't stay open", "I've been building toward this and I'm finally ready to step into it", "I can feel the cost of staying where I am — financially and personally", "The longer I wait, the more I convince myself it isn't possible"], .whyNow),
            ("What is happening in your life or industry right now that makes this the right moment?", 5,
             ["the market or opportunity is open right now", "I've built enough experience to make a real move", "staying where I am has started to cost me more than moving", "I've been patient long enough and I'm ready to accelerate"], .whyNow),
            // ── Identity ─────────────────────────────────────────────────────────
            ("Who are you becoming professionally, and what does that person do every day?", 5, ["A leader who makes decisions with clarity and takes responsibility without flinching", "A builder who creates things that last beyond any single role", "An expert whose opinion shapes how others think in this field", "A person who works with freedom — choosing projects, clients, and hours"], .identity),
            ("In the career you're building, how do people describe you in a room you're not in?", 5,
             ["someone who delivers exceptional work and is completely reliable", "a visionary who spots opportunities others miss", "the person you call when a problem seems unsolvable", "someone who builds teams and cultures that last", "a founder who built something from nothing"], .identity),
            // ── Observable Evidence ───────────────────────────────────────────────
            ("What would someone who knows your industry well see that proves you've achieved this goal?", 5, ["My title, my organisation, or my client list speaks for itself", "People in my field know my name and what I've built", "I'm invited into rooms I used to only read about", "My income reflects the level I said I'd reach"], .observable),
            ("What specific, measurable outcome marks success in your career over the next 3–5 years?", 5, ["A specific role or title I've defined and am working toward", "A revenue or income figure my career is producing", "A number of people I lead or impact through my work", "A specific thing I've shipped, built, or launched"], .measurable),
            // ── Constraint ───────────────────────────────────────────────────────
            ("What career paths or opportunities are you deliberately ruling out to stay focused?", 5,
             ["roles that pay more but take me in the wrong direction", "staying in a company that doesn't match my ambition", "taking on work that fills my calendar but not my purpose", "chasing status that doesn't align with my actual goals"], .constraint),
            // ── Tradeoff ─────────────────────────────────────────────────────────
            ("What will you say no to in your professional life so the right thing can grow?", 5, ["Work that pays well but pulls me away from where I'm heading", "Staying in a role or company that has already taught me everything it can", "Distractions disguised as opportunities that don't fit the direction", "Comfort — the known that feels safe but doesn't grow"], .tradeoff),
            // ── Milestone Ladder ─────────────────────────────────────────────────
            ("What must be true 12 months from now for your career vision to be on track?", 5,
             ["I've taken on a specific stretch responsibility", "I've had the conversation about the role or salary I want", "I've launched the side project or business I keep delaying", "I've built a relationship with someone who can open the right door"], .milestone),
            // ── Pre-mortem ────────────────────────────────────────────────────────
            ("What is the most likely thing that holds your career back, and what's your plan to prevent it?", 5, ["Not putting myself forward — I'll commit to raising my hand more", "Staying too long somewhere that no longer challenges me", "Not building the relationships that open doors — I'll invest in that deliberately", "Fear of failure keeping me in the planning phase — I'll ship before I'm ready"], .premortem),
            // ── Values → Behaviour ───────────────────────────────────────────────
            ("How does the career you're building show up in how you behave on a normal Tuesday?", 5,
             ["I do deep, focused work in the morning before anything else", "I have real conversations with people worth learning from", "I protect time for the work that actually matters", "I invest in getting better at my craft every single week"], .valueBehavior),
            // ── Decision Rule ─────────────────────────────────────────────────────
            ("What principle guides you when you're choosing between two career opportunities?", 5, ["The one that teaches me the most in the next two years", "The one that positions me closer to where I ultimately want to be", "The one where I'll be surrounded by the best people", "The one with the most ownership — financially or creatively"], .decisionRule),
            // ── Qualitative Signal ────────────────────────────────────────────────
            ("If you can't measure your career progress with a metric, what feeling tells you you're on track?", 5,
             ["I'm energised by my work rather than drained by it", "I'm growing faster than I expected", "I'm solving problems that actually matter", "the people around me are lifting me up"], .qualitative),
            // ── Environment Design ────────────────────────────────────────────────
            ("What will you change about your environment to make career success more likely?", 5,
             ["join a community or peer group of people at the level I want to reach", "build a workspace that reflects the professional I'm becoming", "reduce the meetings and commitments that don't move me forward", "find a mentor who has done what I want to do"], .environment),
            // ── Support Network ───────────────────────────────────────────────────
            ("Who do you need in your corner professionally, and what will you ask of them?", 5, ["A mentor who's done what I want to do — I'll ask for honest direction", "A sponsor who'll advocate for me in rooms I'm not in yet", "A peer group at my level who push each other — I'll invest in building it", "A coach who helps me get out of my own way — I'll commit to the process"], .support),
            // ── Counterfactual ────────────────────────────────────────────────────
            ("If you do nothing different in your career for 12 months, what specifically gets worse?", 5, ["The gap between where I am and where I want to be keeps widening", "I become more specialised in skills that are already becoming less relevant", "Someone else fills the role or builds the thing I keep saying I'll do", "My confidence in myself as someone who follows through takes another hit"], .counterfactual),
            // ── Discovery ─────────────────────────────────────────────────────────
            ("What kind of work environment makes you do your best work?", 5,
             ["fully remote — deep focus on my own schedule", "a collaborative office with energy and people around me", "hybrid — the best of both", "location-independent, moving between places", "outdoors or on the move"], .discovery),
            ("What income are you building toward in the next 3–5 years?", 5,
             ["$75k–$100k", "$100k–$150k", "$150k–$250k", "$250k–$500k", "over $500k", "building a business so the ceiling is mine to set"], .measurable),
            ("Are you building a career inside an organisation, or building your own?", 5,
             ["growing within a company I believe in", "launching and running my own business", "freelancing on my own terms", "consulting — my expertise, my clients, my schedule", "a combination that evolves as I grow"], .discovery),
            ("What impact do you want your work to have?", 5,
             ["build products or services millions of people use", "change the way an industry works", "give people a skill or perspective that changes their lives", "create jobs and opportunity for others", "generate enough wealth to fund the causes I care about"], .northStar),
            ("What would you want to be known for professionally at the peak of your career?", 10,
             ["the person who built something truly great from scratch", "someone who made their field better for everyone", "a leader who developed exceptional people", "an expert others cite and learn from", "someone who proved that doing good and doing well aren't opposites"], .identity),
            ("How important is flexibility and autonomy in your work?", 5,
             ["it's non-negotiable — I need to own my schedule", "important — I want flexibility with accountability", "less important than the work itself and who I do it with", "I prefer structure — it helps me perform"], .discovery),
            ("What size of stage do you want to operate on?", 10,
             ["a global stage — I want to be known internationally", "industry-wide — respected across my field", "local and deeply meaningful within a specific community", "private — the work and its results matter, not the audience"], .discovery),
            ("What do you want to stop doing professionally as soon as possible?", 5, ["Work that doesn't use my real strengths", "Reporting to people I've already surpassed in capability", "Doing operational tasks that should be delegated or automated", "Pretending I'm satisfied with a direction that isn't right for me"], .constraint),
            ("How do you want to feel at the end of a hard work week?", 5,
             ["proud of something I built or shipped", "energised by the people I worked alongside", "confident I'm getting closer to something that matters", "clear that my time went toward what I actually care about"], .valueBehavior),
            ("What skill, if you mastered it in the next 2 years, would change everything for your career?", 5, ["Leadership — the ability to build and move a high-performing team", "Sales — the ability to sell my ideas, myself, or my product convincingly", "Communication — writing and speaking that makes people pay attention", "Strategic thinking — seeing the system, not just the task"], .milestone),
            ("What is the work that only you can do — the intersection of your skills, values and what the world needs?", 10, ["Building teams and cultures that bring out the best in people", "Creating things — products, content, businesses — that solve real problems", "Translating complexity into clarity for people who need it", "Leading in an area where my lived experience gives me a perspective no one else has"], .northStar),
        ]
    }

    private func generateHealthQuestions() -> [Q] {
        return [
            // ── North Star ────────────────────────────────────────────────────────
            ("What does being truly healthy look and feel like for you — describe it specifically?", 5, ["I have energy from the moment I wake up to when I go to sleep", "My body performs the way I ask it to without complaint", "I feel confident in how I look and what my body can do", "I sleep deeply, recover quickly, and never feel depleted"], .northStar),
            ("Describe a day in your life when your health is exactly where you want it to be.", 5, ["I train, eat with intention, and feel sharp for everything else the day demands", "My morning routine sets the tone — movement, nutrition, and a clear mind", "I end the day without the weight of guilt about what I didn't do for myself", "I have the physical and mental energy to be fully present for the people and work that matter"], .vivid),
            // ── Why Now ───────────────────────────────────────────────────────────
            ("Why does your health need to change or improve right now, not eventually?", 5, ["I can already feel the consequences of ignoring it — this is my line in the sand", "The people who depend on me need me well — not eventually, now", "I'm at an age where what I do in the next 12 months will define the next 20 years", "I've made this promise before and this time the cost of breaking it is too high"], .whyNow),
            ("What event, feeling, or realisation has made health a priority at this moment in your life?", 5,
             ["I felt something physically that made it real", "I saw what decline looks like in someone I care about", "my energy has dropped and it's affecting everything else", "I've achieved other things — now I want to feel as good as they look"], .whyNow),
            // ── Identity ─────────────────────────────────────────────────────────
            ("Who is the healthy version of you, and what does that person do and value?", 5, ["Someone who treats their body as a foundation, not an afterthought", "A person who trains consistently — not perfectly, but never quitting", "Someone whose energy and discipline in health spills into every other area of life", "A person who has made peace with food and movement — it's just how they live"], .identity),
            ("How does the healthy version of you show up differently in relationships, work, and energy?", 5,
             ["I show up with more energy and presence for the people I love", "I make decisions from strength rather than depletion", "I set an example for the people around me without needing to say a word", "I take on harder things because I know my body can handle it"], .identity),
            // ── Observable Evidence ───────────────────────────────────────────────
            ("What would a doctor or someone close to you see that proves your health goal is achieved?", 5, ["My numbers — bloodwork, weight, fitness markers — are genuinely good", "I look and move differently than I did before", "The people close to me comment on my energy and how present I am", "I no longer talk about 'getting healthy' — I just am"], .observable),
            ("What specific, trackable metric marks real progress on your health goal?", 5,
             ["a target body weight or body fat percentage", "a resting heart rate I'm proud of", "a performance benchmark — a run time, a lift, a distance", "a bloodwork result that comes back clean", "sleeping 7–8 hours consistently for 30 days straight"], .measurable),
            // ── Constraint ───────────────────────────────────────────────────────
            ("What habit or pattern are you ruling out because it's incompatible with who you're becoming?", 5,
             ["eating past fullness out of boredom or stress", "skipping sleep for productivity", "exercising only when I feel motivated", "using alcohol or food to manage difficult emotions"], .constraint),
            // ── Tradeoff ─────────────────────────────────────────────────────────
            ("What will you say no to in your daily life so your health gets what it deserves?", 5, ["Late nights that destroy my sleep and everything that depends on it", "Food choices driven by convenience or emotion rather than intention", "Saying yes to things that fill my calendar and leave no room for recovery", "The story that I'm too busy — everyone who has done this was also busy"], .tradeoff),
            // ── Milestone Ladder ─────────────────────────────────────────────────
            ("What must be true about your health 12 months from now for you to be on track?", 5,
             ["I've built a training routine that I've held for at least 3 months", "my diet reflects what I actually believe about food", "my sleep is consistent and I wake up feeling rested", "I've done a health check and addressed everything that came up"], .milestone),
            // ── Pre-mortem ────────────────────────────────────────────────────────
            ("What is the most likely thing that derails your health goals, and what's your prevention plan?", 5, ["A busy period at work — I'll keep a minimum viable routine that survives chaos", "Injury or illness — I'll build in recovery and not use it as a reason to stop everything", "Losing motivation after the initial phase — I'll commit to a structure, not a feeling", "Social situations and travel — I'll make decisions in advance, not in the moment"], .premortem),
            // ── Values → Behaviour ───────────────────────────────────────────────
            ("How do your health values show up in what you actually do on a normal Wednesday?", 5,
             ["I move my body every day, even when it's only for 20 minutes", "I eat in a way that gives me energy rather than taking it", "I protect my sleep the same way I protect important meetings", "I manage stress before it manages me"], .valueBehavior),
            // ── Decision Rule ─────────────────────────────────────────────────────
            ("What rule do you follow when choosing between rest and pushing through?", 5, ["If it's my body asking for rest, I listen. If it's my mind making excuses, I push.", "I have a minimum I always do — something is always better than nothing", "I rest deliberately and schedule it — I don't wait until I'm broken", "I ask: will this choice serve future me? That answer decides."], .decisionRule),
            // ── Qualitative Signal ────────────────────────────────────────────────
            ("If you can't measure your health progress with a number, what feeling tells you you're on track?", 5,
             ["I wake up without needing an alarm and feel ready", "I feel comfortable and confident in my own body", "I have energy left at the end of the day for the people I love", "I'm not thinking about my health with anxiety — I trust it"], .qualitative),
            // ── Environment Design ────────────────────────────────────────────────
            ("What will you change in your home, schedule, or surroundings to make healthy choices easier?", 5,
             ["prepare food in advance so the easy choice is the right one", "put my gym bag by the door so training isn't optional", "remove what tempts me away from my goals", "schedule my workouts as fixed appointments, not aspirations"], .environment),
            // ── Support Network ───────────────────────────────────────────────────
            ("Who will you bring into your health journey, and what will you ask of them?", 5, ["A trainer — I'll ask for structure and accountability I can't give myself", "My partner or a friend — I'll ask them to join me so we keep each other honest", "A doctor or specialist — I'll ask for an honest baseline and a clear target", "A nutritionist — I'll ask for a real plan, not another generic approach"], .support),
            // ── Counterfactual ────────────────────────────────────────────────────
            ("If your health stays exactly as it is for 12 more months, what gets worse?", 5, ["My energy keeps declining and everything else in my life pays the price", "The gap between where I am and where I want to be becomes harder to close", "My confidence in my own body and appearance erodes further", "The habits I'm tolerating now become harder to break the longer they stay"], .counterfactual),
            // ── Discovery ─────────────────────────────────────────────────────────
            ("What area of your health needs the most attention right now?", 5,
             ["physical fitness and strength", "nutrition and how I eat", "sleep quality and recovery", "mental health and stress management", "energy levels throughout the day", "managing a specific health condition"], .discovery),
            ("What movement or training do you actually enjoy?", 5,
             ["strength training — lifting and building", "running or endurance sports", "team sports or group classes", "yoga, mobility, or mindfulness movement", "outdoor activities like hiking or cycling", "high-intensity training"], .discovery),
            ("How do you want your body to perform, not just look?", 5,
             ["I want to be strong and capable of hard physical tasks", "I want endurance — to go long without fading", "I want flexibility and to move without pain or restriction", "I want to feel athletic and coordinated", "I want to feel light, energetic, and unrestricted"], .identity),
            ("What does your ideal relationship with food look like?", 5,
             ["eating whole foods that fuel rather than comfort", "an 80/20 approach — discipline with flexibility", "intuitive eating — fully in tune with what my body needs", "a structured plan with clear guidelines that reduce decisions"], .discovery),
            ("How many hours of sleep do you need to feel truly rested?", 5, ["6 hours", "7 hours", "8 hours", "9+ hours"], .measurable),
            ("What time of day works best for you to train?", 5,
             ["early morning — before the day takes over", "lunchtime — a mid-day reset", "evening — when stress needs a physical outlet", "it varies, I need flexibility"], .discovery),
            ("What health milestone would tell you you've genuinely transformed?", 5, ["I hit a fitness goal I've never reached before — a weight, a time, a lift", "My doctor reviews my bloodwork and tells me there's nothing to improve", "I go a full month without reverting to old patterns under pressure", "The people close to me notice before I say anything"], .observable),
            ("What does stress look like in your body, and how do you want to handle it?", 5,
             ["I want to notice it early and move before it builds", "I want a daily practice that keeps it from accumulating", "I want to respond rather than react — stay grounded under pressure", "I want to be honest with myself when I need support"], .valueBehavior),
            ("What would make you proud of your health in 10 years' time?", 10,
             ["I never let it slip into neglect", "I built habits early that compound beautifully over time", "I'm physically capable of doing everything I love at any age", "I invested in prevention rather than treatment"], .identity),
            ("How important is longevity and long-term health versus short-term performance?", 10,
             ["long-term is everything — I want to be well at 80", "I want to perform now and sustain it as long as possible", "I'm focused on feeling great right now", "both — I want peak performance that I can sustain for decades"], .discovery),
        ]
    }

    private func generateRelationshipsQuestions() -> [Q] {
        return [
            // ── North Star ────────────────────────────────────────────────────────
            ("What do your most important relationships look like at their best — describe it specifically?", 5, ["There is genuine presence — phones away, real conversations, no performing", "We challenge and support each other in equal measure", "There is trust so deep we can say anything without fear", "We make time for each other consistently, not just in crisis"], .northStar),
            ("Describe a specific evening with the people you love most in your ideal future.", 5, ["We're around a table, food on the table, no agenda — just being together", "We're doing something simple — a walk, a film, a meal — and it feels enough", "There's laughter and honesty and the feeling that this is what life is for", "The people I love feel seen and celebrated, not just present"], .vivid),
            // ── Why Now ───────────────────────────────────────────────────────────
            ("Why do your relationships need attention or investment right now, not later?", 5, ["The distance that forms slowly is hard to reverse — I need to act before it sets", "The people I love are in seasons of life where they need me present", "I've been prioritising other things at the expense of what actually matters", "The relationships I neglect now won't automatically recover when I have more time"], .whyNow),
            ("What is happening in your relationships right now that makes this the right moment to reflect?", 5,
             ["a relationship that matters to me is drifting", "I've been putting work before connection for too long", "I want to build the right relationships before life gets busier", "I've realised who actually matters and I want to invest accordingly"], .whyNow),
            // ── Identity ─────────────────────────────────────────────────────────
            ("What kind of partner, friend, or family member are you becoming?", 5, ["Someone who shows up consistently, not just in the big moments", "A person who listens to understand, not to respond", "Someone who makes the people around them feel safe and seen", "A person who loves generously and expects the same in return"], .identity),
            ("How do the people closest to you describe you at your best?", 5,
             ["someone who shows up completely, no half-measures", "someone who makes people feel genuinely seen and heard", "someone who can be counted on without question", "someone who brings lightness and joy into a room", "someone who tells the truth even when it's difficult"], .identity),
            // ── Observable Evidence ───────────────────────────────────────────────
            ("What would someone close to you see that proves your relationships are where you want them?", 5, ["They initiate spending time with me — they want to be around me", "I know what's going on in their lives and they know mine", "There is no unspoken tension — we've had the hard conversations", "We have rituals — regular time together that neither of us cancels"], .observable),
            ("What measurable habit or commitment marks real investment in your relationships?", 5,
             ["regular one-on-one time with each person I care about", "I'm fully present — phone away — in shared time", "I've had the honest conversations that I've been putting off", "I've shown up for them in a way that required real effort"], .measurable),
            // ── Constraint ───────────────────────────────────────────────────────
            ("What pattern or habit are you ruling out because it's hurting the relationships you value?", 5,
             ["being distracted when I'm physically present", "prioritising convenience over the people who matter", "avoiding difficult conversations until they become fractures", "holding onto resentment instead of addressing it directly"], .constraint),
            // ── Tradeoff ─────────────────────────────────────────────────────────
            ("What will you say no to so the relationships that matter get the time and energy they deserve?", 5, ["Filling my schedule so completely that there's nothing left for the people I love", "Surface-level socialising that doesn't nourish any of us", "Letting work bleed into time that belongs to the people closest to me", "Relationships that consistently take more than they give"], .tradeoff),
            // ── Milestone Ladder ─────────────────────────────────────────────────
            ("What must be true about your relationships 12 months from now for you to feel on track?", 5,
             ["I've had the honest conversation I've been avoiding", "I've built a consistent ritual with the people I love most", "I've let go of a relationship that was costing me more than it gave", "I've been fully present in a way I wasn't before"], .milestone),
            // ── Pre-mortem ────────────────────────────────────────────────────────
            ("What is the most likely thing that damages your most important relationships, and what's your plan?", 5, ["My tendency to be absent even when I'm physically present — I'll practise real presence", "Not addressing small resentments before they become big ones", "Letting months pass without meaningful one-on-one time", "Prioritising productivity over people during busy periods — I'll protect relationship time"], .premortem),
            // ── Values → Behaviour ───────────────────────────────────────────────
            ("How do your relationship values show up in what you actually do on a normal day?", 5,
             ["I reach out first — I don't wait to be contacted", "I remember what matters to the people I love and act on it", "I'm honest even when it would be easier not to be", "I create the time rather than waiting for it to appear"], .valueBehavior),
            // ── Decision Rule ─────────────────────────────────────────────────────
            ("What principle guides you when deciding how to spend your limited social time?", 5, ["Depth over breadth — fewer people, more often, more honestly", "I prioritise the relationships that are reciprocal and nourishing", "I show up for the big moments and the small ordinary ones equally", "I ask: does this bring us closer, or are we just occupying the same space?"], .decisionRule),
            // ── Qualitative Signal ────────────────────────────────────────────────
            ("What feeling tells you your relationships are healthy and strong?", 5,
             ["I don't feel alone even when I'm by myself", "the people I love know I'm in their corner", "I'm comfortable being fully honest with the people closest to me", "I leave time with the people I care about feeling energised"], .qualitative),
            // ── Environment Design ────────────────────────────────────────────────
            ("What will you change in your schedule or environment to make quality time with loved ones easier?", 5,
             ["protect specific evenings every week for the people I love", "reduce commitments that crowd out genuine connection", "create shared rituals that happen without needing to be planned", "live closer to the people who matter most"], .environment),
            // ── Support Network ───────────────────────────────────────────────────
            ("Who in your life supports your growth, and what will you ask of them this year?", 5, ["My closest friend — I'll ask for honest feedback, not just encouragement", "My partner — I'll ask for patience and partnership as I grow", "A mentor or elder in my life — I'll ask for perspective I don't yet have", "My peer group — I'll ask us all to raise our standards together"], .support),
            // ── Counterfactual ────────────────────────────────────────────────────
            ("If you invest no more effort into your relationships over the next 12 months, what drifts away?", 5, ["The friendships that require effort to maintain — and they're worth the effort", "The closeness with family that exists when we're intentional about it", "My partner's sense that I'm truly present and invested", "The feeling of being truly known by anyone — that requires showing up"], .counterfactual),
            // ── Discovery ─────────────────────────────────────────────────────────
            ("What does your ideal romantic relationship look and feel like?", 5,
             ["a partnership of equals who challenge and support each other", "a deep friendship with physical and emotional intimacy", "adventurous and evolving — we grow together, not just alongside each other", "calm and secure — a safe place to come home to"], .discovery),
            ("What role do friendships play in your ideal future?", 5,
             ["a small group of deep, lifelong friendships", "a broader community of like-minded people with some deep anchors", "friendships built around shared pursuits and adventures", "I invest most in family and keep friendships meaningful but light"], .discovery),
            ("What does family mean to you in your ideal future?", 10,
             ["building my own family — partner, children, home", "being deeply close to the family I was born into", "chosen family — the people I've built my life around", "a combination of both blood and chosen connection"], .identity),
            ("How do you want to show love to the people you care about?", 5,
             ["through consistent presence and undivided attention", "through acts of service — making their lives easier", "through words — telling them honestly and often", "through shared experiences and adventures", "through creating security and stability they can rely on"], .valueBehavior),
            ("What boundaries do you need in relationships to stay healthy and whole?", 5, ["I need time that's mine — not available to anyone, consistently", "I need relationships where honesty goes both ways", "I need to be able to say no without guilt or consequence", "I need to stop managing other people's emotions at the expense of my own"], .constraint),
            ("How do you want to handle conflict in your most important relationships?", 5,
             ["address it early before it compounds", "take time to cool down, then come back with clarity", "lead with curiosity rather than defensiveness", "work through it together — never outsource the conversation"], .decisionRule),
            ("What kind of social life energises rather than drains you?", 5,
             ["deep, meaningful one-on-one time", "a rich social calendar with people I genuinely enjoy", "a mix — some depth and some breadth", "small intimate gatherings where conversation is real"], .discovery),
            ("How do you want to invest in friendships that have drifted?", 5, ["Reach out with a specific plan — not 'we should catch up' but 'are you free Thursday'", "Share something real about my life to reset the surface-level dynamic", "Acknowledge the drift directly — it clears the air immediately", "Show up for something that matters to them without being asked"], .structured),
            ("What would you want the people who love you most to say about you at the end of a great life?", 15, ["That I made the people around me feel loved and important", "That I lived fully and didn't hold back from the things that mattered", "That I was honest, consistent, and someone you could always count on", "That being around me made their life bigger, not smaller"], .identity),
            ("In 10 years, what does love and connection look like in your daily life?", 10, ["The people I love are close, present, and choosing to be in my life", "Love is easy — not without effort, but without fear or pretending", "I am known deeply by a small number of people and that feels like enough", "Connection is a daily experience, not something I have to schedule or chase"], .vivid),
        ]
    }

    private func generateFinancesQuestions() -> [Q] {
        return [
            // ── North Star ────────────────────────────────────────────────────────
            ("What does financial freedom look like for you specifically — describe the life, not just the number?", 5, ["I make decisions about where to live and work without money being the deciding factor", "I have investments working for me while I focus on what I actually care about", "I give generously without calculating what I have left", "I wake up without financial anxiety — that is what freedom actually means"], .northStar),
            ("Describe your financial life five years from now in a way that would make you proud.", 5, ["My net worth reflects years of intentional decisions, not luck", "I have built multiple income streams so no single source controls my life", "My financial life is organised, growing, and completely under my control", "I am proud of the discipline I showed when it was hard"], .vivid),
            // ── Why Now ───────────────────────────────────────────────────────────
            ("Why does your financial life need to change right now, not someday?", 5, ["Every month I delay costs me compounding growth I cannot get back", "I am close enough to my goal that acting now could genuinely change my life", "The habits I do not fix now will be harder to fix in five years", "I want my forties or fifties to look different from my thirties — and that starts now"], .whyNow),
            ("What financial reality right now is no longer acceptable to you?", 5,
             ["I'm not building wealth — I'm just covering costs", "I have no real financial safety net and it creates anxiety", "my income is not growing at the rate my life demands", "I'm spending in ways that don't reflect my real priorities"], .whyNow),
            // ── Identity ─────────────────────────────────────────────────────────
            ("What kind of relationship with money are you building, and who does that make you?", 5, ["Someone who earns it intentionally, keeps it deliberately, and grows it consistently", "A person who is generous from abundance, not guilt or performance", "Someone for whom money is a tool that serves their life — not a source of identity or anxiety", "A builder — I treat every dollar as a resource to be deployed, not just spent"], .identity),
            ("How does someone with your financial vision behave differently from how you behave today?", 5,
             ["they make decisions from long-term thinking, not short-term emotion", "they pay themselves first before lifestyle takes the rest", "they know their numbers and review them without anxiety", "they invest consistently whether markets are up or down"], .identity),
            // ── Observable Evidence ───────────────────────────────────────────────
            ("What specific number or milestone proves your financial goal is real?", 5, ["A net worth figure I have committed to and am tracking monthly", "A passive income number that covers my core lifestyle expenses", "Zero personal debt — owned outright, nothing owed", "An investment account at a threshold that changes my options"], .measurable),
            ("What would a financially smart person who knows your situation see that proves you're on track?", 5, ["A clear financial plan that I am actually following, not just admiring", "Consistent monthly investment regardless of how I feel about markets", "A growing gap between what I earn and what I spend", "A debt position that is shrinking with intention, not just time"], .observable),
            // ── Constraint ───────────────────────────────────────────────────────
            ("What spending pattern or financial habit are you ruling out entirely?", 5,
             ["spending on impulse rather than intention", "keeping subscriptions and costs I never consciously review", "lifestyle inflation every time income increases", "avoiding my finances because the numbers feel uncomfortable"], .constraint),
            // ── Tradeoff ─────────────────────────────────────────────────────────
            ("What lifestyle choice will you say no to so your financial future can grow?", 5, ["Upgrading my lifestyle every time my income goes up", "Spending to manage emotions rather than to genuinely enrich my life", "Keeping financial decisions vague so I can avoid the discomfort of discipline", "Helping others financially before my own foundation is solid"], .tradeoff),
            // ── Milestone Ladder ─────────────────────────────────────────────────
            ("What must be true about your finances 12 months from now for you to feel on track?", 5,
             ["I have a 3–6 month emergency fund fully in place", "I'm investing a specific percentage of my income every month", "I've eliminated high-interest debt", "I know exactly what I earn, spend, save, and invest — every month"], .milestone),
            // ── Pre-mortem ────────────────────────────────────────────────────────
            ("What is the most likely financial mistake that could set you back, and how will you prevent it?", 5, ["Investing in things I do not understand because someone I trust says it is a good idea", "Letting a period of high income make me feel like discipline no longer applies", "Putting off the financial admin until it becomes a crisis", "Spending emotionally during hard seasons — I will have a rule for this in advance"], .premortem),
            // ── Values → Behaviour ───────────────────────────────────────────────
            ("How do your financial values show up in what you actually do with money this week?", 5,
             ["I spend intentionally — every purchase is a choice, not a default", "I invest before I give lifestyle the rest", "I review my finances monthly without flinching from the truth", "I say no to things that look like value but cost me future freedom"], .valueBehavior),
            // ── Decision Rule ─────────────────────────────────────────────────────
            ("What financial principle guides your decisions when you're tempted to spend vs save?", 5, ["Will I remember this purchase in five years? If not, I probably do not need it.", "Does this purchase build my life or just feel good in the moment?", "I pay myself first — the investment happens before I see the money", "I ask: does this align with the financial plan I have actually committed to?"], .decisionRule),
            // ── Qualitative Signal ────────────────────────────────────────────────
            ("What feeling about money tells you you're on the right track, even before the numbers fully reflect it?", 5,
             ["I make financial decisions without anxiety or guilt", "I feel genuinely in control rather than managed by money", "I'm building something real that compounds over time", "I have clarity — I know where everything is going and why"], .qualitative),
            // ── Environment Design ────────────────────────────────────────────────
            ("What will you set up in your financial environment so the right choices happen automatically?", 5,
             ["automated savings and investments before I can spend them", "a monthly financial review on my calendar", "accounts structured so spending is separated from saving", "remove payment methods that enable impulsive decisions"], .environment),
            // ── Support Network ───────────────────────────────────────────────────
            ("Who do you need to talk to about your finances, and what will you ask of them?", 5, ["A financial advisor — I will ask for a real plan built around my actual goals", "An accountant — I will ask them to find every legal way to keep more of what I earn", "Someone who has already built what I want — I will ask what they know now that they wish they had known earlier", "My partner — I will ask for honest alignment on what we both want financially"], .support),
            // ── Counterfactual ────────────────────────────────────────────────────
            ("If your financial habits stay exactly as they are for 12 more months, what gets significantly worse?", 5, ["The gap between my income and my net worth stays embarrassing", "I get to the end of another year with nothing structurally different", "Financial anxiety continues to quietly undermine my confidence and decisions", "I lose another year of compounding that I cannot get back"], .counterfactual),
            // ── Discovery ─────────────────────────────────────────────────────────
            ("What is the income level that changes how you feel about your life?", 5,
             ["$75k — this feels like a solid foundation", "$120k–$150k — this gives real breathing room", "$250k — this is where real choices open up", "$500k+ — this is the target", "income matters less than net worth and assets to me"], .measurable),
            ("What does financial freedom mean to you specifically?", 5,
             ["never having to check my account before saying yes to something", "choosing my work because I want to, not because I have to", "having enough invested that I could stop working and be fine", "being completely debt-free with no payments of any kind"], .northStar),
            ("What is your relationship with debt right now?", 5,
             ["I have none and intend to keep it that way", "I have strategic debt — mortgage, investment — that builds wealth", "I have consumer debt I'm actively eliminating", "I need to be honest with myself about what debt is costing me"], .discovery),
            ("What is your savings rate goal as a percentage of income?", 5,
             ["10% — a minimum starting point", "20% — a solid, sustainable rate", "30–40% — I want to build wealth aggressively", "50%+ — I'm willing to live lean now for freedom later"], .measurable),
            ("Where do you want your money to work for you?", 5,
             ["index funds and equities for long-term compound growth", "real estate — property that generates income", "building and owning a business", "a diversified portfolio across multiple asset classes"], .discovery),
            ("What does your emergency fund look like in your ideal financial life?", 5,
             ["3 months of expenses — basic protection", "6 months — comfortable buffer", "12 months — I want real security and time to choose well if needed", "enough that a job loss or crisis doesn't change my life"], .measurable),
            ("What financial goal would you be most proud of achieving in the next 5 years?", 5, ["Owning property outright or with a clear, committed plan to do so", "Building an investment portfolio that generates real passive income", "Being completely debt-free and staying that way", "Reaching a net worth that gives me genuine optionality over my time"], .northStar),
            ("How important is generosity and giving as part of your financial life?", 5,
             ["central — I'm building wealth partly to give it away well", "important — I want to give more as I earn more", "something I'll invest in when I've built more security first", "a private commitment I keep regardless of how much I have"], .valueBehavior),
            ("What does retirement or financial independence mean to you?", 10,
             ["stopping work entirely before 50", "having the option to stop — whether or not I take it", "retiring from work I don't love while keeping work I do", "never fully retiring — I want to stay engaged, just on my own terms"], .identity),
            ("What would you do with your time if money were no longer a constraint?", 10, ["I would do the work I find most meaningful, regardless of what it pays", "I would travel more, be more present, and stop rushing everything", "I would invest my time in the people and projects I actually care about", "I would build things — businesses, ideas, communities — purely because I believe in them"], .vivid),
        ]
    }

    private func generateTravelQuestions() -> [Q] {
        return [
            // ── North Star ────────────────────────────────────────────────────────
            ("What is the single travel experience that, if you had it, would feel like a defining moment in your life?", 5, ["A journey that tests me — physically, emotionally, or both — and changes how I see myself", "A trip to a place I have dreamed about since I was young, finally done properly", "An extended stay somewhere foreign that forces me to actually live differently", "A meaningful trip shared with someone I love that becomes a shared memory we will always have"], .northStar),
            ("Describe your ideal trip in complete sensory detail — where you are, who you're with, and how you feel.", 5, ["Somewhere warm, slow, and beautiful — the food is extraordinary and I am fully present", "A demanding outdoor adventure — I am tired, alive, and proud of what I am doing", "A city I do not know well — I am curious, wandering, learning without trying to", "Somewhere that feels like a world away — the distance makes everything at home feel clearer"], .vivid),
            // ── Why Now ───────────────────────────────────────────────────────────
            ("Why does travel matter to you right now, in this chapter of your life?", 5, ["I am at a point where I have the resources to do it properly but still the energy to do it fully", "The people I most want to travel with are in a season where this is possible — that window will not stay open", "Travel is one of the few things that reliably makes me feel most alive, and I have been starving that part of myself", "I have worked hard and travel is one of the ways I actually want to enjoy what I have built"], .whyNow),
            ("What changes in your life right now make this the right time to invest in travel?", 5,
             ["I've been putting it off and I'm done waiting", "I want experiences while my energy and health are at their best", "travel will directly support something else I'm building", "the people I'd travel with won't always be available"], .whyNow),
            // ── Identity ─────────────────────────────────────────────────────────
            ("What kind of traveller are you becoming, and what does that say about who you are?", 5, ["Someone who travels slowly and with intention — depth over volume of destinations", "A person who uses travel to learn and be changed, not just to relax and check out", "Someone who brings the right people into experiences that create real shared history", "An adventurous person who is willing to be uncomfortable in exchange for something unforgettable"], .identity),
            ("How does travel shape the person you're becoming?", 5,
             ["it makes me more curious and less certain — and that's the point", "it reminds me how much is possible outside my daily context", "it challenges my assumptions about how life should be lived", "it gives me perspective that makes everything at home feel richer"], .identity),
            // ── Observable Evidence ───────────────────────────────────────────────
            ("What specific travel goal, if achieved, would prove this vision is real?", 5, ["A specific trip I have planned and taken, not just talked about", "A travel fund that exists and grows with genuine commitment", "A passport with stamps that reflect a life actually lived", "A travel rhythm — regular trips built into my year, not occasional accidents"], .observable),
            ("What measurable travel commitment marks real investment in this part of your life?", 5,
             ["at least two meaningful trips per year", "one long trip of 3+ weeks per year", "visiting a specific number of new countries in the next 5 years", "a dedicated travel fund that I actually use"], .measurable),
            // ── Constraint ───────────────────────────────────────────────────────
            ("What are you ruling out so your best travel experiences can happen?", 5,
             ["cheap travel that saves money but costs the experience", "going to the same places out of comfort", "putting travel off for 'when things settle down'", "travelling in a way that doesn't match who I actually am"], .constraint),
            // ── Tradeoff ─────────────────────────────────────────────────────────
            ("What will you say no to in your budget or schedule so travel becomes a real priority?", 5, ["Spending money on things at home that bring less value than an experience abroad would", "Filling every weekend with obligations that leave no room for adventure", "Waiting for the perfect travel companion or the perfect timing", "The assumption that travel is a reward I will eventually earn — it is a choice I make now"], .tradeoff),
            // ── Milestone Ladder ─────────────────────────────────────────────────
            ("What must be true about your travel life 12 months from now for you to feel on track?", 5,
             ["I've taken at least one trip that felt genuinely meaningful", "I have a travel fund and it's growing", "I've booked the trip I've been talking about for years", "I've travelled with someone I wanted to share the experience with"], .milestone),
            // ── Pre-mortem ────────────────────────────────────────────────────────
            ("What is most likely to stop you from travelling the way you want to, and what's your plan?", 5, ["A budget that has no travel line item — I will build one and treat it as non-negotiable", "Inertia — it is genuinely easier to not book than to book — I will book before I feel ready", "Fear of going alone — I will take one solo trip and discover what I was actually afraid of", "Letting work fill every gap — I will block travel time in my calendar before work fills it"], .premortem),
            // ── Values → Behaviour ───────────────────────────────────────────────
            ("How do your travel values show up in how you plan, spend, and choose in daily life?", 5,
             ["I prioritise experiences over objects when I have a choice", "I set aside money for travel before other discretionary spending", "I research and plan in a way that makes the experience richer", "I say yes to invitations that stretch me, even when they're inconvenient"], .valueBehavior),
            // ── Decision Rule ─────────────────────────────────────────────────────
            ("What principle guides you when choosing between two very different travel experiences?", 5, ["The one I will tell stories about in ten years, not the one that is easiest to organise", "The one that stretches me more — comfort is for home, not travel", "The one that involves people and places I have never experienced — novelty over familiarity", "The one that fits where I am in my life right now — adventure looks different at different chapters"], .decisionRule),
            // ── Qualitative Signal ────────────────────────────────────────────────
            ("What feeling tells you your travel life is everything it should be?", 5,
             ["I have a trip coming up that I'm genuinely excited about", "I'm living stories worth telling, not just accumulating destinations", "I feel like the world is open rather than out of reach", "I return from travel changed in a way that lasts"], .qualitative),
            // ── Environment Design ────────────────────────────────────────────────
            ("What will you build into your life so travel actually happens rather than being perpetually planned?", 5,
             ["a dedicated travel savings account with auto-transfer", "book trips 6+ months in advance so they become fixed", "protect annual leave for travel before anything else claims it", "connect with people who travel seriously so it feels normal and achievable"], .environment),
            // ── Support Network ───────────────────────────────────────────────────
            ("Who do you want to travel with, and what will you commit to together?", 5, ["My partner — we will commit to one meaningful trip together every year without exception", "A close friend — we will plan something we have both been saying we should do and actually do it", "My family — I will plan something that works for everyone and prioritise the shared memory over the perfect destination", "Myself — I will commit to at least one solo trip to prove that I do not need permission to go"], .support),
            // ── Counterfactual ────────────────────────────────────────────────────
            ("If you don't invest in travel for the next 12 months, what experience or window closes?", 5, ["A season of life where the people I most want to travel with are available and willing", "The trip I have been saying I will take for years, which will feel harder and further away", "Another year of living in the same environment with the same perspective — travel breaks that", "The version of me that travel creates — curious, open, and genuinely grateful — stays dormant"], .counterfactual),
            // ── Discovery ─────────────────────────────────────────────────────────
            ("What style of travel feels most like you?", 5,
             ["luxury — I want to be taken care of completely", "adventure — off the beaten path, physically demanding", "cultural immersion — living like a local, not a tourist", "slow travel — staying long enough to actually understand a place", "spontaneous — I want the freedom to decide as I go"], .discovery),
            ("How often do you want to travel in your ideal life?", 5,
             ["once or twice a year — meaningful and intentional", "every quarter — travel is a regular rhythm, not a reward", "constantly — location independence is the goal", "one major trip per year plus shorter domestic ones"], .measurable),
            ("What region or type of destination calls to you most right now?", 5,
             ["Southeast Asia — depth, food, culture, cost", "Europe — history, architecture, refinement", "South America — nature, vibrancy, adventure", "Japan — precision, beauty, contrast", "The Middle East or Africa — unknown and transformative", "The Pacific — remote, peaceful, untouched"], .discovery),
            ("What is the trip that you've been talking about for years but haven't taken?", 5, ["A road trip through a country I have always been drawn to but never explored properly", "An adventure in nature — a long hike, a crossing, something that demands physical commitment", "A cultural deep-dive somewhere completely outside my frame of reference", "A return to somewhere that changed me the first time, to see what has changed in me since"], .northStar),
            ("How do you want to travel — solo, with a partner, with friends, or with family?", 5,
             ["solo — I want to move at my own pace and be fully present", "with my partner — shared experiences that build our relationship", "with close friends — adventure and shared memory", "with family — building a legacy of experiences together", "it depends entirely on the trip"], .discovery),
            ("What does your budget for travel look like in your ideal life?", 5,
             ["a dedicated annual travel fund of $5k–$10k", "$10k–$20k per year spent on experiences", "$20k–$50k — travel is a serious investment", "unlimited — I'm building a life where travel has no budget ceiling"], .measurable),
            ("What kind of accommodation feels right to you?", 5,
             ["five-star hotels — I want comfort and service", "boutique properties with character and location", "private rentals — I want to feel like I live there", "a mix depending on the destination and purpose"], .discovery),
            ("What do you want to come home from travel knowing or feeling?", 5, ["That my world is bigger than the one I live in day to day", "That I am more capable and resilient than I had remembered", "That the people I went with are now closer to me because of what we shared", "That I have genuinely lived — not just worked and waited for the next thing"], .structured),
            ("In 10 years, what does your travel history look like?", 10, ["A collection of meaningful trips — not everywhere, but the places that mattered", "A pattern of regular adventure — travel has become part of how I live, not a rare exception", "Stories I am proud to tell — experiences that changed how I see myself and the world", "Memories with the people I love that we still talk about because they were genuinely extraordinary"], .vivid),
            ("What culture or place has already changed how you see the world?", 5, ["Somewhere that showed me a completely different way to measure a good life", "A place where people had very little by my standards but lived with more richness than I had imagined", "A culture whose relationship with time, family, or work made me question everything I had assumed", "Somewhere that showed me my own culture from the outside — and I have not quite seen it the same way since"], .identity),
        ]
    }

    private func generateLearningQuestions() -> [Q] {
        return [
            // ── North Star ────────────────────────────────────────────────────────
            ("What is the single skill or area of knowledge that, if you mastered it, would change the most about your life?", 5, ["The ability to communicate — write and speak — in a way that genuinely moves people", "Deep domain expertise in my field that makes me undeniably excellent, not just competent", "Financial intelligence — understanding how money moves and how to position myself within that", "Leadership — the ability to build, inspire, and coordinate people toward things that matter"], .northStar),
            ("Describe what being genuinely well-educated looks like for you — not credentials, but capability.", 5, ["I can think clearly under uncertainty and make good decisions without perfect information", "I have enough breadth to connect ideas across domains and enough depth to go somewhere with them", "I can learn anything I need to learn — the skill of learning itself is the real education", "I understand how things actually work — money, people, organisations, nature — at a level that lets me navigate them"], .vivid),
            // ── Why Now ───────────────────────────────────────────────────────────
            ("Why is learning and growth a priority for you right now specifically?", 5, ["The next level I want to reach requires capabilities I do not yet have — and that gap is on me to close", "I can feel myself plateauing and I know what stagnation costs over time", "The world is changing faster than ever and the people who keep learning will have more options", "I want to become someone I am proud of — and that person is defined by how they grow, not just what they have"], .whyNow),
            ("What gap in your knowledge or skill is costing you the most right now?", 5,
             ["a technical skill that would make my work significantly more valuable", "a business or financial skill that opens options I don't currently have", "a people or leadership skill that limits how much I can achieve through others", "a creative skill I've always wanted and kept deferring"], .whyNow),
            // ── Identity ─────────────────────────────────────────────────────────
            ("What kind of learner and thinker are you becoming?", 5, ["Someone who goes deep — I would rather understand a few things completely than many things superficially", "A connector — I find the threads between ideas in different fields and that is where my best thinking lives", "A practical learner — I measure what I know by what I can do, not what I can recite", "A curious person who never loses the feeling that the most interesting idea is always the next one"], .identity),
            ("How does someone with your intellectual curiosity and knowledge show up differently in the world?", 5,
             ["they see connections and patterns others miss", "they ask better questions rather than rushing to answers", "they're genuinely interesting to talk to about almost anything", "they learn faster than almost everyone around them", "they apply what they learn — they're not just collectors of information"], .identity),
            // ── Observable Evidence ───────────────────────────────────────────────
            ("What specific outcome proves that your learning goals are real and not aspirational?", 5, ["I have produced something — built, written, shipped — that would not exist without the learning", "Someone I respect has acknowledged my growth in a way that was not prompted or performed", "I have taught someone else what I know — and they are better for it", "I have used the knowledge to make a real decision that turned out better because of it"], .observable),
            ("What measurable commitment to learning marks real progress?", 5,
             ["completing a specific course, certification, or program", "reading a set number of books per year in the areas that matter most", "applying a new skill in real work within 30 days of learning it", "teaching what I've learned to someone else"], .measurable),
            // ── Constraint ───────────────────────────────────────────────────────
            ("What learning habit or pattern are you ruling out because it wastes time without building anything?", 5,
             ["consuming content passively without applying or retaining it", "starting many things and finishing none of them", "learning what's interesting rather than what moves my life forward", "avoiding the hard skills because the easy ones feel more comfortable"], .constraint),
            // ── Tradeoff ─────────────────────────────────────────────────────────
            ("What will you give up in your daily time budget so real learning gets the space it deserves?", 5, ["Passive scrolling that feels like staying informed but mostly just fills silence", "Entertainment that I consume out of habit rather than genuine enjoyment or restoration", "The illusion of productivity — busy work that feels useful but creates nothing of lasting value", "Saying yes to things that sound interesting but do not move my learning in any meaningful direction"], .tradeoff),
            // ── Milestone Ladder ─────────────────────────────────────────────────
            ("What must be true about your learning 12 months from now for you to feel on track?", 5,
             ["I've completed at least one substantial course or program", "I've applied a new skill in a real context", "I've built a consistent daily learning habit", "I can demonstrably do something I couldn't do 12 months ago"], .milestone),
            // ── Pre-mortem ────────────────────────────────────────────────────────
            ("What is most likely to derail your learning goals, and what's your prevention plan?", 5, ["Starting courses or books and not finishing them — I will complete one thing before starting another", "Letting a busy week become a busy month become a lost year — I will protect one learning block per day", "Consuming passively when I should be practising actively — I will build in application, not just absorption", "Thinking that reading about something is the same as knowing it — I will measure knowledge by what I can do with it"], .premortem),
            // ── Values → Behaviour ───────────────────────────────────────────────
            ("How do your learning values show up in what you actually do each day?", 5,
             ["I read or study every day, even for 20 minutes", "I apply what I'm learning — I don't just consume", "I seek out people who know more than me and ask real questions", "I review and consolidate what I've learned so it actually sticks"], .valueBehavior),
            // ── Decision Rule ─────────────────────────────────────────────────────
            ("What principle guides you when choosing what to learn next?", 5, ["I follow the thing I am genuinely curious about — motivation built on interest outlasts motivation built on obligation", "I learn what the next version of me most needs — not what is impressive, but what is useful", "I go deep before I go broad — mastery in one area compounds into everything else", "I ask: if I knew this deeply, would it change how I see the world or what I can do in it?"], .decisionRule),
            // ── Qualitative Signal ────────────────────────────────────────────────
            ("What feeling tells you your intellectual life is where it should be?", 5,
             ["I feel genuinely curious more than I feel bored", "I'm growing faster than I expected", "I can contribute to conversations that I couldn't engage with before", "I'm solving harder problems than I could last year"], .qualitative),
            // ── Environment Design ────────────────────────────────────────────────
            ("What will you change in your environment so learning becomes easier and more consistent?", 5,
             ["a dedicated time block for learning every day that doesn't move", "a physical space set up for focused study", "a reading list or curriculum that removes the decision of what's next", "reduce the passive consumption that crowds out real learning"], .environment),
            // ── Support Network ───────────────────────────────────────────────────
            ("Who will you learn with or from, and what will you commit to together?", 5, ["A mentor who has already done what I want to do — I will ask for direction, not just encouragement", "A learning partner at a similar level — we will hold each other to showing up and doing the work", "A course or cohort with structure and accountability — I will invest in environments that make quitting harder", "A community built around what I want to learn — I will find where the serious people gather and join them"], .support),
            // ── Counterfactual ────────────────────────────────────────────────────
            ("If your learning habits stay exactly as they are for 12 more months, what opportunity closes?", 5, ["The gap between me and people who kept growing will widen to a point that is hard to close", "A role, project, or conversation I am not yet qualified for stays out of reach for another year", "The confidence that comes from genuine growth — from knowing you are becoming more capable — stays dormant", "I arrive at the end of another year knowing more or less the same as I do today — and I will feel that"], .counterfactual),
            // ── Discovery ─────────────────────────────────────────────────────────
            ("What domains of knowledge genuinely excite and pull you?", 5,
             ["business, strategy, and building things", "technology, AI, and the future of work", "human behaviour, psychology, and what drives people", "history, philosophy, and how ideas shape civilisations", "science, biology, and how the world actually works", "creative skills — writing, design, music, storytelling"], .discovery),
            ("How do you learn best?", 5,
             ["through books — deep, linear, and thorough", "through courses with structure and progression", "through doing and building — I need to apply it immediately", "through conversation and debate with smart people", "through teaching — explaining forces real understanding"], .discovery),
            ("What credential, qualification, or certification would genuinely change your options?", 5, ["A professional qualification that opens doors currently closed to me", "A credential that gives credibility to skills I already have but cannot yet prove formally", "A licence or certification that lets me work in a way I currently cannot", "An academic or professional designation that signals a level of rigour and commitment to my field"], .measurable),
            ("What is the most intellectually ambitious goal you have in the next 5 years?", 5, ["Publishing something — a book, a body of work — that reflects genuine depth of thinking", "Building expertise recognised beyond my immediate organisation or community", "Completing a qualification or programme that is genuinely hard and that I am proud of", "Mastering a domain to the point where others come to me as a reference, not the other way around"], .northStar),
            ("What subject, if you knew it deeply, would make you significantly more valuable professionally?", 5, ["The financial and commercial mechanics of my industry — how money actually moves through it", "Data and systems thinking — the ability to see patterns and build things that scale", "Communication and persuasion — the ability to make complex ideas land clearly and memorably", "Strategy and decision-making — knowing how to choose well when the answer is not obvious"], .northStar),
            ("What creative skill have you always wanted but kept putting off?", 5,
             ["writing — long-form, precise, compelling", "design — visual communication and aesthetics", "programming — the ability to build things digitally", "music — performance, production, or composition", "public speaking — the ability to move an audience"], .whyNow),
            ("How much time per day are you willing to commit to intentional learning?", 5,
             ["20–30 minutes — a sustainable daily habit", "1 hour — a serious daily investment", "2+ hours — learning is a primary priority right now", "it varies — I go in focused sprints rather than daily habits"], .measurable),
            ("What do you want to know in 10 years that you don't know now?", 10, ["How to lead at a level of genuine complexity — organisations, crises, people at scale", "How the world works at a systems level — economics, history, human nature — not just my corner of it", "How to build things that outlast me — institutions, businesses, knowledge that compounds", "How to live well — not just perform well — in a way that gets richer with time rather than more exhausting"], .vivid),
            ("Who is the person you most want to think like, and what do they know that you don't?", 5, ["Someone who sees the system, not just the task — they understand why things are the way they are", "A person with genuine wisdom — earned through experience, failure, and reflection, not just study", "Someone who combines rigorous thinking with creative application — they know and they make", "A person who has navigated real complexity and uncertainty and come out with better principles, not just better answers"], .identity),
            ("What would you study if outcome didn't matter — purely for the love of it?", 5, ["Philosophy — the great questions about how to live, what is real, what we owe each other", "History — how the world got here, what repeats, what the past can teach us about now", "A creative discipline — music, writing, art — purely for the joy of making something", "A science — the physical world, the cosmos, or the complexity of living systems — purely out of wonder"], .identity),
        ]
    }

    private func generateGenericQuestions(for categoryName: String) -> [Q] {
        return [
            // North Star
            ("What does success in '\(categoryName)' look like for you — describe the specific outcome?", 5, ["A life where this area no longer causes me stress or regret", "A clear outcome I have defined and am measurably moving toward", "The feeling that I am genuinely proud of where I am in this area", "Something specific and real that I could show someone to prove it"], .northStar),
            ("Describe a day in your life when '\(categoryName)' is exactly where you want it to be.", 5, ["I wake up with energy and purpose and this area of my life contributes to that", "Everything in this area works — quietly, reliably, in the background", "I am fully present and this area of my life feels aligned with who I am", "I feel proud — not in a performance way, but in a genuine settled way"], .vivid),
            // Why Now
            ("Why does '\(categoryName)' matter to you right now in your life?", 5, ["Because the cost of not changing is already showing up in my life", "Because I am at a point where I finally have the clarity and readiness to act", "Because this matters to the people I love and therefore it matters to me", "Because I do not want to look back and wish I had started now"], .whyNow),
            // Identity
            ("What kind of person are you becoming through your progress in '\(categoryName)'?", 5, ["Someone who follows through on the things that matter — consistently, not just when it is easy", "A person with real discipline in this area who does not need to rely on motivation", "Someone whose actions in this area align with the values they say they hold", "A person who will be genuinely proud to look back on this chapter"], .identity),
            // Observable Evidence
            ("What would someone you respect see that proves you've achieved your '\(categoryName)' goal?", 5, ["They see me pull up in it — that is the moment", "My lifestyle overall reflects the level the car represents", "My finances are solid enough that the car did not stretch me", "I talk about it with pride, not stress"], .observable),
            // Measurable
            ("What specific, trackable metric marks real progress in '\(categoryName)'?", 5, ["A number I have defined that I check monthly without excuses", "A behaviour I do consistently — frequency and quality, not just intention", "An outcome that someone else could observe and confirm without my help", "A before-and-after that I can point to and say — that is what changed"], .measurable),
            // Constraint
            ("What are you ruling out so you can stay focused on '\(categoryName)'?", 5, ["Everything that looks like progress but is not — busy work, performance, and comfortable distraction", "Options that are good but not right — saying yes to the right thing means saying no to a lot of good things", "The tendency to start new things before finishing what I have committed to", "Anything that divides my attention without a proportional return on what matters here"], .constraint),
            // Tradeoff
            ("What will you say no to so '\(categoryName)' gets the attention it deserves?", 5, ["The things that fill my time without moving this forward", "The people or obligations that consistently take more than they give in this area", "The version of me that says yes to avoid the discomfort of saying no", "Anything that feels like action but is really just postponing the real decision"], .tradeoff),
            // Milestone
            ("What must be true 12 months from now for '\(categoryName)' to be on track?", 5, ["I have moved from intention to consistent action — and I can prove it", "The foundation is in place — the decisions have been made and the habits are running", "Someone who knows me well can see the change without me telling them", "I am further along than I was and the direction is unmistakably clear"], .milestone),
            // Pre-mortem
            ("What is most likely to derail your '\(categoryName)' goal, and what is your plan?", 5, ["A period of high pressure that makes it feel justified to deprioritise this temporarily — but temporary becomes permanent", "The gap between my intention and my systems — wanting it without building the structure that supports it", "Comparing my progress to others instead of to my own baseline", "Losing the emotional connection to why this matters — so I will keep that visible and specific"], .premortem),
            // Values → Behaviour
            ("How do your values in '\(categoryName)' show up in what you actually do each day?", 5, ["I make small decisions that align with what I say I care about — and I am consistent, not occasional", "The people close to me can see what I value by watching how I spend my time and energy", "I do not need to announce my values — they show up in what I actually do", "I use my values as a filter when I am tempted — and the answer is usually clear"], .valueBehavior),
            // Decision Rule
            ("What principle guides your decisions in '\(categoryName)' when two options seem equal?", 5, ["The option that aligns with who I am becoming, not just what feels easiest right now", "The choice I will be proud of in five years, not just comfortable with today", "The decision that serves the long-term without destroying the short-term", "Whatever moves me closer to the version of this area I have committed to"], .decisionRule),
            // Qualitative Signal
            ("If you can't measure progress in '\(categoryName)' with a number, what feeling tells you you're on track?", 5, ["A quiet confidence that this area of my life is moving in the right direction", "The absence of the anxiety or regret that used to be here", "A sense of alignment — my actions and my values are pointing at the same thing", "The feeling of becoming someone I respect in this area — not performing it, but genuinely living it"], .qualitative),
            // Environment Design
            ("What will you change in your environment to make success in '\(categoryName)' more likely?", 5, ["Remove the friction that makes the wrong choice easy and add friction that makes the right choice easier", "Surround myself with people who are already where I want to be in this area", "Make the goal visible — literally visible — so I am reminded of it daily", "Structure my time so this gets the best hours, not the leftovers"], .environment),
            // Support
            ("Who will support you in '\(categoryName)', and what specifically will you ask of them?", 5, ["Someone who has already done what I want to do and will give me honest direction", "A peer who is working on the same thing so we can keep each other accountable", "Someone close to me who understands why this matters and will call me out when I drift", "A professional or expert who can give me structured support I cannot give myself"], .support),
            // Counterfactual
            ("If nothing changes in '\(categoryName)' for 12 months, what gets significantly worse?", 5, ["The cost of staying here gets higher — and it is already costing me more than I admit", "I arrive at the same point next year with the same regret I have now", "The gap between who I am and who I want to be in this area widens", "I prove to myself again that I say things matter without acting like they do"], .counterfactual),
            // Structured Template
            ("Complete this: In \(5) years, I will [outcome] in '\(categoryName)'. I'll know because [evidence]. The first step is [action] this week.", 5, ["In [timeframe] years, I will have [specific outcome] in this area. I will know because [evidence I can observe]. The first step I am taking this week is [one specific action].", "I will have built [something concrete]. The evidence will be [something measurable or visible]. This week I will [the smallest real step].", "I will be [description of who I am in this area]. People around me will notice [observable change]. I start by [action this week].", "My future self will look back on this moment as when I decided — and actually followed through."], .structured),
        ]
    }


    // MARK: - AI-Generated Follow-up Questions
    
    func generateFollowUpQuestions(
        categoryId: UUID,
        categoryName: String,
        previousAnswers: [VisionAnswer],
        timeframeYears: Int,
        count: Int = 3
    ) async -> [VisionQuestion] {
        // This is a placeholder for AI integration
        // In production, this would call OpenAI API
        
        let prompt = buildPrompt(
            categoryName: categoryName,
            previousAnswers: previousAnswers,
            timeframeYears: timeframeYears
        )
        
        do {
            let generatedQuestions = try await callOpenAIAPI(prompt: prompt, count: count)
            return generatedQuestions.map { questionText in
                VisionQuestion(
                    categoryId: categoryId,
                    questionText: questionText,
                    timeframeYears: timeframeYears,
                    isAiGenerated: true,
                    relatedAnswerIds: previousAnswers.map { $0.id }
                )
            }
        } catch {
            print("Error generating AI questions: \(error)")
            return generateFallbackQuestions(
                categoryId: categoryId,
                previousAnswers: previousAnswers,
                timeframeYears: timeframeYears,
                count: count
            )
        }
    }
    
    // MARK: - Synthesize Vision Statement
    
    func synthesizeVisionStatement(
        categoryName: String,
        answers: [VisionAnswer],
        timeframeYears: Int
    ) async -> String {
        let prompt = """
        Based on these answers about someone's vision for their \(categoryName) in \(timeframeYears) years:
        
        \(answers.map { "Q: \($0.questionText)\nA: \($0.answerText)" }.joined(separator: "\n\n"))
        
        Create a concise, inspiring vision statement (2-3 sentences) that synthesizes their core vision. \
        Make it personal and specific, not generic. Use active, present tense as if describing their future reality.
        """
        
        do {
            let statement = try await callOpenAIAPI(prompt: prompt, count: 1).first ?? ""
            return statement
        } catch {
            print("Error synthesizing vision statement: \(error)")
            return "Vision statement pending..."
        }
    }
    
    // MARK: - Synthesize Vision Timeline
    struct VisionTimelineResult {
        let headline: String
        let narrative: String
    }
    
    func synthesizeVisionTimeline(
        answers: [VisionAnswer],
        timeframeYears: Int
    ) async -> VisionTimelineResult {
        // This is a placeholder for AI integration
        // In production, this would call OpenAI API
        let joinedAnswers = answers.map { "\($0.questionText)\n\($0.answerText)" }.joined(separator: "\n\n")
        let headline = "Your \(timeframeYears)-Year Vision: A Journey of Growth"
        let narrative = "In \(timeframeYears) years, you envision: \n" + joinedAnswers
        return VisionTimelineResult(headline: headline, narrative: narrative)
    }
    
    // MARK: - Private Helpers
    
    private func buildPrompt(
        categoryName: String,
        previousAnswers: [VisionAnswer],
        timeframeYears: Int
    ) -> String {
        let answersContext = previousAnswers
            .map { "Q: \($0.questionText)\nA: \($0.answerText)" }
            .joined(separator: "\n\n")
        
        return """
        User is building their vision for \(categoryName) over the next \(timeframeYears) years.
        
        Their previous answers:
        \(answersContext)
        
        Generate 3 follow-up questions that:
        1. Are PRECISE and SPECIFIC (not broad)
        2. Dig deeper into what they've already shared
        3. Help clarify potential contradictions or dependencies
        4. Are direct and answerable (not open-ended philosophical)
        
        Format: Return ONLY the 3 questions, one per line, without numbering or prefixes.
        """
    }
    
    private func generateFallbackQuestions(
        categoryId: UUID,
        previousAnswers: [VisionAnswer],
        timeframeYears: Int,
        count: Int
    ) -> [VisionQuestion] {
        // If AI fails, return contextual follow-ups based on answer patterns
        let fallbackQuestions = [
            "What obstacles might you need to overcome to achieve this?",
            "Who or what could help you make this vision a reality?",
            "How would achieving this change your daily life?",
            "What's one concrete step you could take this year toward this vision?",
            "How does this connect to your other life goals?",
            "What would success in this area look like in practical terms?"
        ]
        
        return fallbackQuestions.prefix(count).map { questionText in
            VisionQuestion(
                categoryId: categoryId,
                questionText: questionText,
                timeframeYears: timeframeYears,
                isAiGenerated: false,
                relatedAnswerIds: previousAnswers.map { $0.id }
            )
        }
    }
    
    private func callOpenAIAPI(prompt: String, count: Int) async throws -> [String] {
        return []
    }
}

// --- Helper for context-aware options ---
private func generateContextualOptions(for question: String) -> [String] {
    let lower = question.lowercased()
    if lower.contains("car appeals") {
        return ["Luxury", "Sports", "Practical", "Electric", "SUV", "Convertible"]
    } else if lower.contains("primary purpose of your ideal car") {
        return ["Daily Commute", "Weekend Adventures", "Shows", "Family", "Business"]
    } else if lower.contains("features are non-negotiable") && lower.contains("car") {
        return ["Speed", "Comfort", "Efficiency", "Brand", "Design", "Technology"]
    } else if lower.contains("home setting appeals") {
        return ["Urban", "Suburban", "Rural", "Beach", "Mountains"]
    } else if lower.contains("bedrooms and bathrooms") {
        return ["1 Bedroom", "2 Bedrooms", "3 Bedrooms", "4+ Bedrooms"]
    } else if lower.contains("architectural style") {
        return ["Modern", "Traditional", "Minimalist", "Rustic", "Industrial"]
    } else if lower.contains("work environment") {
        return ["Remote", "Office", "Hybrid", "Outdoors"]
    } else if lower.contains("physical activities") {
        return ["Running", "Cycling", "Swimming", "Gym", "Yoga", "Team Sports"]
    } else if lower.contains("relationship") {
        return ["Trust", "Support", "Communication"]
    } else if lower.contains("travel appeals") {
        return ["Luxury", "Adventure", "Cultural Immersion", "Budget"]
    } else if lower.contains("learning") {
        return ["Formal Education", "Self-Study", "Mentorship", "Experience"]
    }
    // If no match, return empty so only 'Other' is shown
    return []
}
