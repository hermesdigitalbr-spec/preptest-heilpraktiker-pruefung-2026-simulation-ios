import SwiftUI

struct QuizResultsView: View {
    @Environment(AppSession.self) private var app
    @Environment(\.horizontalSizeClass) private var hSize

    let controller: QuizController
    let onClose: () -> Void

    @State private var selectedQuestion: Question?
    @State private var resultFilter: ResultFilter = .all
    @State private var showPaywall = false
    @State private var newlyUnlocked: [AchievementStatus] = []
    @State private var shareItems: [Any]?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.vertical, AppSpacing.sm)
            .readableWidth()

            ScrollView {
                VStack(spacing: AppSpacing.sectionGap) {
                    headline
                    statsRow
                    if controller.session.answers.count > 0 { shareSection }
                    subjectBreakdown
                    answerCardGrid
                    questionsSection
                    subscribeBanner
                }
                .padding(AppSpacing.screenMargin)
                .readableWidth()
            }
        }
        .background(AppColor.background.ignoresSafeArea())
        .sheet(item: $selectedQuestion) { question in
            ReviewDetailSheet(question: question)
                .presentationDetents([.large])
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: Binding(get: { shareItems != nil },
                                    set: { if !$0 { shareItems = nil } })) {
            if let shareItems {
                ShareSheet(items: shareItems)
            }
        }
        .sheet(isPresented: Binding(get: { !newlyUnlocked.isEmpty },
                                    set: { if !$0 { newlyUnlocked = [] } })) {
            AchievementUnlockSheet(statuses: newlyUnlocked)
                .presentationDetents(newlyUnlocked.count > 3 ? [.medium, .large] : [.medium])
                .presentationDragIndicator(newlyUnlocked.count > 3 ? .visible : .hidden)
        }
        .onAppear {
            if score >= 50 {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            // Celebrate any badge this quiz just earned, once.
            let unlocks = app.uncelebratedUnlocks
            if !unlocks.isEmpty {
                newlyUnlocked = unlocks
                app.progress.markCelebrated(Set(unlocks.map(\.id)))
            }
            // Refresh widgets + rebase the lapse reminder on this fresh practice.
            app.publishWidgetSnapshot()
            app.refreshLapseReminder()
        }
        .task {
            // Let the results screen — and any achievement-unlock sheet — settle
            // before asking for a review.
            try? await Task.sleep(for: .seconds(2.2))
            RatePromptService.maybeRequestAfterQuiz(
                mode: controller.mode,
                finishedNaturally: controller.session.isFinished,
                answered: controller.session.answers.count,
                total: controller.session.questions.count,
                isPro: app.iap.isPro)
        }
    }

    // MARK: - Share (Lei 5 — organic growth at the proudest moment)

    /// The brag text + app link that rides alongside the image in the sheet.
    /// Falls back to the support/landing page until the App Store URL is known.
    private var shareText: String {
        let base = String(format: app.strings.results.shareFormat, score, app.pack.examName)
        let store = app.pack.appStoreUrl ?? ""
        let support = app.pack.legal.supportUrl ?? ""
        let link = store.isEmpty ? support : store
        return link.isEmpty ? base : base + "\n" + link
    }

    private var shareCardData: ShareCardData {
        let s = app.strings.results
        return ShareCardData(
            eyebrow: app.pack.examName.uppercased(with: .current),
            headline: headlineText,
            score: score,
            correctText: "\(controller.session.correctCount)/\(controller.session.answers.count)",
            streak: app.currentStreak,
            timeText: QuizView.format(seconds: controller.elapsedSeconds),
            challenge: String(format: s.shareChallengeFormat, score),
            brandName: app.pack.examName,
            tagline: app.pack.tagline,
            correctLabel: s.correct,
            streakLabel: s.streakLabel,
            timeLabel: s.timeLabel, scoreLabel: s.scoreLabel,
            iconGlyph: app.pack.examShortName.lowercased(with: .current))
    }

    /// Just the button — the card itself is built and previewed only when the
    /// user taps Share, in the system share sheet's own preview.
    private var shareSection: some View {
        Button { presentShare() } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                Text(app.strings.results.shareButton)
                    .font(AppFont.bodyMedium(15))
            }
            .foregroundStyle(AppColor.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    private func presentShare() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        var items: [Any] = [shareText]
        if let image = ShareCardRenderer.image(for: shareCardData) {
            items.insert(image, at: 0)   // image first so previews use it
        }
        shareItems = items
    }

    // MARK: - Sections

    private var score: Int { controller.session.scorePercent }

    private var headlineText: String {
        if score >= 80 { return app.strings.results.headlineGreat }
        if score >= 50 { return app.strings.results.headlineGood }
        return app.strings.results.headlineKeepTrying
    }

    private var headline: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(headlineText)
                .font(AppFont.display(28))
                .foregroundStyle(AppColor.textPrimary)

            RingGauge(progress: Double(score) / 100,
                      lineWidth: 16,
                      tint: score >= 50 ? AppColor.success : AppColor.error,
                      track: AppColor.surfaceHigh) {
                VStack(spacing: 2) {
                    Text("\(score)%")
                        .font(AppFont.display(48))
                        .foregroundStyle(score >= 50 ? AppColor.success : AppColor.error)
                    Text(app.strings.results.scoreLabel)
                        .font(AppFont.caption(13))
                        .foregroundStyle(AppColor.textDim)
                }
            }
            .frame(maxWidth: 190)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppSpacing.sm)
    }

    /// Single source of truth — same value the share card bakes in (counts
    /// days saved by streak freezes).
    private var streak: Int { app.currentStreak }

    private var statsRow: some View {
        HStack(spacing: AppSpacing.cardGap) {
            statCard(value: "\(streak)", label: app.strings.results.streakLabel, symbol: "flame.fill", color: AppColor.warning)
            statCard(value: "\(controller.session.correctCount)/\(controller.session.answers.count)",
                     label: app.strings.results.correct, symbol: "checkmark.circle.fill", color: AppColor.success)
            statCard(value: QuizView.format(seconds: controller.elapsedSeconds),
                     label: app.strings.results.timeLabel, symbol: "clock.fill", color: AppColor.accent)
        }
    }

    private func statCard(value: String, label: String, symbol: String, color: Color) -> some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(value)
                .font(AppFont.bodyMedium(17))
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(AppFont.caption(12))
                .foregroundStyle(AppColor.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardY)
    }

    private var breakdownItems: [SubjectBreakdown] {
        ScoringLogic.breakdown(answers: controller.session.answers, questions: controller.session.questions)
    }

    @ViewBuilder
    private var subjectBreakdown: some View {
        if !breakdownItems.isEmpty {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                SectionLabel(text: app.strings.results.subjectsSection)
                Card {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(breakdownItems) { item in
                            breakdownRow(item)
                        }
                    }
                }
            }
        }
    }

    private func breakdownRow(_ item: SubjectBreakdown) -> some View {
        let subject = app.pack.subjects.first { $0.id == item.subjectId }
        let percent = Int((item.accuracy * 100).rounded())
        return VStack(spacing: AppSpacing.xs) {
            HStack {
                Text(subject?.name ?? item.subjectId)
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Text("\(percent)%")
                    .font(AppFont.bodyMedium(15))
                    .foregroundStyle(percent >= 50 ? AppColor.success : AppColor.error)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.surfaceHigh)
                    Capsule()
                        .fill(percent >= 50 ? AppColor.success : AppColor.error)
                        .frame(width: geo.size.width * item.accuracy)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Answer card (numbered overview, taps open the question)

    private var answerCardGrid: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionLabel(text: app.strings.results.answerCardSection)
            Card {
                // More columns on iPad so the number chips stay phone-sized
                // instead of ballooning across the wider card.
                let columns = Array(repeating: GridItem(.flexible(), spacing: AppSpacing.sm),
                                    count: hSize == .regular ? 10 : 6)
                LazyVGrid(columns: columns, spacing: AppSpacing.sm) {
                    ForEach(Array(controller.session.questions.enumerated()), id: \.offset) { index, question in
                        answerCell(number: index + 1, question: question)
                    }
                }
            }
        }
    }

    private func answerCell(number: Int, question: Question) -> some View {
        let answer = controller.session.answers.first { $0.questionId == question.id }
        let background: Color = {
            guard let answer else { return AppColor.surfaceHigh }
            return answer.isCorrect ? AppColor.successSoft : AppColor.errorSoft
        }()
        let foreground: Color = {
            guard let answer else { return AppColor.textDim }
            return answer.isCorrect ? AppColor.success : AppColor.error
        }()
        return Button {
            selectedQuestion = question
        } label: {
            Text("\(number)")
                .font(AppFont.bodyMedium(13))
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(background)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Subscribe banner (free users only)

    @ViewBuilder
    private var subscribeBanner: some View {
        if !app.iap.isPro {
            Button {
                showPaywall = true
            } label: {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                    Text(String(format: app.strings.home.unlockBannerFormat, app.questionPool.count))
                        .font(AppFont.bodyMedium(15))
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .opacity(0.7)
                }
                .foregroundStyle(AppColor.onWarning)
                .padding(AppSpacing.cardPadding)
                .background(
                    LinearGradient(colors: [Color(hexString: "#FFD66B"), Color(hexString: "#F5A623")],
                                   startPoint: .leading, endPoint: .trailing))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Questions review (filterable, answers + explanations inline)

    private enum ResultFilter: CaseIterable {
        case all, correct, wrong
    }

    private func filterLabel(_ filter: ResultFilter) -> String {
        switch filter {
        case .all: app.strings.review.filterAll
        case .correct: app.strings.results.correct
        case .wrong: app.strings.results.wrong
        }
    }

    private var reviewRows: [(number: Int, question: Question, answer: AnswerRecord?)] {
        controller.session.questions.enumerated().compactMap { index, question in
            let answer = controller.session.answers.first { $0.questionId == question.id }
            switch resultFilter {
            case .all: break
            case .correct: guard answer?.isCorrect == true else { return nil }
            case .wrong: guard answer?.isCorrect == false else { return nil }
            }
            return (index + 1, question, answer)
        }
    }

    private var questionsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionLabel(text: app.strings.results.questionsSection)

            SegmentedPills(options: ResultFilter.allCases, selection: $resultFilter, label: filterLabel)

            VStack(spacing: AppSpacing.cardGap) {
                ForEach(reviewRows, id: \.question.id) { row in
                    questionResultCard(row)
                }
            }
        }
    }

    private func questionResultCard(_ row: (number: Int, question: Question, answer: AnswerRecord?)) -> some View {
        let isCorrect = row.answer?.isCorrect == true
        return Button {
            selectedQuestion = row.question
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .top, spacing: AppSpacing.sm) {
                    Image(systemName: row.answer == nil
                          ? "minus.circle.fill"
                          : (isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill"))
                        .foregroundStyle(row.answer == nil
                                         ? AppColor.textDim
                                         : (isCorrect ? AppColor.success : AppColor.error))
                    Text(row.question.text)
                        .font(AppFont.bodyMedium(15))
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let answer = row.answer, !answer.isCorrect,
                   row.question.choices.indices.contains(answer.selectedIndex) {
                    answerLine(label: app.strings.review.yourAnswer,
                               text: row.question.choices[answer.selectedIndex],
                               color: AppColor.error)
                }

                answerLine(label: app.strings.review.correctAnswer,
                           text: row.question.choices[row.question.correctIndex],
                           color: AppColor.success)

                Text(row.question.explanation)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.leading)
                    .padding(AppSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.surfaceHigh.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardY)
        }
        .buttonStyle(.plain)
    }

    private func answerLine(label: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: AppSpacing.xs) {
            Text(label)
                .font(AppFont.caption(13))
                .foregroundStyle(AppColor.textDim)
            Text(text)
                .font(AppFont.bodyMedium(13))
                .foregroundStyle(color)
                .multilineTextAlignment(.leading)
        }
    }
}
