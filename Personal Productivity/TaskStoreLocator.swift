import Foundation

// Singleton locator for TaskStore to allow cross-object access
final class TaskStoreLocator {
    static let shared = TaskStoreLocator()
    private init() {}
    weak var store: TaskStore?
}
