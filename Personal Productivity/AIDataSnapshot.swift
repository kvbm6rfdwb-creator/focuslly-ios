import Foundation

/// Codable snapshot of AI-related on-device caches.
///
/// Purpose: allow export/import via Files app for debugging/backup.
///
/// This intentionally excludes tasks and session logs.
struct AIDataSnapshot: Codable {
    var createdAt: Date

    /// Raw UserDefaults blobs for various AI stores.
    /// Stored as Data so we can round-trip without depending on internal structs.
    var taskCategoryAssignments: Data?
    var taskCategorizationLearning: Data?

    /// Break feedback is stored as a property list array of dictionaries.
    /// Represent as JSON-compatible array so it round-trips across devices iOS versions.
    var breakDurationFeedbackEntries: [[String: AnyCodable]]

    init(
        createdAt: Date = Date(),
        taskCategoryAssignments: Data?,
        taskCategorizationLearning: Data?,
        breakDurationFeedbackEntries: [[String: AnyCodable]]
    ) {
        self.createdAt = createdAt
        self.taskCategoryAssignments = taskCategoryAssignments
        self.taskCategorizationLearning = taskCategorizationLearning
        self.breakDurationFeedbackEntries = breakDurationFeedbackEntries
    }

    static func captureFromUserDefaults() -> AIDataSnapshot {
        let defaults = UserDefaults.standard

        let categoryAssignments = defaults.data(forKey: "task_category_assignments_v1")
        let categorizationLearning = defaults.data(forKey: "task_categorization_learning_v1")

        let rawEntries = defaults.array(forKey: "break_duration_feedback_v1") as? [[String: Any]] ?? []
        let wrappedEntries: [[String: AnyCodable]] = rawEntries.map { dict in
            var out: [String: AnyCodable] = [:]
            for (k, v) in dict {
                out[k] = AnyCodable(v)
            }
            return out
        }

        return AIDataSnapshot(
            taskCategoryAssignments: categoryAssignments,
            taskCategorizationLearning: categorizationLearning,
            breakDurationFeedbackEntries: wrappedEntries
        )
    }

    func applyToUserDefaultsReplacingExisting() {
        let defaults = UserDefaults.standard

        // Replace category assignments
        if let taskCategoryAssignments {
            defaults.set(taskCategoryAssignments, forKey: "task_category_assignments_v1")
        } else {
            defaults.removeObject(forKey: "task_category_assignments_v1")
        }

        // Replace categorization learning
        if let taskCategorizationLearning {
            defaults.set(taskCategorizationLearning, forKey: "task_categorization_learning_v1")
        } else {
            defaults.removeObject(forKey: "task_categorization_learning_v1")
        }

        // Replace break feedback entries
        let raw: [[String: Any]] = breakDurationFeedbackEntries.map { dict in
            var out: [String: Any] = [:]
            for (k, v) in dict {
                out[k] = v.value
            }
            return out
        }
        defaults.set(raw, forKey: "break_duration_feedback_v1")
    }
}

/// Minimal type-erasure wrapper to encode/decode JSON-safe primitives.
/// Supports String/Int/Double/Bool and falls back to String description.
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let b = try? container.decode(Bool.self) {
            value = b
        } else if let i = try? container.decode(Int.self) {
            value = i
        } else if let d = try? container.decode(Double.self) {
            value = d
        } else if let s = try? container.decode(String.self) {
            value = s
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let b as Bool: try container.encode(b)
        case let i as Int: try container.encode(i)
        case let d as Double: try container.encode(d)
        case let s as String: try container.encode(s)
        default:
            try container.encode(String(describing: value))
        }
    }
}
