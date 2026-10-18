import SwiftUI
import StoreKit

// MARK: - Shared pieces

/// The approved-candidate photos shipped in the asset catalog
/// (`pack.niche.studentPhotoCount`, 32 by default). The first eight are the
/// pair of rows on the opening screen; the paywall grid uses the rest. Swapping the art in `Assets.xcassets/Onboarding` re-skins every
/// surface that shows people — that's the portfolio-wide preset.
enum OnboardingPhotos {
    static func all(count: Int) -> [String] {
        (1...max(8, count)).map { String(format: "student%02d", $0) }
    }
    /// Exactly `slots` names for a grid: the first `slots` photos, repeating
    /// from the start when the niche has fewer photos than tiles, so a grid
    /// never shows a blank tile.
    static func grid(count: Int, slots: Int) -> [String] {
        let names = all(count: count)
        return (0..<max(0, slots)).map { names[$0 % names.count] }
    }
    /// Four per row: the loop is long enough that the repeat is not obvious
    /// at a glance, and the two rows never show the same face at once.
    static let introRowTop = Array(all(count: 8)[0..<4])
    static let introRowBottom = Array(all(count: 8)[4..<8])
}

/// A row of photos sliding sideways forever. The track holds two copies of the
/// list and its offset is driven off the clock rather than by an implicit
/// animation — a `repeatForever` here gets interrupted every time the funnel
/// re-lays out, which is what made the loop stutter.
struct PhotoMarqueeRow: View {
    let names: [String]
    var reversed = false
    var duration: Double = OnboardingTokens.marqueeDuration

    private var tileWidth: CGFloat { OnboardingTokens.tileWidth }
    private var tileHeight: CGFloat { OnboardingTokens.tileHeight }
    private var gap: CGFloat { OnboardingTokens.tileGap }
    private var loopWidth: CGFloat { CGFloat(names.count) * (tileWidth + gap) }

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let travelled = CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration) * loopWidth
            let offset = reversed ? travelled - loopWidth : -travelled

            Color.clear
                .frame(height: tileHeight)
                .overlay(alignment: .leading) {
                    track
                        .offset(x: offset)
                }
                .clipped()
        }
        .accessibilityHidden(true)
    }

    /// Two copies of the list: sliding exactly one copy's width and starting
    /// over lands on an identical frame, so the loop has no seam. Rasterised
    /// once so the per-frame offset is a cheap layer move, not a re-render of
    /// eight shadowed images.
    private var track: some View {
        HStack(spacing: gap) {
            ForEach(Array((names + names).enumerated()), id: \.offset) { _, name in
                FaceAwarePhoto(name: name, width: tileWidth, height: tileHeight)
                    .clipShape(RoundedRectangle(cornerRadius: OnboardingTokens.photoRadius))
                    .shadow(color: Color(red: 20 / 255, green: 40 / 255, blue: 70 / 255).opacity(0.14),
                            radius: 8, y: 3)
            }
        }
        .fixedSize()
        .drawingGroup()
    }
}

/// The statistic framed by the two laurel branches. Branch B goes on the left
/// and branch A on the right — the other way round they turn their backs on
/// the number.
struct LaurelStat<Content: View>: View {
    var tint: Color = OnboardingTokens.laurelTint
    var height: CGFloat = 60
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 16) {
            branch("laurelLeft")
            content()
            branch("laurelRight")
        }
        .foregroundStyle(tint)
    }

    private func branch(_ name: String) -> some View {
        Image(name)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: height * 27 / 60, height: height)
    }
}

/// Falling paper, used once — on the affirmation screen. Driven off the clock
/// so it keeps running through the funnel's own transitions.
struct ConfettiView: View {
    private struct Piece {
        let x: CGFloat
        let color: Color
        let offset: Double
        let speed: Double
        let size: CGSize
        let spin: Double
    }

    private static let pieces: [Piece] = {
        let palette: [Color] = [AppColor.error, AppColor.accent, AppColor.warning,
                                Color(hexString: "#6C5CE7"), AppColor.success]
        var generator = SystemRandomNumberGenerator()
        return (0..<44).map { index in
            Piece(x: .random(in: 0.02...0.98, using: &generator),
                  color: palette[index % palette.count],
                  offset: .random(in: 0...1, using: &generator),
                  speed: .random(in: 2.2...3.8, using: &generator),
                  size: CGSize(width: .random(in: 5...9, using: &generator),
                               height: .random(in: 9...15, using: &generator)),
                  spin: .random(in: -2...2, using: &generator))
        }
    }()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let now = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(Array(Self.pieces.enumerated()), id: \.offset) { _, piece in
                        let cycle = (now / piece.speed + piece.offset).truncatingRemainder(dividingBy: 1)
                        Rectangle()
                            .fill(piece.color)
                            .frame(width: piece.size.width, height: piece.size.height)
                            .rotationEffect(.radians(now * piece.spin))
                            .position(x: piece.x * geo.size.width,
                                      y: -20 + cycle * (geo.size.height + 40))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The green shield with a check — the affirmation screen's only illustration.
struct ShieldCheckMark: View {
    var size: CGFloat = 82

    var body: some View {
        ZStack {
            Image(systemName: "shield.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(
                    LinearGradient(colors: [Color(hexString: "#7BCB8B"), Color(hexString: "#3AA45C")],
                                   startPoint: .top, endPoint: .bottom))
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size * 1.13)
        .accessibilityHidden(true)
    }
}

// MARK: - 1. Abertura

struct OnboardingIntroStep: View {
    @Environment(AppSession.self) private var session

    private var strings: UIStrings.Onboarding { session.strings.onboarding }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            VStack(spacing: OnboardingTokens.tileGap) {
                PhotoMarqueeRow(names: OnboardingPhotos.introRowTop)
                PhotoMarqueeRow(names: OnboardingPhotos.introRowBottom, reversed: true)
            }
            // The rows bleed past the gutter, as in the reference.
            .padding(.horizontal, -OnboardingTokens.gutter)

            trustChip

            Spacer(minLength: 0)

            LaurelStat(height: 62) {
                VStack(spacing: 2) {
                    Text(strings.introStatValue)
                        .font(AppFont.stat(26))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(session.pack.nicheConfig.outcomeText(pass: strings.introStatLabel,
                                                              score: strings.introStatLabelScore))
                        .font(AppFont.bodyMedium(13))
                        .foregroundStyle(OnboardingTokens.leadText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(1)
                }
            }

            Text(strings.introTitle)
                .font(AppFont.display(27))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, AppSpacing.xs)

            Text(String(format: strings.introSubtitleFormat,
                        NicheConfig.displayYear(language: session.pack.language)))
                .font(AppFont.body(15))
                .foregroundStyle(OnboardingTokens.leadText)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTokens.gutter)
        .padding(.top, AppSpacing.sm)
    }

    private var trustChip: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(AppColor.success, in: Circle())
            Text(strings.introTrustChip)
                .font(AppFont.heading(13))
                .foregroundStyle(.white)
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.vertical, 9)
        .background(OnboardingTokens.chipBackground, in: Capsule())
        .shadow(color: .black.opacity(0.35), radius: 11, y: 8)
    }
}

// MARK: - 7. Afirmação

struct OnboardingAffirmationStep: View {
    @Environment(AppSession.self) private var session
    let model: OnboardingModel

    private var strings: UIStrings.Onboarding { session.strings.onboarding }

    var body: some View {
        ZStack {
            ConfettiView()
            VStack(spacing: AppSpacing.md) {
                Spacer()
                ShieldCheckMark(size: 82)
                Text(model.firstTime == 1 ? strings.affirmationRetry
                     : session.pack.nicheConfig.outcomeText(pass: strings.affirmationFirst,
                                                            score: strings.affirmationFirstScore))
                    .font(AppFont.display(27))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.md)
                Text(strings.affirmationLead)
                    .font(AppFont.body(16))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
                Spacer()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, OnboardingTokens.gutter)
        }
        .onAppear { Haptics.celebrate() }
    }
}

// MARK: - 9. Você está no lugar certo

struct OnboardingRightPlaceStep: View {
    @Environment(AppSession.self) private var session

    /// The rating chip only appears once the live App Store score clears 4.5 —
    /// below that it would be a claim we'd rather not make.
    @State private var shownChips = 0
    private static let heroHeight: CGFloat = 250

    private var strings: UIStrings.Onboarding { session.strings.onboarding }
    private var rating: Double? { session.pack.appStoreRating }
    private var showsRating: Bool { NicheConfig.showsRating(rating) }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            // Width comes from the column; the photo is cropped around the group's faces.
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: Self.heroHeight)
                .overlay {
                    GeometryReader { geo in
                        FaceAwarePhoto(name: session.pack.nicheConfig.heroImage,
                                       width: geo.size.width, height: geo.size.height, group: true)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero))
                .shadow(color: Color(red: 20 / 255, green: 40 / 255, blue: 70 / 255).opacity(0.16),
                        radius: 17, y: 14)
                .accessibilityLabel(Text(strings.rightPlaceTitleGreen))
                .padding(.top, AppSpacing.sm)

            (Text(strings.rightPlaceTitle + "\n")
                + Text(strings.rightPlaceTitleGreen).foregroundColor(AppColor.success))
                .font(AppFont.display(27))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, AppSpacing.xs)

            Text(strings.rightPlaceLead)
                .font(AppFont.body(15))
                .foregroundStyle(OnboardingTokens.leadText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 272)

            VStack(spacing: AppSpacing.sm) {
                proofChip(emoji: strings.rightPlaceProofTopEmoji,
                          text: session.pack.nicheConfig.outcomeText(
                              pass: strings.rightPlaceProofTop, score: strings.rightPlaceProofTopScore),
                          index: 0)
                if showsRating, let rating {
                    proofChip(emoji: strings.rightPlaceProofRatingEmoji,
                              text: String(format: strings.rightPlaceProofRatingFormat,
                                           Self.formatRating(rating, locale: session.pack.contentLocale)),
                              index: 1)
                }
            }
            .padding(.top, AppSpacing.xs)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTokens.gutter)
        .task { await revealChips() }
    }

    /// Each chip slides up in turn — the second only starts once the first has
    /// landed, so it reads as one notification pushing the other up.
    private func revealChips() async {
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { shownChips = 1 }
        Haptics.tap(.soft)
        guard showsRating else { return }
        try? await Task.sleep(for: .milliseconds(540))
        withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) { shownChips = 2 }
        Haptics.tap(.soft)
    }

    private func proofChip(emoji: String, text: String, index: Int) -> some View {
        HStack(spacing: 13) {
            Text(emoji)
                .font(.system(size: 22))
                .frame(width: 46, height: 46)
                .background(AppColor.successSoft, in: RoundedRectangle(cornerRadius: 13))
            Text(text)
                .font(AppFont.strong(15))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: OnboardingTokens.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: OnboardingTokens.cardRadius)
            .stroke(OnboardingTokens.surfaceBorder, lineWidth: 1))
        .shadow(color: Color(red: 20 / 255, green: 40 / 255, blue: 70 / 255).opacity(0.07),
                radius: 9, y: 6)
        .opacity(shownChips > index ? 1 : 0)
        .offset(y: shownChips > index ? 0 : 34)
    }

    /// Uses the pack's language, never the device locale: an en app on a
    /// pt-BR iPhone must still read "5.0", not "5,0".
    static func formatRating(_ value: Double, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: value as NSNumber) ?? String(value)
    }
}

// MARK: - 10. Avaliações

struct OnboardingReviewsStep: View {
    @Environment(AppSession.self) private var session
    let model: OnboardingModel

    @State private var loopHeight: CGFloat = 0

    private var strings: UIStrings.Onboarding { session.strings.onboarding }
    private var reviews: [UIStrings.Onboarding.Review] { strings.reviews }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Text(strings.reviewsTitle)
                .font(AppFont.display(23))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            LaurelStat(tint: Color(hexString: "#F5B301"), height: 52) {
                Text(String(repeating: "★", count: 5))
                    .font(.system(size: 24))
                    .tracking(3)
                    .foregroundStyle(Color(hexString: "#F5B301"))
            }

            Text(strings.reviewsLead)
                .font(AppFont.body(14))
                .foregroundStyle(OnboardingTokens.leadText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if !reviews.isEmpty { reviewMarquee }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, OnboardingTokens.gutter)
        .padding(.top, AppSpacing.sm)
    }

    /// The stack drifts upward forever. Cards are not all the same height, so
    /// the loop distance is measured from the first copy rather than assumed —
    /// a fixed slot left some cards touching and others far apart.
    private var reviewMarquee: some View {
        // The track is taller than the screen; an overlay keeps that height
        // from propagating out and pushing the page open.
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .top) {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSinceReferenceDate
                    let cycle = CGFloat(elapsed.truncatingRemainder(dividingBy: duration) / duration)
                    VStack(spacing: Self.cardGap) {
                        copy.background(
                            GeometryReader { geo in
                                Color.clear.preference(key: TrackHeightKey.self,
                                                       value: geo.size.height)
                            })
                        copy
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: -cycle * (loopHeight + Self.cardGap))
                }
            }
            .clipped()
            .onPreferenceChange(TrackHeightKey.self) { height in
                if height > 0 { loopHeight = height }
            }
            .mask(
                LinearGradient(stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.08),
                    .init(color: .black, location: 0.9),
                    .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom))
    }

    private var copy: some View {
        VStack(spacing: Self.cardGap) {
            ForEach(Array(reviews.enumerated()), id: \.offset) { _, review in
                reviewCard(review)
            }
        }
    }

    private static let cardGap: CGFloat = 12

    private var duration: Double { Double(max(reviews.count, 1)) * 5.5 }

    private func reviewCard(_ review: UIStrings.Onboarding.Review) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Text(review.title)
                    .font(AppFont.strong(14))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer(minLength: AppSpacing.sm)
                Text(String(repeating: "★", count: 5))
                    .font(.system(size: 12))
                    .foregroundStyle(Color(hexString: "#F5B301"))
            }
            Text(review.body)
                .font(AppFont.body(14))
                .foregroundStyle(OnboardingTokens.leadText)
                .fixedSize(horizontal: false, vertical: true)
            Text(review.author)
                .font(AppFont.bodyMedium(12))
                .foregroundStyle(AppColor.textDim)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: OnboardingTokens.optionRadius))
        .overlay(RoundedRectangle(cornerRadius: OnboardingTokens.optionRadius)
            .stroke(Color(hexString: "#E6ECF3"), lineWidth: 1))
        .shadow(color: Color(red: 20 / 255, green: 40 / 255, blue: 70 / 255).opacity(0.05), radius: 7, y: 4)
        .padding(.horizontal, 4)
    }
}

/// Natural height of one copy of the review list, used as the loop distance.
private struct TrackHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
