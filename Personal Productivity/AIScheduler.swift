import Foundation

struct AIScheduler {

    static func generatePlan(for title: String) -> FocusPlan {

        let difficulty = estimateDifficulty(from: title)
        let totalMinutes = totalTime(for: difficulty)

        var remainingFocus = totalMinutes
        var blocks: [FocusBlock] = []

        while remainingFocus > 0 {
            let focusChunk = min(remainingFocus, focusChunk(for: difficulty))
            blocks.append(
                FocusBlock(duration: focusChunk * 60, type: .focus)
            )
            remainingFocus -= focusChunk

            if remainingFocus > 0 {
                blocks.append(
                    FocusBlock(duration: breakChunk(for: difficulty) * 60, type: .breakTime)
                )
            }
        }

        return FocusPlan(blocks: blocks)
    }

    // MARK: - Heuristics
    private static func estimateDifficulty(from title: String) -> Int {
        let lower = title.lowercased()

        if lower.contains("deep") || lower.contains("code") {
            return 3
        }

        if lower.contains("email") || lower.contains("admin") {
            return 1
        }

        return 2
    }

    private static func totalTime(for difficulty: Int) -> Int {
        switch difficulty {
        case 1: return 30
        case 2: return 60
        default: return 90
        }
    }

    private static func focusChunk(for difficulty: Int) -> Int {
        switch difficulty {
        case 1: return 15
        case 2: return 25
        default: return 45
        }
    }

    private static func breakChunk(for difficulty: Int) -> Int {
        difficulty == 3 ? 10 : 5
    }
}

