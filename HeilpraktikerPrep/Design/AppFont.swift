import SwiftUI
import UIKit

/// Typography tokens, ported from the approved funnel prototype.
///
/// Two families: **Sora** for headings and the numbers that carry the pitch,
/// **Manrope** for everything else. Both Open Font License (Resources/Fonts).
///
/// Each token names a real face — never call `.weight()` on the result, as
/// SwiftUI cannot synthesise weights for a custom font and would silently
/// leave the type at the face's own weight.
enum AppFont {
    private enum Face: String {
        case regular = "Manrope-Regular"       // 400
        case medium = "Manrope-Medium"         // 500
        case semibold = "Manrope-SemiBold"     // 600
        case bold = "Manrope-Bold"             // 700
        case extraBold = "Manrope-ExtraBold"   // 800
        case soraBold = "Sora-Bold"            // 700
        case soraExtraBold = "Sora-ExtraBold"  // 800
    }

    /// Scales a base size with the user's Dynamic Type setting.
    private static func scaled(_ size: CGFloat) -> CGFloat {
        UIFontMetrics.default.scaledValue(for: size)
    }

    private static func font(_ face: Face, _ size: CGFloat, fallback: Font.Weight) -> Font {
        let points = scaled(size)
        guard UIFont(name: face.rawValue, size: points) != nil else {
            return .system(size: points, weight: fallback)
        }
        return .custom(face.rawValue, fixedSize: points)
    }

    // MARK: Sora — headings

    /// Screen titles. Sora 800.
    static func display(_ size: CGFloat = 27) -> Font {
        font(.soraExtraBold, size, fallback: .heavy)
    }

    /// Section headings inside a screen, and the headline statistic. Sora 700.
    static func title(_ size: CGFloat = 19) -> Font {
        font(.soraBold, size, fallback: .bold)
    }

    /// Big numbers: the 94,7%, the building percentage. Sora 700.
    static func stat(_ size: CGFloat = 26) -> Font {
        font(.soraBold, size, fallback: .bold)
    }

    /// The one number that has to shout — the free-days line. Sora 800.
    static func statHeavy(_ size: CGFloat = 29) -> Font {
        font(.soraExtraBold, size, fallback: .heavy)
    }

    // MARK: Manrope — everything else

    /// Manrope 800: badges, prices, card values that must out-weigh their row.
    static func strong(_ size: CGFloat = 16) -> Font {
        font(.extraBold, size, fallback: .heavy)
    }

    /// Manrope 700: option labels, card titles, emphasis inside a sentence.
    static func heading(_ size: CGFloat = 16) -> Font {
        font(.bold, size, fallback: .bold)
    }

    /// Manrope 600.
    static func bodyMedium(_ size: CGFloat = 16) -> Font {
        font(.semibold, size, fallback: .semibold)
    }

    /// Manrope 500.
    static func caption(_ size: CGFloat = 13) -> Font {
        font(.medium, size, fallback: .medium)
    }

    /// Manrope 400 — running text.
    static func body(_ size: CGFloat = 15) -> Font {
        font(.regular, size, fallback: .regular)
    }
}
