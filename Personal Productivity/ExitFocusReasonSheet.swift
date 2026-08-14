import SwiftUI

struct ExitFocusReasonSheet: View {

    let onDecision: (FocusSessionExit) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var showCustomInput = false
    @State private var customReason = ""

    var body: some View {
        VStack(spacing: 20) {

            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 8)

            Text("Why did you leave focus?")
                .font(.title3.weight(.semibold))

            if showCustomInput {
                customReasonInput
            } else {
                reasonButtons
            }

            Spacer(minLength: 12)
        }
        .padding()
        .background(.ultraThinMaterial)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }

    private var reasonButtons: some View {
        VStack(spacing: 12) {

            reasonButton(
                title: "Had to do something",
                subtitle: "I'm continuing with the task",
                systemImage: "arrow.clockwise.circle.fill"
            ) {
                select(.continueNow)
            }

            reasonButton(
                title: "Lost focus",
                subtitle: "I got distracted",
                systemImage: "eye.slash.fill"
            ) {
                select(.distracted)
            }

            reasonButton(
                title: "Finished early",
                subtitle: "Done sooner than planned",
                systemImage: "checkmark.circle.fill"
            ) {
                select(.earlyFinished)
            }

            reasonButton(
                title: "Other reason",
                subtitle: "Tell us what happened",
                systemImage: "ellipsis.circle.fill"
            ) {
                showCustomInput = true
            }
        }
    }

    private var customReasonInput: some View {
        VStack(spacing: 12) {
            TextField("What happened?", text: $customReason)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)

            HStack(spacing: 12) {
                Button(action: { showCustomInput = false }) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.secondary.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Button(action: {
                    select(.other(customReason))
                }) {
                    Text("Submit")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(customReason.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Button
    private func reasonButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
            )
        }
        .buttonStyle(.plain)
    }

    private func select(_ exit: FocusSessionExit) {
        onDecision(exit)
        dismiss()
    }
}
