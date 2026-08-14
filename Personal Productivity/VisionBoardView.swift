import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct VisionBoardView: View {
    @ObservedObject var visionStore: VisionBoardStore
    @State private var selectedTab: VisionBoardTab = .questionQueue
    @State private var showAddCategorySheet = false
    @State private var journalPanel: VisionTimelineView.TimelinePanel = .vision
    @State private var journalTimeframe: Int = 1
    @State private var showStoryMode = false

    enum VisionBoardTab {
        case questionQueue
        case categories
        case journal
    }

    private func categoryProgress(for categoryId: UUID) -> Double {
        let categoryAnswers = visionStore.answers.filter { $0.categoryId == categoryId }
        return min(Double(categoryAnswers.count) / Double(visionCategorySoftCap), 1.0)
    }

    private func answeredCount(for categoryId: UUID) -> Int {
        return visionStore.answers.filter { $0.categoryId == categoryId }.count
    }

    private func totalQuestions(for categoryId: UUID) -> Int {
        return visionCategorySoftCap
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            VStack(spacing: 0) {
                VisionBoardHeader(
                    selectedTab: $selectedTab,
                    journalPanel: $journalPanel,
                    journalTimeframe: $journalTimeframe,
                    onStoryMode: { showStoryMode = true }
                )
                Group {
                    switch selectedTab {
                    case .questionQueue:
                        DailyQuestionsView(visionStore: visionStore)
                    case .categories:
                        CategoriesView(visionStore: visionStore, showAddCategorySheet: $showAddCategorySheet)
                    case .journal:
                        VisionTimelineView(visionStore: visionStore, timelinePanel: $journalPanel, selectedTimeframe: $journalTimeframe)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: selectedTab)
        }
        .environmentObject(visionStore)
        .sheet(isPresented: $showAddCategorySheet) { AddCategorySheet(visionStore: visionStore) }
        .fullScreenCover(isPresented: $showStoryMode) {
            VisionStoryModeView(visionStore: visionStore, selectedTimeframe: journalTimeframe, categoryOrder: visionStore.categories.map { $0.id })
        }
    }
}

// MARK: - Vision Board Header

private struct VisionBoardHeader: View {
    @Binding var selectedTab: VisionBoardView.VisionBoardTab
    @Binding var journalPanel: VisionTimelineView.TimelinePanel
    @Binding var journalTimeframe: Int
    let onStoryMode: () -> Void

    private var subtitle: String {
        switch selectedTab {
        case .questionQueue: return "Daily reflection"
        case .categories:    return "Your life areas"
        case .journal:       return ""
        }
    }

    private var timeframeLabel: String {
        journalTimeframe == 1 ? "1-Year Vision" : "\(journalTimeframe)-Year Vision"
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Rectangle()
                .fill(.bar)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.primary.opacity(0.10)).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 11) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.brgBright.opacity(0.12))
                            .frame(width: 38, height: 38)
                        Image(systemName: "mountain.2.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brgBright)
                    }

                    if selectedTab == .journal {
                        Picker("", selection: $journalPanel) {
                            ForEach(VisionTimelineView.TimelinePanel.allCases, id: \.self) { panel in
                                Text(panel.rawValue).tag(panel)
                            }
                        }
                        .pickerStyle(.segmented)
                        .transition(.opacity.combined(with: .scale(scale: 0.94)))
                        .onChange(of: journalPanel) { _, _ in UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    } else {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Vision Board")
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text(subtitle)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, selectedTab == .journal ? 10 : 14)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedTab)

                if selectedTab == .journal && journalPanel == .vision {
                    VStack(spacing: 6) {
                        Text(timeframeLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: journalTimeframe)
                        TimelineSlider(selectedTimeframe: $journalTimeframe)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                HStack(spacing: 0) {
                    VisionTabButton(title: "Queue",      icon: "tray.fill",            isSelected: selectedTab == .questionQueue) { selectedTab = .questionQueue }
                    VisionTabButton(title: "Categories", icon: "square.grid.2x2.fill", isSelected: selectedTab == .categories)    { selectedTab = .categories }
                    VisionTabButton(title: "Journal",    icon: "book.closed.fill",     isSelected: selectedTab == .journal)       { selectedTab = .journal }

                    if selectedTab == .journal {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onStoryMode()
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(Color.brgBright)
                                Text("Story")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.brgBright)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                        .transition(.opacity.combined(with: .scale(scale: 0.85)))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
                .animation(.spring(response: 0.28, dampingFraction: 0.75), value: selectedTab)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selectedTab)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: journalPanel)
    }
}

// MARK: - Vision Tab Button

private struct VisionTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.brgBright : Color.secondary)
                    .scaleEffect(isSelected ? 1.08 : 1.0)
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.brgBright : Color.secondary)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.brgBright)
                    .frame(height: 2)
                    .scaleEffect(x: isSelected ? 1 : 0, anchor: .center)
                    .opacity(isSelected ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isSelected)
    }
}

// MARK: - Daily Questions View

private struct DailyQuestionsView: View {
    @ObservedObject var visionStore: VisionBoardStore
    @State private var todaysQuestions: [VisionQuestion] = []
    @State private var currentAnswers: [UUID: String] = [:]
    @State private var selectedImageURLs: [UUID: [URL]] = [:]

    var answeredToday: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let log = visionStore.dailyLogs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        return log?.answeredQuestionIds.count ?? 0
    }

    var body: some View {
        if visionStore.isLoading {
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.3)
                Text("Loading your vision…").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground))
            .onReceive(visionStore.$isLoading) { loading in
                if !loading { loadTodaysQuestions() }
            }
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    dailyHeaderCard
                    ForEach(clarityMilestonesToday, id: \.self) { note in
                        ClarityBannerView(note: note)
                    }
                    if visionStore.categoriesNeedingQuestions.isEmpty {
                        allCategoriesSatisfiedView
                    } else {
                        ForEach(todaysQuestions) { question in
                            QuestionCard(
                                question: question,
                                visionStore: visionStore,
                                answer: Binding(
                                    get: { currentAnswers[question.id] ?? "" },
                                    set: { currentAnswers[question.id] = $0 }
                                ),
                                imageURLs: Binding(
                                    get: { selectedImageURLs[question.id] ?? [] },
                                    set: { selectedImageURLs[question.id] = $0 }
                                ),
                                onAnswered: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { loadTodaysQuestions() }
                                }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .onAppear { loadTodaysQuestions() }
            .onChange(of: visionStore.answers.count) { _, _ in loadTodaysQuestions() }
        }
    }

    private var dailyHeaderCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.brgBright.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color.brgBright)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(formattedDate).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                Text(todaysQuestions.isEmpty ? "All caught up!" : "\(todaysQuestions.count - answeredToday) question\(todaysQuestions.count - answeredToday == 1 ? "" : "s") left")
                    .font(.headline)
            }
            Spacer()
            if !todaysQuestions.isEmpty {
                ZStack {
                    Circle()
                        .stroke(Color.brgBright.opacity(0.15), lineWidth: 3)
                        .frame(width: 38, height: 38)
                    Circle()
                        .trim(from: 0, to: todaysQuestions.isEmpty ? 0 : CGFloat(answeredToday) / CGFloat(todaysQuestions.count))
                        .stroke(Color.brgBright, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 38, height: 38)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(todaysQuestions.isEmpty ? 0 : Double(answeredToday) / Double(todaysQuestions.count) * 100))%")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.brgBright)
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: answeredToday)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var clarityMilestonesToday: [String] {
        visionStore.todaysEvents
            .filter { $0.action == .milestone && $0.note?.contains("clarity") == true }
            .compactMap(\.note)
    }

    private var allCategoriesSatisfiedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.brgBright)
            VStack(spacing: 6) {
                Text("Your vision is taking shape!").font(.title3.weight(.bold))
                Text("You've reached clarity in all your categories. Head to the Categories tab to reopen any category and go deeper, or generate your story.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(32).frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var allDoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(Color.brgBright)
            VStack(spacing: 6) {
                Text("You've answered everything!").font(.title3.weight(.bold))
                Text("Incredible. You've worked through every question in your vision board. New questions will be added over time.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .padding(32).frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var formattedDate: String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMM d"; return f.string(from: Date())
    }

    private func loadTodaysQuestions() {
        visionStore.ensureDailySet()
        todaysQuestions = visionStore.getDailyQuestions()
    }
}

// MARK: - Clarity Banner

private struct ClarityBannerView: View {
    let note: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.brgBright)
                .frame(width: 36, height: 36)
                .background(Color.brg.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Clarity reached").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(note).font(.subheadline.weight(.medium)).foregroundStyle(.primary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.brg.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.brg.opacity(0.18), lineWidth: 1))
    }
}

// MARK: - Question Card

private struct QuestionCard: View {
    let question: VisionQuestion
    let visionStore: VisionBoardStore
    @Binding var answer: String
    @Binding var imageURLs: [URL]
    @State private var showCustomAnswerBox = false
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var validationMessage: String? = nil
    @State private var submitted = false
    @FocusState private var editorFocused: Bool
    var onAnswered: () -> Void

    var isAnswered: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let log = visionStore.dailyLogs.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
        return log?.answeredQuestionIds.contains(question.id) ?? false
    }

    var category: VisionCategory? {
        visionStore.categories.first { $0.id == question.categoryId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader
            VStack(alignment: .leading, spacing: 16) {
                Text(question.questionText)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(isAnswered ? .secondary : .primary)
                    .fixedSize(horizontal: false, vertical: true)
                previousAnswerBanner
                if isAnswered { answeredBadge } else { answerSection }
            }
            .padding(20)
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 3)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: answer)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showCustomAnswerBox)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isAnswered)
        .floatingKeyboardDismiss(isVisible: editorFocused)
    }

    private var cardHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("\(question.timeframeYears)-yr vision")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.brgBright)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.brgBright.opacity(0.1), in: Capsule())

                if question.isReview {
                    Label("Revisit", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.primary)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color(uiColor: .tertiarySystemFill), in: Capsule())
                } else if let mod = question.module, mod != .discovery {
                    Label(mod.label, systemImage: mod.icon)
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                } else if question.isAiGenerated {
                    Label("Follow-up", systemImage: "sparkles")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                }

                Spacer()

                if let cat = category {
                    let colors = visionCategoryColor(for: cat)
                    Text("\(cat.emoji) \(cat.name)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [colors.start, colors.end], startPoint: .leading, endPoint: .trailing))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(colors.start.opacity(0.12), in: Capsule())
                }

                if isAnswered {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.brgBright)
                        .font(.system(size: 17))
                }
            }

            if let reason = visionStore.pickReason(for: question.id), !isAnswered {
                Label(reason, systemImage: "info.circle")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.secondary)
                    .lineLimit(1).padding(.top, 6)
            }
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 4)
    }

    @ViewBuilder
    private var previousAnswerBanner: some View {
        if question.isReview, let prev = question.previousAnswerText {
            VStack(alignment: .leading, spacing: 4) {
                Label("Your previous answer", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold)).foregroundStyle(.primary)
                Text(prev).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 20).padding(.bottom, 4)
        }
    }

    private var answeredBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill").foregroundStyle(Color.brgBright)
            Text("Answered").font(.subheadline.weight(.medium)).foregroundStyle(.primary)
        }
        .padding(.vertical, 10).frame(maxWidth: .infinity)
        .background(Color.brgBright.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var answerSection: some View {
        if let options = question.answerOptions, !options.isEmpty {
            if showCustomAnswerBox { customTextEntry } else { optionsGrid(options: options) }
        } else {
            freeformEntry
        }
        imageSection
    }

    private func optionsGrid(options: [String]) -> some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                if option.hasPrefix("Other") {
                    Button { withAnimation { showCustomAnswerBox = true } } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "square.and.pencil").font(.system(size: 14)).foregroundStyle(.secondary)
                            Text("Write my own…").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                } else {
                    let isSelected = answer == option
                    Button {
                        answer = option
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { submitAnswer() }
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(isSelected ? Color.brgBright : Color.secondary.opacity(0.3), lineWidth: 2)
                                    .frame(width: 20, height: 20)
                                if isSelected {
                                    Circle().fill(Color.brgBright).frame(width: 11, height: 11)
                                }
                            }
                            Text(option)
                                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? Color.brgBright : .primary)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(isSelected ? Color.brgBright.opacity(0.08) : Color(uiColor: .tertiarySystemBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isSelected)
                }
            }
        }
    }

    private var customTextEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                if answer.isEmpty {
                    Text("Write your own answer…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 14)
                        .padding(.leading, 14)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $answer)
                    .frame(minHeight: 110)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        editorFocused ? Color.brgBright.opacity(0.45) : Color.clear,
                        lineWidth: 1.5
                    )
            )
            .animation(.easeInOut(duration: 0.18), value: editorFocused)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { editorFocused = true }
            }

            if let hint = question.questionType.smartHint {
                Label(hint, systemImage: "lightbulb").font(.caption).foregroundStyle(.secondary)
            }
            if let msg = validationMessage {
                Label(msg, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showCustomAnswerBox = false; answer = ""; validationMessage = nil; editorFocused = false
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                        Text("Back").font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.secondary).padding(.horizontal, 16).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color(uiColor: .tertiarySystemBackground)))
                }
                .buttonStyle(.plain)

                Button(action: submitAnswer) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                        Text("Submit").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                answer.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? AnyShapeStyle(Color.secondary.opacity(0.2))
                                    : AnyShapeStyle(Color.brgBright)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
                .animation(.easeInOut(duration: 0.18), value: answer.isEmpty)
            }
        }
    }

    private var freeformEntry: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if answer.isEmpty {
                    Text("Write your answer…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 14)
                        .padding(.leading, 14)
                }
                TextEditor(text: $answer)
                    .frame(minHeight: 100)
                    .padding(10)
                    .scrollContentBackground(.hidden)
                    .focused($editorFocused)
            }
            .background(Color(uiColor: .tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            if let hint = question.questionType.smartHint {
                Label(hint, systemImage: "lightbulb").font(.caption).foregroundStyle(.secondary)
            }
            if let msg = validationMessage {
                Label(msg, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange)
            }

            Button(action: submitAnswer) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                    Text("Submit Answer")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(answer.trimmingCharacters(in: .whitespaces).isEmpty
                              ? AnyShapeStyle(Color.secondary.opacity(0.2))
                              : AnyShapeStyle(Color.brgBright))
                )
            }
            .buttonStyle(.plain)
            .disabled(answer.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Add Images")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 5, matching: .images) {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brgBright)
                }
                .onChange(of: selectedItems) { _, _ in
                    for item in selectedItems {
                        item.loadTransferable(type: Data.self) { result in
                            if case .success(let data) = result, let data = data {
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".jpg")
                                try? data.write(to: tempURL)
                                DispatchQueue.main.async { if !imageURLs.contains(tempURL) { imageURLs.append(tempURL) } }
                            }
                        }
                    }
                }
            }
            if !imageURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(imageURLs, id: \.self) { url in
                            ZStack(alignment: .topTrailing) {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.brgBright.opacity(0.08))
                                    .frame(width: 72, height: 72)
                                    .overlay(Image(systemName: "photo").foregroundStyle(Color.brgBright.opacity(0.4)))
                                Button { imageURLs.removeAll { $0 == url } } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white, Color.black.opacity(0.5)).font(.system(size: 18))
                                }
                                .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
            }
        }
    }

    private func submitAnswer() {
        validationMessage = nil
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let msg = validateAnswerIfNeeded(for: question, answer: trimmed) {
            validationMessage = msg
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }
        if question.isReview {
            visionStore.recordReviewAnswer(reviewQuestion: question, newAnswerText: trimmed)
        } else {
            visionStore.addAnswer(categoryId: question.categoryId, questionText: question.questionText, answerText: trimmed, timeframeYears: question.timeframeYears, imageURLs: imageURLs)
        }
        visionStore.markQuestionAnswered(question.id)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        answer = ""; imageURLs = []; selectedItems = []; validationMessage = nil
        onAnswered()
    }

    private func validateAnswerIfNeeded(for question: VisionQuestion, answer: String) -> String? {
        if let options = question.answerOptions, !options.isEmpty, !showCustomAnswerBox { return nil }
        guard question.questionType.requiresSentence else { return nil }
        let words = answer.split(whereSeparator: \.isWhitespace)
        if words.count < 12 || answer.count < 60 { return "Write 1–2 full sentences — this helps your story sound like you wrote it." }
        let endsPunct = answer.last.map { ".!?".contains($0) } ?? false
        if !endsPunct && !answer.contains(",") { return "Make it a full sentence — end with a period." }
        return nil
    }
}

// MARK: - Categories View

private struct CategoriesView: View {
    @ObservedObject var visionStore: VisionBoardStore
    @Binding var showAddCategorySheet: Bool
    @State private var selectedCategory: VisionCategory?

    var totalAnswers: Int { visionStore.answers.count }
    var totalProgress: Double {
        let target = visionStore.categories.count * visionCategorySoftCap
        return target == 0 ? 0 : min(Double(totalAnswers) / Double(target), 1.0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                overviewHeader
                VStack(spacing: 12) {
                    ForEach(visionStore.categories) { category in
                        CategoryCard(category: category, visionStore: visionStore)
                            .onTapGesture { selectedCategory = category }
                    }
                }
                Button { showAddCategorySheet = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "plus.circle.fill").font(.system(size: 18))
                        Text("Add Custom Category").font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.brgBright).frame(maxWidth: .infinity).padding(.vertical, 16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.brgBright.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16).padding(.vertical, 20)
        }
        .background(Color(.systemGroupedBackground))
        .sheet(item: $selectedCategory) { category in
            CategoryDetailView(category: category, visionStore: visionStore)
        }
    }

    private var overviewHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.brgBright.opacity(0.15), lineWidth: 5).frame(width: 60, height: 60)
                Circle()
                    .trim(from: 0, to: totalProgress)
                    .stroke(Color.brgBright, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 60, height: 60).rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.5, dampingFraction: 0.8), value: totalProgress)
                VStack(spacing: 0) {
                    Text("\(Int(totalProgress * 100))").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(Color.brgBright)
                    Text("%").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.brgBright.opacity(0.7))
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Progress").font(.headline)
                Text("\(totalAnswers) answers · \(visionStore.categories.count) categories").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16).background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Category Card

private struct CategoryCard: View {
    let category: VisionCategory
    @ObservedObject var visionStore: VisionBoardStore

    private var clarity: CategoryClarity { visionStore.categoryClarity(for: category.id) }
    private var answerCount: Int { clarity.answerCount }
    private var softCapProgress: Double { min(Double(answerCount) / Double(visionCategorySoftCap), 1.0) }
    private var isSatisfied: Bool { category.isSatisfied }
    private var isAtSoftCap: Bool { clarity.atSoftCap }
    private var isClear: Bool { clarity.isClear }
    private var coreComplete: Bool { clarity.coreComplete }

    private var statusColor: Color {
        if isSatisfied || isAtSoftCap { return Color.brgBright }
        if isClear { return Color.brgBright }
        if coreComplete { return Color.brgMuted }
        return .secondary
    }

    private var statusIcon: String {
        if isSatisfied { return "checkmark.seal.fill" }
        if isAtSoftCap { return "checkmark.circle.fill" }
        if isClear     { return "bolt.fill" }
        if coreComplete { return "arrow.forward.circle.fill" }
        return "chevron.right"
    }

    private var statusLabel: String {
        if isSatisfied  { return "Satisfied" }
        if isAtSoftCap  { return "Complete (\(visionCategorySoftCap) answers)" }
        if isClear      { return "Clear — story ready" }
        if coreComplete { return "Core done · deep-dives unlocked" }
        return "\(answerCount)/\(visionCategoryCoreMin) core answers"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 14) {
                Text(category.emoji)
                    .font(.system(size: 28))
                    .frame(width: 44, height: 44)
                    .background((isSatisfied ? Color.brg : Color(uiColor: .tertiarySystemFill)).opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(category.name).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        if isSatisfied {
                            Text("Paused").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2).background(Color.brg, in: Capsule())
                        }
                        Spacer()
                        Text("\(answerCount)/\(visionCategorySoftCap)").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.secondary.opacity(0.1)).frame(height: 5)
                            Capsule().fill(statusColor).frame(width: geo.size.width * softCapProgress, height: 5)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: softCapProgress)
                        }
                    }
                    .frame(height: 5)
                    Label(statusLabel, systemImage: statusIcon).font(.system(size: 10, weight: .medium)).foregroundStyle(statusColor)
                }

                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.secondary.opacity(0.3))
            }
            .padding(.horizontal, 14).padding(.vertical, 13)

            if answerCount >= visionCategoryCoreMin {
                Divider().padding(.horizontal, 14)
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    visionStore.markCategorySatisfied(category.id, satisfied: !isSatisfied)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSatisfied ? "arrow.counterclockwise" : "hand.thumbsup.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text(isSatisfied ? "Reopen — ask more questions" : "I'm happy here — stop asking")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(isSatisfied ? Color.brgBright : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: answerCount)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSatisfied)
    }
}

// MARK: - Add Category Sheet

private struct AddCategorySheet: View {
    @ObservedObject var visionStore: VisionBoardStore
    @Environment(\.dismiss) var dismiss
    @State private var categoryName = ""
    @State private var selectedEmoji = "✨"
    let emojis = ["✨","🎯","🎨","🏆","🚀","💡","🌟","🎪","🎭","🎬","❤️","🏡","💰","🌍","📚","💪","🧘","🎵"]
    var isValid: Bool { !categoryName.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Emoji picker
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Choose an icon", systemImage: "face.smiling").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(emojis, id: \.self) { emoji in
                                Button { selectedEmoji = emoji } label: {
                                    Text(emoji)
                                        .font(.system(size: 26))
                                        .frame(width: 48, height: 48)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(selectedEmoji == emoji ? Color.brgBright.opacity(0.15) : Color(.secondarySystemGroupedBackground))
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(selectedEmoji == emoji ? Color.brgBright : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: selectedEmoji)
                            }
                        }
                    }

                    // Preview
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Color.brgBright.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Text(selectedEmoji).font(.system(size: 26))
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(categoryName.isEmpty ? "Category name" : categoryName)
                                .font(.headline)
                                .foregroundStyle(categoryName.isEmpty ? .tertiary : .primary)
                            Text("0/\(visionCategorySoftCap) answers")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.brgBright.opacity(0.12), lineWidth: 1))

                    // Name input
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Category name", systemImage: "textformat").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                        TextField("e.g., Hobbies, Creative Work…", text: $categoryName)
                            .font(.body)
                            .padding(14)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.brgBright.opacity(isValid ? 0.35 : 0.1), lineWidth: 1.5)
                            )
                    }

                    // Add button
                    Button {
                        visionStore.addCategory(name: categoryName.trimmingCharacters(in: .whitespaces), emoji: selectedEmoji)
                        UINotificationFeedbackGenerator().notificationOccurred(.success)
                        dismiss()
                    } label: {
                        Text("Add Category")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(isValid
                                        ? AnyShapeStyle(Color.brgBright)
                                        : AnyShapeStyle(Color.gray.opacity(0.3)))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!isValid)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Category").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.foregroundStyle(.secondary) } }
        }
    }
}

// MARK: - Category Detail View

private struct CategoryDetailView: View {
    let category: VisionCategory
    @ObservedObject var visionStore: VisionBoardStore
    @Environment(\.dismiss) var dismiss
    @State private var editingAnswer: VisionAnswer? = nil
    @State private var deletingAnswer: VisionAnswer? = nil
    @State private var showDeleteConfirm = false

    var categoryAnswers: [VisionAnswer] { visionStore.answers.filter { $0.categoryId == category.id } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    if categoryAnswers.isEmpty { emptyState }
                    else {
                        ForEach(categoryAnswers) { answer in
                            answerCard(answer)
                                .contextMenu {
                                    Button { editingAnswer = answer } label: { Label("Edit Answer", systemImage: "pencil") }
                                    Button(role: .destructive) { deletingAnswer = answer; showDeleteConfirm = true } label: { Label("Delete Answer", systemImage: "trash") }
                                }
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("\(category.emoji) \(category.name)").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $editingAnswer) { EditAnswerSheet(answer: $0, visionStore: visionStore) }
            .confirmationDialog("Delete this answer?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { if let a = deletingAnswer { visionStore.deleteAnswer(a.id) } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This cannot be undone.") }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Text(category.emoji).font(.system(size: 52))
            Text("No answers yet").font(.headline)
            Text("Answer questions in the Queue tab to populate this category.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(40).frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func answerCard(_ answer: VisionAnswer) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(answer.questionText).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(2)
            Text(answer.answerText).font(.system(size: 15, weight: .regular, design: .rounded)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Label("\(answer.timeframeYears)-yr vision", systemImage: "scope")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.brg))
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "chart.bar.fill").font(.system(size: 9)).foregroundStyle(.secondary)
                    Text("\(Int(answer.confidence * 100))%").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(16).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Edit Answer Sheet

private struct EditAnswerSheet: View {
    let answer: VisionAnswer
    @ObservedObject var visionStore: VisionBoardStore
    @Environment(\.dismiss) var dismiss
    @State private var text: String = ""
    @FocusState private var focused: Bool

    init(answer: VisionAnswer, visionStore: VisionBoardStore) {
        self.answer = answer; self.visionStore = visionStore; _text = State(initialValue: answer.answerText)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Question").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(answer.questionText).font(.subheadline).foregroundStyle(.primary)
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your Answer").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    TextEditor(text: $text)
                        .focused($focused)
                        .font(.system(size: 16, weight: .regular, design: .rounded))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(12)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(focused ? Color.brgBright : Color.clear, lineWidth: 1.5)
                        )
                }
                Spacer()
            }
            .padding(20).background(Color(.systemGroupedBackground))
            .navigationTitle("Edit Answer").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        visionStore.updateAnswer(answer.id, newAnswerText: trimmed); dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear { focused = true }
        }
    }
}

private struct VisionTimelineView: View {
    @ObservedObject var visionStore: VisionBoardStore
    @Binding var timelinePanel: TimelinePanel
    @Binding var selectedTimeframe: Int
    @State private var editingCategoryId: UUID? = nil
    @State private var categoryOrder: [UUID] = []
    @State private var showStoryMode: Bool = false
    @State private var draggingCardId: UUID? = nil
    @State private var scrollOffset: CGFloat = 0
    @Namespace private var cardNamespace

    enum TimelinePanel: String, CaseIterable {
        case vision   = "Vision"
        case activity = "Activity"
        var icon: String { self == .vision ? "sparkles" : "clock.arrow.circlepath" }
    }

    var body: some View {
        ZStack {
            AmbientBackgroundView().ignoresSafeArea()
            Group {
                if timelinePanel == .vision {
                    VisionBoardCardsView(
                        visionStore: visionStore,
                        categoryOrder: $categoryOrder,
                        selectedTimeframe: $selectedTimeframe,
                        cardNamespace: cardNamespace,
                        draggingCardId: $draggingCardId,
                        scrollOffset: scrollOffset,
                        onEdit: { id in editingCategoryId = id },
                        categoryColor: visionCategoryColor(for:),
                        onPlayStory: { showStoryMode = true }
                    )
                } else {
                    ActivityHistoryView(visionStore: visionStore)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: timelinePanel)
        }
        .onAppear { categoryOrder = visionStore.categories.map { $0.id } }
        .sheet(item: Binding<IdentifiableUUID?>(
            get: { editingCategoryId.map { IdentifiableUUID($0) } },
            set: { editingCategoryId = $0?.id }
        )) { identifiableCatId in
            if let category = visionStore.categories.first(where: { $0.id == identifiableCatId.id }) {
                EditCategorySheet(category: category, visionStore: visionStore)
            }
        }
        .fullScreenCover(isPresented: $showStoryMode) {
            VisionStoryModeView(visionStore: visionStore, selectedTimeframe: selectedTimeframe, categoryOrder: categoryOrder)
        }
    }
}

// MARK: - Activity History View

private struct ActivityHistoryView: View {
    @ObservedObject var visionStore: VisionBoardStore

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                StreaksRowView(visionStore: visionStore)
                if let nextStep = visionStore.todaysEvents.first(where: { $0.action == .nextStep }), let note = nextStep.note {
                    NextStepCard(note: note)
                }
                if visionStore.eventsByDay.isEmpty { emptyState }
                else {
                    ForEach(visionStore.eventsByDay, id: \.date) { group in
                        DayEventGroupView(date: group.date, events: group.events, visionStore: visionStore)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 44)).foregroundStyle(.secondary)
            Text("No activity yet").font(.headline)
            Text("Answer questions and complete sessions to build your activity history.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(40).frame(maxWidth: .infinity)
        .background(Color(uiColor: .secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct IdentifiableUUID: Identifiable {
    let id: UUID
    init(_ id: UUID) { self.id = id }
}

private struct TimelineSlider: View {
    @Binding var selectedTimeframe: Int

    var body: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { Double(selectedTimeframe) },
                    set: { selectedTimeframe = Int($0.rounded()) }
                ),
                in: 1...10,
                step: 1
            )
            .tint(Color.brgBright)

            HStack {
                Text("1 year").font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text("10 years").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }
}

private func visionCategoryColor(for category: VisionCategory) -> (start: Color, end: Color) {
    let palette: [(Color, Color)] = [
        (.brgBright, .brg),
        (.brgMuted, .brg.opacity(0.9)),
        (Color.brg.opacity(0.85), Color.brg.opacity(0.6)),
        (Color(uiColor: .secondaryLabel), Color(uiColor: .tertiaryLabel)),
        (Color(uiColor: .tertiaryLabel), Color(uiColor: .quaternaryLabel)),
        (.brg, .brgMuted),
        (Color.brg.opacity(0.7), Color(uiColor: .tertiaryLabel))
    ]
    let index = abs(category.id.uuidString.hashValue) % palette.count
    return palette[index]
}

private struct AmbientBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(uiColor: .systemGroupedBackground),
                Color(uiColor: .secondarySystemGroupedBackground)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

private struct VisionStoryModeView: View {
    @ObservedObject var visionStore: VisionBoardStore
    let selectedTimeframe: Int
    let categoryOrder: [UUID]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Story").font(.largeTitle.bold())
                    Text("Story mode content is temporarily simplified while this view is being restored.")
                        .foregroundStyle(.secondary)

                    ForEach(orderedCategories, id: \.id) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("\(category.emoji) \(category.name)").font(.headline)
                            let answers = visionStore.answers.filter { $0.categoryId == category.id }
                            if answers.isEmpty {
                                Text("No answers yet.").foregroundStyle(.secondary)
                            } else {
                                ForEach(answers.prefix(3)) { answer in
                                    Text("• \(answer.answerText)").font(.subheadline)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var orderedCategories: [VisionCategory] {
        let byID = Dictionary(uniqueKeysWithValues: visionStore.categories.map { ($0.id, $0) })
        let ordered = categoryOrder.compactMap { byID[$0] }
        let remaining = visionStore.categories.filter { !categoryOrder.contains($0.id) }
        return ordered + remaining
    }
}

private struct VisionBoardCardsView: View {
    @ObservedObject var visionStore: VisionBoardStore
    @Binding var categoryOrder: [UUID]
    @Binding var selectedTimeframe: Int
    let cardNamespace: Namespace.ID
    @Binding var draggingCardId: UUID?
    let scrollOffset: CGFloat
    let onEdit: (UUID) -> Void
    let categoryColor: (VisionCategory) -> (start: Color, end: Color)
    let onPlayStory: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(orderedCategories, id: \.id) { category in
                    let colors = categoryColor(category)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("\(category.emoji) \(category.name)").font(.headline)
                            Spacer()
                            Button("Edit") { onEdit(category.id) }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.brgBright)
                        }

                        let answers = visionStore.answers.filter { $0.categoryId == category.id }
                        if answers.isEmpty {
                            Text("No entries yet").foregroundStyle(.secondary)
                        } else {
                            ForEach(answers.prefix(3)) { answer in
                                Text(answer.answerText)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                            }
                        }
                    }
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [colors.start.opacity(0.10), colors.end.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                }

                Button("Play Story") { onPlayStory() }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.brgBright)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var orderedCategories: [VisionCategory] {
        let byID = Dictionary(uniqueKeysWithValues: visionStore.categories.map { ($0.id, $0) })
        let ordered = categoryOrder.compactMap { byID[$0] }
        let remaining = visionStore.categories.filter { !categoryOrder.contains($0.id) }
        return ordered + remaining
    }
}

private struct EditCategorySheet: View {
    let category: VisionCategory
    @ObservedObject var visionStore: VisionBoardStore
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var emoji: String = "✨"

    init(category: VisionCategory, visionStore: VisionBoardStore) {
        self.category = category
        self.visionStore = visionStore
        _name = State(initialValue: category.name)
        _emoji = State(initialValue: category.emoji)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    TextField("Name", text: $name)
                    TextField("Emoji", text: $emoji)
                }
            }
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }
                }
            }
        }
    }
}

private struct StreaksRowView: View {
    @ObservedObject var visionStore: VisionBoardStore

    var body: some View {
        let streak = visionStore.dailyLogs.reversed().prefix { !$0.answeredQuestionIds.isEmpty }.count
        HStack(spacing: 12) {
            Image(systemName: "flame.fill").foregroundStyle(Color.brgBright)
            VStack(alignment: .leading, spacing: 2) {
                Text("Current streak").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text("\(streak) day\(streak == 1 ? "" : "s")").font(.headline)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct NextStepCard: View {
    let note: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.forward.circle.fill").foregroundStyle(Color.brgBright)
            VStack(alignment: .leading, spacing: 4) {
                Text("Next Step").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(note).font(.subheadline).foregroundStyle(.primary)
            }
            Spacer()
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DayEventGroupView: View {
    let date: Date
    let events: [DailyEvent]
    @ObservedObject var visionStore: VisionBoardStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())).font(.headline)
            ForEach(events) { event in
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.action.rawValue.capitalized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.brgBright)
                    if let note = event.note, !note.isEmpty {
                        Text(note).font(.subheadline).foregroundStyle(.primary)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }
}
