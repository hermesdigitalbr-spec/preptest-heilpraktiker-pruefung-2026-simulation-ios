import SwiftUI

struct HomeView: View {
    @Environment(AppSession.self) private var session

    @State private var activeQuiz: QuizController?
    @State private var emptyModeAlert: EmptyModeAlert?
    @State private var showCustomSheet = false
    @State private var showTimedSheet = false
    @State private var showPaywall = false
    @State private var paywallSource: PaywallView.Source = .generic
    @State private var appeared = false
    @State private var playWelcomeConfetti = false

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct EmptyModeAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                header
                // The "today" block reads as one unit — tighter rhythm.
                VStack(spacing: AppSpacing.cardGap) {
                    WeekStripView()
                    dailyCard
                    unlockBanner
                }
                modeGrid
            }
            .padding(AppSpacing.screenMargin)
            .readableWidth(AppLayout.readableContent, alignment: .leading)
            // A gentle one-time arrival so opening the app feels like the day's
            // session is being laid out for you. Reduce Motion → final state.
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 12)
        }
        .background(AppColor.background.ignoresSafeArea())
        .overlay { WelcomeConfettiOverlay(isPlaying: $playWelcomeConfetti) }
        .fullScreenCover(item: $activeQuiz) { controller in
            QuizView(controller: controller)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(source: paywallSource)
        }
        .sheet(isPresented: $showTimedSheet) {
            TimedQuizSheet { count, minutes in
                showTimedSheet = false
                activeQuiz = QuizController.makeTimed(count: count, minutes: minutes, app: session)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showCustomSheet) {
            CustomQuizSheet { subjectIds, count in
                showCustomSheet = false
                activeQuiz = QuizController.makeCustom(subjectIds: subjectIds, count: count, app: session)
            }
            // Single .large detent: a multi-detent sheet hijacks the inner
            // ScrollView's swipe to resize itself (default .resizes interaction),
            // which freezes scrolling once the subject list overflows. Every other
            // scrolling sheet in the app uses [.large] for the same reason.
            .presentationDetents([.large])
        }
        .alert(item: $emptyModeAlert) { alert in
            Alert(title: Text(alert.title),
                  message: Text(alert.message),
                  dismissButton: .default(Text(session.strings.common.ok)))
        }
        .onAppear {
            consumePendingDailyLaunch()
            if !appeared {
                if reduceMotion { appeared = true }
                else { withAnimation(AppMotion.smooth) { appeared = true } }
                // First-ever entry into Home (right after onboarding
                // completes) — play the welcome confetti, one-shot via its
                // own UserDefaults flag. No rating prompt here: asking before
                // the user has engaged with the app violates Guideline 5.6.3.
                if WelcomeConfetti.consumePending() {
                    playWelcomeConfetti = true
                }
            }
        }
        .onChange(of: session.pendingDailyLaunch) { _, pending in
            if pending { consumePendingDailyLaunch() }
        }
    }

    /// Handles a `heilpraktiker://daily` deep link (widget tap): launch the daily
    /// quiz once, ignoring it if a quiz or the paywall is already up.
    private func consumePendingDailyLaunch() {
        guard session.pendingDailyLaunch else { return }
        session.pendingDailyLaunch = false
        guard activeQuiz == nil, !showPaywall else { return }
        launch(.daily)
    }

    // MARK: - Header

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        if hour < 12 { return session.strings.home.greetingMorning }
        if hour < 18 { return session.strings.home.greetingAfternoon }
        return session.strings.home.greetingEvening
    }

    private var daysLeft: Int? {
        guard let examDate = session.profile.examDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: examDate)).day ?? 0
        return days > 0 ? days : nil
    }

    private var header: some View {
        // The greeting is the home title — the exam name is intentionally not
        // shown here (it's long for some packs and redundant once
        // you're inside the app).
        HStack(alignment: .top) {
            Text(greeting)
                .font(AppFont.display(28))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            if let daysLeft {
                Text(String(format: session.strings.home.daysLeftFormat, daysLeft))
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.accent)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColor.accentSoft)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Daily questions

    private var dailyDoneToday: Bool {
        session.progress.dailyDone()
    }

    /// Free user who has spent every free daily set (and hasn't done one today)
    /// — show an explicit upgrade CTA instead of a Start button that would
    /// ambush them with the paywall.
    private var dailyLocked: Bool {
        !dailyDoneToday && !isPro && dailyQuizzesLeft == 0
    }

    /// Days until the exam, or nil if the user hasn't set one.
    private var daysUntilExam: Int? {
        guard let exam = session.profile.examDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let target = calendar.startOfDay(for: exam)
        let days = calendar.dateComponents([.day], from: today, to: target).day
        guard let days, days > 0 else { return nil }
        return days
    }

    private var dailySubtitle: String {
        if dailyDoneToday { return session.strings.home.dailyQuestionsDone }
        let strings = session.strings.home
        if !isPro && dailyQuizzesLeft < session.pack.freeDailyQuizzes {
            return String(format: strings.dailyFreeLeftFormat, dailyQuizzesLeft)
        }
        if let plan = session.profile.planQuestionsPerDay {
            if let days = daysUntilExam {
                return String(format: strings.dailyPlanFormat, plan, days)
            }
            return String(format: strings.dailyCountFormat, plan)
        }
        return strings.dailyQuestionsSubtitle
    }

    private var dailyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: dailyDoneToday ? "checkmark.seal.fill" : "calendar.badge.checkmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(dailyDoneToday ? AppColor.success : AppColor.accent)
                        .frame(width: 48, height: 48)
                        .background(dailyDoneToday ? AppColor.successSoft : AppColor.accentSoft)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.strings.home.dailyQuestionsTitle)
                            .font(AppFont.heading(17))
                            .foregroundStyle(AppColor.textPrimary)
                        if !dailyDoneToday {
                            Text(dailySubtitle)
                                .font(AppFont.caption(13))
                                .foregroundStyle(AppColor.textDim)
                        }
                    }
                }
                if dailyDoneToday {
                    // Make "already done today" unmistakable instead of leaving an
                    // empty, button-less card that reads as broken.
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                        Text(session.strings.home.dailyQuestionsDone)
                        Spacer(minLength: 0)
                    }
                    .font(AppFont.bodyMedium(15))
                    .foregroundStyle(AppColor.success)
                    .padding(.vertical, AppSpacing.sm)
                    .padding(.horizontal, AppSpacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.successSoft)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                } else if dailyLocked {
                    dailyUnlockButton
                } else {
                    PrimaryCTAButton(title: session.strings.home.startButton) {
                        launch(.daily)
                    }
                }
            }
        }
    }

    /// Gold monetization CTA shown when the free daily allowance is spent.
    private var dailyUnlockButton: some View {
        Button {
            paywallSource = .dailyCapHit
            showPaywall = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(session.strings.home.dailyUnlockCta)
                    .font(AppFont.bodyMedium(15))
            }
            .foregroundStyle(AppColor.onWarning)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(
                LinearGradient(colors: [Color(hexString: "#FFD66B"), Color(hexString: "#F5A623")],
                               startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Unlock banner

    @ViewBuilder
    private var unlockBanner: some View {
        if !session.iap.isPro {
            unlockBannerButton
        }
    }

    /// Golden, distinct from the accent CTAs — monetization has its own color.
    private var unlockBannerButton: some View {
        Button {
            paywallSource = .generic
            showPaywall = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                Text(String(format: session.strings.home.unlockBannerFormat, session.questionPool.count))
                    .font(AppFont.bodyMedium(15))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .opacity(0.7)
            }
            .foregroundStyle(AppColor.onWarning)
            .padding(AppSpacing.cardPadding)
            .background(
                LinearGradient(colors: [Color(hexString: "#FFD66B"), Color(hexString: "#F5A623")],
                               startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Mode grid

    private var isPro: Bool { session.iap.isPro }

    private var quickQuizzesUsed: Int {
        session.progress.state.attempts.filter { $0.mode == .quick10 }.count
    }

    private var quickQuizzesLeft: Int {
        ProAccess.remainingFreeQuickQuizzes(
            used: quickQuizzesUsed,
            allowance: session.pack.freeQuickQuizzes)
    }

    private var dailyQuizzesUsed: Int {
        session.progress.state.attempts.filter { $0.mode == .daily }.count
    }

    private var dailyQuizzesLeft: Int {
        ProAccess.remainingFreeDailyQuizzes(
            used: dailyQuizzesUsed,
            allowance: session.pack.freeDailyQuizzes)
    }

    private var quick10Subtitle: String {
        if isPro { return session.strings.home.modeQuick10Subtitle }
        return String(format: session.strings.home.quick10FreeLeftFormat, quickQuizzesLeft)
    }

    private var reviewSubtitle: String {
        let due = session.reviewDueCount
        return due > 0
            ? String(format: session.strings.home.modeReviewDueFormat, due)
            : session.strings.home.modeReviewEmpty
    }

    // 3 columns on iPad (regular), 2 on iPhone (compact) — keeps phone-like
    // tile proportions within the capped content width.
    private var modeColumns: [GridItem] {
        let count = hSize == .regular ? 3 : 2
        return Array(repeating: GridItem(.flexible(), spacing: AppSpacing.cardGap), count: count)
    }

    private var modeGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionLabel(text: session.strings.home.modesSectionTitle)
            LazyVGrid(columns: modeColumns, spacing: AppSpacing.cardGap) {
                QuizModeCard(title: session.strings.home.modeQuick10Title,
                             subtitle: quick10Subtitle,
                             sfSymbol: "bolt.fill", tint: AppColor.accent,
                             info: session.strings.home.modeQuick10Info,
                             showsProBadge: !isPro && quickQuizzesLeft == 0) { launch(.quick10) }
                QuizModeCard(title: session.strings.home.modeTimedTitle,
                             subtitle: session.strings.home.modeTimedSubtitle,
                             sfSymbol: "stopwatch.fill", tint: AppColor.warning,
                             info: session.strings.home.modeTimedInfo,
                             showsProBadge: !isPro) { launch(.timed) }
                QuizModeCard(title: session.strings.home.modeReviewTitle,
                             subtitle: reviewSubtitle,
                             sfSymbol: "arrow.triangle.2.circlepath", tint: AppColor.error,
                             info: session.strings.home.modeReviewInfo,
                             showsProBadge: !isPro) { launch(.review) }
                QuizModeCard(title: session.strings.home.modeCollectedTitle,
                             subtitle: session.strings.home.modeCollectedSubtitle,
                             sfSymbol: "bookmark.fill", tint: Color(hexString: "#8E6FF7"),
                             info: session.strings.home.modeCollectedInfo,
                             showsProBadge: !isPro) { launch(.collected) }
                QuizModeCard(title: session.strings.home.modeMockTitle,
                             subtitle: session.strings.home.modeMockSubtitle,
                             sfSymbol: "graduationcap.fill", tint: AppColor.success,
                             info: session.strings.home.modeMockInfo,
                             showsProBadge: !isPro) { launch(.mock) }
                QuizModeCard(title: session.strings.home.modeCustomTitle,
                             subtitle: session.strings.home.modeCustomSubtitle,
                             sfSymbol: "slider.horizontal.3", tint: Color(hexString: "#F2789F"),
                             info: session.strings.home.modeCustomInfo,
                             showsProBadge: !isPro) { launch(.custom) }
            }
        }
    }

    // MARK: - Launching

    private func launch(_ mode: QuizMode) {
        if ProAccess.isLocked(mode: mode, isPro: isPro,
                              quickQuizzesUsed: quickQuizzesUsed,
                              freeQuickQuizzes: session.pack.freeQuickQuizzes,
                              dailyQuizzesUsed: dailyQuizzesUsed,
                              freeDailyQuizzes: session.pack.freeDailyQuizzes) {
            paywallSource = switch mode {
            case .daily: .dailyCapHit
            case .quick10: .quickCapHit
            default: .generic
            }
            showPaywall = true
            return
        }
        if mode == .custom {
            showCustomSheet = true
            return
        }
        if mode == .timed {
            showTimedSheet = true
            return
        }
        if let controller = QuizController.make(mode: mode, app: session) {
            activeQuiz = controller
            return
        }
        switch mode {
        case .review:
            emptyModeAlert = EmptyModeAlert(
                title: session.strings.home.modeReviewEmpty,
                message: session.strings.empty.missedSubtitle)
        case .missed:
            emptyModeAlert = EmptyModeAlert(
                title: session.strings.empty.missedTitle,
                message: session.strings.empty.missedSubtitle)
        case .collected:
            emptyModeAlert = EmptyModeAlert(
                title: session.strings.empty.collectedTitle,
                message: session.strings.empty.collectedSubtitle)
        default:
            break
        }
    }
}

extension QuizController: Identifiable {}
