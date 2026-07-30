import SwiftUI

/// Per-subject deep dive pushed from the Stats subject list: accuracy,
/// quiz/practice totals, and the full list of practiced questions filtered
/// by correct/wrong so the user can drill into their weak spots.
struct SubjectDetailView: View {
    @Environment(AppSession.self) private var session
    let subject: Subject

    @State private var filter: Filter = .all
    @State private var selectedQuestion: Question?

    enum Filter: CaseIterable { case all, correct, wrong }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                header
                statGrid
                questionList
            }
            .padding(AppSpacing.screenMargin)
            .readableWidth(AppLayout.readableContent, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(subject.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedQuestion) { question in
            ReviewDetailSheet(question: question)
                .presentationDetents([.large])
        }
    }

    // MARK: - Data

    private var subjectQuestionIds: Set<String> {
        Set(session.questionPool.filter { $0.subjectId == subject.id }.map(\.id))
    }

    private struct Totals {
        var quizCount = 0
        var practiceSeconds = 0
        var correct = 0
        var missed = 0
        var answered: Int { correct + missed }
        var accuracy: Double? { answered > 0 ? Double(correct) / Double(answered) : nil }
    }

    /// Cumulative across every attempt — matches the Stats subject card so
    /// the numbers are consistent when drilling in.
    private var totals: Totals {
        let ids = subjectQuestionIds
        var result = Totals()
        var seconds = 0.0
        for attempt in session.progress.state.attempts {
            let subjectAnswers = attempt.answers.filter { ids.contains($0.questionId) }
            guard !subjectAnswers.isEmpty else { continue }
            result.quizCount += 1
            let share = Double(subjectAnswers.count) / Double(max(attempt.answers.count, 1))
            seconds += Double(attempt.durationSeconds) * share
            result.correct += subjectAnswers.filter(\.isCorrect).count
            result.missed += subjectAnswers.filter { !$0.isCorrect }.count
        }
        result.practiceSeconds = Int(seconds.rounded())
        return result
    }

    /// Latest answer per question in this subject, newest first.
    private var rows: [(answer: AnswerRecord, question: Question)] {
        let ids = subjectQuestionIds
        let questionsById = Dictionary(uniqueKeysWithValues: session.content.questions.map { ($0.id, $0) })
        var latest: [String: AnswerRecord] = [:]
        for answer in session.progress.allAnswers.sorted(by: { $0.date < $1.date })
        where ids.contains(answer.questionId) {
            latest[answer.questionId] = answer
        }
        return latest.values
            .sorted { $0.date > $1.date }
            .compactMap { answer in
                guard let question = questionsById[answer.questionId] else { return nil }
                switch filter {
                case .all: break
                case .correct: guard answer.isCorrect else { return nil }
                case .wrong: guard !answer.isCorrect else { return nil }
                }
                return (answer, question)
            }
    }

    // MARK: - Header

    private var header: some View {
        let totals = totals
        return Card {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(AppColor.accentSoft)
                        .frame(width: 64, height: 64)
                    Image(systemName: subject.sfSymbol)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(AppColor.accent)
                }
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(session.strings.stats.quizAccuracy)
                        .font(AppFont.caption(13))
                        .foregroundStyle(AppColor.textSecondary)
                    if let accuracy = totals.accuracy {
                        HStack(spacing: AppSpacing.xs) {
                            Text("\(Int((accuracy * 100).rounded()))%")
                                .font(AppFont.display(34))
                                .foregroundStyle(AppColor.textPrimary)
                            Circle()
                                .fill(accuracy >= 0.5 ? AppColor.success : AppColor.error)
                                .frame(width: 9, height: 9)
                        }
                        Text(String(format: session.strings.stats.answeredFormat, totals.answered))
                            .font(AppFont.caption(13))
                            .foregroundStyle(AppColor.textDim)
                    } else {
                        Text("—")
                            .font(AppFont.display(34))
                            .foregroundStyle(AppColor.textDim)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Stat grid

    private var statGrid: some View {
        let totals = totals
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: AppSpacing.cardGap),
                                   GridItem(.flexible(), spacing: AppSpacing.cardGap)],
                         spacing: AppSpacing.cardGap) {
            StatTile(symbol: "square.and.pencil", tint: AppColor.accent,
                     label: session.strings.stats.quizTimes, value: "\(totals.quizCount)",
                     help: session.strings.stats.quizTimesHelp)
            StatTile(symbol: "clock", tint: Color(hexString: "#8E6FF7"),
                     label: session.strings.stats.practiceTime,
                     value: QuizView.format(seconds: totals.practiceSeconds),
                     help: session.strings.stats.practiceTimeHelp)
            StatTile(symbol: "checkmark.circle.fill", tint: AppColor.success,
                     label: session.strings.stats.correctQuestions, value: "\(totals.correct)")
            StatTile(symbol: "xmark.circle.fill", tint: AppColor.error,
                     label: session.strings.stats.missedQuestions, value: "\(totals.missed)")
        }
    }

    // MARK: - Question list

    private func filterLabel(_ filter: Filter) -> String {
        switch filter {
        case .all: session.strings.review.filterAll
        case .correct: session.strings.results.correct
        case .wrong: session.strings.results.wrong
        }
    }

    @ViewBuilder
    private var questionList: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionLabel(text: session.strings.results.questionsSection)

            HStack(spacing: AppSpacing.sm) {
                ForEach(Array(Filter.allCases.enumerated()), id: \.offset) { _, option in
                    let selected = filter == option
                    Button {
                        withAnimation(AppMotion.snap) { filter = option }
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text(filterLabel(option))
                            .font(AppFont.bodyMedium(13))
                            .foregroundStyle(selected ? .white : AppColor.textSecondary)
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.xs)
                            .background(selected ? AppColor.accent : AppColor.surfaceHigh)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if rows.isEmpty {
                emptyState
            } else {
                ForEach(rows, id: \.answer.id) { row in
                    questionRow(row)
                }
            }
        }
    }

    private func questionRow(_ row: (answer: AnswerRecord, question: Question)) -> some View {
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
            GlowIcon(symbol: subject.sfSymbol, tint: AppColor.accent, size: 72)
            Text(session.strings.empty.reviewSubtitle)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.lg)
    }
}

/// A stat tile with an optional "?" that explains the metric in a popover —
/// keeps the number uncluttered while making "Practice time" etc. self-explaining.
private struct StatTile: View {
    let symbol: String
    let tint: Color
    let label: String
    let value: String
    var help: String?

    @State private var showHelp = false

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Image(systemName: symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(tint)
                    Spacer()
                    if help != nil {
                        Button {
                            showHelp = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColor.textDim)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showHelp) {
                            helpCard
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
                Text(value)
                    .font(AppFont.heading(22))
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
                Text(label)
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var helpCard: some View {
        if let help {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(label)
                    .font(AppFont.bodyMedium(15))
                    .foregroundStyle(AppColor.textPrimary)
                Text(help)
                    .font(AppFont.body(14))
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppSpacing.md)
            .frame(width: 250)
        }
    }
}
