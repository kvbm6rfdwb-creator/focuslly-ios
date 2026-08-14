import SwiftUI

// MARK: - Presets Settings View (entry point shown in Settings)

struct PresetsSettingsView: View {
    @EnvironmentObject var settings: AppSettingsStore

    var body: some View {
        List {
            Section {
                NavigationLink(destination: StringPresetListView(
                    title: "Task Names",
                    icon: "pencil",
                    accentColor: .accentColor,
                    presets: $settings.taskNamePresets,
                    defaults: AppSettingsStore.defaultTaskNamePresets,
                    placeholder: "e.g. Cold calls",
                    footer: "These chips appear when adding or editing a task name."
                )) {
                    HStack(spacing: 10) {
                        SettingsPresetBadge(icon: "pencil", color: .accentColor)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Task Names")
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(settings.taskNamePresets.count) presets")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                NavigationLink(destination: StringPresetListView(
                    title: "Intentions",
                    icon: "text.quote",
                    accentColor: .purple,
                    presets: $settings.intentionPresets,
                    defaults: AppSettingsStore.defaultIntentionPresets,
                    placeholder: "e.g. Offer sent",
                    footer: "These chips appear in the session intention field and Quick Start sheets."
                )) {
                    HStack(spacing: 10) {
                        SettingsPresetBadge(icon: "text.quote", color: .purple)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Intentions")
                                .font(.system(size: 14, weight: .semibold))
                            Text("\(settings.intentionPresets.count) presets")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Presets")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Generic String Preset List

struct StringPresetListView: View {
    let title: String
    let icon: String
    let accentColor: Color
    @Binding var presets: [String]
    let defaults: [String]
    let placeholder: String
    let footer: String

    @State private var showAddSheet = false
    @State private var editingIndex: Int? = nil
    @State private var editingText: String = ""
    @State private var showResetConfirm = false

    var body: some View {
        List {
            Section {
                ForEach(Array(presets.enumerated()), id: \.element) { idx, preset in
                    HStack(spacing: 10) {
                        SettingsPresetBadge(icon: icon, color: accentColor)
                        Text(preset)
                            .font(.system(size: 14))
                        Spacer()
                        Button {
                            editingIndex = idx
                            editingText = preset
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .onDelete { presets.remove(atOffsets: $0) }
                .onMove  { presets.move(fromOffsets: $0, toOffset: $1) }
            } footer: {
                Text(footer)
            }

            Section {
                Button {
                    editingIndex = nil
                    editingText = ""
                    showAddSheet = true
                } label: {
                    Label("Add Preset", systemImage: "plus.circle.fill")
                        .foregroundStyle(accentColor)
                }
            }

            Section {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { EditButton() }
        // Add sheet
        .sheet(isPresented: $showAddSheet) {
            PresetTextSheet(
                title: "Add Preset",
                placeholder: placeholder,
                accentColor: accentColor,
                initialText: "",
                onSave: { newText in
                    let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty, !presets.contains(trimmed) else { return }
                    presets.append(trimmed)
                }
            )
        }
        // Edit sheet
        .sheet(item: Binding(
            get: { editingIndex.map { IndexWrapper(index: $0) } },
            set: { editingIndex = $0?.index }
        )) { wrapper in
            PresetTextSheet(
                title: "Edit Preset",
                placeholder: placeholder,
                accentColor: accentColor,
                initialText: presets[wrapper.index],
                onSave: { newText in
                    let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    presets[wrapper.index] = trimmed
                }
            )
        }
        .confirmationDialog("Reset to Defaults?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { presets = defaults }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will replace all your custom presets with the built-in defaults.")
        }
    }
}

// MARK: - Preset Text Sheet

private struct PresetTextSheet: View {
    let title: String
    let placeholder: String
    let accentColor: Color
    let initialText: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(title: String, placeholder: String, accentColor: Color, initialText: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.placeholder = placeholder
        self.accentColor = accentColor
        self.initialText = initialText
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

    private var isValid: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(placeholder, text: $text)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit { if isValid { onSave(text); dismiss() } }
                }

                // Live preview chip
                Section("Preview") {
                    HStack {
                        Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? placeholder : text)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(accentColor.opacity(0.12))
                            .foregroundStyle(accentColor)
                            .clipShape(Capsule())
                        Spacer()
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(text); dismiss() }
                        .fontWeight(.semibold)
                        .tint(accentColor)
                        .disabled(!isValid)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Helpers

private struct IndexWrapper: Identifiable {
    let index: Int
    var id: Int { index }
}

private struct SettingsPresetBadge: View {
    let icon: String
    let color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(color.opacity(0.15))
                .frame(width: 28, height: 28)
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}
