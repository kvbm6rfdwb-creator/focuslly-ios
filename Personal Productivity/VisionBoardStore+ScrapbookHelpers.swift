import Foundation

extension VisionBoardStore {
    /// Short per-category narrative shown on the grid cards.
    func generateNarrative(for category: VisionCategory, timeframe: Int) -> String {
        let catAnswers = answers.filter {
            $0.categoryId == category.id &&
            $0.timeframeYears == timeframe &&
            !$0.answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard !catAnswers.isEmpty else { return "Start answering questions to build your vision here." }

        // Pick the single richest answer (most words, then highest confidence).
        let best = catAnswers.sorted {
            let wa = $0.answerText.split(whereSeparator: \.isWhitespace).count
            let wb = $1.answerText.split(whereSeparator: \.isWhitespace).count
            return wa != wb ? wa > wb : $0.confidence > $1.confidence
        }.first!

        // Normalize + cap for card display.
        var t = best.answerText
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: .whitespaces).filter { !$0.isEmpty }.joined(separator: " ")

        // Strip boilerplate openers.
        let openers = ["i want to ", "i want ", "my goal is to ", "my goal is ",
                       "i will ", "i'm going to ", "i am going to ",
                       "i hope to ", "i plan to "]
        for o in openers where t.lowercased().hasPrefix(o) {
            let rest = String(t.dropFirst(o.count)).trimmingCharacters(in: .whitespaces)
            if let first = rest.first { t = first.uppercased() + rest.dropFirst() }
            break
        }

        // Cap at 120 chars for card legibility.
        if t.count > 120 {
            let prefix = String(t.prefix(120))
            if let cut = prefix.lastIndex(of: " ") { t = String(prefix[..<cut]) + "…" }
            else { t = prefix + "…" }
        }

        // Ensure punctuation.
        if let last = t.last, !".!?…".contains(last) { t += "." }

        return t
    }

    func imageForCategory(_ category: VisionCategory, timeframe: Int) -> URL? {
        // Return the first image for this category and timeframe, if any
        let answers = self.answers.filter { $0.categoryId == category.id && $0.timeframeYears == timeframe }
        return answers.compactMap { $0.imageURLs.first }.first
    }
}
