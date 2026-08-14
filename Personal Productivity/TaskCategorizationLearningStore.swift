import Foundation

/// Persists lightweight, transparent phrase → category associations based on user corrections.
///
/// Design goals:
/// - Local-only, deterministic (no network, no ML).
/// - Safe: learned associations only *nudge* categorization and never override explicit user assignments.
/// - Simple: store token-level weights keyed by TaskCategory rawValue.
final class TaskCategorizationLearningStore {

    static let shared = TaskCategorizationLearningStore()

    private init() {
        load()
    }

    private let storageKey = "task_categorization_learning_v1"

    /// token -> [categoryRaw: weight]
    private var tokenWeights: [String: [String: Double]] = [:]

    /// Record that the user explicitly assigned a category to a task title.
    func recordUserCorrection(title: String, category: TaskCategory) {
        let tokens = tokenize(normalize(title))
        guard tokens.isEmpty == false else { return }

        // Conservative learning: small bump per token.
        // This avoids overfitting: a single correction won't dominate forever.
        for t in tokens {
            var map = tokenWeights[t, default: [:]]
            map[category.rawValue, default: 0] += 0.75

            // Mild decay on other categories for this token to sharpen signal.
            for key in map.keys where key != category.rawValue {
                map[key] = (map[key] ?? 0) * 0.98
            }

            tokenWeights[t] = map
        }

        save()
    }

    /// Returns learned score bumps per category for a given title.
    func learnedScores(for title: String) -> [TaskCategory: Double] {
        let tokens = tokenize(normalize(title))
        guard tokens.isEmpty == false else { return [:] }

        var result: [TaskCategory: Double] = [:]
        for t in tokens {
            guard let map = tokenWeights[t] else { continue }
            for (raw, w) in map {
                guard let cat = TaskCategory(rawValue: raw) else { continue }
                result[cat, default: 0] += w
            }
        }
        return result
    }

    /// Clears all learned categorization weights.
    func reset() {
        tokenWeights = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    // MARK: - Persistence

    private func save() {
        guard let data = try? JSONEncoder().encode(tokenWeights) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        guard let decoded = try? JSONDecoder().decode([String: [String: Double]].self, from: data) else { return }
        tokenWeights = decoded
    }

    // MARK: - Text helpers

    private func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func tokenize(_ s: String) -> [String] {
        let separators = CharacterSet.alphanumerics.inverted
        return s
            .components(separatedBy: separators)
            .filter { !$0.isEmpty }
    }
}
