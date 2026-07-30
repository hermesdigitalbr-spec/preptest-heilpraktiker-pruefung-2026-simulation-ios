import SwiftUI

/// Onboarding container: progress bar, back/skip chrome, step routing.
/// Funnel rules (onboarding playbook): single-select auto-advances; skip is
/// small, gray, top-right and only on question pages — it skips ONE page.
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
            topBar(model)
                .readableWidth(AppLayout.readableNarrow)

            Group {
                switch model.current {
                case .intro:
                    OnboardingIntroStep()
                case .value1:
                    OnboardingQuestionPreviewStep()
                case .value2:
                    OnboardingModesPreviewStep()
                case .level:
                    levelStep(model)
                case .goal:
                    goalStep(model)
                case .taken:
                    takenStep(model)
                case .concern:
                    concernStep(model)
                case .pain:
                    let pain = painCopy(for: model.concern)
                    OnboardingBulletStep(symbol: pain.symbol, tint: pain.tint,
                                         title: pain.title, lead: pain.lead, points: pain.points)
                case .minutes:
                    minutesStep(model)
                case .days:
                    OnboardingDaysStep(model: model)
                case .time:
                    OnboardingTimeStep(model: model)
                case .state:
                    OnboardingStateStep(model: model)
                case .examDate:
                    OnboardingExamDateStep(model: model)
                case .streakGoal:
                    streakStep(model)
                case .subjects:
                    OnboardingSubjectsStep(model: model)
                case .notif:
                    OnboardingHeroStep(
                        symbol: "bell.badge.fill",
                        tint: AppColor.accent,
                        title: session.strings.onboarding.notifTitle,
                        subtitle: session.strings.onboarding.notifSubtitle)
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
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)))

            bottomBar(model)
                .readableWidth(AppLayout.readableNarrow)
        }
        .background(AmbientBackground())
        .animation(AppMotion.smooth, value: model.index)
        .onChange(of: model.index) { _, _ in
            hideKeyboard()
        }
        .fullScreenCover(isPresented: $showPaywall, onDismiss: {
            // Single completion point regardless of outcome — purchased,
            // exited via the exit-intent offer, or dismissed for free.
            // There's no separate "welcome" confirmation step anymore; the
            // Home screen's first-appearance confetti is the celebration.
            model.complete(into: session)
        }) {
            PaywallView()
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

            Button(session.strings.common.skip) {
                model.advance()
            }
            .font(AppFont.caption(13))
            .foregroundStyle(AppColor.textDim)
            .opacity(model.isSkippable ? 1 : 0)
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.vertical, AppSpacing.sm)
    }

    /// Continue CTA for steps that need explicit confirmation.
    @ViewBuilder
    private func bottomBar(_ model: OnboardingModel) -> some View {
        switch model.current {
        case .intro, .value1, .value2, .pain:
            PrimaryCTAButton(title: session.strings.common.continueButton) {
                model.advance()
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.bottom, AppSpacing.sm)
        case .days:
            PrimaryCTAButton(title: session.strings.common.continueButton,
                             isEnabled: !model.studyDays.isEmpty) {
                model.advance()
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.bottom, AppSpacing.sm)
        case .time:
            PrimaryCTAButton(title: session.strings.common.continueButton) {
                model.advance()
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.bottom, AppSpacing.sm)
        case .examDate:
            // Just record the date here — requesting notification permission
            // (and scheduling the countdowns) happens later, at the dedicated
            // `.notif` ("Stay on track") step, so the system prompt appears
            // exactly once, at the intended moment.
            PrimaryCTAButton(title: session.strings.common.continueButton,
                             isEnabled: model.examDate != nil) {
                model.advance()
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.bottom, AppSpacing.sm)
        case .subjects:
            PrimaryCTAButton(title: session.strings.common.continueButton,
                             isEnabled: !model.weakSubjects.isEmpty) {
                model.advance()
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.bottom, AppSpacing.sm)
        case .notif:
            VStack(spacing: AppSpacing.sm) {
                PrimaryCTAButton(title: session.strings.onboarding.notifEnable) {
                    requestNotif(model)
                }
                Button(session.strings.onboarding.notifLater) {
                    model.advance()
                }
                .font(AppFont.bodyMedium(15))
                .foregroundStyle(AppColor.textDim)
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.bottom, AppSpacing.sm)
        default:
            EmptyView()
        }
    }

    /// Asks for notification permission at peak motivation (the ONLY place in
    /// onboarding that triggers the system prompt), schedules the daily
    /// reminder at the chosen hour and — if an exam date was picked earlier —
    /// the exam countdown notifications, then advances regardless of outcome.
    private func requestNotif(_ model: OnboardingModel) {
        let strings = session.strings.settings
        let hour = Int(model.preferredHour)
        Task {
            let result = await NotificationService.enableDailyReminder(
                hour: hour, minute: 0,
                title: strings.reminderNotificationTitle,
                body: strings.reminderNotificationBody)
            if case .granted = result { session.settings.notificationsEnabled = true }
            if let date = model.examDate {
                await NotificationService.scheduleExamCountdowns(examDate: date, strings: strings)
            }
            model.advance()
        }
    }

    // MARK: - Single-select steps

    private func levelStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        return OnboardingSingleSelectStep(
            title: strings.levelTitle,
            subtitle: strings.levelSubtitle,
            options: [strings.levelNewbie, strings.levelSkilled, strings.levelMaster, strings.levelExpert],
            icons: ["sparkles", "book.fill", "chart.line.uptrend.xyaxis", "crown.fill"],
            selectedIndex: model.level.flatMap { UserProfile.Level.allCases.firstIndex(of: $0) }
        ) { index in
            model.level = UserProfile.Level.allCases[index]
            autoAdvance(model)
        }
    }

    private func goalStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        return OnboardingSingleSelectStep(
            title: strings.goalTitle,
            subtitle: strings.goalSubtitle,
            options: [strings.goalPass, strings.goalKnowledge, strings.goalSkills, strings.goalBarriers],
            icons: ["checkmark.seal.fill", "brain.head.profile", "shield.lefthalf.filled", "bolt.heart.fill"],
            selectedIndex: model.goal.flatMap { UserProfile.Goal.allCases.firstIndex(of: $0) }
        ) { index in
            model.goal = UserProfile.Goal.allCases[index]
            autoAdvance(model)
        }
    }

    private func takenStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        return OnboardingSingleSelectStep(
            title: strings.takenTitle,
            subtitle: strings.takenSubtitle,
            options: [strings.takenNever, strings.takenOnce, strings.takenMany],
            icons: ["star.fill", "arrow.counterclockwise", "arrow.triangle.2.circlepath"],
            selectedIndex: model.takenBefore
        ) { index in
            model.takenBefore = index
            autoAdvance(model)
        }
    }

    private func concernStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        return OnboardingSingleSelectStep(
            title: strings.concernTitle,
            subtitle: strings.concernSubtitle,
            options: [strings.concernFailing, strings.concernTime, strings.concernMaterial, strings.concernAnxiety],
            icons: ["xmark.octagon.fill", "clock.badge.exclamationmark", "books.vertical.fill", "bolt.heart.fill"],
            selectedIndex: model.concern
        ) { index in
            model.concern = index
            autoAdvance(model)
        }
    }

    private func minutesStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        let values = [10, 15, 30, 60]
        let labels = values.map { value in
            value >= 60 ? strings.minutesMaxLabel : String(format: strings.minutesFormat, value)
        }
        return OnboardingSingleSelectStep(
            title: strings.minutesTitle,
            subtitle: strings.minutesSubtitle,
            options: labels,
            icons: ["bolt.fill", "timer", "clock.fill", "flame.fill"],
            selectedIndex: model.minutes.flatMap { values.firstIndex(of: $0) }
        ) { index in
            model.minutes = values[index]
            autoAdvance(model)
        }
    }

    private func streakStep(_ model: OnboardingModel) -> some View {
        let strings = session.strings.onboarding
        let values = [7, 14, 30]
        // Goals longer than the runway to the exam are visible but faded out.
        let disabled: Set<Int> = {
            guard let days = model.daysUntilExam else { return [] }
            let set = Set(values.indices.filter { values[$0] > days })
            return set.count == values.count ? Set(values.indices.dropFirst()) : set
        }()
        return OnboardingSingleSelectStep(
            title: strings.streakTitle,
            subtitle: strings.streakSubtitle,
            options: values.map { String(format: strings.streakFormat, $0) },
            icons: ["flame.fill", "calendar.badge.clock", "trophy.fill"],
            disabledIndices: disabled,
            selectedIndex: model.streakGoal.flatMap { values.firstIndex(of: $0) }
        ) { index in
            model.streakGoal = values[index]
            autoAdvance(model)
        }
    }

    /// The pain-reflection page mirrors the concern chosen on the previous
    /// step — copy, icon and tint all follow the answer (indices match
    /// `concernStep`'s option order).
    private func painCopy(for concern: Int?)
        -> (title: String, lead: String, points: [String], symbol: String, tint: Color) {
        let strings = session.strings.onboarding
        switch concern {
        case 0: return (strings.painFailingTitle, strings.painFailingLead, strings.painFailingPoints,
                        "xmark.octagon.fill", AppColor.error)
        case 1: return (strings.painTimeTitle, strings.painTimeLead, strings.painTimePoints,
                        "clock.fill", AppColor.warning)
        case 2: return (strings.painMaterialTitle, strings.painMaterialLead, strings.painMaterialPoints,
                        "books.vertical.fill", Color(hexString: "#8E6FF7"))
        case 3: return (strings.painAnxietyTitle, strings.painAnxietyLead, strings.painAnxietyPoints,
                        "bolt.heart.fill", Color(hexString: "#F2789F"))
        default: return (strings.painTitle, strings.painLead, strings.painPoints,
                         "exclamationmark.bubble.fill", AppColor.accent)
        }
    }

    /// Single-select pages advance on their own ~350ms after the tap.
    private func autoAdvance(_ model: OnboardingModel) {
        UISelectionFeedbackGenerator().selectionChanged()
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            model.advance()
        }
    }
}
