import UIKit

enum HapticManager {

    // Injected from App
    static var settings: AppSettingsStore?

    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        guard settings?.hapticsEnabled ?? true else { return }

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    static func success() {
        guard settings?.hapticsEnabled ?? true else { return }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}
