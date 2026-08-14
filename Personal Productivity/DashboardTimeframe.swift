import Foundation

// MARK: - Dashboard Timeframe
// Kept in its own file so it cannot be accidentally removed by editor tools.

enum DashboardTimeframe: String, CaseIterable, Identifiable {
    case today = "Today"
    case week  = "Week"
    case month = "Month"
    var id: String { rawValue }
}
