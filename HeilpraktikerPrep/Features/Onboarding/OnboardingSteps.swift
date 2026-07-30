import SwiftUI

// MARK: - Shared scaffolding

struct OnboardingStepHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppFont.display(28))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingOptionCard: View {
    let title: String
    let selected: Bool
    var checkbox = false
    var symbol: String?
    var tint: Color = AppColor.accent
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 36, height: 36)
                        .background(tint.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: tint.opacity(selected ? 0.5 : 0), radius: 8)
                }
                Text(title)
                    .font(AppFont.bodyMedium(17))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                if checkbox {
                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? AppColor.accent : AppColor.border)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.accent)
                }
            }
            .padding(AppSpacing.cardPadding)
            .background(selected ? AppColor.accentSoft : AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(selected ? AppColor.accent : AppColor.border, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .opacity(isDisabled ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Hero / marketing steps

struct OnboardingHeroStep: View {
    let symbol: String
    var tint: Color = AppColor.accent
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            GlowIcon(symbol: symbol, tint: tint, size: 130)
            VStack(spacing: AppSpacing.md) {
                Text(title)
                    .font(AppFont.display(28))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(AppFont.body(17))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            Spacer()
            Spacer()
        }
    }
}

/// Marketing page: glowing icon, headline, short lead and 3 scannable bullets.
struct OnboardingBulletStep: View {
    let symbol: String
    let tint: Color
    let title: String
    let lead: String
    let points: [String]

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            GlowIcon(symbol: symbol, tint: tint, size: 100)

            VStack(spacing: AppSpacing.sm) {
                Text(title)
                    .font(AppFont.display(28))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lead)
                    .font(AppFont.body(17))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(Array(points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .top, spacing: AppSpacing.md) {
                        // Checkmarks are promises — always green, never the
                        // page tint (a red checkmark reads as a problem).
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppColor.success)
                            .shadow(color: AppColor.success.opacity(0.6), radius: 6)
                        Text(point)
                            .font(AppFont.bodyMedium(17))
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(AppSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.surface.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

            Spacer()
            Spacer()
        }
        .padding(.horizontal, AppSpacing.screenMargin)
    }
}

// MARK: - Single select

struct OnboardingSingleSelectStep: View {
    let title: String
    let subtitle: String
    let options: [String]
    var icons: [String]?
    var disabledIndices: Set<Int> = []
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var hSize

    private static let tints: [Color] = [
        AppColor.accent,
        Color(hexString: "#8E6FF7"),
        Color(hexString: "#2FB8C5"),
        Color(hexString: "#F2789F"),
        Color(hexString: "#23A566"),
        Color(hexString: "#F5A623"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
            if hSize == .regular { Spacer(minLength: 0) }
            OnboardingStepHeader(title: title, subtitle: subtitle)
            VStack(spacing: AppSpacing.cardGap) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    OnboardingOptionCard(
                        title: option,
                        selected: selectedIndex == index,
                        symbol: icons.map { $0[index] },
                        tint: Self.tints[index % Self.tints.count],
                        isDisabled: disabledIndices.contains(index)
                    ) {
                        onSelect(index)
                    }
                }
            }
            Spacer()
        }
        .padding(AppSpacing.screenMargin)
    }
}

// MARK: - Days of week (multi)

struct OnboardingDaysStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        return VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
            if hSize == .regular { Spacer(minLength: 0) }
            OnboardingStepHeader(title: session.strings.onboarding.daysTitle,
                                 subtitle: session.strings.onboarding.daysSubtitle)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm), count: 4),
                      spacing: AppSpacing.sm) {
                ForEach(1...7, id: \.self) { weekday in
                    let selected = model.studyDays.contains(weekday)
                    Button {
                        if selected {
                            model.studyDays.remove(weekday)
                        } else {
                            model.studyDays.insert(weekday)
                        }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(symbols[weekday - 1])
                            .font(AppFont.bodyMedium(15))
                            .foregroundStyle(selected ? .white : AppColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(selected ? AppColor.accent : AppColor.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.row)
                                    .stroke(selected ? AppColor.accent : AppColor.border, lineWidth: 1)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(AppSpacing.screenMargin)
    }
}

// MARK: - Preferred time (slider)

struct OnboardingTimeStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel
    @Environment(\.horizontalSizeClass) private var hSize

    private var hourSymbol: String {
        switch Int(model.preferredHour) {
        case 5..<8: "sunrise.fill"
        case 8..<17: "sun.max.fill"
        case 17..<20: "sunset.fill"
        default: "moon.stars.fill"
        }
    }

    private var hourTint: Color {
        switch Int(model.preferredHour) {
        case 5..<17: AppColor.warning
        case 17..<20: Color(hexString: "#F2789F")
        default: Color(hexString: "#8E6FF7")
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
            if hSize == .regular { Spacer(minLength: 0) }
            OnboardingStepHeader(title: session.strings.onboarding.timeTitle,
                                 subtitle: session.strings.onboarding.timeSubtitle)
            if hSize != .regular { Spacer() }
            VStack(spacing: AppSpacing.lg) {
                GlowIcon(symbol: hourSymbol, tint: hourTint, size: 84)
                Text(String(format: "%02d:00", Int(model.preferredHour)))
                    .font(AppFont.display(48))
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity)
                Slider(value: $model.preferredHour, in: 0...23, step: 1)
                    .tint(AppColor.accent)
            }
            Spacer()
            if hSize != .regular { Spacer() }
        }
        .padding(AppSpacing.screenMargin)
    }
}

// MARK: - State picker (regions from the pack)

struct RegionPickerList: View {
    let regions: [Region]
    let searchPlaceholder: String
    let selectedId: String?
    let onSelect: (Region) -> Void

    @State private var query = ""

    private var filtered: [Region] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return regions }
        return regions.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColor.textDim)
                TextField(searchPlaceholder, text: $query)
                    .font(AppFont.body(17))
                    .autocorrectionDisabled()
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))

            ScrollView {
                VStack(spacing: AppSpacing.xs) {
                    ForEach(filtered) { region in
                        let selected = region.id == selectedId
                        Button {
                            hideKeyboard()
                            onSelect(region)
                        } label: {
                            HStack {
                                Text(region.name)
                                    .font(AppFont.body(17))
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColor.accent)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.sm + 2)
                            .background(selected ? AppColor.accentSoft : AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }
}

struct OnboardingStateStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            OnboardingStepHeader(title: session.strings.onboarding.stateTitle,
                                 subtitle: session.strings.onboarding.stateSubtitle)
            RegionPickerList(
                regions: session.pack.regions ?? [],
                searchPlaceholder: session.strings.onboarding.stateSearch,
                selectedId: model.stateId
            ) { region in
                model.stateId = region.id
                UISelectionFeedbackGenerator().selectionChanged()
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    model.advance()
                }
            }
        }
        .padding(AppSpacing.screenMargin)
    }
}

// MARK: - Exam date

struct OnboardingExamDateStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if hSize == .regular { Spacer(minLength: 0) }
            OnboardingStepHeader(title: session.strings.onboarding.examDateTitle,
                                 subtitle: session.strings.onboarding.examDateSubtitle)

            DatePicker("",
                       selection: Binding(
                           get: { model.examDate ?? Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now },
                           set: { model.examDate = $0 }),
                       in: Date.now...,
                       displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(AppColor.accent)
                .padding(AppSpacing.sm)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .readableWidth(480)

            if let examDate = model.examDate {
                let days = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: .now),
                    to: Calendar.current.startOfDay(for: examDate)).day ?? 0
                if days > 0 {
                    Text(String(format: session.strings.home.daysLeftFormat, days))
                        .font(AppFont.bodyMedium(15))
                        .foregroundStyle(AppColor.accent)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColor.accentSoft)
                        .clipShape(Capsule())
                        .frame(maxWidth: .infinity)
                }
            }

            Button {
                model.examDate = nil
                model.advance()
            } label: {
                Text(session.strings.onboarding.examDateUnknown)
                    .font(AppFont.bodyMedium(15))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity)

            Spacer()
        }
        .padding(AppSpacing.screenMargin)
    }
}

// MARK: - Weak subjects (multi, from the pack)

struct OnboardingSubjectsStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        // Header pinned at the top (the "question"); the option list scrolls
        // below it. A 5-subject pack fits a plain VStack in the fixed
        // step frame; some packs ship 13+ subjects, which overflow and clip without a
        // ScrollView (same long-list reason RegionPickerList scrolls).
        VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
            OnboardingStepHeader(title: session.strings.onboarding.subjectsTitle,
                                 subtitle: session.strings.onboarding.subjectsSubtitle)
            ScrollView {
                VStack(spacing: AppSpacing.cardGap) {
                    ForEach(session.pack.subjects) { subject in
                        OnboardingOptionCard(
                            title: subject.name,
                            selected: model.weakSubjects.contains(subject.id),
                            checkbox: true,
                            symbol: subject.sfSymbol,
                            tint: AppColor.accent
                        ) {
                            if model.weakSubjects.contains(subject.id) {
                                model.weakSubjects.remove(subject.id)
                            } else {
                                model.weakSubjects.insert(subject.id)
                            }
                            UISelectionFeedbackGenerator().selectionChanged()
                        }
                    }
                }
                .padding(.bottom, AppSpacing.sm)
            }
            .scrollIndicators(.automatic)
        }
        .padding(AppSpacing.screenMargin)
    }
}

// MARK: - Personalizing (animated, auto-advances)

struct OnboardingPersonalizingStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel

    @State private var percent = 0.0
    @State private var visibleSteps = 0

    var body: some View {
        let labels = [
            session.strings.onboarding.personalizingStep1,
            session.strings.onboarding.personalizingStep2,
            session.strings.onboarding.personalizingStep3,
        ]
        return VStack(spacing: AppSpacing.xl) {
            Spacer()
            RingGauge(progress: percent, lineWidth: 14, tint: AppColor.accent,
                      track: AppColor.surfaceHigh) {
                Text("\(Int(percent * 100))%")
                    .font(AppFont.display(28))
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
            }
            .frame(maxWidth: 170)

            Text(session.strings.onboarding.personalizingTitle)
                .font(AppFont.heading(22))
                .foregroundStyle(AppColor.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: index < visibleSteps ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(index < visibleSteps ? AppColor.success : AppColor.border)
                        Text(labels[index])
                            .font(AppFont.body(15))
                            .foregroundStyle(index < visibleSteps ? AppColor.textPrimary : AppColor.textDim)
                    }
                }
            }
            Spacer()
            Spacer()
        }
        .padding(AppSpacing.screenMargin)
        .task {
            for tick in 1...100 {
                try? await Task.sleep(for: .milliseconds(28))
                withAnimation(.linear(duration: 0.03)) { percent = Double(tick) / 100 }
                if tick == 30 { withAnimation(AppMotion.snap) { visibleSteps = 1 } }
                if tick == 62 { withAnimation(AppMotion.snap) { visibleSteps = 2 } }
                if tick == 92 { withAnimation(AppMotion.snap) { visibleSteps = 3 } }
            }
            try? await Task.sleep(for: .milliseconds(400))
            model.advance()
        }
    }
}

// MARK: - Plan ready (pre-paywall)

struct OnboardingPlanReadyStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    var body: some View {
        var draftProfile = session.profile
        draftProfile.examDate = model.examDate
        let plan = PlanGenerator.makePlan(
            profile: draftProfile,
            totalQuestions: session.content.questions.count,
            defaultDailyCount: session.pack.dailyQuestionsCount,
            today: .now,
            calendar: .current)
        let strings = session.strings.onboarding

        return ScrollView {
            VStack(spacing: AppSpacing.lg) {
                GlowIcon(symbol: "chart.line.uptrend.xyaxis", tint: AppColor.success, size: 88)
                    .padding(.top, AppSpacing.md)

                VStack(spacing: AppSpacing.sm) {
                    Text(strings.planTitle)
                        .font(AppFont.display(28))
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                    Text(strings.planSubtitle)
                        .font(AppFont.body(15))
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }

                statRow(plan: plan)

                bullets

                Spacer(minLength: AppSpacing.lg)

                VStack(spacing: AppSpacing.xs) {
                    PrimaryCTAButton(title: strings.planCta, action: onContinue)
                    Text(strings.planCtaSubtext)
                        .font(AppFont.caption(12))
                        .foregroundStyle(AppColor.textDim)
                }
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.bottom, AppSpacing.lg)
        }
    }

    @ViewBuilder
    private func statRow(plan: StudyPlan) -> some View {
        let strings = session.strings.onboarding
        let totalQuestions = session.content.questions.count
        let topicCount = session.pack.subjects.count
        HStack(spacing: AppSpacing.cardGap) {
            statCell(value: "\(plan.questionsPerDay)",
                     label: String(format: strings.planPerDayFormat, plan.questionsPerDay)
                        .replacingOccurrences(of: "\(plan.questionsPerDay) ", with: ""))
            if let days = plan.daysUntilExam {
                statCell(value: "\(days)",
                         label: String(format: session.strings.home.daysLeftFormat, days)
                            .replacingOccurrences(of: "\(days) ", with: "")
                            .replacingOccurrences(of: "Exam in ", with: ""))
            } else {
                statCell(value: "\(totalQuestions)", label: strings.planQuestionsLabel)
            }
            statCell(value: "\(topicCount)", label: strings.planTopicsLabel)
        }
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.display(26))
                .foregroundStyle(AppColor.accent)
                .monospacedDigit()
            Text(label)
                .font(AppFont.caption(12))
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private var bullets: some View {
        let strings = session.strings.onboarding
        let lines = [strings.planBullet1, strings.planBullet2, strings.planBullet3]
        return VStack(alignment: .leading, spacing: AppSpacing.md) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(AppColor.success)
                        .shadow(color: AppColor.success.opacity(0.55), radius: 6)
                    Text(line)
                        .font(AppFont.bodyMedium(15))
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }
}


// MARK: - Intro + visual value steps

/// First screen: the exam name front and center.
struct OnboardingIntroStep: View {
    @Environment(AppSession.self) private var session
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            GlowIcon(symbol: "stethoscope", tint: AppColor.accent,
                     size: hSize == .regular ? 96 : 64, animationDuration: 1.05)
                .padding(.horizontal, 36)
            VStack(spacing: AppSpacing.md) {
                Text(session.pack.examName)
                    .font(AppFont.display(34))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(session.pack.tagline)
                    .font(AppFont.body(17))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            Spacer()
            Spacer()
        }
    }
}

/// Value screen with a real product preview: a live question card from the
/// pack with the right answer revealed — show, don't tell.
struct OnboardingQuestionPreviewStep: View {
    @Environment(AppSession.self) private var session

    private var sample: Question? {
        session.content.questions.first { $0.text.count < 90 && $0.choices.allSatisfy { $0.count < 40 } }
            ?? session.content.questions.first
    }

    /// 0 = idle · 1 = answer picked (turns green) · 2 = explanation in.
    @State private var phase = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()
            if let question = sample {
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    Text(question.text)
                        .font(AppFont.bodyMedium(15))
                        .foregroundStyle(AppColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    previewChoice(question.choices[question.correctIndex],
                                  correct: true, revealed: phase >= 1)
                    if let wrong = question.choices.indices.first(where: { $0 != question.correctIndex }) {
                        previewChoice(question.choices[wrong], correct: false, revealed: phase >= 1)
                    }
                    HStack(alignment: .top, spacing: AppSpacing.xs) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(AppColor.warning)
                        Text(question.explanation)
                            .font(AppFont.caption(13))
                            .foregroundStyle(AppColor.textSecondary)
                            .lineLimit(2)
                    }
                    .opacity(phase >= 2 ? 1 : 0)
                    .offset(y: phase >= 2 ? 0 : 8)
                }
                .padding(AppSpacing.cardPadding)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .shadow(color: AppColor.accent.opacity(0.25), radius: 28, y: 8)
                .padding(.horizontal, AppSpacing.screenMargin)
                .rotationEffect(.degrees(-1.5))
                .gentleFloat(amplitude: 5)
                .task { await playLoop() }
            }
            VStack(spacing: AppSpacing.md) {
                Text(session.strings.onboarding.value1Title)
                    .font(AppFont.display(28))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(session.strings.onboarding.value1Subtitle)
                    .font(AppFont.body(17))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            Spacer()
            Spacer()
        }
    }

    /// A choice row that "gets answered" mid-loop: neutral until revealed,
    /// then the correct one fills green and pops while the other dims.
    private func previewChoice(_ text: String, correct: Bool, revealed: Bool) -> some View {
        let highlighted = revealed && correct
        return HStack(spacing: AppSpacing.sm) {
            Image(systemName: highlighted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(highlighted ? AppColor.success : AppColor.border)
            Text(text)
                .font(AppFont.body(14))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
            Spacer()
        }
        .padding(AppSpacing.sm)
        .background(highlighted ? AppColor.successSoft : AppColor.surfaceHigh.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
        .scaleEffect(highlighted ? 1.03 : 1)
        .opacity(revealed && !correct ? 0.55 : 1)
    }

    /// Ghost-answer loop: pick → green pop → explanation slides in → reset.
    private func playLoop() async {
        guard !reduceMotion else {
            phase = 2
            return
        }
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(AppMotion.bouncy) { phase = 1 }
            try? await Task.sleep(for: .milliseconds(650))
            withAnimation(AppMotion.smooth) { phase = 2 }
            try? await Task.sleep(for: .milliseconds(2600))
            withAnimation(AppMotion.smooth) { phase = 0 }
        }
    }
}

/// Value screen showing the quiz modes as a living mini-grid.
struct OnboardingModesPreviewStep: View {
    @Environment(AppSession.self) private var session

    /// Ghost finger cycling through the tiles, one at a time.
    @State private var highlighted = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let strings = session.strings.home
        let modes: [(String, String, Color)] = [
            (strings.modeQuick10Title, "bolt.fill", AppColor.accent),
            (strings.modeTimedTitle, "stopwatch.fill", AppColor.warning),
            (strings.modeMissedTitle, "arrow.uturn.left.circle.fill", AppColor.error),
            (strings.modeMockTitle, "graduationcap.fill", AppColor.success),
        ]
        return VStack(spacing: AppSpacing.xl) {
            Spacer()
            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.sm),
                                GridItem(.flexible(), spacing: AppSpacing.sm)],
                      spacing: AppSpacing.sm) {
                ForEach(Array(modes.enumerated()), id: \.offset) { index, mode in
                    let active = highlighted == index
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: mode.1)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(active ? Color.white : mode.2)
                            .frame(width: 32, height: 32)
                            .background(active ? mode.2 : mode.2.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .shadow(color: mode.2.opacity(active ? 0.8 : 0.5), radius: active ? 12 : 8)
                        Text(mode.0)
                            .font(AppFont.bodyMedium(14))
                            .foregroundStyle(AppColor.textPrimary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(AppSpacing.sm + 2)
                    .background(AppColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadius.row)
                            .stroke(active ? mode.2.opacity(0.6) : .clear, lineWidth: 1.5)
                    )
                    .scaleEffect(active ? 1.05 : 1)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -1.2 : 1.2))
                }
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .gentleFloat(amplitude: 4, duration: 3.6)
            .task {
                guard !reduceMotion else { return }
                while !Task.isCancelled {
                    for index in 0..<modes.count {
                        withAnimation(AppMotion.bouncy) { highlighted = index }
                        try? await Task.sleep(for: .milliseconds(750))
                    }
                    withAnimation(AppMotion.smooth) { highlighted = -1 }
                    try? await Task.sleep(for: .milliseconds(1200))
                }
            }
            VStack(spacing: AppSpacing.md) {
                Text(session.strings.onboarding.value2Title)
                    .font(AppFont.display(28))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(session.strings.onboarding.value2Subtitle)
                    .font(AppFont.body(17))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            Spacer()
            Spacer()
        }
    }
}
