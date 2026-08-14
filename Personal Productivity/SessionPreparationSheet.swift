import SwiftUI

// MARK: - Session Intention Store

final class SessionIntentionStore {
    static let shared = SessionIntentionStore()
    private let key = "session_intentions_v1"

    func set(_ intention: String, for taskId: UUID) {
        var dict = all()
        dict[taskId.uuidString] = intention
        UserDefaults.standard.set(dict, forKey: key)
    }

    func get(for taskId: UUID) -> String? {
        all()[taskId.uuidString]
    }

    private func all() -> [String: String] {
        UserDefaults.standard.dictionary(forKey: key) as? [String: String] ?? [:]
    }
}

// MARK: - Session Preparation Sheet

struct SessionPreparationSheet: View {
    let task: FocusTask
    /// Called when user taps Start. Passes optional intention text.
    let onStart: (String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var intention: String = ""
    @FocusState private var intentionFocused: Bool

    private var durationMins: Int {
        (task.focusPlan.blocks.first(where: { $0.type == .focus })?.duration ?? 0) / 60
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Task context strip ────────────────────────────────
                VStack(spacing: 6) {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(uiColor: .tertiarySystemFill))
                                .frame(width: 40, height: 40)
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(LinearGradient(
                                    colors: [Color.brg, Color.brgBright],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.system(size: 16, weight: .bold))
                                .lineLimit(2)
                            Text("\(durationMins) min session")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)

                Divider()

                // ── Intention field ───────────────────────────────────
                VStack(alignment: .leading, spacing: 10) {
                    Label("Set your intention", systemImage: "text.quote")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)

                    TextField("What will you accomplish in this session?", text: $intention, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(3...5)
                        .padding(14)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .focused($intentionFocused)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Text("Optional — helps you reflect after the session")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                Spacer()

                // ── Start button ──────────────────────────────────────
                Button {
                    HapticManager.impact()
                    let trimmed = intention.trimmingCharacters(in: .whitespacesAndNewlines)
                    onStart(trimmed.isEmpty ? nil : trimmed)
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Start focusing")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.brg)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Ready to focus?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                if intention.isEmpty, let saved = SessionIntentionStore.shared.get(for: task.id) {
                    intention = saved
                }
                // Removed auto-focus to prevent keyboard from showing automatically
            }
        }
        .floatingKeyboardDismiss(isVisible: intentionFocused)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
