import Foundation

struct FocusDayStat: Identifiable, Codable, Equatable {
    var id: Date { date }
    let date: Date
    let focusedMinutes: Int
    let sessionsCompleted: Int
}

struct FocusStatsSnapshot: Codable, Equatable {
    let focusedMinutesToday: Int
    let sessionsToday: Int
    let currentStreak: Int
    let last7Days: [FocusDayStat]
}
