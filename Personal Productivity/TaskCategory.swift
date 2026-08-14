import Foundation
import SwiftUI

/// Fixed built-in task categories used for AI learning and recommendations.
enum TaskCategory: String, CaseIterable, Identifiable, Codable {
    case coreWork
    case admin
    case planning
    case learning
    case creative
    case meetings
    case maintenance
    case personalTasks
    case health
    case leisure

    var id: String { rawValue }

    /// Built-in English name. Use `displayName` in the UI so user overrides apply.
    var title: String {
        switch self {
        case .coreWork:      return "Core Work"
        case .admin:         return "Emails & Admin"
        case .planning:      return "Planning"
        case .learning:      return "Learning"
        case .creative:      return "Creative"
        case .meetings:      return "Meetings"
        case .maintenance:   return "Fix & Maintain"
        case .personalTasks: return "Personal Tasks"
        case .health:        return "Health & Fitness"
        case .leisure:       return "Free Time"
        }
    }

    /// User-customised name if set, otherwise the built-in title.
    var displayName: String {
        CategoryNameStore.shared.name(for: self)
    }

    /// Returns the user-customised colour, falling back to the built-in default.
    var color: Color {
        CategoryColorStore.shared.color(for: self)
    }

    var icon: String {
        switch self {
        case .coreWork:      return "briefcase.fill"
        case .admin:         return "envelope.fill"
        case .planning:      return "list.bullet.clipboard.fill"
        case .learning:      return "book.fill"
        case .creative:      return "paintbrush.fill"
        case .meetings:      return "person.2.fill"
        case .maintenance:   return "wrench.fill"
        case .personalTasks: return "person.fill"
        case .health:        return "heart.fill"
        case .leisure:       return "gamecontroller.fill"
        }
    }
}
