import Foundation

// MARK: - Follow-Up Task Store
// Persists data about tasks that weren't finished on time so the app can
// suggest a better duration for the follow-up session.

final class FollowUpTaskStore {
    static let shared = FollowUpTaskStore()
    private let key = "followup_task_overruns_v1"

    // MARK: - Public

    /// Record that a task ran out of time.
    /// - originalSeconds: the full planned focus duration
    /// - spentSeconds: how long the user actually worked before time ran out
    func recordOverrun(taskTitle: String, originalSeconds: Int, spentSeconds: Int) {
        let remaining = max(0, originalSeconds - spentSeconds)
        var history = load()
        let normalised = normalise(taskTitle)
        var entries = history[normalised] ?? []
        entries.append(remaining)
        // Keep the last 10 overruns only
        if entries.count > 10 { entries = Array(entries.suffix(10)) }
        history[normalised] = entries
        save(history)
    }

    /// Suggest how many minutes the follow-up task needs.
    /// Uses: remaining time from this session + average historic overrun for this task.
    /// - Returns: suggested minutes, clamped to 5…600.
    func suggestedFollowUpMinutes(
        taskTitle: String,
        originalSeconds: Int,
        spentSeconds: Int
    ) -> Int {
        let remainingNow = max(0, originalSeconds - spentSeconds)
        let history = load()
        let normalised = normalise(taskTitle)
        let past = history[normalised] ?? []

        // Difficulty modifier: tasks the user has consistently not finished
        // get a 20 % buffer added on top of the raw remaining time.
        let difficultyBuffer: Double
        if past.count >= 2 {
            let avgOverrun = past.map(Double.init).reduce(0, +) / Double(past.count)
            difficultyBuffer = avgOverrun * 0.2
        } else {
            difficultyBuffer = 0
        }

        let totalSeconds = Double(remainingNow) + difficultyBuffer
        let minutes = max(5, min(600, Int((totalSeconds / 60).rounded())))
        return minutes
    }

    // MARK: - Private

    private func normalise(_ title: String) -> String {
        title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func load() -> [String: [Int]] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [Int]].self, from: data)
        else { return [:] }
        return decoded
    }

    private func save(_ dict: [String: [Int]]) {
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
