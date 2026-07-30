import SwiftUI

struct ReviewView: View {
    @Environment(AppSession.self) private var session

    @State private var filter: Filter = .all
    @State private var selectedQuestion: Question?

    enum Filter: CaseIterable {
        case all, correct, wrong, bookmarked
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(session.strings.review.title)
                .font(AppFont.display(28))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, AppSpacing.screenMargin)

            filterChips

            if rows.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .padding(.top, AppSpacing.screenMargin)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .readableWidth(AppLayout.readableContent, alignment: .leading)
        .background(AppColor.background.ignoresSafeArea())
        .sheet(item: $selectedQuestion) { question in
            ReviewDetailSheet(question: question)
                .presentationDetents([.large])
        }
    }

    // MARK: - Data

    /// Latest answer per question, newest first.
    private var latestAnswers: [AnswerRecord] {
        var latest: [String: AnswerRecord] = [:]
        for answer in session.progress.allAnswers.sorted(by: { $0.date < $1.date }) {
            latest[answer.questionId] = answer
        }
        return latest.values.sorted { $0.date > $1.date }
    }

    private var rows: [(answer: AnswerRecord, question: Question)] {
        let questionsById = Dictionary(uniqueKeysWithValues: session.content.questions.map { ($0.id, $0) })
        return latestAnswers.compactMap { answer in
            guard let question = questionsById[answer.questionId] else { return nil }
            switch filter {
            case .all: break
            case .correct: guard answer.isCorrect else { return nil }
            case .wrong: guard !answer.isCorrect else { return nil }
            case .bookmarked:
                guard session.progress.state.bookmarkedQuestionIds.contains(question.id) else { return nil }
            }
            return (answer, question)
        }
    }

    private func label(for filter: Filter) -> String {
        switch filter {
        case .all: session.strings.review.filterAll
        case .correct: session.strings.review.filterCorrect
        case .wrong: session.strings.review.filterWrong
        case .bookmarked: session.strings.review.filterBookmarked
        }
    }

    // MARK: - UI

    private var filterChips: some View {
        SegmentedPills(options: Filter.allCases, selection: $filter, label: label(for:))
            .padding(.horizontal, AppSpacing.screenMargin)
    }

    private var list: some View {
        ScrollView {
            VStack(spacing: AppSpacing.cardGap) {
                ForEach(rows, id: \.answer.id) { row in
                    rowView(row)
                }
            }
            .padding(.horizontal, AppSpacing.screenMargin)
            .padding(.bottom, AppSpacing.sectionGap)
        }
    }

    private func rowView(_ row: (answer: AnswerRecord, question: Question)) -> some View {
        Button {
            selectedQuestion = row.question
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: row.answer.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(row.answer.isCorrect ? AppColor.success : AppColor.error)

                Text(row.question.text)
                    .font(AppFont.body(17))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if session.progress.state.bookmarkedQuestionIds.contains(row.question.id) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.accent)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppColor.textDim)
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardY)
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            GlowIcon(symbol: "magnifyingglass", tint: AppColor.accent, size: 84)
            Text(session.strings.empty.reviewTitle)
                .font(AppFont.heading(17))
                .foregroundStyle(AppColor.textPrimary)
            Text(session.strings.empty.reviewSubtitle)
                .font(AppFont.body(17))
                .foregroundStyle(AppColor.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.screenMargin)
    }
}

/// Full question with marked choices, explanation and bookmark toggle.
struct ReviewDetailSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    let question: Question

    private static let letters = ["A", "B", "C", "D", "E", "F"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack {
                    Spacer()
                    Button {
                        session.progress.toggleBookmark(questionId: question.id)
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(isBookmarked ? AppColor.accent : AppColor.textSecondary)
                    }
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(.leading, AppSpacing.sm)
                }

                QuestionImageView(question: question)

                Text(question.text)
                    .font(AppFont.heading(20))
                    .foregroundStyle(AppColor.textPrimary)

                VStack(spacing: AppSpacing.cardGap) {
                    ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                        ChoiceRow(
                            letter: Self.letters[index],
                            text: choice,
                            state: state(for: index),
                            fontScale: 1.0
                        ) {}
                        .allowsHitTesting(false)
                    }
                }

                Text(question.explanation)
                    .font(AppFont.body(17))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(AppSpacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.surfaceHigh)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
            }
            .padding(AppSpacing.screenMargin)
            .readableWidth(AppLayout.readableContent, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
    }

    private var isBookmarked: Bool {
        session.progress.state.bookmarkedQuestionIds.contains(question.id)
    }

    private var latestAnswer: AnswerRecord? {
        session.progress.allAnswers
            .filter { $0.questionId == question.id }
            .max { $0.date < $1.date }
    }

    private func state(for index: Int) -> ChoiceRow.ChoiceState {
        if index == question.correctIndex { return .revealedCorrect }
        if let latest = latestAnswer, !latest.isCorrect, latest.selectedIndex == index {
            return .revealedWrong
        }
        return .dimmed
    }
}
