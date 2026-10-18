import SwiftUI

/// Onboarding container: progress bar, back chrome, step routing.
/// Order and copy follow the approved funnel prototype (2026-09-11).
struct OnboardingView: View {
    @Environment(AppSession.self) private var session

    @State private var model: OnboardingModel?
    @State private var showPaywall = false

    var body: some View {
        Group {
            if let model {
                content(model)
            } else {
                AppColor.background.ignoresSafeArea()
            }
        }
        .onAppear {
            if model == nil {
                model = OnboardingModel(hasRegions: !(session.pack.regions ?? []).isEmpty)
            }
        }
    }

    private func content(_ model: OnboardingModel) -> some View {
        VStack(spacing: 0) {
            if model.showsChrome {
                topBar(model)
                    .readableWidth(AppLayout.readableNarrow)
            }

            Group {
                switch model.current {
                case .intro:
                    OnboardingIntroStep()
                case .state:
                    OnboardingStateStep(model: model)
                case .examDate:
                    OnboardingExamDateStep(model: model)
                case .name:
                    OnboardingNameStep(model: model)
                case .motivation:
                    motivationStep(model)
                case .firstTime:
                    firstTimeStep(model)
                case .affirmation:
                    OnboardingAffirmationStep(model: model)
                case .level:
                    levelStep(model)
                case .rightPlace:
                    OnboardingRightPlaceStep()
                case .reviews:
                    OnboardingReviewsStep(model: model)
                case .minutes:
                    minutesStep(model)
                case .personalizing:
                    OnboardingPersonalizingStep(model: model)
                case .planReady:
                    OnboardingPlanReadyStep(model: model) {
                        showPaywall = true
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .readableWidth(AppLayout.readableNarrow)
            .id(model.index)
            // Pages fade; the motion belongs to the options rising in.
            .transition(.opacity)

            bottomBar(model)
                .readableWidth(AppLayout.readableNarrow)
        }
        .background(OnboardingBackground())
        .animation(AppMotion.smooth, value: model.index)
        .onChange(of: model.index) { _, _ in
            hideKeyboard()
            Haptics.prepare()
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            // Either way the funnel is over — the paywall is the last screen.
            model.complete(into: session)
        }) {
            OnboardingPaywallView()
        }
    }

    // MARK: - Chrome

    private func topBar(_ model: OnboardingModel) -> some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                model.back()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .opacity(model.canGoBack ? 1 : 0)
            .disabled(!model.canGoBack)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.surfaceHigh)
                    Capsule()
                        .fill(AppColor.accent)
                        .frame(width: geo.size.width * model.progress)
                        .animation(AppMotion.smooth, value: model.progress)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, OnboardingTokens.gutter)
        .padding(.vertical, AppSpacing.sm)
    }

    @ViewBuilder
    private func bottomBar(_ model: OnboardingModel) -> some View {
        switch model.current {
        case .intro, .affirmation, .rightPlace, .reviews:
            // Guideline 5.6.3: the funnel never asks for an App Store rating.
            // The reviews page is social proof only; the rating prompt lives
            // after completed quizzes (RatePromptService).
            cta(session.strings.common.continueButton) { model.advance() }
        case .state:
            cta(session.strings.common.continueButton, enabled: model.stateId != nil) {
                model.advance()
            }
        case .examDate:
            VStack(spacing: AppSpacing.sm) {
                PrimaryCTAButton(title: session.strings.onboarding.examDateCta,
                                 isEnabled: model.examDate != nil) {
                    model.advance()
                }
                SecondaryCTAButton(title: session.strings.onboarding.examDateNoDate) {
                    model.examDate = nil
                    model.advance()
                }
            }
            .padding(.horizontal, OnboardingTokens.gutter)
            .padding(.bottom, AppSpacing.sm)
        case .name:
            cta(session.strings.common.continueButton, enabled: model.displayName != nil) {
                model.advance()
            }
        case .minutes:
            cta(session.strings.common.continueButton, enabled: model.minutes != nil) {
                askPushThenAdvance(model)
            }
        case .planReady:
            cta(session.strings.onboarding.planCtaFunnel) { showPaywall = true }
        default:
            EmptyView()
        }
    }

    private func cta(_ title: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        PrimaryCTAButton(title: title, isEnabled: enabled, action: action)
            .padding(.horizontal, OnboardingTokens.gutter)
            .padding(.bottom, AppSpacing.sm)
    }

    /// The one place in the funnel that raises the system notification prompt:
    /// right after the user commits to a daily amount of time, which is what
    /// the reminders are for. Advances whatever the answer.
    private func askPushThenAdvance(_ model: OnboardingModel) {
        guard !model.askedForPush else {
            model.advance()
            return
        }
        model.askedForPush = true
        let strings = session.strings.settings
        let hour = Int(model.preferredHour)
        Task {
            let result = await NotificationService.enableDailyReminder(
                hour: hour, minute: 0,
                title: strings.reminderNotificationTitle,
                body: strings.reminderNotificationBody,
                // Never bounce the user out to Settings mid-funnel; the Home
                // nudge picks this up later.
                openSettingsIfDenied: false)
            if case .granted = result {
                Haptics.success()
                session.settings.notificationsEnabled = true
                if let date = model.examDate {
                    await NotificationService.scheduleExamCountdowns(examDate: date, strings: strings)
                }
            }
            model.advance()
        }
    }

    // MARK: - Single-select steps

    private func motivationStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        let generic: [String: (label: String, detail: String)] = [
            "stability": (strings.motivationStability, strings.motivationStabilityDetail),
            "calling": (strings.motivationCalling, strings.motivationCallingDetail),
            "family": (strings.motivationFamily, strings.motivationFamilyDetail),
            "newCareer": (strings.motivationNewCareer, strings.motivationNewCareerDetail),
        ]
        let motivations = session.pack.nicheConfig.motivations
        let options = motivations.map(\.id)
        let labels = motivations.map { $0.label.isEmpty ? (generic[$0.id]?.label ?? $0.id) : $0.label }
        let details = motivations.map { $0.detail.isEmpty ? (generic[$0.id]?.detail ?? "") : $0.detail }
        return OnboardingSingleSelectStep(
            title: strings.motivationTitle,
            subtitle: strings.motivationSubtitle,
            options: labels,
            details: details,
            selectedIndex: model.motivation.flatMap { options.firstIndex(of: $0) }
        ) { index in
            model.motivation = options[index]
            autoAdvance(model)
        }
    }

    private func firstTimeStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        return OnboardingSingleSelectStep(
            title: strings.firstTimeTitle,
            subtitle: nil,
            options: [strings.firstTimeYes, strings.firstTimeNo],
            selectedIndex: model.firstTime
        ) { index in
            model.firstTime = index
            autoAdvance(model)
        }
    }

    private func levelStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        return OnboardingSingleSelectStep(
            title: strings.levelTitleFunnel,
            subtitle: nil,
            options: [strings.levelNotReady, strings.levelSomewhat,
                      strings.levelReady, strings.levelVeryReady],
            emojis: [strings.levelEmojiNotReady, strings.levelEmojiSomewhat,
                     strings.levelEmojiReady, strings.levelEmojiVeryReady],
            selectedIndex: model.level.flatMap { UserProfile.Level.allCases.firstIndex(of: $0) }
        ) { index in
            model.level = UserProfile.Level.allCases[index]
            autoAdvance(model)
        }
    }

    private func minutesStep(_ model: OnboardingModel) -> some View {
        OnboardingMinutesStep(model: model) { askPushThenAdvance(model) }
    }

    /// Single-select pages advance on their own ~350ms after the tap.
    private func autoAdvance(_ model: OnboardingModel) {
        Haptics.select()
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            model.advance()
        }
    }
}

/// The funnel's own backdrop: a cool blue wash at the top fading into the
/// app background. Approved in the prototype — blue only, no pink.
struct OnboardingBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Group {
            if scheme == .dark {
                AppColor.background
            } else {
                wash
            }
        }
        .ignoresSafeArea()
    }

    private var wash: some View {
        LinearGradient(
            stops: [
                .init(color: Color(hexString: "#DCE9FA"), location: 0.0),
                .init(color: Color(hexString: "#E8F0FB"), location: 0.20),
                .init(color: Color(hexString: "#F4F7FB"), location: 0.48),
                .init(color: AppColor.background, location: 0.72),
                .init(color: AppColor.background, location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom)
    }
}
