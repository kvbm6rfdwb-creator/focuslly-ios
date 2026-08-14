import SwiftUI

// MARK: - Floating Keyboard Dismiss Button
// Glassmorphic floating checkmark that appears above the keyboard.
// Usage: .floatingKeyboardDismiss(isVisible: $anyFocusState)

struct FloatingKeyboardDismissModifier: ViewModifier {
    let isVisible: Bool

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottomTrailing) {
                if isVisible {
                    Button {
                        UIApplication.shared.sendAction(
                            #selector(UIResponder.resignFirstResponder),
                            to: nil, from: nil, for: nil
                        )
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .opacity(0.9)
                            Circle()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            Color.white.opacity(0.55),
                                            Color.white.opacity(0.1),
                                            Color.black.opacity(0.25)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                            Image(systemName: "checkmark")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.primary)
                        }
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.25), radius: 10, x: 0, y: 4)
                        .shadow(color: .white.opacity(0.06), radius: 2, x: 0, y: -1)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 20)
                    .padding(.bottom, 8)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
    }
}

extension View {
    func floatingKeyboardDismiss(isVisible: Bool) -> some View {
        modifier(FloatingKeyboardDismissModifier(isVisible: isVisible))
    }
}

// Keyboard dismiss is handled per-view via ToolbarItemGroup(placement: .keyboard)
// in each NavigationStack's .toolbar block.
