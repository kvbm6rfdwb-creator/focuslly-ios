import Foundation

enum FocusTaskStatus: String, Codable {
    case pending
    case completed
}

enum RecurrenceType: String, Codable, CaseIterable {
    case once
    case daily
    case weekdays
    case custom
}

struct FocusTask: Identifiable, Codable, Hashable {

    let id: UUID
    var title: String
    var focusPlan: FocusPlan
    let startDate: Date
    var status: FocusTaskStatus

    // Scheduling
    var scheduledTime: Date?
    var recurrenceType: RecurrenceType
    var recurrenceDays: [Int]?

    // State
    var useAIScheduling: Bool
    var isActive: Bool
    var pausedAt: Date?

    // Vision link (auto-matched by keyword analysis)
    var visionGoalID: UUID?
    var visionGoalTitle: String?

    // Pipeline link — set when task is created from Quick Start or Call Wizard
    var pipelineCategory: PipelineTaskCategory?
    var linkedDealID: UUID?

    init(
        title: String,
        focusPlan: FocusPlan = .basic(),
        startDate: Date = Date(),
        status: FocusTaskStatus = .pending,
        scheduledTime: Date? = nil,
        recurrenceType: RecurrenceType = .once,
        recurrenceDays: [Int]? = nil,
        useAIScheduling: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.focusPlan = focusPlan
        self.startDate = startDate
        self.status = status
        self.scheduledTime = scheduledTime
        self.recurrenceType = recurrenceType
        self.recurrenceDays = recurrenceDays
        self.useAIScheduling = useAIScheduling
        self.isActive = false
        self.pausedAt = nil
    }

    // Accessing the name of the focus plan
    var focusPlanName: String {
        focusPlan.name
    }

    // Hashable by ID only
    static func == (lhs: FocusTask, rhs: FocusTask) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
