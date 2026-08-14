import Foundation
import Combine
import UserNotifications

final class PipelineStore: ObservableObject {

    static let shared = PipelineStore()

    // MARK: - Published data
    @Published var callLogs:         [CallLog]               = []
    @Published var saleLogs:         [SaleLog]               = []
    @Published var openHouseLogs:    [OpenHouseLog]          = []
    @Published var contentLogs:      [ContentLog]            = []
    @Published var trainingLogs:     [TrainingLog]           = []
    @Published var csatEntries:      [CSATEntry]             = []
    @Published var bigFourChecks:    [BigFourCheck]          = []
    @Published var hotSheetLogs:     [HotSheetReview]        = []
    @Published var cmaLogs:          [CMALog]                = []
    @Published var deals:            [PipelineDeal]          = []
    @Published var durationLearning: [DurationLearningEntry] = []
    @Published var contactMetadata:  [ContactMetadata]       = []

    // MARK: - Configurable targets
    @Published var dailyDialTarget: Int {
        didSet { UserDefaults.standard.set(dailyDialTarget, forKey: Keys.dailyDialTarget) }
    }
    @Published var weeklyDialTarget: Int {
        didSet { UserDefaults.standard.set(weeklyDialTarget, forKey: Keys.weeklyDialTarget) }
    }

    // MARK: - Keys
    private enum Keys {
        static let calls            = "pipeline_calls_v1"
        static let sales            = "pipeline_sales_v1"
        static let openHouses       = "pipeline_openhouses_v1"
        static let content          = "pipeline_content_v1"
        static let training         = "pipeline_training_v1"
        static let csat             = "pipeline_csat_v1"
        static let bigFour          = "pipeline_bigfour_v1"
        static let hotSheet         = "pipeline_hotsheet_v1"
        static let cma              = "pipeline_cma_v1"
        static let deals            = "pipeline_deals_v1"
        static let duration         = "pipeline_duration_v1"
        static let contactMetadata  = "pipeline_contact_metadata_v1"
        static let dailyDialTarget  = "pipeline_daily_dial_target"
        static let weeklyDialTarget = "pipeline_weekly_dial_target"
    }

    // Background queue for all saves
    private let saveQueue = DispatchQueue(label: "com.focuslly.pipeline.save", qos: .utility)

    init() {
        dailyDialTarget  = UserDefaults.standard.integer(forKey: Keys.dailyDialTarget).nonZero ?? 55
        let stored = UserDefaults.standard.integer(forKey: Keys.weeklyDialTarget)
        // If nothing stored, or the stored value is the old wrong default (300),
        // derive from dailyDialTarget × 7 so it stays in sync.
        let daily = UserDefaults.standard.integer(forKey: Keys.dailyDialTarget).nonZero ?? 55
        weeklyDialTarget = (stored == 0 || stored == 300) ? daily * 7 : stored
        loadAll()
    }

    // MARK: - CRUD: Calls
    func addCall(_ log: CallLog) {
        callLogs.insert(log, at: 0)
        saveAsync(callLogs, key: Keys.calls)
        scheduleFollowUpNotifications()
    }

    func updateCall(_ log: CallLog) {
        if let idx = callLogs.firstIndex(where: { $0.id == log.id }) {
            callLogs[idx] = log
            saveAsync(callLogs, key: Keys.calls)
            scheduleFollowUpNotifications()
        }
    }

    func deleteCall(id: UUID) {
        callLogs.removeAll { $0.id == id }
        saveAsync(callLogs, key: Keys.calls)
        scheduleFollowUpNotifications()
    }

    // MARK: - CRUD: Sales / Outcomes
    func addSale(_ log: SaleLog) {
        saleLogs.insert(log, at: 0)
        // Auto-log activity on linked deal
        if let dealID = log.dealID {
            let actType: DealActivityLog.ActivityType = {
                switch log.type {
                case .offerSent:                    return .offerSent
                case .listingSigned:                return .listingSigned
                case .closedDeal:                   return .closedSale
                default:                            return .focusSession
                }
            }()
            logDealActivity(dealID: dealID, type: actType, notes: log.notes)
            // Increment counters
            if log.type == .offerSent {
                incrementDealCounter(dealID: dealID, keyPath: \.offersCount)
            }
        }
        saveAsync(saleLogs, key: Keys.sales)
    }

    func updateSale(_ log: SaleLog) {
        if let idx = saleLogs.firstIndex(where: { $0.id == log.id }) {
            saleLogs[idx] = log
            saveAsync(saleLogs, key: Keys.sales)
        }
    }

    func deleteSale(id: UUID) {
        saleLogs.removeAll { $0.id == id }
        saveAsync(saleLogs, key: Keys.sales)
    }

    // MARK: - CRUD: Open House
    func addOpenHouse(_ log: OpenHouseLog) {
        openHouseLogs.insert(log, at: 0)
        saveAsync(openHouseLogs, key: Keys.openHouses)
    }

    func updateOpenHouse(_ log: OpenHouseLog) {
        if let idx = openHouseLogs.firstIndex(where: { $0.id == log.id }) {
            openHouseLogs[idx] = log
            saveAsync(openHouseLogs, key: Keys.openHouses)
        }
    }

    func deleteOpenHouse(id: UUID) {
        openHouseLogs.removeAll { $0.id == id }
        saveAsync(openHouseLogs, key: Keys.openHouses)
    }

    // MARK: - CRUD: Content
    func addContent(_ log: ContentLog) {
        contentLogs.insert(log, at: 0)
        saveAsync(contentLogs, key: Keys.content)
    }

    func updateContent(_ log: ContentLog) {
        if let idx = contentLogs.firstIndex(where: { $0.id == log.id }) {
            contentLogs[idx] = log
            saveAsync(contentLogs, key: Keys.content)
        }
    }

    func deleteContent(id: UUID) {
        contentLogs.removeAll { $0.id == id }
        saveAsync(contentLogs, key: Keys.content)
    }

    // MARK: - CRUD: Training
    func addTraining(_ log: TrainingLog) {
        trainingLogs.insert(log, at: 0)
        saveAsync(trainingLogs, key: Keys.training)
    }

    func updateTraining(_ log: TrainingLog) {
        if let idx = trainingLogs.firstIndex(where: { $0.id == log.id }) {
            trainingLogs[idx] = log
            saveAsync(trainingLogs, key: Keys.training)
        }
    }

    func deleteTraining(id: UUID) {
        trainingLogs.removeAll { $0.id == id }
        saveAsync(trainingLogs, key: Keys.training)
    }

    // MARK: - CRUD: CSAT
    func addCSAT(_ entry: CSATEntry) {
        csatEntries.insert(entry, at: 0)
        saveAsync(csatEntries, key: Keys.csat)
    }

    func updateCSAT(_ entry: CSATEntry) {
        if let idx = csatEntries.firstIndex(where: { $0.id == entry.id }) {
            csatEntries[idx] = entry
            saveAsync(csatEntries, key: Keys.csat)
        }
    }

    func deleteCSAT(id: UUID) {
        csatEntries.removeAll { $0.id == id }
        saveAsync(csatEntries, key: Keys.csat)
    }

    // MARK: - CRUD: Big Four
    func saveBigFour(_ check: BigFourCheck) {
        bigFourChecks.removeAll { Calendar.current.isDate($0.date, inSameDayAs: check.date) }
        bigFourChecks.insert(check, at: 0)
        saveAsync(bigFourChecks, key: Keys.bigFour)
    }

    // MARK: - CRUD: Hot Sheet
    func logHotSheetReview() {
        guard !Calendar.current.isDateInToday(hotSheetLogs.first?.date ?? .distantPast) else { return }
        let entry = HotSheetReview(date: Date(), completed: true)
        hotSheetLogs.insert(entry, at: 0)
        saveAsync(hotSheetLogs, key: Keys.hotSheet)
    }

    // MARK: - CRUD: CMA
    func addCMA(_ log: CMALog) {
        cmaLogs.insert(log, at: 0)
        saveAsync(cmaLogs, key: Keys.cma)
    }

    func updateCMA(_ log: CMALog) {
        if let idx = cmaLogs.firstIndex(where: { $0.id == log.id }) {
            cmaLogs[idx] = log
            saveAsync(cmaLogs, key: Keys.cma)
        }
    }

    func deleteCMA(id: UUID) {
        cmaLogs.removeAll { $0.id == id }
        saveAsync(cmaLogs, key: Keys.cma)
    }

    // MARK: - CRUD: Deals
    func addDeal(_ deal: PipelineDeal) {
        deals.insert(deal, at: 0)
        saveAsync(deals, key: Keys.deals)
    }

    func updateDeal(_ deal: PipelineDeal) {
        if let idx = deals.firstIndex(where: { $0.id == deal.id }) {
            deals[idx] = deal
            saveAsync(deals, key: Keys.deals)
        }
    }

    func deleteDeal(id: UUID) {
        deals.removeAll { $0.id == id }
        saveAsync(deals, key: Keys.deals)
    }

    // MARK: - Deal Activity Logging

    /// Log a timestamped activity against a deal and save.
    func logDealActivity(dealID: UUID, type: DealActivityLog.ActivityType,
                         notes: String = "", taskID: UUID? = nil, durationMinutes: Int? = nil) {
        guard let idx = deals.firstIndex(where: { $0.id == dealID }) else { return }
        let entry = DealActivityLog(dealID: dealID, type: type, notes: notes,
                                    taskID: taskID, durationMinutes: durationMinutes)
        deals[idx].activityLog.insert(entry, at: 0)
        deals[idx].updatedAt = Date()
        saveAsync(deals, key: Keys.deals)
    }

    /// Increment a numeric counter on a deal (offers, listings, calls, sessions).
    func incrementDealCounter(dealID: UUID, keyPath: WritableKeyPath<PipelineDeal, Int>) {
        guard let idx = deals.firstIndex(where: { $0.id == dealID }) else { return }
        deals[idx][keyPath: keyPath] += 1
        deals[idx].updatedAt = Date()
        saveAsync(deals, key: Keys.deals)
    }

    /// Called by TaskStore when a pipeline-tagged FocusTask completes.
    func recordTaskCompletion(task: FocusTask, durationMinutes: Int) {
        guard let category = task.pipelineCategory else { return }

        // Map task category to deal activity type
        let actType: DealActivityLog.ActivityType = {
            switch category {
            case .followUps:        return .followUpCall
            case .sendOffers:       return .offerSent
            case .addListing:       return .listingAdded
            case .meeting:          return .meetingHeld
            case .cmaAdmin:         return .cmaPrepped
            case .answerInquiries, .coldCalls, .physicalTraining, .reading: return .focusSession
            }
        }()

        // If linked to a specific deal, log there
        if let dealID = task.linkedDealID {
            logDealActivity(dealID: dealID, type: actType, taskID: task.id, durationMinutes: durationMinutes)
            switch category {
            case .sendOffers:  incrementDealCounter(dealID: dealID, keyPath: \.offersCount)
            case .addListing:  incrementDealCounter(dealID: dealID, keyPath: \.listingsAddedCount)
            case .coldCalls, .followUps: incrementDealCounter(dealID: dealID, keyPath: \.callsCount)
            default: incrementDealCounter(dealID: dealID, keyPath: \.focusSessionsCount)
            }
        }

        // Auto-log training sessions separately and increment daily discipline counter
        if category == .physicalTraining {
            let log = TrainingLog(durationMinutes: durationMinutes, topic: task.title)
            addTraining(log)
            // Also bump today's discipline training counter
            var today = bigFourToday
            today.completedTraining += 1
            saveBigFour(today)
        }
    }

    // MARK: - MyNumbers Analytics

    /// Average number of calls logged before a deal moves past .contacted stage.
    var avgCallsBeforeContact: Double? {
        let relevant = deals.filter { $0.stage.rawValue != DealStage.lead.rawValue && $0.callsCount > 0 }
        guard !relevant.isEmpty else { return nil }
        return Double(relevant.reduce(0) { $0 + $1.callsCount }) / Double(relevant.count)
    }

    /// Average offers sent before a listing is signed (across closed+listing-signed deals).
    var avgOffersBeforeListing: Double? {
        let relevant = deals.filter {
            ($0.stage == .listing || $0.stage == .offer || $0.stage == .closed) && $0.offersCount > 0
        }
        guard !relevant.isEmpty else { return nil }
        return Double(relevant.reduce(0) { $0 + $1.offersCount }) / Double(relevant.count)
    }

    /// Average new listings added per deal before a sale closes.
    var avgListingsBeforeSale: Double? {
        let relevant = deals.filter { $0.stage == .closed && $0.listingsAddedCount > 0 }
        guard !relevant.isEmpty else { return nil }
        return Double(relevant.reduce(0) { $0 + $1.listingsAddedCount }) / Double(relevant.count)
    }

    /// Average days from deal creation to closed stage.
    var avgDaysToClose: Double? {
        let closed = deals.filter { $0.stage == .closed }
        guard !closed.isEmpty else { return nil }
        let totalDays = closed.reduce(0.0) { sum, deal in
            let ref = deal.closedAt ?? deal.updatedAt
            return sum + ref.timeIntervalSince(deal.createdAt) / 86400.0
        }
        return totalDays / Double(closed.count)
    }

    /// Average focus sessions invested per closed deal.
    var avgFocusSessionsPerDeal: Double? {
        let relevant = deals.filter { $0.stage == .closed && $0.focusSessionsCount > 0 }
        guard !relevant.isEmpty else { return nil }
        return Double(relevant.reduce(0) { $0 + $1.focusSessionsCount }) / Double(relevant.count)
    }

    /// Total revenue from closed deals.
    var totalRevenueClosed: Double {
        deals.filter { $0.stage == .closed }.compactMap { $0.estimatedValue }.reduce(0, +)
    }

    /// Win rate — closed / (closed + lost)
    var winRate: Double? {
        let closed = deals.filter { $0.stage == .closed }.count
        let lost   = deals.filter { $0.stage == .lost }.count
        guard closed + lost > 0 else { return nil }
        return Double(closed) / Double(closed + lost)
    }

    /// Average time (days) between consecutive stages across all deals.
    var avgDaysPerStage: [DealStage: Double] {
        var stageTotals: [DealStage: (total: Double, count: Int)] = [:]
        for deal in deals {
            // Use activity log to find stage-advance events
            let advances = deal.activityLog.filter { $0.type == .stageAdvanced }.sorted { $0.date < $1.date }
            var prevDate = deal.createdAt
            var stageIdx = 0
            let stages: [DealStage] = [.lead, .contacted, .appointment, .proposal, .listing, .offer]
            for advance in advances {
                guard stageIdx < stages.count else { break }
                let stage = stages[stageIdx]
                let days = advance.date.timeIntervalSince(prevDate) / 86400.0
                stageTotals[stage, default: (0, 0)].total += days
                stageTotals[stage, default: (0, 0)].count += 1
                prevDate = advance.date
                stageIdx += 1
            }
        }
        return stageTotals.mapValues { $0.total / Double($0.count) }
    }

    // MARK: - Duration Learning
    func recordDurationUsed(nextStep: NextStepType, suggested: Int, actual: Int) {
        guard actual != suggested else { return }
        let entry = DurationLearningEntry(nextStepType: nextStep, suggestedMinutes: suggested, actualMinutes: actual)
        durationLearning.append(entry)
        saveAsync(durationLearning, key: Keys.duration)
    }

    func suggestedDuration(for nextStep: NextStepType) -> Int {
        let actuals = durationLearning
            .filter { $0.nextStepType == nextStep }
            .suffix(20)
            .map { $0.actualMinutes }
        guard !actuals.isEmpty else { return nextStep.defaultDurationMinutes }
        let sorted = actuals.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    func learnedSampleCount(for nextStep: NextStepType) -> Int {
        durationLearning.filter { $0.nextStepType == nextStep }.count
    }

    // MARK: - Contact normalisation helper
    static func contactKey(_ name: String) -> String {
        let trimmed = name.lowercased().trimmingCharacters(in: .whitespaces)
        let tokens = trimmed.components(separatedBy: .whitespaces).filter { $0.count > 1 }
        guard !tokens.isEmpty else { return trimmed }
        return tokens.max(by: { $0.count < $1.count }) ?? trimmed
    }

    private static func uniqueContacts(in logs: [CallLog]) -> Set<String> {
        Set(logs.compactMap { log -> String? in
            let n = log.contactName.trimmingCharacters(in: .whitespaces)
            guard !n.isEmpty else { return nil }
            return contactKey(n)
        })
    }

    // MARK: - Daily stats
    var dialsToday: Int {
        callLogs.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    var meaningfulConversationsToday: Int {
        callLogs.filter { Calendar.current.isDateInToday($0.date) && $0.outcome.isMeaningful }.count
    }

    var appointmentAsksToday: Int {
        callLogs.filter {
            Calendar.current.isDateInToday($0.date) && $0.outcome.isConnected && $0.askedForAppointment
        }.count
    }

    var connectedCallsToday: Int {
        callLogs.filter { Calendar.current.isDateInToday($0.date) && $0.outcome.isConnected }.count
    }

    var appointmentAskRateToday: Double {
        guard connectedCallsToday > 0 else { return 1.0 }
        return Double(appointmentAsksToday) / Double(connectedCallsToday)
    }

    var newContactsToday: Int {
        let cal = Calendar.current
        var names: Set<String> = []
        for log in callLogs where cal.isDateInToday(log.date) {
            let n = log.contactName.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty { names.insert(Self.contactKey(n)) }
        }
        for log in saleLogs where cal.isDateInToday(log.date) {
            let n = log.contactName.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty { names.insert(Self.contactKey(n)) }
        }
        for log in cmaLogs where cal.isDateInToday(log.date) {
            let n = log.contactName.trimmingCharacters(in: .whitespaces)
            if !n.isEmpty { names.insert(Self.contactKey(n)) }
        }
        let prevContactNames: Set<String> = {
            var prev: Set<String> = []
            for log in callLogs where !cal.isDateInToday(log.date) {
                let n = log.contactName.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { prev.insert(Self.contactKey(n)) }
            }
            for log in saleLogs where !cal.isDateInToday(log.date) {
                let n = log.contactName.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { prev.insert(Self.contactKey(n)) }
            }
            for log in cmaLogs where !cal.isDateInToday(log.date) {
                let n = log.contactName.trimmingCharacters(in: .whitespaces)
                if !n.isEmpty { prev.insert(Self.contactKey(n)) }
            }
            return prev
        }()
        let genuinelyNew = names.subtracting(prevContactNames).count
        let openHouseNew = openHouseLogs
            .filter { cal.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.contactsCaptured }
        return genuinelyNew + openHouseNew
    }

    var hotSheetReviewedToday: Bool {
        hotSheetLogs.first.map { Calendar.current.isDateInToday($0.date) } ?? false
    }

    var cmaCreatedToday: Int {
        cmaLogs.filter { Calendar.current.isDateInToday($0.date) }.count
    }

    /// Calls today that resulted in an appointment + open houses held today.
    var meetingsToday: Int {
        let apptCalls = callLogs.filter {
            Calendar.current.isDateInToday($0.date) && $0.nextStep == .appointment
        }.count
        let openHouses = openHouseLogs.filter {
            Calendar.current.isDateInToday($0.date)
        }.count
        return apptCalls + openHouses
    }

    var bigFourToday: BigFourCheck {
        bigFourChecks.first { Calendar.current.isDateInToday($0.date) } ?? BigFourCheck(date: Date())
    }

    var trainedToday: Bool { bigFourToday.completedTraining > 0 }

    /// Number of workout sessions logged in the current calendar week (Mon–Sun).
    var weeklyWorkoutCount: Int {
        bigFourChecks.filter { isInCurrentWeek($0.date) && $0.completedTraining > 0 }.count
    }

    /// Whether the user has hit the 3-per-week minimum.
    var weeklyWorkoutGoalMet: Bool { weeklyWorkoutCount >= 3 }

    /// Hours since the last recorded workout session (nil if never trained).
    var hoursSinceLastWorkout: Double? {
        let last = bigFourChecks
            .filter { $0.completedTraining > 0 }
            .sorted { $0.date > $1.date }
            .first
        guard let last else { return nil }
        return Date().timeIntervalSince(last.date) / 3600
    }

    /// True when 72h have passed since the last workout — grace window expired.
    var workoutGraceExpired: Bool {
        (hoursSinceLastWorkout ?? 0) > 72
    }

    /// Total consecutive workouts without breaking either rule:
    ///   1. No gap > 72h between any two consecutive sessions.
    ///   2. The week that each session belongs to must contain >= 3 sessions.
    /// Rule 2 is not enforced for the *current* (in-progress) week.
    var trainingStreak: Int {
        let cal  = Calendar.current
        // All days on which the user trained, sorted newest first
        let trainedDays = bigFourChecks
            .filter { $0.completedTraining > 0 }
            .map    { cal.startOfDay(for: $0.date) }
            .sorted { $0 > $1 }
        guard !trainedDays.isEmpty else { return 0 }

        // Group by calendar week so we can enforce the 3/week rule
        func weekKey(_ date: Date) -> String {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            return "\(comps.yearForWeekOfYear ?? 0)-\(comps.weekOfYear ?? 0)"
        }

        var weekCounts: [String: Int] = [:]
        for day in trainedDays { weekCounts[weekKey(day), default: 0] += 1 }

        let currentWeekKey = weekKey(Date())

        var streak = 0
        for (idx, day) in trainedDays.enumerated() {
            // Rule 1: gap to next (more recent) session must be <= 72h
            if idx > 0 {
                let gapHours = trainedDays[idx - 1].timeIntervalSince(day) / 3600
                if gapHours > 72 { break }
            }
            // Rule 2: the week this session belongs to must have >= 3 sessions,
            //         unless it's the current (not yet finished) week.
            let wk = weekKey(day)
            if wk != currentWeekKey && (weekCounts[wk] ?? 0) < 3 { break }

            streak += 1
        }
        return streak
    }

    // MARK: - Weekly stats
    private func isInCurrentWeek(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var dialsThisWeek: Int {
        callLogs.filter { isInCurrentWeek($0.date) }.count
    }

    var meaningfulConversationsThisWeek: Int {
        callLogs.filter { isInCurrentWeek($0.date) && $0.outcome.isMeaningful }.count
    }

    var appointmentsSetThisWeek: Int {
        callLogs.filter { isInCurrentWeek($0.date) && $0.nextStep == .appointment }.count
    }

    var newContactsThisWeek: Int {
        let weekLogs = callLogs.filter { isInCurrentWeek($0.date) }
        return Self.uniqueContacts(in: weekLogs).count
    }

    var contentPiecesThisWeek: Int {
        contentLogs.filter { isInCurrentWeek($0.date) }.count
    }

    var trainingMinutesThisWeek: Int {
        trainingLogs.filter { isInCurrentWeek($0.date) }.reduce(0) { $0 + $1.durationMinutes }
    }

    var openHouseContactsThisWeekend: Int {
        openHouseLogs
            .filter { isInCurrentWeek($0.date) }
            .reduce(0) { $0 + $1.contactsCaptured }
    }

    // MARK: - Monthly stats
    private func isInCurrentMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: Date(), toGranularity: .month)
    }

    var averageResponseTimeSecondsThisMonth: Double? {
        let times = callLogs.filter { isInCurrentMonth($0.date) }.compactMap { $0.responseTimeSeconds }
        guard !times.isEmpty else { return nil }
        return Double(times.reduce(0, +)) / Double(times.count)
    }

    var csatScoreLast20: Double? {
        let last20 = Array(csatEntries.prefix(20))
        guard !last20.isEmpty else { return nil }
        return last20.map { $0.score }.reduce(0, +) / Double(last20.count)
    }

    var missedLeadPercentage: Double {
        let withTime = callLogs.filter { $0.responseTimeSeconds != nil }
        guard !withTime.isEmpty else { return 0 }
        let slow = withTime.filter { ($0.responseTimeSeconds ?? 0) > 300 }.count
        return Double(slow) / Double(withTime.count) * 100
    }

    var databaseTouchesThisMonth: Int {
        callLogs.filter { isInCurrentMonth($0.date) }.count
    }

    // MARK: - Funnel ratios (all-time data)
    private var recentCalls: [CallLog] { callLogs }
    private func isRecentDate(_ date: Date) -> Bool { true }

    var callToConversationRateIsEstimated: Bool  { recentCalls.isEmpty }
    var callToAppointmentRateIsEstimated: Bool   { recentCalls.isEmpty }
    var appointmentToProposalRateIsEstimated: Bool {
        recentCalls.filter { $0.nextStep == .appointment }.isEmpty
    }
    var proposalToListingRateIsEstimated: Bool {
        saleLogs.filter { isRecentDate($0.date) && $0.type == .offerSent }.isEmpty
    }
    var overallLeadToClientRateIsEstimated: Bool { recentCalls.isEmpty }

    var callToConversationRate: Double {
        let total = recentCalls.count
        guard total > 0 else { return 0.33 }
        let meaningful = recentCalls.filter { $0.outcome.isMeaningful }.count
        return Double(meaningful) / Double(total)
    }

    var callToAppointmentRate: Double {
        let total = recentCalls.count
        guard total > 0 else { return 0.01 }
        let appts = recentCalls.filter { $0.nextStep == .appointment }.count
        return Double(appts) / Double(total)
    }

    var appointmentToProposalRate: Double {
        let appts = recentCalls.filter { $0.nextStep == .appointment }.count
        guard appts > 0 else { return 0.20 }
        let proposals = saleLogs.filter { isRecentDate($0.date) && ($0.type == .offerSent || $0.type == .listingSigned) }.count
        return min(1.0, Double(proposals) / Double(appts))
    }

    var proposalToListingRate: Double {
        let proposals = saleLogs.filter { isRecentDate($0.date) && $0.type == .offerSent }.count
        guard proposals > 0 else { return 0.20 }
        let listings = saleLogs.filter { isRecentDate($0.date) && $0.type == .listingSigned }.count
        return min(1.0, Double(listings) / Double(proposals))
    }

    var overallLeadToClientRate: Double {
        let total = recentCalls.count
        guard total > 0 else { return 0.005 }
        let closed = saleLogs.filter { isRecentDate($0.date) && $0.type == .closedDeal }.count
        return Double(closed) / Double(total)
    }

    // MARK: - Insights

    /// Per lead-source: total calls, appointments set, conversion rate
    struct LeadSourceStat {
        let source: LeadSource
        let calls: Int
        let appointments: Int
        var rate: Double { calls > 0 ? Double(appointments) / Double(calls) : 0 }
    }
    var leadSourceROI: [LeadSourceStat] {
        LeadSource.allCases.compactMap { src in
            let c = callLogs.filter { $0.leadSource == src }
            guard !c.isEmpty else { return nil }
            let appts = c.filter { $0.nextStep == .appointment }.count
            return LeadSourceStat(source: src, calls: c.count, appointments: appts)
        }.sorted { $0.rate > $1.rate }
    }

    /// A contact with an open follow-up, enriched with client type and smart overdue window
    struct FollowUpContact {
        let name: String
        let nextStep: NextStepType
        let daysSince: Int
        let lastCallDate: Date
        let clientType: ClientType?
        let overdueDays: Int          // threshold for this contact type
        var isOverdue: Bool { daysSince >= overdueDays }
        var urgencyLabel: String {
            guard let ct = clientType else { return "Follow up" }
            return ct.shortLabel
        }
    }

    /// Resolve the effective client type for a contact key, with auto-detection from logs
    private func resolvedClientType(for key: String, name: String) -> ClientType? {
        // 1. Explicit CRM value takes priority
        if let meta = contactMetadata.first(where: { $0.id == key }),
           let ct = meta.clientType { return ct }

        // 2. Auto-detect from sale logs
        let nameKey = PipelineStore.contactKey(name)
        let hasClosed = saleLogs.contains {
            PipelineStore.contactKey($0.contactName) == nameKey && $0.type == .closedDeal
        }
        if hasClosed { return .postSale }

        let hasOffer = saleLogs.contains {
            PipelineStore.contactKey($0.contactName) == nameKey && $0.type == .offerSent
        }
        if hasOffer { return .buyerOfferStage }

        return nil
    }

    var smartFollowUps: [FollowUpContact] {
        var seen: Set<String> = []
        var result: [FollowUpContact] = []
        let sorted = callLogs
            .filter { $0.nextStep != .none && $0.nextStep != .nurture }
            .sorted { $0.date > $1.date }

        for log in sorted {
            let key = PipelineStore.contactKey(log.contactName)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)

            let days = Calendar.current.dateComponents([.day], from: log.date, to: Date()).day ?? 0
            let ct = resolvedClientType(for: key, name: log.contactName)

            // Determine overdue window
            let meta = contactMetadata.first(where: { $0.id == key })
            var overdueDays: Int
            if let ct = ct {
                if ct == .buyerActive && (meta?.buyerSaturated == true) {
                    overdueDays = 14
                } else {
                    overdueDays = ct.defaultOverdueDays
                }
            } else {
                overdueDays = 7  // sensible default if no type set
            }

            result.append(FollowUpContact(
                name: log.contactName,
                nextStep: log.nextStep,
                daysSince: days,
                lastCallDate: log.date,
                clientType: ct,
                overdueDays: overdueDays
            ))
        }
        // Sort: overdue first (by severity), then by days since
        return result.sorted {
            if $0.isOverdue != $1.isOverdue { return $0.isOverdue }
            return $0.daysSince > $1.daysSince
        }
    }

    var smartOverdueCount: Int { smartFollowUps.filter { $0.isOverdue }.count }

    // Legacy alias kept for any remaining references
    var overdueFollowUps: [FollowUpContact] { smartFollowUps }
    var overdueFollowUpsCount: Int { smartOverdueCount }

    /// How many days this week (Mon–Sun) the user hit their daily dial target
    var weeklyDialConsistency: (hitDays: Int, totalDays: Int) {
        let cal = Calendar.current
        let today = Date()
        let weekday = cal.component(.weekday, from: today) // 1=Sun, 2=Mon...
        // Days elapsed Mon–today (Mon=1 ... Sun=7)
        let daysElapsed = weekday == 1 ? 7 : weekday - 1
        var hit = 0
        for offset in 0..<daysElapsed {
            guard let day = cal.date(byAdding: .day, value: -(daysElapsed - 1 - offset), to: today) else { continue }
            let count = callLogs.filter { cal.isDate($0.date, inSameDayAs: day) }.count
            if count >= dailyDialTarget { hit += 1 }
        }
        return (hit, daysElapsed)
    }

    /// Average days a deal spends moving through the pipeline per stage
    struct StageDuration {
        let stage: DealStage
        let avgDays: Double
        let dealCount: Int
    }
    var pipelineVelocityByStage: [StageDuration] {
        // For each deal compute total elapsed days and distribute across stages reached
        var stageAccum: [DealStage: [Double]] = [:]
        for deal in deals {
            // Count how many stageAdvanced events exist for this deal
            let advances = deal.activityLog.filter { $0.type == .stageAdvanced }.sorted { $0.date < $1.date }
            let endDate = deal.closedAt ?? deal.updatedAt
            let totalDays = max(1, Calendar.current.dateComponents([.day], from: deal.createdAt, to: endDate).day ?? 1)
            let stagesCount = max(1, advances.count + 1)
            let daysPerStage = Double(totalDays) / Double(stagesCount)
            // Attribute avg days to each stage the deal passed through
            var stage: DealStage = .lead
            stageAccum[stage, default: []].append(daysPerStage)
            for _ in advances {
                guard let next = stage.next else { break }
                stage = next
                stageAccum[stage, default: []].append(daysPerStage)
            }
        }
        return DealStage.allCases.compactMap { stage in
            guard let times = stageAccum[stage], !times.isEmpty else { return nil }
            let avg = times.reduce(0, +) / Double(times.count)
            return StageDuration(stage: stage, avgDays: avg, dealCount: times.count)
        }
    }

    /// Contact-to-appointment and contact-to-sale rate broken down by lead source
    struct SourceConversionStat {
        let source: LeadSource
        let calls: Int
        let appointments: Int
        let sales: Int
        var rate: Double       { calls > 0 ? Double(appointments) / Double(calls) : 0 }
        var saleRate: Double   { calls > 0 ? Double(sales) / Double(calls) : 0 }
        var ratePercent: String     { String(format: "%.1f%%", rate * 100) }
        var saleRatePercent: String { String(format: "%.1f%%", saleRate * 100) }
    }
    var contactToAppointmentBySource: [SourceConversionStat] {
        // Build a lookup: normalised contact name -> lead source (from most recent call)
        var nameToSource: [String: LeadSource] = [:]
        for log in callLogs.sorted(by: { $0.date < $1.date }) {
            let key = PipelineStore.contactKey(log.contactName)
            guard !key.isEmpty else { continue }
            nameToSource[key] = log.leadSource
        }
        return LeadSource.allCases.compactMap { src in
            let c = callLogs.filter { $0.leadSource == src }
            guard !c.isEmpty else { return nil }
            let appts = c.filter { $0.nextStep == .appointment }.count
            // Count closed deals whose contact maps back to this source
            let closedNames: Set<String> = Set(
                saleLogs
                    .filter { $0.type == .closedDeal }
                    .map { PipelineStore.contactKey($0.contactName) }
            )
            let sales = nameToSource
                .filter { $0.value == src && closedNames.contains($0.key) }
                .count
            return SourceConversionStat(source: src, calls: c.count, appointments: appts, sales: sales)
        }.sorted { $0.rate > $1.rate }
    }

    // MARK: - Predictions
    var predictedCallsPerAppointment: Int {
        let rate = callToAppointmentRate > 0 ? callToAppointmentRate : 0.01
        return max(1, Int((1.0 / rate).rounded(.up)))
    }

    var predictedAppointmentsPerListing: Int {
        let combined = appointmentToProposalRate * proposalToListingRate
        let rate = combined > 0 ? combined : 0.04
        return max(1, Int((1.0 / rate).rounded(.up)))
    }

    var predictedCallsPerSale: Int {
        let rate = overallLeadToClientRate > 0 ? overallLeadToClientRate : 0.005
        return max(1, Int((1.0 / rate).rounded(.up)))
    }

    func remainingDialsToday(target: Int? = nil) -> Int {
        max(0, (target ?? dailyDialTarget) - dialsToday)
    }

    var remainingDialsThisWeek: Int {
        max(0, weeklyDialTarget - dialsThisWeek)
    }

    var projectedWeeklyDials: Int {
        let cal = Calendar.current
        let today = Date()
        let weekdayCallsThisWeek = callLogs.filter { log in
            guard isInCurrentWeek(log.date) else { return false }
            let wd = cal.component(.weekday, from: log.date)
            return wd >= 2 && wd <= 6
        }.count
        let dayOfWeek = cal.component(.weekday, from: today)
        let mondayBased = dayOfWeek == 1 ? 5 : min(dayOfWeek - 1, 5)
        let daysElapsed = max(1, mondayBased)
        let daysRemaining = max(0, 5 - daysElapsed)
        let dailyPace = Double(weekdayCallsThisWeek) / Double(daysElapsed)
        return dialsThisWeek + Int(dailyPace * Double(daysRemaining))
    }

    // MARK: - Follow-Up Notifications

    /// Identifier prefix used for all follow-up notifications so they can be
    /// targeted for bulk removal without touching task or insight notifications.
    static let followUpNotificationPrefix = "followup_"

    /// Reschedules all follow-up notifications based on the current call log state.
    /// Call this whenever callLogs change (add / update / delete).
    func scheduleFollowUpNotifications() {
        guard AppSettingsStore.shared.notificationsFollowUp else { return }
        // Build a lightweight contact list directly from callLogs + contactMetadata.
        // Group calls by normalised contact key, pick the most recent call per contact.
        var grouped: [String: (displayName: String, latestCall: CallLog)] = [:]
        for log in callLogs {
            let name = log.contactName.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, log.nextStep != .none else { continue }
            let key = Self.contactKey(name)
            if let existing = grouped[key] {
                if log.date > existing.latestCall.date {
                    grouped[key] = (name, log)
                }
            } else {
                // Prefer display name from ContactMetadata if available.
                let displayName = contactMetadata.first { $0.id == key }?.displayName ?? name
                grouped[key] = (displayName, log)
            }
        }

        let center = UNUserNotificationCenter.current()

        // Remove all previously scheduled follow-up notifications.
        center.getPendingNotificationRequests { pending in
            let followUpIds = pending
                .filter { $0.identifier.hasPrefix(Self.followUpNotificationPrefix) }
                .map { $0.identifier }
            if !followUpIds.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: followUpIds)
            }

            center.getNotificationSettings { settings in
                guard settings.authorizationStatus == .authorized else { return }

                for (key, entry) in grouped {
                    let step     = entry.latestCall.nextStep
                    let dueDays  = UpcomingStepsEngine.dueDays(for: step)
                    let dueDate  = entry.latestCall.date.addingTimeInterval(Double(dueDays) * 86400)

                    // Only schedule if the due date is in the future.
                    guard dueDate > Date() else { continue }

                    let content       = UNMutableNotificationContent()
                    content.title     = "Follow up with \(entry.displayName)"
                    content.body      = "\(step.rawValue) is due today."
                    content.sound     = .default

                    let triggerDate   = Calendar.current.dateComponents(
                        [.year, .month, .day, .hour, .minute],
                        from: dueDate
                    )
                    let trigger       = UNCalendarNotificationTrigger(
                        dateMatching: triggerDate,
                        repeats: false
                    )
                    let identifier    = "\(Self.followUpNotificationPrefix)\(key)"
                    let request       = UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: trigger
                    )
                    center.add(request)
                }
            }
        }
    }

    // MARK: - Persistence
    private func saveAsync<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        saveQueue.async {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - CRUD: Contact Metadata
    func upsertContactMetadata(_ meta: ContactMetadata) {
        var updated = meta
        updated.updatedAt = Date()
        if let idx = contactMetadata.firstIndex(where: { $0.id == meta.id }) {
            contactMetadata[idx] = updated
        } else {
            contactMetadata.append(updated)
        }
        saveAsync(contactMetadata, key: Keys.contactMetadata)
    }

    func contactMeta(for id: String) -> ContactMetadata? {
        contactMetadata.first { $0.id == id }
    }

    func deleteContactMetadata(id: String) {
        contactMetadata.removeAll { $0.id == id }
        saveAsync(contactMetadata, key: Keys.contactMetadata)
    }

    private func loadAll() {
        callLogs         = load([CallLog].self,               key: Keys.calls)       ?? []
        saleLogs         = load([SaleLog].self,               key: Keys.sales)       ?? []
        openHouseLogs    = load([OpenHouseLog].self,          key: Keys.openHouses)  ?? []
        contentLogs      = load([ContentLog].self,            key: Keys.content)     ?? []
        trainingLogs     = load([TrainingLog].self,           key: Keys.training)    ?? []
        csatEntries      = load([CSATEntry].self,             key: Keys.csat)        ?? []
        bigFourChecks    = load([BigFourCheck].self,          key: Keys.bigFour)     ?? []
        hotSheetLogs     = load([HotSheetReview].self,        key: Keys.hotSheet)    ?? []
        cmaLogs          = load([CMALog].self,                key: Keys.cma)         ?? []
        deals            = load([PipelineDeal].self,          key: Keys.deals)       ?? []
        durationLearning = load([DurationLearningEntry].self, key: Keys.duration)    ?? []
        contactMetadata  = load([ContactMetadata].self,        key: Keys.contactMetadata) ?? []
    }
}

// MARK: - Int helper
private extension Int {
    var nonZero: Int? { self == 0 ? nil : self }
}

// MARK: - Calendar helper
private extension Calendar {
    func startOfWeek(for date: Date) -> Date {
        let comps = dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return self.date(from: comps) ?? date
    }
}
