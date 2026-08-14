import SwiftUI

// MARK: - Set Times Settings

struct SetTimesSettingsView: View {
    @EnvironmentObject var settings: AppSettingsStore
    @State private var showAddSheet = false
    @State private var editingPreset: AppSettingsStore.SetTimePreset? = nil

    var body: some View {
        List {
            Section {
                ForEach(settings.setTimePresets) { preset in
                    HStack {
                        Image(systemName: "timer")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.brg)
                            .clipShape(RoundedRectangle(cornerRadius: 6))

                        Text(preset.label)
                            .font(.system(size: 15))

                        Spacer()

                        Button {
                            editingPreset = preset
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete { indexSet in
                    guard settings.setTimePresets.count - indexSet.count >= 1 else { return }
                    settings.setTimePresets.remove(atOffsets: indexSet)
                }
                .onMove { settings.setTimePresets.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("These chips appear in the Quick Start duration picker. Swipe left to delete, drag to reorder.")
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.primary)
                        Text("Add Time Preset")
                            .foregroundStyle(.primary)
                    }
                    .font(.system(size: 15))
                }
            }

            Section {
                Button(role: .destructive) {
                    settings.setTimePresets = [
                        .init(minutes: 15), .init(minutes: 25), .init(minutes: 30),
                        .init(minutes: 45), .init(minutes: 60), .init(minutes: 90)
                    ]
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                        Text("Reset to Defaults")
                            .foregroundStyle(.red)
                    }
                    .font(.system(size: 15))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Set Times")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { EditButton() }
        .sheet(isPresented: $showAddSheet) {
            SetTimeEditSheet(preset: nil) { newPreset in
                settings.setTimePresets.append(newPreset)
            }
        }
        .sheet(item: $editingPreset) { preset in
            SetTimeEditSheet(preset: preset) { updated in
                if let idx = settings.setTimePresets.firstIndex(where: { $0.id == updated.id }) {
                    settings.setTimePresets[idx] = updated
                }
            }
        }
    }
}

// MARK: - Set Time Edit Sheet

private struct SetTimeEditSheet: View {
    let preset: AppSettingsStore.SetTimePreset?
    let onSave: (AppSettingsStore.SetTimePreset) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var minutes: Int

    private let steps = stride(from: 5, through: 240, by: 5).map { $0 }

    init(preset: AppSettingsStore.SetTimePreset?, onSave: @escaping (AppSettingsStore.SetTimePreset) -> Void) {
        self.preset = preset
        self.onSave = onSave
        _minutes = State(initialValue: preset?.minutes ?? 25)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    Picker("Minutes", selection: $minutes) {
                        ForEach(steps, id: \.self) { m in
                            Text("\(m) minutes").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 160)
                }
            }
            .navigationTitle(preset == nil ? "Add Preset" : "Edit Preset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = AppSettingsStore.SetTimePreset(
                            id: preset?.id ?? UUID(),
                            minutes: minutes
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Color.brg)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Quick Start Tasks Settings

struct QuickStartTasksSettingsView: View {
    @EnvironmentObject var settings: AppSettingsStore
    @State private var showAddSheet = false
    @State private var editingPreset: AppSettingsStore.QuickStartTaskPreset? = nil

    var body: some View {
        List {
            Section {
                ForEach(settings.quickStartTaskPresets) { preset in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(preset.color.opacity(0.15))
                                .frame(width: 34, height: 34)
                            Image(systemName: preset.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(preset.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(preset.title)
                                .font(.system(size: 14, weight: .semibold))
                            Text(preset.description.isEmpty ? "\(preset.defaultMinutes)m" : "\(preset.description) · \(preset.defaultMinutes)m")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button {
                            editingPreset = preset
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
                }
                .onDelete { indexSet in
                    guard settings.quickStartTaskPresets.count - indexSet.count >= 1 else { return }
                    settings.quickStartTaskPresets.remove(atOffsets: indexSet)
                }
                .onMove { settings.quickStartTaskPresets.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text("These appear on the Focus tab's Quick Start card. Swipe left to delete, drag to reorder.")
            }

            Section {
                Button {
                    showAddSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.primary)
                        Text("Add Quick Start Task")
                            .foregroundStyle(.primary)
                    }
                    .font(.system(size: 15))
                }
            }

            Section {
                Button(role: .destructive) {
                    settings.quickStartTaskPresets = [
                        .init(title: "Follow-Ups",       icon: "arrow.uturn.right", colorHex: "34C759", defaultMinutes: 30, description: "Warm leads & callbacks",   pipelineCategoryRaw: "followUps"),
                        .init(title: "Send Offers",       icon: "doc.text.fill",     colorHex: "007AFF", defaultMinutes: 60, description: "Prepare & send proposals", pipelineCategoryRaw: "sendOffers"),
                        .init(title: "Add New Listing",   icon: "house.fill",        colorHex: "FF9500", defaultMinutes: 90, description: "List a new property",      pipelineCategoryRaw: "addListing"),
                        .init(title: "Answer Inquiries",  icon: "message.fill",      colorHex: "30B0C7", defaultMinutes: 20, description: "Reply to incoming requests",pipelineCategoryRaw: "answerInquiries"),
                        .init(title: "Meeting",           icon: "person.2.fill",     colorHex: "AF52DE", defaultMinutes: 90, description: "Client or team meeting",   pipelineCategoryRaw: "meeting"),
                        .init(title: "Physical Training", icon: "figure.run",        colorHex: "FF3B30", defaultMinutes: 60, description: "Gym, run or sport session", pipelineCategoryRaw: "physicalTraining"),
                        .init(title: "Reading",           icon: "book.fill",         colorHex: "5856D6", defaultMinutes: 45, description: "Books, articles, learning", pipelineCategoryRaw: "reading")
                    ]
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                        Text("Reset to Defaults")
                            .foregroundStyle(.red)
                    }
                    .font(.system(size: 15))
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Quick Start Tasks")
        .navigationBarTitleDisplayMode(.large)
        .toolbar { EditButton() }
        .sheet(isPresented: $showAddSheet) {
            QuickStartTaskEditSheet(preset: nil) { newPreset in
                settings.quickStartTaskPresets.append(newPreset)
            }
        }
        .sheet(item: $editingPreset) { preset in
            QuickStartTaskEditSheet(preset: preset) { updated in
                if let idx = settings.quickStartTaskPresets.firstIndex(where: { $0.id == updated.id }) {
                    settings.quickStartTaskPresets[idx] = updated
                }
            }
        }
    }
}

// MARK: - Quick Start Task Edit Sheet

struct QuickStartTaskEditSheet: View {
    let preset: AppSettingsStore.QuickStartTaskPreset?
    let onSave: (AppSettingsStore.QuickStartTaskPreset) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var description: String
    @State private var icon: String
    @State private var colorHex: String
    @State private var defaultMinutes: Int
    @State private var showIconPicker = false

    private let minuteSteps = stride(from: 5, through: 240, by: 5).map { $0 }

    // Common SF Symbols for task types
    private let iconOptions: [String] = [
        "phone.fill", "arrow.uturn.right", "doc.text.fill", "house.fill",
        "message.fill", "person.2.fill", "figure.run", "book.fill",
        "bolt.fill", "star.fill", "checkmark.circle.fill", "calendar",
        "chart.bar.fill", "megaphone.fill", "envelope.fill", "laptopcomputer",
        "hammer.fill", "building.2.fill", "car.fill", "briefcase.fill",
        "dollarsign.circle.fill", "tag.fill", "magnifyingglass", "pencil"
    ]

    private let colorOptions: [(String, Color)] = [
        ("FF3B30", .red), ("FF9500", .orange), ("FFCC00", .yellow),
        ("34C759", .green), ("30B0C7", Color(red: 0.19, green: 0.69, blue: 0.78)),
        ("007AFF", .blue), ("5856D6", Color(red: 0.35, green: 0.34, blue: 0.84)),
        ("AF52DE", Color(red: 0.69, green: 0.32, blue: 0.87)), ("FF2D55", Color(red: 1, green: 0.18, blue: 0.33)),
        ("8E8E93", Color(red: 0.56, green: 0.56, blue: 0.58)),
        ("34C759", .green), ("1C3D22", Color(red: 0.11, green: 0.24, blue: 0.13))
    ]

    init(preset: AppSettingsStore.QuickStartTaskPreset?, onSave: @escaping (AppSettingsStore.QuickStartTaskPreset) -> Void) {
        self.preset = preset
        self.onSave = onSave
        _title          = State(initialValue: preset?.title ?? "")
        _description    = State(initialValue: preset?.description ?? "")
        _icon           = State(initialValue: preset?.icon ?? "bolt.fill")
        _colorHex       = State(initialValue: preset?.colorHex ?? "FF9500")
        _defaultMinutes = State(initialValue: preset?.defaultMinutes ?? 30)
    }

    private var previewColor: Color { Color(hex: colorHex) ?? .orange }

    var body: some View {
        NavigationStack {
            Form {
                // Preview
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(previewColor.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(previewColor)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title.isEmpty ? "Task Name" : title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(title.isEmpty ? .secondary : .primary)
                            Text(description.isEmpty ? "Description" : description)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(defaultMinutes)m")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(previewColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(previewColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Preview")
                }

                // Name & description
                Section("Details") {
                    TextField("Task name", text: $title)
                    TextField("Short description", text: $description)
                }

                // Duration
                Section("Default Duration") {
                    Picker("Minutes", selection: $defaultMinutes) {
                        ForEach(minuteSteps, id: \.self) { m in
                            Text("\(m) minutes").tag(m)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 140)
                }

                // Icon picker
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { sym in
                            Button {
                                icon = sym
                                HapticManager.impact()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(icon == sym ? previewColor : Color(uiColor: .tertiarySystemFill))
                                        .frame(width: 44, height: 44)
                                    Image(systemName: sym)
                                        .font(.system(size: 17, weight: .medium))
                                        .foregroundStyle(icon == sym ? .white : .primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Colour picker
                Section("Colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(colorOptions, id: \.0) { hex, color in
                            Button {
                                colorHex = hex
                                HapticManager.impact()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 36, height: 36)
                                    if colorHex == hex {
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
            .navigationTitle(preset == nil ? "Add Quick Start" : "Edit Quick Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let updated = AppSettingsStore.QuickStartTaskPreset(
                            id: preset?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Quick Task" : title,
                            icon: icon,
                            colorHex: colorHex,
                            defaultMinutes: defaultMinutes,
                            description: description,
                            pipelineCategoryRaw: preset?.pipelineCategoryRaw
                        )
                        onSave(updated)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .tint(Color.brg)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
