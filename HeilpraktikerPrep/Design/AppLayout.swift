import SwiftUI

/// iPad-aware layout helpers.
///
/// The app is portrait-only on iPhone, so iPhone is *always* horizontally
/// `.compact`. Every `.regular` branch in this file therefore only ever runs
/// on iPad: on iPhone (and in a narrow iPad Split View / Slide Over pane, which
/// also reports `.compact`) the content is returned unchanged, byte-for-byte
/// identical to the existing full-width layout. This is the single guarantee
/// that the iPad adaptation never alters the iPhone experience.
enum AppLayout {
    /// Readable content-width caps for the regular (iPad) size class. Centered
    /// columns at these widths keep line length and control proportions close
    /// to the iPhone design instead of stretching across a 13" canvas.
    static let readableContent: CGFloat = 700   // dashboards, lists, results, stats
    static let readableNarrow: CGFloat = 600    // onboarding, settings forms
    static let readablePaywall: CGFloat = 520   // paywall column
    static let readableWide: CGFloat = 820      // achievements badge wall
    static let ctaMaxWidth: CGFloat = 420       // primary CTA on iPad
}

/// Caps content to a readable width and centers it — ONLY in the regular
/// (iPad) size class. On compact (iPhone) it returns `content` untouched.
private struct ReadableWidth: ViewModifier {
    @Environment(\.horizontalSizeClass) private var hSize
    let maxWidth: CGFloat
    let alignment: Alignment

    func body(content: Content) -> some View {
        if hSize == .regular {
            content
                .frame(maxWidth: maxWidth, alignment: alignment)
                .frame(maxWidth: .infinity)
        } else {
            content
        }
    }
}

extension View {
    /// Centers content within a readable max width on iPad (regular size class);
    /// a no-op on iPhone (compact). Apply to a screen's scroll content so the
    /// surrounding full-bleed background still fills the window.
    /// - Parameters:
    ///   - maxWidth: the column cap on iPad. Defaults to `AppLayout.readableContent`.
    ///   - alignment: how content sits inside the capped column (use `.leading`
    ///     for leading-aligned dashboards). Defaults to `.center`.
    func readableWidth(_ maxWidth: CGFloat = AppLayout.readableContent,
                       alignment: Alignment = .center) -> some View {
        modifier(ReadableWidth(maxWidth: maxWidth, alignment: alignment))
    }
}
