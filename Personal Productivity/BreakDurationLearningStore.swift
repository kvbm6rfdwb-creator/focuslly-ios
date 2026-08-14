import Foundation

final class BreakDurationLearningStore {

    static let shared = BreakDurationLearningStore()

    private init() {}

    enum Feedback: String, Codable {
        case tooShort
        case justRight
        case tooLong
    }

    private let key = "break_duration_feedback_v1"

    // MARK: - Category keys
    private func categoryKey(_ category: TaskCategory) -> String {
        "category:" + category.rawValue
    }

    // Legacy (title-based) record
    func record(_ feedback: Feedback, taskTitle: String) {
        let entry: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "feedback": feedback.rawValue,
            "taskTitle": taskTitle
        ]

        var existing = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        existing.append(entry)
        UserDefaults.standard.set(existing, forKey: key)
    }

    // New (category-based) record
    func record(_ feedback: Feedback, category: TaskCategory) {
        let entry: [String: Any] = [
            "timestamp": Date().timeIntervalSince1970,
            "feedback": feedback.rawValue,
            "categoryKey": categoryKey(category)
        ]

        var existing = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        existing.append(entry)
        UserDefaults.standard.set(existing, forKey: key)
    }

    func allFeedback() -> [[String: Any]] {
        UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
    }

    // Legacy (title-based) adjustment
    func adjustedDuration(for taskTitle: String, baseDuration: Int) -> Int {
        let base = max(1, baseDuration)

        let entries = allFeedback().filter { entry in
            (entry["taskTitle"] as? String) == taskTitle
        }

        guard !entries.isEmpty else { return base }

        return adjustedDuration(base: base, entries: entries)
    }

    // New (category-based) adjustment with fallback to legacy taskTitle data.
    func adjustedDuration(for category: TaskCategory, baseDuration: Int, fallbackTaskTitle: String? = nil) -> Int {
        let base = max(1, baseDuration)

        let catKey = categoryKey(category)
        let categoryEntries = allFeedback().filter { entry in
            (entry["categoryKey"] as? String) == catKey
        }

        if !categoryEntries.isEmpty {
            return adjustedDuration(base: base, entries: categoryEntries)
        }

        // Backward compatibility: if we don't yet have category-level feedback,
        // fall back to title-based feedback for this task.
        if let fallbackTaskTitle {
            let legacyEntries = allFeedback().filter { entry in
                (entry["taskTitle"] as? String) == fallbackTaskTitle
            }
            if !legacyEntries.isEmpty {
                return adjustedDuration(base: base, entries: legacyEntries)
            }
        }

        return base
    }

    /// Clears all stored break feedback (both legacy title-based and new category-based entries).
    func resetAllFeedback() {
        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Internal scoring
    private func adjustedDuration(base: Int, entries: [[String: Any]]) -> Int {
        guard !entries.isEmpty else { return base }

        let weights: [Feedback: Double] = [
            .tooShort: 0.10,
            .justRight: 0.0,
            .tooLong: -0.10
        ]

        var sum: Double = 0
        var count: Double = 0

        for entry in entries {
            guard let raw = entry["feedback"] as? String, let fb = Feedback(rawValue: raw) else { continue }
            sum += weights[fb] ?? 0
            count += 1
        }

        guard count > 0 else { return base }

        let avg = sum / count
        let adjusted = Int((Double(base) * (1.0 + avg)).rounded())
        return max(1, adjusted)
    }
}
