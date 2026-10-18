import SwiftUI

enum PaywallSlideMetrics {
    /// iPhone 17 Pro slide area (art + title + subtitle), in points.
    static let referenceSize = CGSize(width: 322, height: 311)
    /// Headline and supporting line: 20% above the original 24/16.
    static let titleSize: CGFloat = 29
    static let subtitleSize: CGFloat = 19
    /// Cap on how much bigger the slide type gets on iPad.
    static let maxTextScale: CGFloat = 1.1
    /// The type shrinks to this before the art gives up any more height.
    static let minTextScale: CGFloat = 0.72
    /// The photo grid never gets less than this, even on the shortest screen.
    static let minArtHeight: CGFloat = 132
    /// ...and never less than this share of a short slide area.
    static let minArtShare: CGFloat = 0.52
    /// Below this the slide runs in its tight layout.
    static let shortSlideHeight: CGFloat = 290
}

/// Shared layout for the three onboarding-paywall slides: artwork on top,
/// then a headline and a green supporting line.
private struct PaywallSlideFrame<Art: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder var art: () -> Art

    /// Room kept for the two text lines below the art. Measured once rather
    /// than negotiated: a flexible art view inside a paged TabView was being
    /// handed less height than the page actually had, leaving a hole under
    /// the subtitle.
    private let textBlockHeight: CGFloat = 149
    /// The art never takes more than this, so the text sits right under it
    /// instead of drifting to the bottom of a tall page.
    private let artMaxHeight: CGFloat = 300
    private let topInset: CGFloat = 28

    @Environment(\.horizontalSizeClass) private var hSize

    /// The slide area on an iPhone 17 Pro (art + title + subtitle), measured
    /// in the simulator. On iPad the slide is laid out at this size and scaled
    /// up to fit the room it has, so it keeps the iPhone's proportions
    /// instead of leaving a dead band under a 300pt-capped art strip.
    static var referenceSize: CGSize { PaywallSlideMetrics.referenceSize }
    /// Headline/supporting line, 20% above the original 24/16 at the
    /// operator's request. The lines still cap at two and shrink to fit.
    static var titleSize: CGFloat { PaywallSlideMetrics.titleSize }
    static var subtitleSize: CGFloat { PaywallSlideMetrics.subtitleSize }

    /// Scale for a regular-width slide area: limited by width and height.
    /// Never shrinks, and iPhone (compact) is never touched.
    static func iPadScale(for available: CGSize) -> CGFloat {
        max(1, min(available.width / referenceSize.width, available.height / referenceSize.height))
    }

    var body: some View {
        GeometryReader { geo in
            if hSize == .regular {
                // iPad: same proportions as the iPhone slide, scaled to the
                // room available (width AND height), centred — no dead band.
                iPadSlide(size: geo.size)
            } else {
                phoneSlide(size: geo.size)
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    /// The art grows with the slide; the type only just enough to not look
    /// undersized on a 13" screen. Scaling the headline linearly made it shout.
    static func textScale(for scale: CGFloat) -> CGFloat {  // swiftlint:disable:this identifier_name
        #if DEBUG
        if ProcessInfo.processInfo.environment["PAYWALL_IPAD_TEXT_LINEAR"] != nil { return scale }
        #endif
        return min(scale, PaywallSlideMetrics.maxTextScale)
    }

    /// How big the type may be, and how much height is left for the art, on
    /// a slide area of this height. The text block is reserved first, but it
    /// shrinks (never below `minTextScale`) before the art does, and the art
    /// never falls under `minArtHeight` while there is room at all.
    /// A short slide also gives up the top inset: on an SE every point of
    /// height is either art or type.
    static func inset(_ base: CGFloat, height: CGFloat) -> CGFloat {
        height < PaywallSlideMetrics.shortSlideHeight ? 8 : base
    }

    static func fit(height: CGFloat, textBlock: CGFloat, inset: CGFloat,
                    artMax: CGFloat, cap: CGFloat = 1) -> (textScale: CGFloat, art: CGFloat, text: CGFloat) {
        let usable = max(0, height - inset)
        let wanted = min(cap, PaywallSlideMetrics.maxTextScale)
        let fits = (usable - PaywallSlideMetrics.minArtHeight) / textBlock
        let textScale = min(wanted, max(PaywallSlideMetrics.minTextScale, fits))
        // The art keeps at least its share of a short slide: it may be small,
        // it may never vanish. Whatever is left is the text's, and the labels
        // shrink inside it rather than being clipped.
        // Only a short slide trades type for art; taller screens keep the
        // layout the operator approved.
        let floorShare = height < PaywallSlideMetrics.shortSlideHeight
            ? PaywallSlideMetrics.minArtShare : 0
        let art = min(artMax, max(usable * floorShare, usable - textBlock * textScale))
        return (textScale, art, max(0, usable - art))
    }

    /// iPhone: the art takes whatever height the page leaves it, after the
    /// headline — which shrinks on a short screen instead of pushing the
    /// photos off the slide.
    private func phoneSlide(size: CGSize) -> some View {
        let inset = Self.inset(topInset, height: size.height)
        let f = Self.fit(height: size.height, textBlock: textBlockHeight,
                         inset: inset, artMax: artMaxHeight)
        let spacing = 8 * f.textScale
        return VStack(spacing: spacing) {
            art()
                .frame(height: f.art)
                .clipped()
                .padding(.top, inset)
            textBlock(scale: f.textScale, height: max(0, f.text - spacing))
            Spacer(minLength: 0)
        }
        .frame(width: size.width, height: size.height, alignment: .top)
    }

    /// The art block, always composed at the iPhone reference width and only
    /// then scaled: on iPad the grid, the cards and the rings keep the exact
    /// composition of the phone instead of being stretched across 13 inches.
    /// Typography stays at (or just above) the phone's size.
    private func iPadSlide(size: CGSize) -> some View {
        let referenceArt = max(0, min(artMaxHeight, Self.referenceSize.height - textBlockHeight - topInset))
        let f = Self.fit(height: size.height, textBlock: textBlockHeight, inset: topInset,
                         artMax: .greatestFiniteMagnitude,
                         cap: Self.textScale(for: Self.iPadScale(for: size)))
        let scale = max(1, min(size.width / Self.referenceSize.width, f.art / referenceArt))
        return VStack(spacing: 10 * f.textScale) {
            Color.clear
                .frame(width: Self.referenceSize.width * scale, height: referenceArt * scale)
                .overlay(alignment: .topLeading) {
                    art()
                        .frame(width: Self.referenceSize.width, height: referenceArt)
                        .scaleEffect(scale, anchor: .topLeading)
                }
                .clipped()
                .padding(.top, topInset * f.textScale)
            textBlock(scale: f.textScale, height: nil)
        }
        // Centred in the slide area: the room left over is split above and
        // below instead of piling up between the subtitle and the dots.
        .frame(width: size.width, height: size.height, alignment: .center)
    }

    /// Headline + supporting line. On a short phone the pair is capped to the
    /// height left over and scales down inside it, so nothing is ever cut.
    private func textBlock(scale: CGFloat, height: CGFloat?) -> some View {
        VStack(spacing: 6 * scale) {
            titleText(scale: scale, fixed: height == nil)
            subtitleText(scale: scale, fixed: height == nil)
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private func titleText(scale: CGFloat, fixed: Bool) -> some View {
        Text(title)
            .font(AppFont.title(Self.titleSize * scale))
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .lineLimit(3)
            .minimumScaleFactor(0.55)
            // Capped block (phone): shrink to the room left instead of overflowing.
            .fixedSize(horizontal: false, vertical: fixed)
    }

    private func subtitleText(scale: CGFloat, fixed: Bool) -> some View {
        Text(subtitle)
            .font(AppFont.heading(Self.subtitleSize * scale))
            .foregroundStyle(PaywallDark.softGreen)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .lineLimit(3)
            .minimumScaleFactor(0.55)
            // Capped block (phone): shrink to the room left instead of overflowing.
            .fixedSize(horizontal: false, vertical: fixed)
    }
}

// MARK: - Slide 1 — approved candidates

struct PaywallSlideApproved: View {
    let strings: UIStrings.Paywall
    var niche = NicheConfig()

    /// Seven columns: the tiles that fit the slide's own width whole. Eight
    /// columns only fit by bleeding past the margins, where the art area's
    /// clip cut the first and last one in half. Rows come from the pack
    /// (`paywallPhotoRows`, default 3 = 21 taller photos; 4 = 28 smaller).
    private static let columns = 7
    private var rows: Int {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment["PAYWALL_PHOTO_ROWS"].flatMap(Int.init) {
            return override
        }
        #endif
        return niche.paywallPhotoRows
    }
    /// Breathing room between tiles: the grid reads as a wall of faces, not a
    /// contact sheet. 2x the original 4pt, at the operator's request.
    private static let gap: CGFloat = 8
    private static let cornerRadius: CGFloat = 6

    private var photos: [String] {
        OnboardingPhotos.grid(count: niche.studentPhotoCount, slots: Self.columns * rows)
    }

    var body: some View {
        PaywallSlideFrame(title: niche.outcomeText(pass: strings.slide1Title, score: strings.slide1TitleScore),
                          subtitle: strings.slide1Subtitle) {
            // The tile is measured from the art area in both directions, so
            // the block fills it exactly and every photo is drawn whole. The
            // images are cropped to fill their tile around the detected face.
            GeometryReader { geo in
                let tileWidth = max(0, (geo.size.width - Self.gap * CGFloat(Self.columns - 1))
                    / CGFloat(Self.columns))
                let tileHeight = max(0, (geo.size.height - Self.gap * CGFloat(rows - 1))
                    / CGFloat(rows))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(tileWidth), spacing: Self.gap),
                                   count: Self.columns),
                    spacing: Self.gap
                ) {
                    ForEach(photos, id: \.self) { name in
                        FaceAwarePhoto(name: name, width: tileWidth, height: tileHeight)
                            .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Slide 2 — this year's syllabus

struct PaywallSlideSyllabus: View {
    let strings: UIStrings.Paywall
    let year: Int

    private static let gap: CGFloat = 10
    private static let yearsHeight: CGFloat = 32
    /// How the height left after the year chips splits when there is room for
    /// two cards: the front one carries the answer row, the one behind it is a
    /// glimpse of the next question.
    private static let frontShare: CGFloat = 0.6
    /// Below this the card behind is dropped instead of squeezing both: two
    /// cramped cards read worse than one whole one.
    private static let twoCardMinimum: CGFloat = 210

    var body: some View {
        PaywallSlideFrame(title: String(format: strings.slide2TitleFormat, year),
                          subtitle: strings.slide2Subtitle) {
            // Sized from the art area, so the deck stands as tall as the photo
            // grid on slide 1 and still never clips: the cards take explicit
            // heights and their contents spread inside with spacers.
            GeometryReader { geo in
                let deck = max(0, geo.size.height - Self.yearsHeight - Self.gap - 2)
                let showsSecond = deck >= Self.twoCardMinimum
                let cards = showsSecond ? deck - Self.gap : deck
                VStack(spacing: Self.gap) {
                    questionCard(height: showsSecond ? cards * Self.frontShare : cards,
                                 lines: [1.0, 0.82, 0.68, 0.45],
                                 isFront: true)
                    if showsSecond {
                        questionCard(height: cards * (1 - Self.frontShare),
                                     lines: [1.0, 0.74, 0.5],
                                     isFront: false)
                    }
                    years.frame(height: Self.yearsHeight)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    /// One question card at an exact height. The header sits at the top, the
    /// answer row at the bottom, and the abstract question lines spread over
    /// whatever is between them — so any height reads as a real card.
    private func questionCard(height: CGFloat, lines: [CGFloat], isFront: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(strings.slide2CardTitle)
                    .font(AppFont.strong(isFront ? 15 : 13))
                    .foregroundStyle(isFront ? .white : Color.white.opacity(0.55))
                Spacer(minLength: 0)
                Text(String(format: strings.slide2BadgeFormat, isFront ? year : year - 1))
                    .font(AppFont.strong(isFront ? 11 : 10))
                    .foregroundStyle(isFront ? AppColor.accent : PaywallDark.dim)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 3)
                    .background((isFront ? AppColor.accent : Color.white).opacity(isFront ? 0.16 : 0.08),
                                in: Capsule())
            }
            // Zero minimums throughout: the card's height is decided by the
            // slide, so nothing inside may insist on more than it was given.
            Spacer(minLength: 0)

            // Abstract "lines of a question" — never real exam text.
            ForEach(Array(lines.enumerated()), id: \.offset) { _, width in
                Capsule()
                    .fill(Color.white.opacity(isFront ? 0.14 : 0.09))
                    .frame(height: isFront ? 7 : 6)
                    .scaleEffect(x: width, anchor: .leading)
                Spacer(minLength: 0)
            }

            if isFront {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(AppColor.success, in: Circle())
                    Text(strings.slide2Answer)
                        .font(AppFont.heading(13))
                        .foregroundStyle(PaywallDark.dim)
                }
            }
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .leading)
        .background(isFront ? PaywallDark.card : Color.white.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
            .stroke(isFront ? PaywallDark.stroke : Color.white.opacity(0.06), lineWidth: 1))
    }

    private var years: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(NicheConfig.slideYears(now: year, count: 4).reversed(), id: \.self) { value in
                let current = value == year
                Text(String(value))
                    .font(AppFont.strong(12))
                    .foregroundStyle(current ? .white : PaywallDark.dim)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, AppSpacing.xs)
                    .background(current ? AppColor.accent : PaywallDark.card, in: Capsule())
            }
        }
    }
}

// MARK: - Slide 3 — progress tracking

struct PaywallSlideProgress: View {
    let strings: UIStrings.Paywall
    let session: AppSession

    /// Each card below the first is a genuinely smaller, greyer copy — real
    /// sizes, not a scale effect, so the stack's height is exactly what is
    /// drawn and always fits the art area.
    private struct Step {
        let size: CGFloat
        let card: Color
        let icon: Color
        let opacity: Double
    }

    /// Three cards, not four: the stack has to stand whole inside the art
    /// area, and a fourth one only fit by being cut off.
    private static let steps: [Step] = [
        Step(size: 1.00, card: .white, icon: Color(hexString: "#E8F0FF"), opacity: 1),
        Step(size: 0.88, card: Color(hexString: "#EEF1F6"), icon: Color(hexString: "#FFF0E2"), opacity: 1),
        Step(size: 0.78, card: Color(hexString: "#D4DAE3"), icon: Color(hexString: "#E6F7EE"), opacity: 0.92),
    ]

    /// Sample progress: enough to show what the screen will look like once the
    /// user has answered something, never presented as their own data.
    private static let samples = [(17, 20), (25, 50), (20, 30)]

    private static let gap: CGFloat = 8
    /// A card at full size: the 40pt icon plus 9pt of padding above and below.
    private static let cardHeight: CGFloat = 58
    /// Room kept under the stack for the drop shadow.
    private static let shadowRoom: CGFloat = 8
    /// Cap on how far the stack may grow to fill a tall art area — past this
    /// the cards stop reading as list rows.
    private static let maxGrowth: CGFloat = 1.45

    /// The subjects that carry the most of the real bank, named exactly as the
    /// exam names them, with the pack's own pictogram.
    private var rows: [(subject: Subject, done: Int, total: Int)] {
        let counts = Dictionary(grouping: session.content.questions, by: \.subjectId)
            .mapValues(\.count)
        let top = session.pack.subjects
            .sorted { counts[$0.id, default: 0] > counts[$1.id, default: 0] }
            .prefix(Self.samples.count)
        return zip(top, Self.samples).map { ($0, $1.0, $1.1) }
    }

    var body: some View {
        PaywallSlideFrame(title: strings.slide3Title,
                          subtitle: session.pack.nicheConfig.outcomeText(pass: strings.slide3Subtitle,
                                                                         score: strings.slide3SubtitleScore)) {
            // Every card height is computed, never negotiated: the stack's
            // natural height is known, so the art area scales it — down on a
            // short page instead of cutting the first and last cards off, up
            // on a tall one so this slide stands as tall as the other two.
            GeometryReader { geo in
                let visible = Array(rows.prefix(Self.steps.count))
                let natural = visible.indices.reduce(CGFloat(0)) {
                    $0 + Self.cardHeight * Self.steps[$1].size
                } + Self.gap * CGFloat(max(0, visible.count - 1))
                let room = max(0, geo.size.height - Self.shadowRoom)
                let fit = natural > 0 ? min(Self.maxGrowth, room / natural) : 1
                // Whatever the growth cap left over goes into the gaps, so the
                // stack spans the art area exactly — the same height as the
                // photo grid and the question card on the other two slides.
                let slack = max(0, room - natural * fit)
                let spacing = Self.gap * fit
                    + (visible.count > 1 ? slack / CGFloat(visible.count - 1) : 0)

                VStack(spacing: spacing) {
                    ForEach(Array(visible.enumerated()), id: \.offset) { index, row in
                        let step = Self.steps[index]
                        subjectCard(row, step: step, scale: step.size * fit)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, (1 - step.size) * 150)
                            .opacity(step.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.horizontal, 4)
            }
        }
    }

    private func subjectCard(_ row: (subject: Subject, done: Int, total: Int),
                             step: Step, scale k: CGFloat) -> some View {
        let ratio = row.total > 0 ? Double(row.done) / Double(row.total) : 0
        return HStack(spacing: 11 * k) {
            Text(row.subject.emoji ?? "📘")
                .font(.system(size: 16 * k))
                .frame(width: 40 * k, height: 40 * k)
                .background(step.icon, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                // One line, shrinking if it has to: the card's height is fixed,
                // so a wrapping name would be a name with its bottom cut off.
                Text(row.subject.name)
                    .font(AppFont.strong(10 * k))
                    .foregroundStyle(Color(hexString: "#0F1B2D"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                Text(String(format: strings.slide3QuestionsFormat, row.done, row.total))
                    .font(AppFont.bodyMedium(8.5 * k))
                    .foregroundStyle(Color(hexString: "#5A6B82"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle().stroke(Color(hexString: "#E2E8F0"), lineWidth: 4 * k)
                Circle()
                    .trim(from: 0, to: ratio)
                    .stroke(Color(hexString: "#12B76A"),
                            style: StrokeStyle(lineWidth: 4 * k, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int((ratio * 100).rounded()))%")
                    .font(AppFont.strong(8.5 * k))
                    .foregroundStyle(Color(hexString: "#0F1B2D"))
            }
            .frame(width: 40 * k, height: 40 * k)
        }
        .padding(.horizontal, 12 * k)
        .frame(maxWidth: .infinity, minHeight: Self.cardHeight * k,
               maxHeight: Self.cardHeight * k, alignment: .leading)
        .background(step.card, in: RoundedRectangle(cornerRadius: 16 * k))
        .shadow(color: .black.opacity(0.28), radius: 10, y: 8)
    }
}
