import SwiftUI
import UIKit

/// Typography tokens. SF Pro (system default) — professional, adult tone for
/// exam prep (rounded read as childish); free of font licensing across clones.
enum AppFont {
    /// Scales a base size with the user's Dynamic Type setting.
    private static func scaled(_ size: CGFloat) -> CGFloat {
        UIFontMetrics.default.scaledValue(for: size)
    }

    static func display(_ size: CGFloat = 30) -> Font {
        .system(size: scaled(size), weight: .heavy, design: .default)
    }

    static func heading(_ size: CGFloat = 22) -> Font {
        .system(size: scaled(size), weight: .bold, design: .default)
    }

    static func bodyMedium(_ size: CGFloat = 17) -> Font {
        .system(size: scaled(size), weight: .semibold, design: .default)
    }

    static func body(_ size: CGFloat = 17) -> Font {
        .system(size: scaled(size), weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 14) -> Font {
        .system(size: scaled(size), weight: .medium, design: .default)
    }
}
