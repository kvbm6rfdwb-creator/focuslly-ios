import SwiftUI

// MARK: - CategoryColourPickerView

struct CategoryColourPickerView: View {

    @StateObject private var colorStore = CategoryColorStore.shared
    @State private var editingCategory: TaskCategory? = nil
    @State private var refresh = false

    // Preset palette — nice system colours
    private let palette: [Color] = [
        .red, .orange, .yellow, Color(red: 0.75, green: 0.6, blue: 0),
        .green, .mint, .teal, .cyan,
        .blue, .indigo, .purple, .pink,
        .brown, .gray, Color(red: 0.4, green: 0.2, blue: 0.6),
        Color(red: 0.9, green: 0.4, blue: 0.1)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                ForEach(Array(TaskCategory.allCases.enumerated()), id: \.element.id) { idx, category in
                    if idx > 0 { Divider().padding(.leading, 60) }
                    categoryRow(category)
                }
            }
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // Reset all button
            Button(role: .destructive) {
                withAnimation { colorStore.resetAll(); refresh.toggle() }
            } label: {
                Label("Reset all colours to default", systemImage: "arrow.counterclockwise")
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Category Colours")
        .navigationBarTitleDisplayMode(.inline)
        .id(refresh)
        .sheet(item: $editingCategory) { category in
            ColourPickerSheet(
                category: category,
                palette: palette,
                current: colorStore.color(for: category),
                onSelect: { color in
                    colorStore.setColor(color, for: category)
                    refresh.toggle()
                },
                onReset: {
                    colorStore.resetColor(for: category)
                    refresh.toggle()
                }
            )
        }
    }

    private func categoryRow(_ category: TaskCategory) -> some View {
        let isCustom = CategoryColorStore.shared.customColors[category.rawValue]?.isEmpty == false
        return Button {
            editingCategory = category
        } label: {
            HStack(spacing: 14) {
                // Colour swatch
                ZStack {
                    Circle()
                        .fill(category.color)
                        .frame(width: 34, height: 34)
                    Image(systemName: category.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.primary)
                    if isCustom {
                        Text("Custom colour")
                            .font(.system(size: 11))
                            .foregroundStyle(category.color)
                    } else {
                        Text("Default")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                // Colour preview circle
                Circle()
                    .fill(category.color)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ColourPickerSheet

private struct ColourPickerSheet: View {
    let category: TaskCategory
    let palette: [Color]
    let current: Color
    let onSelect: (Color) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selected: Color
    @State private var customColor: Color

    init(category: TaskCategory, palette: [Color], current: Color,
         onSelect: @escaping (Color) -> Void, onReset: @escaping () -> Void) {
        self.category = category
        self.palette = palette
        self.current = current
        self.onSelect = onSelect
        self.onReset = onReset
        _selected = State(initialValue: current)
        _customColor = State(initialValue: current)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // Preview
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(selected.opacity(0.15))
                                .frame(width: 64, height: 64)
                            Image(systemName: category.icon)
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(selected)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(category.title)
                                .font(.system(size: 18, weight: .bold))
                            Text("Tap a colour to preview")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    // Preset palette
                    VStack(alignment: .leading, spacing: 12) {
                        Text("PRESET COLOURS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(0.4)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 8), spacing: 12) {
                            ForEach(palette.indices, id: \.self) { i in
                                let color = palette[i]
                                Button {
                                    HapticManager.impact()
                                    selected = color
                                } label: {
                                    ZStack {
                                        Circle().fill(color).frame(width: 36, height: 36)
                                        if isSameColor(selected, color) {
                                            Circle()
                                                .stroke(Color(.systemBackground), lineWidth: 2.5)
                                                .frame(width: 36, height: 36)
                                            Circle()
                                                .stroke(color, lineWidth: 2)
                                                .frame(width: 42, height: 42)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    // Custom colour picker
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CUSTOM COLOUR")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .kerning(0.4)
                        ColorPicker("Pick any colour", selection: $customColor, supportsOpacity: false)
                            .font(.system(size: 14))
                            .onChange(of: customColor) { _, newColor in
                                selected = newColor
                            }
                    }
                    .padding(16)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    // Reset to default
                    Button(role: .destructive) {
                        onReset()
                        dismiss()
                    } label: {
                        Label("Reset to default (\(colorName(category.defaultColor)))", systemImage: "arrow.counterclockwise")
                            .font(.system(size: 14))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Choose Colour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onSelect(selected)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.fraction(0.85)])
        .presentationDragIndicator(.visible)
    }

    private func isSameColor(_ a: Color, _ b: Color) -> Bool {
        UIColor(a).cgColor.components?.prefix(3).map { Int($0 * 255) } ==
        UIColor(b).cgColor.components?.prefix(3).map { Int($0 * 255) }
    }

    private func colorName(_ color: Color) -> String {
        switch color {
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .mint: return "Mint"
        case .teal: return "Teal"
        case .cyan: return "Cyan"
        case .blue: return "Blue"
        case .indigo: return "Indigo"
        case .purple: return "Purple"
        case .pink: return "Pink"
        case .brown: return "Brown"
        case .gray: return "Gray"
        default: return "Default"
        }
    }
}


