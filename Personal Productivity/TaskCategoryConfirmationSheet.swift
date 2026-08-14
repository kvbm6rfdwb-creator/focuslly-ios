import SwiftUI

struct TaskCategoryConfirmationSheet: View {

    let title: String
    let suggested: TaskCategory
    let confidence: Double
    let onConfirm: (TaskCategory) -> Void

    @State private var selection: TaskCategory
    @ObservedObject private var nameStore = CategoryNameStore.shared

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    init(
        title: String,
        suggested: TaskCategory,
        confidence: Double,
        onConfirm: @escaping (TaskCategory) -> Void
    ) {
        self.title = title
        self.suggested = suggested
        self.confidence = confidence
        self.onConfirm = onConfirm
        _selection = State(initialValue: suggested)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // ── Task title + confidence banner ────────────────
                    VStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                            Text("Suggested: \(suggested.displayName) · \(Int((confidence * 100).rounded()))% confident")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.10))
                        .clipShape(Capsule())
                    }
                    .padding(.top, 4)

                    // ── Category grid ─────────────────────────────────
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(TaskCategory.allCases) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selection == category
                            )
                            .onTapGesture { selection = category }
                        }
                    }

                    // ── Confirm button ────────────────────────────────
                    Button {
                        onConfirm(selection)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selection.icon)
                            Text("Confirm \(selection.displayName)")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(selection.color)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 8)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Choose Category")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let category: TaskCategory
    let isSelected: Bool
    @ObservedObject private var nameStore = CategoryNameStore.shared

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(isSelected ? 1 : 0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: category.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : category.color)
            }
            Text(category.displayName)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected
                      ? category.color.opacity(0.12)
                      : Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? category.color : Color.clear, lineWidth: 1.5)
        )
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
