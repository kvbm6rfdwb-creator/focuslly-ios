import SwiftUI

struct SystemView: View {

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                Text("System")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                rulesSection
                feedbackSection
                memorySection
            }
            .padding()
        }
        .background(Color.black)
    }

    // MARK: - Rules

    private var rulesSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Rules")
                    .font(.headline)
                    .foregroundStyle(.white)

                ruleRow("Do not schedule tasks under 20 minutes")
                ruleRow("Prefer deep work in the morning")
                ruleRow("Avoid back-to-back focus blocks")
            }
        }
    }

    private func ruleRow(_ text: String) -> some View {
        HStack {
            Text(text)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.brg)
        }
    }

    // MARK: - Feedback

    private var feedbackSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Feedback")
                    .font(.headline)
                    .foregroundStyle(.white)

                feedbackRow("AI scheduled tasks too tightly")
                feedbackRow("Preferred longer focus sessions")
                feedbackRow("Low energy in the afternoon")
            }
        }
    }

    private func feedbackRow(_ text: String) -> some View {
        HStack {
            Text(text)
                .foregroundStyle(.white)

            Spacer()

            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - AI Memory

    private var memorySection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("AI Memory")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("You are most productive between 10:00–12:00.")
                    .foregroundStyle(.white.opacity(0.7))

                Text("You often exit focus early in the evening.")
                    .foregroundStyle(.white.opacity(0.7))

                Text("Short tasks feel disruptive to your flow.")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}

#Preview {
    SystemView()
}

