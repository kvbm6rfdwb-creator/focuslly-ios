import SwiftUI

// MARK: - Task Group (deduplicated by title)

fileprivate struct TaskGroup {
    let title: String
    let ids: [UUID]
    var isConfirmed: Bool { ids.allSatisfy { TaskCategoryStore.shared.isConfirmed(taskId: $0) } }
    var category: TaskCategory { TaskCategoryStore.shared.category(for: ids[0]) ?? .coreWork }
}

struct TaskCategoriesSettingsView: View {

    @EnvironmentObject var taskStore: TaskStore
    @State private var refresh = false

    private func makeGroups(from tasks: [FocusTask]) -> [TaskGroup] {
        var seen: [String: [UUID]] = [:]
        for task in tasks {
            seen[task.title, default: []].append(task.id)
        }
        return seen.map { TaskGroup(title: $0.key, ids: $0.value) }
    }

    private var pendingGroups: [TaskGroup] {
        makeGroups(from: taskStore.tasks).filter { !$0.isConfirmed }
            .sorted { $0.title < $1.title }
    }

    private var confirmedGroups: [(category: TaskCategory, groups: [TaskGroup])] {
        let confirmed = makeGroups(from: taskStore.tasks).filter { $0.isConfirmed }
        var grouped: [TaskCategory: [TaskGroup]] = [:]
        for g in confirmed {
            grouped[g.category, default: []].append(g)
        }
        return grouped
            .map { (category: $0.key, groups: $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.category.displayName < $1.category.displayName }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                explanationCard
                categoryNamesLink
                pendingSection
                confirmedSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Task Categories")
        .navigationBarTitleDisplayMode(.inline)
        .id(refresh)
    }

    private var categoryNamesLink: some View {
        NavigationLink(destination: CategoryEditorView()) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.brg.opacity(0.10))
                        .frame(width: 38, height: 38)
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Categories")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("Rename, recolour, change icon, add or remove")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: -4) {
                    ForEach(Array(TaskCategory.allCases.prefix(5)), id: \.id) { cat in
                        Circle()
                            .fill(cat.color)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var pendingSection: some View {
        if !pendingGroups.isEmpty {
            CategorySection(
                title: "Needs Review",
                badge: "\(pendingGroups.count)",
                badgeColor: .orange,
                icon: "exclamationmark.circle.fill",
                iconColor: .orange
            ) {
                ForEach(Array(pendingGroups.enumerated()), id: \.element.title) { idx, group in
                    if idx > 0 { Divider().padding(.leading, 16) }
                    TaskCategoryRow(group: group, onChanged: { refresh.toggle() })
                }
            }
        }
    }

    @ViewBuilder
    private var confirmedSection: some View {
        if confirmedGroups.isEmpty && pendingGroups.isEmpty {
            emptyState
        } else {
            ForEach(confirmedGroups, id: \.category.id) { group in
                CategorySection(
                    title: group.category.displayName,
                    badge: "\(group.groups.count)",
                    badgeColor: group.category.color.opacity(0.8),
                    icon: group.category.icon,
                    iconColor: group.category.color
                ) {
                    ForEach(Array(group.groups.enumerated()), id: \.element.title) { idx, taskGroup in
                        if idx > 0 { Divider().padding(.leading, 16) }
                        TaskCategoryRow(group: taskGroup, onChanged: { refresh.toggle() })
                    }
                }
            }
        }
    }

    // ── Explanation card ──────────────────────────────────────────────
    private var explanationCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 38, height: 38)
                Image(systemName: "tag.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Category Assignment")
                    .font(.system(size: 14, weight: .semibold))
                Text("Helps the app personalise break timing and insights.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // ── Empty state ───────────────────────────────────────────────────
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.fill")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No tasks yet")
                .font(.headline)
            Text("Add tasks from the Dashboard to assign categories.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Category Section

private struct CategorySection<Content: View>: View {
    let title: String
    let badge: String
    let badgeColor: Color
    let icon: String
    let iconColor: Color
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .kerning(0.4)
                Spacer()
                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(badgeColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(badgeColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 8)

            // Card
            VStack(spacing: 0) {
                content
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}

// MARK: - Task Category Row

private struct TaskCategoryRow: View {
    let group: TaskGroup
    let onChanged: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(group.title)
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    // Badge when multiple tasks share this title
                    if group.ids.count > 1 {
                        Text("×\(group.ids.count)")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.primary.opacity(0.07))
                            .clipShape(Capsule())
                    }
                }
                if !group.isConfirmed {
                    Text("AI suggested · tap to confirm")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()

            Picker(
                "",
                selection: Binding<TaskCategory>(
                    get: { group.category },
                    set: { newValue in
                        // Apply to every task ID sharing this title
                        for id in group.ids {
                            TaskCategoryStore.shared.set(category: newValue, for: id, confirmed: true)
                        }
                        TaskCategorizationLearningStore.shared.recordUserCorrection(title: group.title, category: newValue)
                        onChanged()
                    }
                )
            ) {
                ForEach(TaskCategory.allCases) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(group.isConfirmed ? .secondary : .orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Category Editor View (unified: name + colour + icon + add/remove)

struct CategoryEditorView: View {

    @ObservedObject private var nameStore   = CategoryNameStore.shared
    @ObservedObject private var colorStore  = CategoryColorStore.shared
    @ObservedObject private var customStore = CustomCategoryStore.shared

    @State private var editingBuiltin: TaskCategory? = nil
    @State private var editingCustom: CustomCategory? = nil
    @State private var showAddSheet = false

    var body: some View {
        List {
            builtinSection
            if !customStore.customCategories.isEmpty {
                customSection
            }
            addSection
            resetSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingBuiltin) { cat in
            CategoryEditSheet(builtinCategory: cat) {
                editingBuiltin = nil
            }
        }
        .sheet(item: $editingCustom) { cat in
            CustomCategoryEditSheet(category: cat, isNew: false) { updated in
                customStore.updateCustomCategory(updated)
                editingCustom = nil
            }
        }
        .sheet(isPresented: $showAddSheet) {
            CustomCategoryEditSheet(
                category: CustomCategory(name: "", icon: "tag.fill", colorHex: "FF9500"),
                isNew: true
            ) { newCat in
                customStore.addCustomCategory(newCat)
                showAddSheet = false
            }
        }
    }

    // MARK: - Sections

    private var builtinSection: some View {
        Section("Built-in Categories") {
            ForEach(TaskCategory.allCases) { cat in
                BuiltinCategoryRow(
                    category: cat,
                    isHidden: customStore.isHidden(cat),
                    onEdit: { editingBuiltin = cat }
                )
            }
        }
    }

    private var customSection: some View {
        Section("My Categories") {
            ForEach(customStore.customCategories) { cat in
                CustomCategoryRow(category: cat, onEdit: { editingCustom = cat })
            }
            .onDelete { indexSet in
                for i in indexSet {
                    customStore.removeCustomCategory(id: customStore.customCategories[i].id)
                }
            }
        }
    }

    private var addSection: some View {
        Section {
            Button {
                showAddSheet = true
            } label: {
                Label("Add New Category", systemImage: "plus.circle.fill")
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                nameStore.resetAll()
                colorStore.resetAll()
                for cat in TaskCategory.allCases { customStore.show(builtin: cat) }
            } label: {
                Label("Reset All to Defaults", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Built-in Category Row

private struct BuiltinCategoryRow: View {
    let category: TaskCategory
    let isHidden: Bool
    let onEdit: () -> Void

    @ObservedObject private var customStore = CustomCategoryStore.shared

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.color.opacity(isHidden ? 0.05 : 0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: CategoryNameStore.shared.icon(for: category))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isHidden ? .secondary : category.color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(category.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isHidden ? .secondary : .primary)
                Text(isHidden ? "Hidden" : category.title)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(isHidden ? Color.secondary : category.color)
            }
            .buttonStyle(.plain)
        }
        .opacity(isHidden ? 0.5 : 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(isHidden ? "Show" : "Hide", role: isHidden ? .none : .destructive) {
                if isHidden {
                    customStore.show(builtin: category)
                } else {
                    customStore.hide(builtin: category)
                }
            }
            .tint(isHidden ? .green : .red)
        }
    }
}

// MARK: - Custom Category Row

private struct CustomCategoryRow: View {
    let category: CustomCategory
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(category.color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(category.color)
            }
            Text(category.name)
                .font(.system(size: 14, weight: .semibold))
            Spacer()
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(category.color)
            }
            .buttonStyle(.plain)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                CustomCategoryStore.shared.removeCustomCategory(id: category.id)
            }
        }
    }
}

// MARK: - Built-in Category Edit Sheet

private struct CategoryEditSheet: View {
    let builtinCategory: TaskCategory
    let onDismiss: () -> Void

    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var nameStore  = CategoryNameStore.shared
    @ObservedObject private var colorStore = CategoryColorStore.shared

    @State private var draftName: String = ""
    @State private var selectedColorHex: String = ""
    @State private var selectedIcon: String = ""

    private let iconOptions = CategoryEditorConstants.iconOptions
    private let colorOptions = CategoryEditorConstants.colorOptions

    init(builtinCategory: TaskCategory, onDismiss: @escaping () -> Void) {
        self.builtinCategory = builtinCategory
        self.onDismiss = onDismiss
        _draftName       = State(initialValue: CategoryNameStore.shared.hasCustomName(for: builtinCategory)
                                    ? (CategoryNameStore.shared.customNames[builtinCategory.rawValue] ?? "")
                                    : "")
        _selectedColorHex = State(initialValue: CategoryColorStore.shared.customColors[builtinCategory.rawValue] ?? builtinCategory.defaultColor.toHex() ?? "")
        _selectedIcon     = State(initialValue: CategoryNameStore.shared.hasCustomIcon(for: builtinCategory)
                                    ? (CategoryNameStore.shared.customIcons[builtinCategory.rawValue] ?? builtinCategory.icon)
                                    : builtinCategory.icon)
    }

    private var previewColor: Color { Color(hex: selectedColorHex) ?? builtinCategory.defaultColor }
    private var displayName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? builtinCategory.title : draftName
    }

    var body: some View {
        NavigationStack {
            List {
                previewSection
                nameSection
                iconSection
                colourSection
                resetSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }

    private var previewSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(previewColor.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: selectedIcon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(previewColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 16, weight: .semibold))
                    Text("Built-in: \(builtinCategory.title)")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: { Text("Preview") }
    }

    private var nameSection: some View {
        Section("Name") {
            TextField(builtinCategory.title, text: $draftName)
        }
    }

    private var iconSection: some View {
        Section("Icon") {
            CategoryIconGrid(selectedIcon: $selectedIcon, accentColor: previewColor)
        }
    }

    private var colourSection: some View {
        Section("Colour") {
            CategoryColourGrid(selectedHex: $selectedColorHex)
        }
    }

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                nameStore.resetName(for: builtinCategory)
                nameStore.resetIcon(for: builtinCategory)
                colorStore.resetColor(for: builtinCategory)
                dismiss()
            } label: {
                Label("Reset to Default", systemImage: "arrow.counterclockwise")
                    .foregroundStyle(.red)
            }
        }
    }

    private func save() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { nameStore.resetName(for: builtinCategory) }
        else { nameStore.setName(name, for: builtinCategory) }

        if selectedIcon == builtinCategory.icon { nameStore.resetIcon(for: builtinCategory) }
        else { nameStore.setIcon(selectedIcon, for: builtinCategory) }

        if let color = Color(hex: selectedColorHex) {
            colorStore.setColor(color, for: builtinCategory)
        }
    }
}

// MARK: - Custom Category Edit Sheet

private struct CustomCategoryEditSheet: View {
    let category: CustomCategory
    let isNew: Bool
    let onSave: (CustomCategory) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draftName: String
    @State private var selectedIcon: String
    @State private var selectedColorHex: String

    private let iconOptions = CategoryEditorConstants.iconOptions
    private let colorOptions = CategoryEditorConstants.colorOptions

    init(category: CustomCategory, isNew: Bool, onSave: @escaping (CustomCategory) -> Void) {
        self.category = category
        self.isNew = isNew
        self.onSave = onSave
        _draftName        = State(initialValue: category.name)
        _selectedIcon     = State(initialValue: category.icon)
        _selectedColorHex = State(initialValue: category.colorHex)
    }

    private var previewColor: Color { Color(hex: selectedColorHex) ?? .orange }
    private var displayName: String {
        draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "New Category" : draftName
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(previewColor.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: selectedIcon)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(previewColor)
                        }
                        Text(displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(draftName.isEmpty ? .secondary : .primary)
                    }
                    .padding(.vertical, 4)
                } header: { Text("Preview") }

                Section("Name") {
                    TextField("Category name", text: $draftName)
                }

                Section("Icon") {
                    CategoryIconGrid(selectedIcon: $selectedIcon, accentColor: previewColor)
                }

                Section("Colour") {
                    CategoryColourGrid(selectedHex: $selectedColorHex)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isNew ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        let updated = CustomCategory(
                            id: category.id,
                            name: trimmed,
                            icon: selectedIcon,
                            colorHex: selectedColorHex
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Shared Icon Grid

private struct CategoryIconGrid: View {
    @Binding var selectedIcon: String
    let accentColor: Color

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(CategoryEditorConstants.iconOptions, id: \.self) { sym in
                Button {
                    selectedIcon = sym
                    HapticManager.impact()
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedIcon == sym ? accentColor : Color(uiColor: .tertiarySystemFill))
                            .frame(width: 44, height: 44)
                        Image(systemName: sym)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(selectedIcon == sym ? .white : .primary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Shared Colour Grid

private struct CategoryColourGrid: View {
    @Binding var selectedHex: String

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 12) {
            ForEach(CategoryEditorConstants.colorOptions, id: \.0) { hex, color in
                Button {
                    selectedHex = hex
                    HapticManager.impact()
                } label: {
                    ZStack {
                        Circle()
                            .fill(color)
                            .frame(width: 36, height: 36)
                        if selectedHex.uppercased() == hex.uppercased() {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Constants

private enum CategoryEditorConstants {
    static let iconOptions: [String] = [
        "briefcase.fill", "envelope.fill", "list.bullet.clipboard.fill", "book.fill",
        "paintbrush.fill", "person.2.fill", "wrench.fill", "person.fill",
        "heart.fill", "gamecontroller.fill", "phone.fill", "arrow.uturn.right",
        "doc.text.fill", "house.fill", "message.fill", "figure.run",
        "bolt.fill", "star.fill", "checkmark.circle.fill", "calendar",
        "chart.bar.fill", "megaphone.fill", "laptopcomputer", "hammer.fill",
        "building.2.fill", "car.fill", "dollarsign.circle.fill", "tag.fill",
        "magnifyingglass", "pencil", "bed.double.fill", "fork.knife"
    ]

    static let colorOptions: [(String, Color)] = [
        ("FF3B30", .red),
        ("FF9500", .orange),
        ("FFCC00", .yellow),
        ("34C759", .green),
        ("00C7BE", .teal),
        ("30B0C7", Color(red: 0.19, green: 0.69, blue: 0.78)),
        ("007AFF", .blue),
        ("5856D6", Color(red: 0.35, green: 0.34, blue: 0.84)),
        ("AF52DE", Color(red: 0.69, green: 0.32, blue: 0.87)),
        ("FF2D55", Color(red: 1, green: 0.18, blue: 0.33)),
        ("A2845E", .brown),
        ("8E8E93", Color(red: 0.56, green: 0.56, blue: 0.58)),
        ("1C3D22", Color(red: 0.11, green: 0.24, blue: 0.13)),
        ("5AC8FA", .cyan)
    ]
}

