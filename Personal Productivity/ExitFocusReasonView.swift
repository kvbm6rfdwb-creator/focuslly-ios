import SwiftUI

struct ExitFocusReasonView: View {

    let onSelect: (FocusExitReason) -> Void
    let onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(FocusExitReason.allCases) { reason in
                    Button {
                        onSelect(reason)
                        dismiss()
                    } label: {
                        Text(title(for: reason))
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Why did you stop?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Title mapping (EXHAUSTIVE)
    private func title(for reason: FocusExitReason) -> String {
        switch reason {
        case .completed:
            return "Completed session"
        case .distracted:
            return "Got distracted"
        case .interrupted:
            return "Had to do something, continuing"
        case .paused:
            return "Just paused"
        case .tired:
            return "Too tired"
        case .other:
            return "Other reason"
        case .breakEnded:
            return "Break ended"
        case .prolonged:
            return "Extended & completed"
        }
    }
}
