import SwiftUI
import StoreKit

/// The end of the onboarding funnel: a dark, three-slide paywall (monthly with
/// a 3-day trial, quarterly billed straight away) that falls back to a weekly
/// exit offer when the user declines.
///
/// Guideline 3.1.2(c): the amount actually charged sits directly above the CTA
/// in the same visual weight class as the button, and Terms / Privacy /
/// Restore are visible without scrolling.
struct OnboardingPaywallView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize

    enum Plan { case monthly, quarterly }

    /// No funil o paywall é o fim do caminho e só se sai pelo link de recusa,
    /// que espera alguns segundos. Aberto de dentro do app ele é modal e
    /// precisa de um X imediato.
    var showsCloseButton = false

    /// A oferta semanal de saída é do funil de onboarding, onde é a última
    /// chance antes de o usuário sair sem assinar. Dentro do app o semanal
    /// não é oferecido: recusar aqui fecha a tela.
    var offersWeeklyExit = true

    /// Position on a 5-wide strip: [3′, 1, 2, 3, 1′] — the ends are clones so
    /// the wrap is a real slide, not a jump. Starts at 1: the photos.
    @State private var page = Self.initialPage

    /// Screenshot harness: SCREENSHOT_PAYWALL_SLIDE=1...3 opens on that slide.
    private static var initialPage: Int {
        #if DEBUG
        if let slide = ProcessInfo.processInfo.environment["SCREENSHOT_PAYWALL_SLIDE"].flatMap(Int.init),
           (1...3).contains(slide) {
            return slide
        }
        #endif
        return 1
    }
    /// Finger offset while a swipe is in progress; the strip follows it.
    @State private var drag: CGFloat = 0
    /// Slides rotate on their own until the user touches them — a tap on a
    /// dot or a swipe hands control over for good.
    @State private var autoplay = Self.initialAutoplay

    /// Screenshot harness: hold on slide 1 (the photo grid) instead of rotating.
    private static var initialAutoplay: Bool {
        #if DEBUG
        return !ScreenshotMode.isActive
        #else
        return true
        #endif
    }
    @State private var showExitOffer = Self.initialExitOffer
    /// Each decline link only becomes tappable after a beat, so the offer is
    /// actually read before it can be dismissed. The exit offer gets its own
    /// timer, counted from when that screen appears.
    @State private var canDecline = false
    @State private var canLeaveGift = false
    /// The plan the CTA buys; tapping a card selects it.
    @State private var selected: Plan = Self.initialPlan

    private static var initialPlan: Plan {
        #if DEBUG
        if ProcessInfo.processInfo.environment["SCREENSHOT_PLAN"] == "quarterly" { return .quarterly }
        #endif
        return .monthly
    }

    /// Screenshot/QA harness: open straight on the weekly gift stage.
    private static var initialExitOffer: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["SCREENSHOT_PAYWALL_STAGE"] == "gift"
        #else
        return false
        #endif
    }

    private var strings: UIStrings.Paywall { session.strings.paywall }
    private var iap: IAPService { session.iap }
    private var year: Int { NicheConfig.displayYear(language: session.pack.language) }

    var body: some View {
        ZStack {
            PaywallDarkBackground()
            if showExitOffer {
                exitOffer
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                GeometryReader { geo in
                    // Short phones (SE/mini) get tighter gaps so the slide
                    // keeps a usable height; every other screen is untouched.
                    main(compact: geo.size.height < Self.compactPageHeight)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                    .transition(.move(edge: .leading).combined(with: .opacity))
                SignupToast(strings: strings)
                    .padding(.top, AppSpacing.xs)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .animation(AppMotion.smooth, value: showExitOffer)
        .onChange(of: showExitOffer) { _, showing in
            guard showing else { return }
            Haptics.tap(.soft)
            canLeaveGift = false
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(AppMotion.smooth) { canLeaveGift = true }
            }
        }
        .task {
            if iap.monthlyProduct == nil { await iap.loadProducts() }
            try? await Task.sleep(for: .seconds(3))
            withAnimation(AppMotion.smooth) { canDecline = true }
        }
        .onChange(of: iap.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    // MARK: - Paywall 1

    /// Below this page height the paywall runs in its tight layout.
    private static let compactPageHeight: CGFloat = 700

    private func main(compact: Bool) -> some View {
        VStack(spacing: compact ? AppSpacing.xs : AppSpacing.md) {
            // The row is always here, with or without the X: inside the app the
            // close button must not push the art down, so both entry points
            // show the slides at exactly the same height.
            HStack {
                Button {
                    Haptics.tap(.soft)
                    decline()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(PaywallDark.dim)
                        .frame(width: 44, height: compact ? 28 : 44, alignment: .leading)
                }
                .accessibilityLabel(strings.declineCta)
                .opacity(showsCloseButton ? 1 : 0)
                .disabled(!showsCloseButton)
                .accessibilityHidden(!showsCloseButton)
                Spacer()
            }

            // A strip of five pages driven by offset, not a TabView: the auto
            // advance always travels right (the clone at the end makes 3 → 1 a
            // real slide), and a manual swipe follows the finger in whichever
            // direction it is going.
            GeometryReader { geo in
                let width = geo.size.width
                HStack(spacing: 0) {
                    ForEach(Array([2, 0, 1, 2, 0].enumerated()), id: \.offset) { _, index in
                        slideView(index).frame(width: width)
                    }
                }
                .offset(x: -CGFloat(page) * width + drag)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            autoplay = false
                            drag = value.translation.width
                        }
                        .onEnded { value in
                            let threshold = width / 4
                            let step = value.translation.width < -threshold ? 1
                                : value.translation.width > threshold ? -1 : 0
                            withAnimation(.easeInOut(duration: 0.35)) {
                                drag = 0
                                page += step
                            }
                            normalizeAfterAnimation()
                        })
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2.5))
                    guard !Task.isCancelled, autoplay else { return }
                    withAnimation(.easeInOut(duration: 0.45)) { page += 1 }
                    normalizeAfterAnimation()
                }
            }

            dots

            Spacer(minLength: 0)

            declineLink

            // Guideline 3.1.2(c): the billed amount is the largest pricing
            // element on the screen. Trial and per-day figures stay smaller
            // and dimmer, and the trial only shows when StoreKit offers it.
            if let disclosure {
                disclosure
                    .font(AppFont.body(13))
                    .foregroundStyle(PaywallDark.dim)
                    .multilineTextAlignment(.center)
                    .animation(nil, value: selected)
            }

            // The button buys the monthly plan; the cards below are their own
            // buy buttons.
            PrimaryCTAButton(title: ctaTitle, isEnabled: !iap.isPurchasing) {
                buy { selected == .monthly ? iap.monthlyProduct : iap.quarterlyProduct }
            }

            planCard(.monthly,
                     name: strings.monthlyCardName,
                     price: monthlyPrice.map { String(format: strings.monthlyCardPriceFormat, $0) },
                     detail: perDay(for: .monthly).map { String(format: strings.monthlyCardDetailFormat, $0) },
                     badge: nil, compact: compact)
            planCard(.quarterly,
                     name: strings.quarterlyCardName,
                     price: quarterlyPrice.map { String(format: strings.quarterlyCardPriceFormat, $0) },
                     detail: perDay(for: .quarterly).map { String(format: strings.quarterlyCardDetailFormat, $0) },
                     badge: savingsBadge, compact: compact)

            legal
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.top, compact ? 2 : AppSpacing.sm)
        .padding(.bottom, compact ? 2 : AppSpacing.sm)
    }

    /// Which of the three real slides is showing (the dots key off this).
    private var realSlide: Int { (page + 2) % 3 }

    /// Once a move onto a clone has finished animating, jump to the matching
    /// real page with animations off — the strip looks identical, so the
    /// user never sees the seam.
    private func normalizeAfterAnimation() {
        Task {
            try? await Task.sleep(for: .milliseconds(480))
            guard page == 0 || page == 4 else { return }
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) { page = page == 0 ? 3 : 1 }
        }
    }

    @ViewBuilder
    private func slideView(_ index: Int) -> some View {
        switch index {
        case 0: PaywallSlideApproved(strings: strings, niche: session.pack.nicheConfig)
        case 1: PaywallSlideSyllabus(strings: strings, year: year)
        default: PaywallSlideProgress(strings: strings, session: session)
        }
    }

    private var dots: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == realSlide ? Color.white : Color.white.opacity(0.28))
                    .frame(width: 6, height: 6)
                    .contentShape(Rectangle().size(width: 24, height: 24))
                    .onTapGesture {
                        Haptics.select()
                        autoplay = false
                        withAnimation(.easeInOut(duration: 0.35)) { page = index + 1 }
                    }
            }
        }
        .accessibilityHidden(true)
    }

    private var declineLink: some View {
        Button(strings.declineCta) { decline() }
        .font(AppFont.body(14))
        .foregroundStyle(PaywallDark.dim)
        .opacity(canDecline ? 1 : 0)
        .disabled(!canDecline)
    }

    /// Recusar no funil abre a oferta semanal, o segundo estágio; dentro do
    /// app, onde o semanal não é oferecido, fecha a tela.
    private func decline() {
        if offersWeeklyExit {
            withAnimation(AppMotion.smooth) { showExitOffer = true }
        } else {
            dismiss()
        }
    }

    /// Each card buys its own plan on the spot: monthly opens the sheet with
    /// its 3-day trial, quarterly opens a straight purchase.
    private func planCard(_ value: Plan, name: String, price: String?,
                          detail: String?, badge: String? = nil,
                          badgeTint: Color = AppColor.success, compact: Bool = false) -> some View {
        let highlighted = selected == value
        return Button {
            Haptics.select()
            withAnimation(AppMotion.smooth) { selected = value }
        } label: {
            HStack(spacing: AppSpacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(name)
                            .font(AppFont.heading(16))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .fixedSize(horizontal: true, vertical: false)
                        if let badge {
                            Text(badge)
                                .font(AppFont.strong(13))
                                .tracking(0.6)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 3)
                                .background(badgeTint, in: Capsule())
                                .shadow(color: badgeTint.opacity(0.45), radius: 6, y: 2)
                        }
                    }
                    // iPhone (product decision 2026-09-14): per-day headline,
                    // billed amount smaller and dim. iPad: billed amount is the
                    // headline under the name, per-day dim on the right.
                    if let price {
                        Text(price)
                            .font(hSize == .regular ? AppFont.strong(20) : AppFont.bodyMedium(14))
                            .foregroundStyle(hSize == .regular ? Color.white : PaywallDark.dim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                }
                Spacer(minLength: AppSpacing.sm)
                if let detail {
                    Text(hSize == .regular ? String(format: strings.perDayEquivalentFormat, detail) : detail)
                        .font(hSize == .regular ? AppFont.body(15) : AppFont.strong(16))
                        .foregroundStyle(hSize == .regular ? PaywallDark.dim : Color.white)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(compact ? AppSpacing.sm : AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(PaywallDark.card, in: RoundedRectangle(cornerRadius: AppRadius.card))
            .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(highlighted ? AppColor.accent : PaywallDark.stroke,
                        lineWidth: highlighted ? 2 : 1))
        }
        .buttonStyle(.pressable)
        .disabled(iap.isPurchasing)
    }

    // MARK: - Paywall 2 (exit offer)

    private var exitOffer: some View {
        VStack(spacing: AppSpacing.md) {
            HStack {
                Button {
                    withAnimation(AppMotion.smooth) { showExitOffer = false }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(PaywallDark.dim)
                }
                Spacer()
            }

            Spacer(minLength: 0)

            Text("🎁").font(.system(size: 58))
            Text(strings.giftTitle)
                .font(AppFont.display(27))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            giftCard

            Spacer(minLength: 0)
            Spacer(minLength: 0)

            PrimaryCTAButton(title: weeklyTrial ? strings.giftCta : strings.giftSubscribeCta,
                             isEnabled: !iap.isPurchasing) {
                buy { iap.weeklyProduct }
            }

            Button(strings.declineCta) { dismiss() }
                .font(AppFont.body(14))
                .foregroundStyle(PaywallDark.dim)
                .opacity(canLeaveGift ? 1 : 0)
                .disabled(!canLeaveGift)

            legal
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.top, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
    }

    private var giftCard: some View {
        VStack(spacing: AppSpacing.xs) {
            Text(strings.giftRibbon)
                .font(AppFont.strong(11))
                .foregroundStyle(.white)
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(AppColor.accent, in: Capsule())
                .offset(y: -AppSpacing.lg)
                .padding(.bottom, -AppSpacing.lg)

            Text(strings.giftPlanName)
                .font(AppFont.strong(17))
                .foregroundStyle(.white)
            Text(strings.giftPlanDetail)
                .font(AppFont.body(13))
                .foregroundStyle(PaywallDark.dim)
            // Guideline 3.1.2(c): the weekly amount is the headline; the trial
            // is a smaller line under it, shown only when StoreKit offers it.
            if let weekly = weeklyPrice {
                Text("\(weekly)\(strings.giftPerWeek)")
                    .font(AppFont.statHeavy(29))
                    .foregroundStyle(.white)
                    .padding(.top, AppSpacing.xs)
            }
            if weeklyTrial {
                Text(strings.giftFreeDays)
                    .font(AppFont.caption(14))
                    .foregroundStyle(PaywallDark.softGreen)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(PaywallDark.card, in: RoundedRectangle(cornerRadius: AppRadius.hero))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.hero)
            .strokeBorder(AppColor.accent.opacity(0.55), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])))
    }

    // MARK: - Footer

    private var legal: some View {
        HStack(spacing: AppSpacing.md) {
            Button(session.strings.settings.termsOfUse) { open(session.pack.legal.termsUrl) }
            Button(session.strings.settings.privacyPolicy) { open(session.pack.legal.privacyUrl) }
            Button(strings.restore) { Task { await iap.restore() } }
        }
        .font(AppFont.body(12))
        .foregroundStyle(PaywallDark.dim)
    }

    // MARK: - Pricing

    private var monthlyPrice: String? { iap.monthlyProduct?.displayPrice ?? iap.debugMonthlyPrice }
    private var quarterlyPrice: String? { iap.quarterlyProduct?.displayPrice ?? iap.debugQuarterlyPrice }
    private var weeklyPrice: String? { iap.weeklyProduct?.displayPrice ?? iap.debugWeeklyPrice }

    /// Trial copy appears only when StoreKit confirms a free-trial intro offer
    /// this user can redeem (Guideline 3.1.2(c)).
    private var monthlyTrial: Bool { iap.offersFreeTrial(iap.monthlyProduct) }
    private var weeklyTrial: Bool { iap.offersFreeTrial(iap.weeklyProduct) }
    private var quarterlyTrial: Bool { iap.offersFreeTrial(iap.quarterlyProduct) }

    private var ctaTitle: String {
        switch selected {
        case .monthly: monthlyTrial ? strings.trialCtaFunnel : strings.subscribeMonthlyCta
        case .quarterly: quarterlyTrial ? strings.trialCtaFunnel : strings.subscribeQuarterlyCta
        }
    }

    /// The line above the CTA states what the selected plan charges, with the
    /// amount in bold (Guideline 3.1.2(c)).
    private var disclosure: Text? {
        switch selected {
        case .monthly:
            guard let monthlyPrice else { return nil }
            return boldPrice(monthlyTrial ? strings.monthlySubtitleFormat
                                          : strings.monthlyNoTrialSubtitleFormat,
                             String(format: strings.monthlyCardPriceFormat, monthlyPrice))
        case .quarterly:
            guard let quarterlyPrice else { return nil }
            return boldPrice(quarterlyTrial ? strings.quarterlyTrialSubtitleFormat
                                            : strings.summaryQuarterlyFormat,
                             String(format: strings.quarterlyCardPriceFormat, quarterlyPrice))
        }
    }

    private func boldPrice(_ format: String, _ price: String) -> Text {
        let parts = format.components(separatedBy: "%@")
        guard parts.count > 1 else { return Text(format) }
        return Text(parts[0])
            + Text(price).font(AppFont.strong(13)).foregroundColor(.white)
            + Text(parts.dropFirst().joined(separator: price))
    }

    private func perDay(for value: Plan) -> String? {
        let fallback = value == .monthly ? iap.debugPerDayMonthly : iap.debugPerDayQuarterly
        guard let product = value == .monthly ? iap.monthlyProduct : iap.quarterlyProduct else {
            return fallback.map { String(format: strings.perDayFormat, $0) }
        }
        let days: Decimal = value == .monthly ? 30 : 90
        let amount = product.price / days
        let formatted = product.priceFormatStyle.format(amount)
        return String(format: strings.perDayFormat, formatted)
    }

    /// How much cheaper a day of quarterly is than a day of monthly. Hidden
    /// until both real prices are known — never a hardcoded claim.
    private var savingsBadge: String? {
        guard let monthly = iap.monthlyProduct, let quarterly = iap.quarterlyProduct else {
            return iap.debugSavingsPercent.map { String(format: strings.saveBadgeFormat, $0) }
        }
        let monthlyPerDay = monthly.price / 30
        let quarterlyPerDay = quarterly.price / 90
        guard monthlyPerDay > 0, quarterlyPerDay < monthlyPerDay else { return nil }
        let ratio = (monthlyPerDay - quarterlyPerDay) / monthlyPerDay
        let percent = Int((NSDecimalNumber(decimal: ratio).doubleValue * 100).rounded())
        guard percent > 0 else { return nil }
        return String(format: strings.saveBadgeFormat, percent)
    }

    /// Products can still be in flight when the user taps — load once more
    /// rather than leaving the button inert.
    private func buy(_ product: @escaping () -> Product?) {
        Task {
            if product() == nil { await iap.loadProducts() }
            guard let target = product() else { return }
            if await iap.purchase(target) { dismiss() }
        }
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - Dark chrome

enum PaywallDark {
    static let top = Color(hexString: "#0F1724")
    static let bottom = Color(hexString: "#070B12")
    static let card = Color.white.opacity(0.06)
    static let stroke = Color.white.opacity(0.12)
    static let dim = Color(hexString: "#93A1B3")
    /// The slide subtitles sit on near-black; the app green would glare.
    static let softGreen = Color(hexString: "#7FD6B1")
}

struct PaywallDarkBackground: View {
    var body: some View {
        LinearGradient(colors: [PaywallDark.top, PaywallDark.bottom],
                       startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
