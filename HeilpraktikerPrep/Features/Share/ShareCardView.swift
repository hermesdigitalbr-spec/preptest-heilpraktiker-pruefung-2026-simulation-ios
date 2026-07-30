import SwiftUI
import UIKit

/// Fully-resolved data for the share card — the view depends on no app
/// singletons so it renders cleanly off the main UI (ImageRenderer) and stays
/// testable. Build it from AppSession at the call site.
struct ShareCardData: Equatable {
    let eyebrow: String          // e.g. "PREP KIT TEXT" (pack.examName.uppercased)
    let headline: String         // tier line
    let score: Int               // 0...100
    let correctText: String      // "23/25"
    let streak: Int              // hidden if < 2
    let timeText: String         // "4:12"
    let challenge: String        // "Think you can beat 92%?"
    let brandName: String        // from pack.examName
    let tagline: String          // from pack.tagline
    let correctLabel: String     // "Correct"
    let streakLabel: String      // "Day Streak"
    let timeLabel: String        // "Time", scoreLabel: "Meine Punktzahl"
    let scoreLabel: String     // "My Score" — eyebrow dentro do anel
    let iconGlyph: String        // wordmark in the mini app icon, e.g. "EXAM"

    var progress: Double { min(max(Double(score) / 100, 0), 1) }
}

/// The shareable result card — minimalist, in the app's visual language.
/// Self-contained: literal hex values frozen from the app's LIGHT palette so
/// the image looks the same regardless of the sharer's system appearance.
/// Built at 360×490 pt; render at scale 3 → 1080×1470 px.
/// Constraints (ImageRenderer): no AppColor (adaptive), no AppFont
/// (UIFontMetrics-scaled), no GeometryReader, no Material.
struct ShareCardView: View {
    static let canvasWidth: CGFloat = 360
    static let canvasHeight: CGFloat = 490

    let data: ShareCardData
    var cornerRadius: CGFloat = 0

    // Palette = AppColor light mode, baked in as literal hex.
    private let background     = Color(hexString: "#F6F8FB")
    private let surface        = Color(hexString: "#FFFFFF")
    private let surfaceHigh    = Color(hexString: "#EDF1F7")
    private let textPrimary    = Color(hexString: "#101720")
    private let textSecondary  = Color(hexString: "#566273")
    private let textDim        = Color(hexString: "#8C97A7")
    private let border         = Color(hexString: "#E2E8F0")
    private let accent         = Color(hexString: "#1B9AF7")
    private let accentSoft     = Color(hexString: "#E4F3FE")
    private let success        = Color(hexString: "#23A566")
    private let warning        = Color(hexString: "#F5A623")

    var body: some View {
        ZStack {
            backdrop
            VStack(spacing: 0) {
                eyebrow.padding(.top, 32)
                Spacer(minLength: 12)
                hero
                Spacer(minLength: 14)
                Text(data.headline)
                    .font(.system(size: 28, weight: .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 28)
                Spacer(minLength: 14)
                statRow.padding(.horizontal, 26)
                Spacer(minLength: 14)
                challengeLine.padding(.horizontal, 28)
                Spacer(minLength: 18)
                footer.padding(.horizontal, 22).padding(.bottom, 24)
            }
        }
        .frame(width: Self.canvasWidth, height: Self.canvasHeight)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    // MARK: - Backdrop (soft surface, subtle accent halo)

    private var backdrop: some View {
        ZStack {
            background
            // Single soft accent halo at the top — the app's gentle glow,
            // not a vibrant gradient.
            RadialGradient(colors: [accent.opacity(0.10), accent.opacity(0)],
                           center: UnitPoint(x: 0.5, y: 0.18),
                           startRadius: 0, endRadius: 220)
        }
    }

    // MARK: - Eyebrow

    private var eyebrow: some View {
        Text(data.eyebrow)
            .font(.system(size: 12, weight: .semibold))
            .tracking(1.6)
            .foregroundStyle(textDim)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 28)
    }

    // MARK: - Hero ring + score (clean, app's RingGauge style)

    private var hero: some View {
        ZStack {
            Circle()
                .inset(by: 7)
                .stroke(surfaceHigh, style: StrokeStyle(lineWidth: 14, lineCap: .round))
            Circle()
                .inset(by: 7)
                .trim(from: 0, to: data.progress)
                .stroke(accent, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 2) {
                // 3-digit scores ("100%") get shrunk 20% so they sit inside the
                // ring with the same visual weight as 1- or 2-digit scores.
                let scoreFont: CGFloat = data.score >= 100 ? 77 : 96
                let pctFont: CGFloat = data.score >= 100 ? 26 : 32
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("\(data.score)")
                        .font(.system(size: scoreFont, weight: .heavy))
                        .tracking(-3)
                        .monospacedDigit()
                        .foregroundStyle(textPrimary)
                    Text("%")
                        .font(.system(size: pctFont, weight: .heavy))
                        .foregroundStyle(accent)
                }
                .lineLimit(1)

                Text(data.eyebrowSubLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(textDim)
                    .padding(.top, 2)
            }
        }
        .frame(width: 208, height: 208)
    }

    // MARK: - Stat row (clean chips — light, soft border, semantic tints)

    private var statRow: some View {
        HStack(spacing: 10) {
            chip(symbol: "checkmark.circle.fill", tint: success,
                 value: data.correctText, label: data.correctLabel)
            if data.streak >= 2 {
                chip(symbol: "flame.fill", tint: warning,
                     value: "\(data.streak)", label: data.streakLabel)
            }
            chip(symbol: "clock.fill", tint: accent,
                 value: data.timeText, label: data.timeLabel)
        }
    }

    private func chip(symbol: String, tint: Color, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: symbol)
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(tint)
                .font(.system(size: 14, weight: .semibold))
            Text(value)
                .font(.system(size: 19, weight: .heavy))
                .monospacedDigit()
                .foregroundStyle(textPrimary)
            Text(label.uppercased(with: .current))
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(textDim)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(surface))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(border, lineWidth: 1))
    }

    // MARK: - Challenge line (subtle, single text — no bold banner)

    private var challengeLine: some View {
        HStack(spacing: 6) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(accent)
            Text(data.challenge)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer()
        }
    }

    // MARK: - Footer (brand + CTA — minimal)

    private var footer: some View {
        VStack(spacing: 14) {
            Rectangle().fill(border).frame(height: 1)
            HStack(spacing: 10) {
                miniIcon
                VStack(alignment: .leading, spacing: 1) {
                    Text(data.brandName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(textPrimary)
                        .lineLimit(1)
                    Text(data.tagline)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(textDim)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                appStorePill
            }
        }
    }

    /// Faithful mini app icon rebuilt in shapes (the .appiconset isn't loadable by name).
    private var miniIcon: some View {
        Image("ShareAppIcon")
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(border, lineWidth: 1))
    }

    private var appStorePill: some View {
        HStack(spacing: 5) {
            Image(systemName: "applelogo")
                .font(.system(size: 12))
                .symbolRenderingMode(.monochrome)
            VStack(alignment: .leading, spacing: 0) {
                Text("LADEN IM")
                    .font(.system(size: 7, weight: .semibold))
                Text("App Store")
                    .font(.system(size: 12, weight: .bold))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(accent))
    }
}

private extension ShareCardData {
    /// Tiny label under the score inside the ring — vem do ContentPack
    /// (results.scoreLabel), igual aos outros labels do card.
    var eyebrowSubLabel: String { scoreLabel.uppercased(with: .current) }
}

/// Renders a ShareCardData into a shareable PNG (1080×1470).
enum ShareCardRenderer {
    @MainActor
    static func image(for data: ShareCardData) -> UIImage? {
        let view = ShareCardView(data: data)
            .frame(width: ShareCardView.canvasWidth, height: ShareCardView.canvasHeight)
            .environment(\.dynamicTypeSize, .large)   // pin Dynamic Type for a fixed canvas
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

#if DEBUG
#Preview {
    ShareCardView(data: ShareCardData(
        eyebrow: "PREP KIT TEXT", headline: "Outstanding!", score: 92,
        correctText: "23/25", streak: 7, timeText: "4:12",
        challenge: "Think you can beat 92%?", brandName: "Prep Kit Text",
        tagline: "REPLACE — your one-line tagline",
        correctLabel: "Correct", streakLabel: "Day Streak", timeLabel: "Time", scoreLabel: "Meine Punktzahl",
        iconGlyph: "EXAM"),
        cornerRadius: 24)
    .scaleEffect(0.8)
}
#endif
