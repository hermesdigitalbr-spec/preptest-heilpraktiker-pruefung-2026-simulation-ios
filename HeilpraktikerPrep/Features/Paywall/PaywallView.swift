import SwiftUI
import StoreKit

/// Apple-compliant paywall (3.1.2c): price + period on the same screen as the
/// CTA, visible "Terms of Use" / "Privacy Policy" / "Restore Purchases" links,
/// and a close button (free path). Monthly carries the 3-day trial; weekly
/// has none — the CTA and timeline adapt to the selected plan.
struct PaywallView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    enum Plan {
        case weekly, monthly
    }

    /// Where the paywall was opened from, so the headline can speak to the
    /// moment (a hard cap-hit converts far better with matching copy).
    enum Source {
        case generic, dailyCapHit, quickCapHit, studyLocked
    }

    let source: Source
    @State private var selectedPlan: Plan = .monthly
    /// The X on the main screen never dismisses directly — it always swaps
    /// to the exit-intent offer screen first (App Store compliant: the
    /// offer screen itself has an immediate, unconditional exit).
    @State private var showExitOffer: Bool

    init(source: Source = .generic, startOnExitOffer: Bool = false) {
        self.source = source
        _showExitOffer = State(initialValue: startOnExitOffer)
    }

    private var strings: UIStrings.Paywall { session.strings.paywall }
    private var iap: IAPService { session.iap }

    private var headline: String {
        switch source {
        case .generic: strings.title
        case .dailyCapHit: strings.titleDailyCap
        case .quickCapHit: strings.titleQuickCap
        case .studyLocked: strings.titleStudyLocked
        }
    }

    var body: some View {
        Group {
            if showExitOffer {
                exitOfferView
            } else {
                mainPaywallView
            }
        }
        .animation(AppMotion.smooth, value: showExitOffer)
        .onChange(of: iap.isPro) { _, isPro in
            if isPro { dismiss() }
        }
    }

    private var mainPaywallView: some View {
        VStack(spacing: 0) {
            header
                .readableWidth(AppLayout.readablePaywall)
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    Text(headline)
                        .font(AppFont.display(28))
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    features
                    planCards

                    Group {
                        if monthlyTrial {
                            timeline
                        } else if selectedPlan == .monthly {
                            monthlyInfo
                        } else {
                            weeklyInfo
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                .padding(AppSpacing.screenMargin)
                .readableWidth(AppLayout.readablePaywall, alignment: .leading)
            }
            footer
                .readableWidth(AppLayout.readablePaywall)
        }
        .background(AppColor.background.ignoresSafeArea())
        .animation(AppMotion.smooth, value: selectedPlan)
    }

    // MARK: - Header

    /// Consistent small-glyph, generous-tap-target close button used on both
    /// the main paywall and the exit-offer screen.
    private func closeButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppColor.textDim)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    private var header: some View {
        HStack {
            // Never dismisses directly — always routes through the
            // exit-intent offer screen, which has its own immediate exit.
            closeButton { showExitOffer = true }
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenMargin - AppSpacing.sm)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Features

    private var features: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            featureRow(strings.feature1)
            featureRow(strings.feature2)
            featureRow(strings.feature3)
            featureRow(strings.feature4)
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.success)
            Text(text)
                .font(AppFont.body(17))
                .foregroundStyle(AppColor.textPrimary)
        }
    }

    // MARK: - Plans

    private var planCards: some View {
        HStack(spacing: AppSpacing.cardGap) {
            planCard(.weekly,
                     name: strings.weeklyName,
                     price: iap.weeklyProduct?.displayPrice ?? iap.debugWeeklyPrice,
                     period: strings.perWeek,
                     badge: nil)
            planCard(.monthly,
                     name: strings.monthlyName,
                     price: iap.monthlyProduct?.displayPrice ?? iap.debugMonthlyPrice,
                     period: strings.perMonth,
                     badge: strings.saveBadge)
        }
    }

    private func planCard(_ plan: Plan, name: String, price: String?, period: String, badge: String?) -> some View {
        let selected = selectedPlan == plan
        return Button {
            selectedPlan = plan
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(name)
                    .font(AppFont.bodyMedium(15))
                    .foregroundStyle(AppColor.textPrimary)
                Text(price ?? "—")
                    .font(AppFont.display(22))
                    .foregroundStyle(AppColor.textPrimary)
                Text(period)
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.textDim)
            }
            .padding(AppSpacing.cardPadding)
            .padding(.top, AppSpacing.xs)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(selected ? AppColor.accent : AppColor.border, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            // Badge rides the top edge — never wraps, never squeezes the name.
            .overlay(alignment: .top) {
                if let badge {
                    Text(badge)
                        .font(AppFont.caption(11))
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(.white)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 3)
                        .background(AppColor.success)
                        .clipShape(Capsule())
                        .offset(y: -10)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Timeline (monthly only — no reminder step, membership language)

    private var timeline: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                timelineRow(icon: "checkmark.circle.fill", tint: AppColor.success,
                            text: strings.timelineInstall, done: true)
                timelineRow(icon: "lock.open.fill", tint: AppColor.accent,
                            text: strings.timelineToday, done: false)
                timelineRow(icon: "crown.fill", tint: AppColor.warning,
                            text: strings.timelineMember, done: false)
            }
        }
    }

    private var weeklyInfo: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                timelineRow(icon: "bolt.fill", tint: AppColor.accent,
                            text: strings.weeklyTodayLine, done: false)
                timelineRow(icon: "arrow.clockwise", tint: AppColor.success,
                            text: strings.weeklyRenewLine, done: false)
            }
        }
    }

    /// Monthly without an available trial (e.g. the user already used it).
    private var monthlyInfo: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                timelineRow(icon: "bolt.fill", tint: AppColor.accent,
                            text: strings.monthlyTodayLine, done: false)
                timelineRow(icon: "arrow.clockwise", tint: AppColor.success,
                            text: strings.monthlyRenewLine, done: false)
            }
        }
    }

    private func timelineRow(icon: String, tint: Color, text: String, done: Bool) -> some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(tint)
                .frame(width: 28)
            Text(text)
                .font(AppFont.body(17))
                .foregroundStyle(done ? AppColor.textDim : AppColor.textPrimary)
                .strikethrough(done, color: AppColor.textDim)
            Spacer()
        }
    }

    // MARK: - Footer (CTA + disclosure + links, all on one screen)

    private var selectedProduct: Product? {
        selectedPlan == .monthly ? iap.monthlyProduct : iap.weeklyProduct
    }

    /// The trial only applies to monthly, and only if the user is still
    /// eligible — an expired-trial user sees the plain paid CTA.
    private var monthlyTrial: Bool {
        selectedPlan == .monthly && iap.isEligibleForTrial
    }

    private var ctaTitle: String {
        monthlyTrial ? strings.trialCta : strings.continueCta
    }

    private var errorBanner: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(AppColor.warning)
                Text(strings.loadErrorTitle)
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Button {
                    iap.clearError()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.textDim)
                }
                Button(strings.retry) {
                    Task { await iap.loadProducts() }
                }
                .font(AppFont.bodyMedium(13))
                .foregroundStyle(AppColor.accent)
            }
        }
        .padding(AppSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
    }

    /// Real StoreKit price of the selected plan (debug fallback in previews).
    private var selectedPrice: String? {
        if let product = selectedProduct { return product.displayPrice }
        return selectedPlan == .monthly ? iap.debugMonthlyPrice : iap.debugWeeklyPrice
    }

    /// Guideline 3.1.2(c): the billed price, big and bold, directly above the
    /// CTA — the most prominent price on the screen.
    private var billedPriceLine: some View {
        Group {
            if let price = selectedPrice {
                Text(price + " " + (selectedPlan == .monthly ? strings.perMonth : strings.perWeek))
                    .font(AppFont.display(26))
                    .fontWeight(.bold)
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
    }

    /// 13pt disclosure under the CTA: trial length + automatic billing.
    private var disclosureLine: String? {
        guard let price = selectedPrice else { return nil }
        if monthlyTrial {
            return String(format: strings.monthlySubtitleFormat, price)
        } else if selectedPlan == .monthly {
            return String(format: strings.monthlyNoTrialSubtitleFormat, price)
        } else {
            return String(format: strings.weeklySubtitleFormat, price)
        }
    }

    private var footer: some View {
        VStack(spacing: AppSpacing.sm) {
            if iap.lastError != nil && iap.debugMonthlyPrice == nil {
                errorBanner
            }

            billedPriceLine

            PrimaryCTAButton(title: ctaTitle, isEnabled: (selectedProduct != nil || iap.debugMonthlyPrice != nil) && !iap.isPurchasing) {
                guard let product = selectedProduct else { return }
                Task {
                    if await iap.purchase(product) { dismiss() }
                }
            }

            if let disclosure = disclosureLine {
                Text(disclosure)
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(strings.securedNote)
                .font(AppFont.caption(12))
                .foregroundStyle(AppColor.textDim)

            HStack(spacing: AppSpacing.lg) {
                Button(session.strings.settings.termsOfUse) {
                    open(session.pack.legal.termsUrl)
                }
                Button(session.strings.settings.privacyPolicy) {
                    open(session.pack.legal.privacyUrl)
                }
                Button(strings.restore) {
                    Task { await iap.restore() }
                }
            }
            .font(AppFont.caption(12))
            .foregroundStyle(AppColor.textDim)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Exit-intent offer (Weekly + 3-day trial, last resort)

    /// Reached only via the main paywall's X. Leads with the Weekly plan and
    /// a special 3-day free trial framing that the main paywall never shows
    /// for Weekly. Both exits here are immediate and unconditional — no
    /// further redirection, per App Store compliance.
    private var exitOfferView: some View {
        VStack(spacing: 0) {
            HStack {
                closeButton { dismiss() }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenMargin - AppSpacing.sm)
            .padding(.vertical, AppSpacing.sm)
            .readableWidth(AppLayout.readablePaywall)

            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    Text(strings.exitOfferTitle)
                        .font(AppFont.display(28))
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(strings.exitOfferSubtitle)
                        .font(AppFont.body(17))
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    weeklyPriceCard

                    Card {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            timelineRow(icon: "checkmark.circle.fill", tint: AppColor.success,
                                        text: strings.timelineInstall, done: true)
                            timelineRow(icon: "lock.open.fill", tint: AppColor.accent,
                                        text: strings.timelineToday, done: false)
                            timelineRow(icon: "crown.fill", tint: AppColor.warning,
                                        text: strings.timelineMember, done: false)
                        }
                    }
                }
                .padding(AppSpacing.screenMargin)
                .readableWidth(AppLayout.readablePaywall, alignment: .leading)
            }

            exitOfferFooter
                .readableWidth(AppLayout.readablePaywall)
        }
        .background(AppColor.background.ignoresSafeArea())
    }

    /// Weekly plan shown as a single, always-highlighted price card —
    /// same visual language as the main paywall's plan cards, but not
    /// interactive since it's the only option here. Satisfies Guideline
    /// 3.1.2(c) (billed price prominent) without a separate disclosure line.
    private var weeklyPriceCard: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(strings.weeklyName)
                .font(AppFont.bodyMedium(15))
                .foregroundStyle(AppColor.textPrimary)
            Text(iap.weeklyProduct?.displayPrice ?? iap.debugWeeklyPrice ?? "—")
                .font(AppFont.display(22))
                .foregroundStyle(AppColor.textPrimary)
            Text(strings.perWeek)
                .font(AppFont.caption(13))
                .foregroundStyle(AppColor.textDim)
        }
        .padding(AppSpacing.cardPadding)
        .padding(.top, AppSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColor.accent, lineWidth: 2)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private var exitOfferWeeklyPrice: String? {
        iap.weeklyProduct?.displayPrice ?? iap.debugWeeklyPrice
    }

    private var exitOfferFooter: some View {
        VStack(spacing: AppSpacing.sm) {
            // Guideline 3.1.2(c): billed price, big and bold, above the CTA.
            if let price = exitOfferWeeklyPrice {
                Text(price + " " + strings.perWeek)
                    .font(AppFont.display(26))
                    .fontWeight(.bold)
                    .foregroundStyle(AppColor.textPrimary)
            }

            PrimaryCTAButton(title: strings.exitOfferCta,
                              isEnabled: (iap.weeklyProduct != nil || iap.debugWeeklyPrice != nil) && !iap.isPurchasing) {
                guard let product = iap.weeklyProduct else { return }
                Task {
                    if await iap.purchase(product) { dismiss() }
                }
            }

            if let price = exitOfferWeeklyPrice {
                Text(String(format: strings.exitOfferSubtitleFormat, price))
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(strings.exitOfferNoThanks) {
                dismiss()
            }
            .font(AppFont.bodyMedium(15))
            .foregroundStyle(AppColor.textDim)

            Text(strings.securedNote)
                .font(AppFont.caption(12))
                .foregroundStyle(AppColor.textDim)

            HStack(spacing: AppSpacing.lg) {
                Button(session.strings.settings.termsOfUse) {
                    open(session.pack.legal.termsUrl)
                }
                Button(session.strings.settings.privacyPolicy) {
                    open(session.pack.legal.privacyUrl)
                }
                Button(strings.restore) {
                    Task { await iap.restore() }
                }
            }
            .font(AppFont.caption(12))
            .foregroundStyle(AppColor.textDim)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.vertical, AppSpacing.sm)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
}
