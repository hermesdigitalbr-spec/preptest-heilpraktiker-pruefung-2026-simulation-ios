import SwiftUI

/// Measurements lifted straight from the approved funnel prototype, kept apart
/// from the app-wide scale so the rest of the product keeps its own rhythm.
enum OnboardingTokens {
    /// The funnel breathes wider than the app's default 20pt gutter.
    static let gutter: CGFloat = 24

    static let optionRadius: CGFloat = 16
    static let optionPadding: CGFloat = 16
    static let optionBorder: CGFloat = 1.5

    static let cardRadius: CGFloat = 18
    static let photoRadius: CGFloat = 14

    /// Marquee tile: 118pt wide, 3:4 portrait, 9pt apart.
    static let tileWidth: CGFloat = 118
    static var tileHeight: CGFloat { tileWidth * 4 / 3 }
    static let tileGap: CGFloat = 9
    static let marqueeDuration: Double = 30

    static let progressHeight: CGFloat = 8
    static let progressMaxWidth: CGFloat = 230

    static let optionBorderColor = Color(hexString: "#E2E8F0")
    static let surfaceBorder = Color(hexString: "#E6EBF2")
    static let leadText = Color(hexString: "#4A5A70")
    static let laurelTint = Color(hexString: "#9AA7B8")
    /// The dark pill that carries the social-proof line on the opening screen.
    static let chipBackground = Color(red: 12 / 255, green: 20 / 255, blue: 34 / 255).opacity(0.82)
}
