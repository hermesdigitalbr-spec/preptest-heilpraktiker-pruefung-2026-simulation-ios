import SwiftUI

struct QuizView: View {
    @Environment(AppSession.self) private var app
    @Environment(\.dismiss) private var dismiss

    @State var controller: QuizController
    @State private var showQuitDialog = false
    // Expanded by default only in the App Store screenshot harness, so the
    // captured quiz screen actually shows the explanation. Always false in prod.
    @State private var showExplanation = ProcessInfo.processInfo.environment["SCREENSHOT_SCREEN"] != nil
    @State private var fontScale: CGFloat = 1.0
    @Environment(\.horizontalSizeClass) private var hSize

    private static let letters = ["A", "B", "C", "D", "E", "F"]

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            if controller.session.isFinished || controller.timeExpired || controller.didRecord {
                QuizResultsView(controller: controller) { dismiss() }
            } else {
                quizContent
            }
        }
        .onAppear { controller.start() }
        .onDisappear { controller.stop() }
        .onChange(of: controller.session.isFinished) { _, finished in
            if finished { controller.recordAttempt() }
        }
        .onChange(of: controller.timeExpired) { _, expired in
            if expired { controller.recordAttempt() }
        }
    }

    // MARK: - Quiz screen

    private var quizContent: some View {
        VStack(spacing: 0) {
            header
                .readableWidth()
            progressBar
                .readableWidth()
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    if let question = controller.session.currentQuestion {
                        QuestionImageView(question: question,
                                          height: hSize == .regular ? 240 : 180)
                        Text(question.text)
                            .font(AppFont.heading(20 * fontScale))
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        choices(for: question)

                        if controller.session.isCurrentRevealed {
                            explanationSection(for: question)
                        }
                    }
                }
                .padding(AppSpacing.screenMargin)
                .readableWidth(alignment: .leading)
            }
            footer
                .readableWidth()
        }
        .confirmationDialog(
            app.strings.quiz.quitTitle,
            isPresented: $showQuitDialog,
            titleVisibility: .visible
        ) {
            Button(app.strings.quiz.viewResults) {
                controller.recordAttempt(finished: false)
            }
            Button(app.strings.quiz.quitButton, role: .destructive) {
                controller.recordAttempt(finished: false)
                dismiss()
            }
            Button(app.strings.quiz.keepGoing, role: .cancel) {}
        } message: {
            Text(String(format: app.strings.quiz.quitMessageFormat,
                        controller.session.answers.count,
                        controller.session.questions.count))
        }
    }

    private var header: some View {
        HStack(spacing: AppSpacing.md) {
            Button {
                showQuitDialog = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .accessibilityLabel(app.strings.common.close)

            Spacer()

            Text(String(format: app.strings.quiz.questionCounterFormat,
                        controller.session.currentIndex + 1,
                        controller.session.questions.count))
                .font(AppFont.bodyMedium(15))
                .foregroundStyle(AppColor.textSecondary)

            Spacer()

            if let remaining = controller.remainingSeconds {
                Text(Self.format(seconds: remaining))
                    .font(AppFont.bodyMedium(15))
                    .foregroundStyle(remaining < 60 ? AppColor.error : AppColor.textSecondary)
                    .monospacedDigit()
            }

            Button {
                fontScale = fontScale >= 1.3 ? 1.0 : fontScale + 0.15
            } label: {
                Image(systemName: "textformat.size")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .accessibilityLabel(app.strings.quiz.a11yFontSize)

            Button {
                controller.toggleBookmark()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
                Image(systemName: controller.isCurrentBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(controller.isCurrentBookmarked ? AppColor.accent : AppColor.textSecondary)
            }
            .accessibilityLabel(app.strings.quiz.a11yBookmark)
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.vertical, AppSpacing.sm)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppColor.surfaceHigh)
                Capsule()
                    .fill(AppColor.accent)
                    .frame(width: geo.size.width * progressFraction)
                    .animation(AppMotion.smooth, value: progressFraction)
            }
        }
        .frame(height: 5)
        .padding(.horizontal, AppSpacing.screenMargin)
    }

    private var progressFraction: CGFloat {
        let total = controller.session.questions.count
        guard total > 0 else { return 0 }
        return CGFloat(controller.session.answers.count) / CGFloat(total)
    }

    private func choices(for question: Question) -> some View {
        VStack(spacing: AppSpacing.cardGap) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                ChoiceRow(
                    letter: Self.letters[index],
                    text: choice,
                    state: choiceState(index: index, question: question),
                    fontScale: fontScale
                ) {
                    answer(index)
                }
            }
        }
    }

    private func choiceState(index: Int, question: Question) -> ChoiceRow.ChoiceState {
        let selected = controller.selectedIndexForCurrent
        let feedbackMode = controller.session.feedback

        // Learning: full reveal — correct answer goes green, wrong goes red, others dim.
        if controller.session.isCurrentRevealed {
            if index == question.correctIndex { return .revealedCorrect }
            if index == selected { return .revealedWrong }
            return .dimmed
        }

        // Quick: show ✓/✗ only on the tapped choice — never reveal which is correct.
        if feedbackMode == .quick, let selected, index == selected,
           controller.session.hasAnsweredCurrent {
            let isCorrect = controller.session.answers
                .first { $0.questionId == question.id }?.isCorrect ?? false
            return isCorrect ? .revealedCorrect : .revealedWrong
        }

        return index == selected ? .selected : .idle
    }

    private func answer(_ index: Int) {
        guard !controller.session.hasAnsweredCurrent else { return }
        let correct = controller.submit(index)
        if controller.session.feedback == .mock {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } else {
            // Both learning and quick give success/error haptic.
            if correct {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }

    @ViewBuilder
    private func explanationSection(for question: Question) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Button {
                withAnimation(AppMotion.smooth) { showExplanation.toggle() }
            } label: {
                HStack(spacing: AppSpacing.xs) {
                    Text(showExplanation ? app.strings.quiz.hideExplanation : app.strings.quiz.showExplanation)
                        .font(AppFont.bodyMedium(15))
                    Image(systemName: showExplanation ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(AppColor.accent)
            }

            if showExplanation {
                Text(question.explanation)
                    .font(AppFont.body(15 * fontScale))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(AppSpacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var footer: some View {
        let isLast = controller.session.currentIndex + 1 >= controller.session.questions.count
        let canAdvance = controller.session.hasAnsweredCurrent || controller.session.feedback == .mock
        return PrimaryCTAButton(
            title: isLast ? app.strings.quiz.finish : app.strings.quiz.next,
            isEnabled: canAdvance
        ) {
            showExplanation = false
            controller.advance()
        }
        .padding(.horizontal, AppSpacing.screenMargin)
        .padding(.vertical, AppSpacing.sm)
    }

    static func format(seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
