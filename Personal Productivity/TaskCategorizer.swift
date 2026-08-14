import Foundation

struct TaskCategorizer {

    struct Result {
        let category: TaskCategory
        let confidence: Double
    }

    /// Heuristic, local categorization. Returns a best guess plus a confidence.
    ///
    /// Confidence is intentionally conservative; low-confidence results should trigger user confirmation.
    static func categorize(title: String) -> Result {
        let normalized = normalize(title)
        let tokens = tokenize(normalized)

        var scores: [TaskCategory: Double] = Dictionary(uniqueKeysWithValues: TaskCategory.allCases.map { ($0, 0) })

        func bump(_ category: TaskCategory, _ weight: Double) {
            scores[category, default: 0] += weight
        }

        // Keyword map. Keep it simple and transparent.
        for t in tokens {
            switch t {
            case "email", "emails", "inbox", "message", "messages", "slack", "dm", "reply", "followup", "coordination":
                bump(.admin, 3)

            case "plan", "planning", "prioritize", "prioritizing", "roadmap", "schedule", "scheduling", "weekly", "daily":
                bump(.planning, 3)

            // review/qa → planning (analysis / checking is closest to planning)
            case "review", "qa", "test", "testing", "retro", "retrospective", "check", "checking", "results":
                bump(.planning, 3)

            case "learn", "learning", "study", "upskill", "course", "tutorial", "read", "reading", "docs", "documentation":
                bump(.learning, 3)

            case "idea", "ideas", "ideation", "design", "creative", "brainstorm", "concept", "strategy", "framing":
                bump(.creative, 3)

            case "meeting", "meetings", "call", "calls", "sync", "standup", "1on1", "reviewcall":
                bump(.meetings, 3)

            case "fix", "bug", "bugs", "refactor", "cleanup", "upkeep", "maintenance", "upgrade":
                bump(.maintenance, 2.5)

            // execution / deep-focus tokens → core work
            case "ship", "implement", "build", "execute", "draft", "send", "do":
                bump(.coreWork, 2)

            case "deep", "focus", "analysis", "research", "architecture", "complex":
                bump(.coreWork, 2.5)

            case "shutdown", "wrap", "wrapup", "eod", "tomorrow":
                bump(.planning, 2)

            case "workout", "gym", "run", "walk", "mobility", "stretch", "recovery":
                bump(.health, 3)

            case "personal", "home", "errand", "groceries", "bank":
                bump(.personalTasks, 3)

            case "break", "rest", "relax", "game", "gaming", "netflix", "movie":
                bump(.leisure, 2.5)

            default:
                break
            }
        }

        // Learned corrections (token-level) — conservative additive bump.
        let learned = TaskCategorizationLearningStore.shared.learnedScores(for: normalized)
        for (cat, w) in learned {
            bump(cat, min(4.0, w))
        }

        // Default bias: most tasks are core work unless evidence says otherwise.
        bump(.coreWork, 0.5)

        let sorted = scores.sorted { $0.value > $1.value }
        let best = sorted.first ?? (.coreWork, 0)
        let second = sorted.dropFirst().first ?? (.coreWork, 0)

        // Confidence is based on separation between best and second best.
        let diff = max(0, best.value - second.value)
        let confidence: Double
        if best.value <= 0.5 {
            confidence = 0.2
        } else if diff >= 3 {
            confidence = 0.85
        } else if diff >= 1.5 {
            confidence = 0.65
        } else {
            confidence = 0.45
        }

        return Result(category: best.key, confidence: min(max(confidence, 0.0), 1.0))
    }

    // MARK: - Text helpers

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func tokenize(_ s: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        return s
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
    }
}
