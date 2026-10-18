import SwiftUI

// MARK: - Personalizing (animated, auto-advances)

/// The checklist quotes the user's own answers (exam, subject count, date)
/// so the "building" moment reads as work done *for them*.
struct OnboardingPersonalizingStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel

    @State private var percent = 0.0
    @State private var visibleSteps = 0

    private var strings: UIStrings.Onboarding { session.strings.onboarding }

    private func draftProfile() -> UserProfile {
        var draft = session.profile
        draft.examDate = model.examDate
        draft.dailyMinutes = model.minutes
        return draft
    }

    var body: some View {
        let strings = session.strings.onboarding
        let labels = [
            strings.personalizingApplyingSyllabus,
            String(format: strings.personalizingSelectingFormat, session.pack.subjects.count),
            model.examDate.map {
                String(format: strings.personalizingSchedulingFormat,
                       $0.formatted(.dateTime.day().month(.abbreviated)
                           .locale(session.pack.contentLocale)))
            } ?? strings.personalizingStep3,
        ]
        let perDay = PlanGenerator.makePlan(
            profile: draftProfile(),
            totalQuestions: session.content.questions.count,
            defaultDailyCount: session.pack.dailyQuestionsCount,
            today: .now, calendar: .current).questionsPerDay

        return VStack(spacing: AppSpacing.lg) {
            // The title is the promise being kept; it stays put while the
            // work animates underneath it.
            Text(strings.personalizingTitleFunnel)
                .font(AppFont.display(27))
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            RingGauge(progress: percent, lineWidth: 14, tint: AppColor.accent,
                      track: AppColor.surfaceHigh) {
                Text("\(Int(percent * 100))%")
                    .font(AppFont.stat(34))
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
            }
            .frame(maxWidth: 170)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                ForEach(0..<3, id: \.self) { index in
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: index < visibleSteps ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(index < visibleSteps ? AppColor.success : AppColor.border)
                        Text(labels[index])
                            .font(AppFont.bodyMedium(15))
                            .foregroundStyle(index < visibleSteps ? AppColor.textPrimary : AppColor.textDim)
                    }
                }
            }

            (Text(String(format: strings.personalizingPerDayFormat, perDay))
                .foregroundColor(AppColor.accent).bold()
                + Text(" " + strings.personalizingPerDayTail))
                .font(AppFont.body(14))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(AppSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.surface.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))

            Spacer(minLength: 0)
        }
        .padding(OnboardingTokens.gutter)
        .task {
            for tick in 1...100 {
                try? await Task.sleep(for: .milliseconds(28))
                withAnimation(.linear(duration: 0.03)) { percent = Double(tick) / 100 }
                if tick == 30 { withAnimation(AppMotion.snap) { visibleSteps = 1 }; Haptics.select() }
                if tick == 62 { withAnimation(AppMotion.snap) { visibleSteps = 2 }; Haptics.select() }
                if tick == 92 { withAnimation(AppMotion.snap) { visibleSteps = 3 }; Haptics.select() }
            }
            Haptics.success()
            try? await Task.sleep(for: .milliseconds(400))
            model.advance()
        }
    }
}

// MARK: - Plan ready (pre-paywall)

/// Hands everything the user typed back as *their* plan: name in the title,
/// a readiness curve that ends on their exam date, and only the details the
/// user actually gave us.
struct OnboardingPlanReadyStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel
    let onContinue: () -> Void

    private var strings: UIStrings.Onboarding { session.strings.onboarding }

    var body: some View {
        var draftProfile = session.profile
        draftProfile.examDate = model.examDate
        draftProfile.dailyMinutes = model.minutes
        let plan = PlanGenerator.makePlan(
            profile: draftProfile,
            totalQuestions: session.content.questions.count,
            defaultDailyCount: session.pack.dailyQuestionsCount,
            today: .now,
            calendar: .current)
        let title = model.displayName.map { String(format: strings.planTitleFunnelNamedFormat, $0) }
            ?? strings.planTitleFunnel

        return ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(title)
                    .font(AppFont.display(22))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, AppSpacing.xl)

                bullets
                paceSection
                forecastCard(plan: plan)
                detailsCard
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, OnboardingTokens.gutter)
            .padding(.bottom, AppSpacing.md)
        }
    }

    // MARK: Bullets

    private var bullets: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            bulletRow(Text(strings.planBulletQuestions))
            bulletRow(Text(strings.planBulletMocks))
            bulletRow(Text(strings.planBulletReview))
            // No guarantee badge here: the refund guarantee lives only in the Terms.
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    private func bulletRow(_ text: Text) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18))
                .foregroundStyle(AppColor.success)
                .shadow(color: AppColor.success.opacity(0.55), radius: 6)
            text
                .font(AppFont.heading(15))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Pace verdict

    /// Names the daily rhythm the user just signed up for and says, in one
    /// line, whether it closes the gap to their exam date.
    private var paceSection: some View {
        let minutes = model.minutes ?? PlanGenerator.minuteOptions.first ?? 30
        let recommended = PlanGenerator.recommendedMinutes(
            totalQuestions: session.content.questions.count,
            daysUntilExam: model.daysUntilExam)
        let hasDate = model.examDate != nil
        let needsSpeed = recommended.map { minutes < $0 } ?? false

        let heading: String = !hasDate ? strings.planPaceNoDate
            : needsSpeed ? strings.planPaceSpeedUp : strings.planPaceOnTrack
        let tail: String = !hasDate ? strings.planPaceLeadNoDate
            : needsSpeed ? strings.planPaceLeadSpeedUp : strings.planPaceLeadOnTrack
        let amount = OnboardingMinutesStep.amountLabel(for: minutes, strings: strings)

        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(heading)
                .font(AppFont.title(19))
                .foregroundStyle(AppColor.textPrimary)
            (Text(String(format: strings.planPaceLeadPrefixFormat, amount))
                .font(AppFont.heading(14))
                + Text(" " + tail).font(AppFont.body(14)))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Forecast

    private func forecastCard(plan: StudyPlan) -> some View {
        let points = ReadinessForecast.points(startingAt: model.level, count: 24)
        let endLabel = model.examDate.map {
            $0.formatted(.dateTime.day().month(.abbreviated).locale(session.pack.contentLocale))
        }
            ?? strings.detailsFallbackExamDate
        let paceLabel: String? = model.pace.map { pace in
            switch pace {
            case .sprint: strings.paceSprint
            case .active: strings.paceActive
            case .steady: strings.paceSteady
            }
        }
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(strings.forecastTitleFunnel)
                .font(AppFont.heading(14))
                .foregroundStyle(AppColor.textPrimary)
            ReadinessForecastChart(points: points, finishEmoji: strings.forecastFinishEmoji)
                .frame(height: 118)
            HStack {
                Text(strings.forecastToday)
                Spacer()
                if let paceLabel { Text(paceLabel) }
                Spacer()
                Text(endLabel)
                    .foregroundStyle(AppColor.textPrimary)
            }
            .font(AppFont.bodyMedium(13))
            .foregroundStyle(Color(hexString: "#6B7A90"))
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }

    // MARK: Details

    /// Only rows the user actually filled in — an empty field would read as a
    /// plan built on nothing.
    private var detailsCard: some View {
        let stateName = model.stateId.flatMap { id in
            (session.pack.regions ?? []).first { $0.id == id }?.name
        }
        return VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(strings.detailsTitleFunnel)
                .font(AppFont.heading(14))
                .foregroundStyle(AppColor.textPrimary)
            detailRow(emoji: strings.detailsExamEmoji, label: strings.detailsExamLabel,
                      value: session.pack.examShortName)
            if let stateName {
                detailRow(emoji: strings.detailsStateEmoji, label: session.regionLabelCapitalized,
                          value: stateName)
            }
            if let date = model.examDate {
                detailRow(emoji: strings.detailsExamDateEmoji, label: strings.detailsExamDateLabel,
                          value: date.formatted(.dateTime.day().month(.wide).year()
                              .locale(session.pack.contentLocale)))
            }
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: OnboardingTokens.cardRadius))
        .overlay(RoundedRectangle(cornerRadius: OnboardingTokens.cardRadius)
            .stroke(OnboardingTokens.surfaceBorder, lineWidth: 1))
    }

    private func detailRow(emoji: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(emoji)
                .font(.system(size: 20))
                .frame(width: 44, height: 44)
                .background(AppColor.accentSoft, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(AppFont.body(13))
                    .foregroundStyle(Color(hexString: "#6B7A90"))
                Text(value)
                    .font(AppFont.heading(16))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }
}

/// Smooth area chart from today's readiness to the exam-day target.
struct ReadinessForecastChart: View {
    let points: [Double]
    /// Flag planted at the finish line once the curve gets there.
    var finishEmoji: String

    @State private var progress: CGFloat = 0
    @State private var arrived = false

    private static let drawDuration = 1.6

    var body: some View {
        GeometryReader { geo in
            // Room at the top for the "95%" label and the flag.
            let inset: CGFloat = 30
            let w = geo.size.width - 24, h = geo.size.height - inset
            let coords = points.enumerated().map { index, value in
                CGPoint(x: w * CGFloat(index) / CGFloat(max(points.count - 1, 1)),
                        y: inset + h * (1 - CGFloat(value)))
            }
            let head = point(on: coords, at: progress)

            ZStack(alignment: .topLeading) {
                area(coords, bottom: geo.size.height)
                    .fill(LinearGradient(
                        colors: [AppColor.success.opacity(0.35), AppColor.success.opacity(0)],
                        startPoint: .top, endPoint: .bottom))
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: max(0, head.x))
                    }

                // Red where readiness starts, green where it ends — the climb
                // is the whole point of the picture.
                line(coords)
                    .trim(from: 0, to: progress)
                    .stroke(LinearGradient(
                        colors: [AppColor.error, AppColor.warning, AppColor.success],
                        startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))

                if let first = coords.first {
                    Circle().fill(AppColor.error)
                        .frame(width: 11, height: 11)
                        .position(first)
                }

                if arrived, let last = coords.last {
                    Circle().fill(AppColor.success)
                        .frame(width: 13, height: 13)
                        .position(last)
                        .transition(.scale.combined(with: .opacity))
                    Text("\(Int(ReadinessForecast.target * 100))%")
                        .font(AppFont.strong(13))
                        .foregroundStyle(AppColor.textPrimary)
                        .position(x: last.x - 38, y: last.y - 17)
                        .transition(.opacity)
                    Text(finishEmoji)
                        .font(.system(size: 19))
                        .position(x: last.x + 6, y: last.y - 21)
                        .transition(.scale(scale: 0.2, anchor: .bottom).combined(with: .opacity))
                }
            }
        }
        .task {
            progress = 0
            arrived = false
            withAnimation(.easeInOut(duration: Self.drawDuration)) { progress = 1 }
            try? await Task.sleep(for: .seconds(Self.drawDuration))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { arrived = true }
            Haptics.success()
        }
    }

    /// Position along the polyline at `t` (0...1), used to clip the area fill
    /// to wherever the stroke currently is.
    private func point(on coords: [CGPoint], at t: CGFloat) -> CGPoint {
        guard let first = coords.first, let last = coords.last else { return .zero }
        guard coords.count > 1 else { return first }
        let exact = t * CGFloat(coords.count - 1)
        let index = Int(exact)
        guard index < coords.count - 1 else { return last }
        let fraction = exact - CGFloat(index)
        let a = coords[index], b = coords[index + 1]
        return CGPoint(x: a.x + (b.x - a.x) * fraction, y: a.y + (b.y - a.y) * fraction)
    }

    private func line(_ c: [CGPoint]) -> Path {
        var path = Path()
        guard let first = c.first else { return path }
        path.move(to: first)
        for point in c.dropFirst() { path.addLine(to: point) }
        return path
    }

    private func area(_ c: [CGPoint], bottom: CGFloat) -> Path {
        var path = line(c)
        guard let last = c.last, let first = c.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: bottom))
        path.addLine(to: CGPoint(x: first.x, y: bottom))
        path.closeSubpath()
        return path
    }
}
