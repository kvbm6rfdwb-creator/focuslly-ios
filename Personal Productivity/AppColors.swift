import SwiftUI

/// Single source of truth for every green in the app.
/// British Racing Green — deep, dark, jewel-toned. #004225
enum AppColors {
    /// Primary brand accent. Use for: backgrounds, fills, button backgrounds, progress bars.
    static let accent = Color(red: 0.0, green: 0.259, blue: 0.145)

    /// Bright accent — vivid medium green for TEXT and ICONS on dark/card backgrounds.
    /// Use wherever BRG would be invisible: trend numbers, badges, labels on cards.
    static let accentBright = Color(red: 0.13, green: 0.74, blue: 0.37)

    /// Slightly lighter tint for backgrounds/fills where full accent is too heavy.
    static let accentMuted = Color(red: 0.0, green: 0.259, blue: 0.145).opacity(0.12)
}

/// Convenience so call sites read `.brg` instead of `AppColors.accent`.
extension Color {
    static let brg       = AppColors.accent
    static let brgBright = AppColors.accentBright
    static let brgMuted  = AppColors.accentMuted
}
