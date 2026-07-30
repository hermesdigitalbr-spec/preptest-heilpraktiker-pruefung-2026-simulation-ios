import SwiftUI
import UIKit

/// Adaptive color tokens. Every user-visible color in the app comes from here —
/// dark mode is a consequence of these tokens, never a retrofitted theme.
enum AppColor {
    /// Set once at launch from `PackConfig.accentHex`. Never read before content loads.
    static var accent: Color = Color(hexString: "#1B9AF7")
    static var accentSoft: Color { accent.opacity(0.14) }

    static let background    = adaptive("#F6F8FB", "#0D1117")
    static let surface       = adaptive("#FFFFFF", "#161C24")
    static let surfaceHigh   = adaptive("#EDF1F7", "#212A35")
    static let textPrimary   = adaptive("#101720", "#F2F6FA")
    static let textSecondary = adaptive("#566273", "#A7B1BF")
    static let textDim       = adaptive("#5F6B79", "#8A94A3")
    static let border        = adaptive("#E2E8F0", "#2B3543")
    static let success       = adaptive("#23A566", "#36C781")
    static let successSoft   = adaptive("#E3F6EC", "#15402C")
    static let error         = adaptive("#E5484D", "#F0565B")
    static let errorSoft     = adaptive("#FCEAEA", "#46191B")
    static let warning       = adaptive("#F5A623", "#FFB84D")
    /// Text/icon color ON TOP of `warning` fills — amber is light in both
    /// schemes, so the readable pairing is dark text, never white.
    static let onWarning     = adaptive("#4A2D00", "#3A2400")

    private static func adaptive(_ light: String, _ dark: String) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(hexString: dark)
                : UIColor(hexString: light)
        })
    }
}

extension UIColor {
    convenience init(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        let r = CGFloat((value & 0xFF0000) >> 16) / 255
        let g = CGFloat((value & 0x00FF00) >> 8) / 255
        let b = CGFloat(value & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    init(hexString: String) { self.init(UIColor(hexString: hexString)) }
}
