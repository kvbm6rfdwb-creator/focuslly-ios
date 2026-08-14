import Foundation

// MARK: - Vision Task Linker
// Automatically matches a task title to the most relevant Vision category
// using weighted keyword scoring. No ML required — runs in microseconds.

struct VisionTaskLinker {

    struct Match {
        let categoryID: UUID
        let categoryName: String
        let confidence: Double   // 0..1
    }

    // MARK: - Real-estate keyword clusters mapped to Vision category name fragments
    // The linker scores each category by how many of its keywords appear in the task title.
    // Category name matching is additive: a Vision category called "Income & Sales"
    // scores higher for call/listing/offer keywords than one called "Family".

    private static let realEstateKeywords: [String: [String]] = [
        "income":       ["call", "dial", "lead", "offer", "listing", "sale", "sold", "contract", "negotiat", "commi"],
        "client":       ["client", "buyer", "seller", "tenant", "prospect", "meeting", "appointment", "present"],
        "property":     ["property", "house", "flat", "apartment", "condo", "valuat", "cma", "inspection", "viewing"],
        "marketing":    ["content", "post", "video", "instagram", "linkedin", "ad ", "campaign", "brand", "market"],
        "learning":     ["train", "course", "study", "read", "practise", "practice", "certif", "webinar"],
        "health":       ["gym", "run", "workout", "meditat", "sleep", "walk", "exercise", "yoga"],
        "personal":     ["family", "personal", "home", "relax", "holiday", "vacation", "friend"],
        "finance":      ["budget", "invest", "saving", "tax", "expense", "revenue", "profit", "cost"],
        "admin":        ["email", "invoice", "crm", "report", "plan", "review", "organis", "document"]
    ]

    // MARK: - Public

    /// Returns the best Vision category match for the given task title, or nil if confidence is too low.
    static func match(taskTitle: String, categories: [(id: UUID, name: String)]) -> Match? {
        guard !categories.isEmpty else { return nil }

        let lower = taskTitle.lowercased()
        var scores: [(UUID, String, Double)] = []

        for cat in categories {
            var score: Double = 0

            // Score from keyword clusters that overlap with the category name
            for (cluster, keywords) in realEstateKeywords {
                let clusterRelevance = categorySimilarity(catName: cat.name.lowercased(), cluster: cluster)
                guard clusterRelevance > 0 else { continue }
                let keywordHits = keywords.filter { lower.contains($0) }.count
                score += Double(keywordHits) * clusterRelevance
            }

            // Bonus: direct word overlap between task title and category name
            let catWords = cat.name.lowercased().components(separatedBy: .whitespaces).filter { $0.count > 3 }
            let titleWords = lower.components(separatedBy: .whitespaces)
            let directHits = catWords.filter { catWord in titleWords.contains { $0.contains(catWord) } }.count
            score += Double(directHits) * 0.8

            scores.append((cat.id, cat.name, score))
        }

        guard let best = scores.max(by: { $0.2 < $1.2 }), best.2 > 0.6 else { return nil }

        // Normalise confidence: cap at 1.0 based on max possible score
        let maxPossible = 5.0
        let confidence = min(1.0, best.2 / maxPossible)
        return Match(categoryID: best.0, categoryName: best.1, confidence: confidence)
    }

    // MARK: - Private helpers

    /// Returns how relevant a keyword cluster is to a category name (0 = not relevant, 1 = very relevant).
    private static func categorySimilarity(catName: String, cluster: String) -> Double {
        let directPairs: [String: [String]] = [
            "income":    ["income", "sales", "revenue", "earn", "money", "financ", "business"],
            "client":    ["client", "relationship", "people", "network", "community"],
            "property":  ["property", "real estate", "housing", "asset"],
            "marketing": ["marketing", "brand", "content", "media", "visibility"],
            "learning":  ["learn", "growth", "educat", "skill", "knowledge", "develop"],
            "health":    ["health", "fitness", "wellness", "body", "energy", "mind"],
            "personal":  ["personal", "family", "life", "balance", "happiness", "relation"],
            "finance":   ["financ", "wealth", "invest", "money", "saving"],
            "admin":     ["admin", "organis", "system", "process", "routine"]
        ]
        let markers = directPairs[cluster] ?? []
        let hits = markers.filter { catName.contains($0) }.count
        return hits > 0 ? min(1.0, Double(hits) * 0.5) : 0
    }
}
