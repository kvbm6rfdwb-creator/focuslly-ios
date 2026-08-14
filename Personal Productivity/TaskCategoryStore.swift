import Foundation
import Combine

/// Persists task category assignments and whether the assignment was confirmed by the user.
///
/// Design goals:
/// - Does not modify FocusTask model.
/// - Uses task.id as the stable key.
/// - Keeps assignments stable when a task title is edited.
final class TaskCategoryStore: ObservableObject {

    static let shared = TaskCategoryStore()

    private init() {
        load()
    }

    private struct Assignment: Codable {
        var category: TaskCategory
        var isConfirmed: Bool
    }

    private let storageKey = "task_category_assignments_v1"
    private var assignments: [UUID: Assignment] = [:]

    // MARK: - Query

    func category(for taskId: UUID) -> TaskCategory? {
        assignments[taskId]?.category
    }

    func isConfirmed(taskId: UUID) -> Bool {
        assignments[taskId]?.isConfirmed ?? false
    }

    func unconfirmedTaskIDs() -> Set<UUID> {
        Set(assignments.filter { !$0.value.isConfirmed }.map { $0.key })
    }

    // MARK: - Mutations

    func set(category: TaskCategory, for taskId: UUID, confirmed: Bool) {
        assignments[taskId] = Assignment(category: category, isConfirmed: confirmed)
        save()
        objectWillChange.send()
    }

    func markConfirmed(taskId: UUID) {
        guard var current = assignments[taskId] else { return }
        current.isConfirmed = true
        assignments[taskId] = current
        save()
        objectWillChange.send()
    }

    func remove(taskId: UUID) {
        assignments.removeValue(forKey: taskId)
        save()
        objectWillChange.send()
    }
    
    /// Clears all stored category assignments.
    /// Note: this does not delete tasks; it only removes the category mapping.
    func resetAllAssignments() {
        assignments = [:]
        UserDefaults.standard.removeObject(forKey: storageKey)
        objectWillChange.send()
    }

    // MARK: - Persistence

    private func save() {
        let enc = JSONEncoder()
        guard let data = try? enc.encode(assignments) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        let dec = JSONDecoder()
        guard let decoded = try? dec.decode([UUID: Assignment].self, from: data) else { return }
        assignments = decoded
    }
}
