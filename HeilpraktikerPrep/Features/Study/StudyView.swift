import SwiftUI

struct StudyView: View {
    @Environment(AppSession.self) private var session

    @State private var activeQuiz: QuizController?
    @State private var showPaywall = false
    @State private var newOnly = true

    @Environment(\.horizontalSizeClass) private var hSize

    private var isPro: Bool { session.iap.isPro }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                header
                overallCard
                if !isPro { proPrompt }
                filterPicker
                subjectList
            }
            .padding(AppSpacing.screenMargin)
            .readableWidth(AppLayout.readableContent, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .fullScreenCover(item: $activeQuiz) { controller in
            QuizView(controller: controller)
        }
        .fullScreenCover(isPresented: $showPaywall) {
            PaywallView(source: .studyLocked)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(session.strings.study.title)
                .font(AppFont.display(28))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            if !isPro { ProBadge() }
        }
    }

    // MARK: - Overall progress

    private var answeredIds: Set<String> {
        Set(session.progress.allAnswers.map(\.questionId))
    }

    private var overallFraction: Double {
        let total = session.questionPool.count
        guard total > 0 else { return 0 }
        return Double(answeredIds.count) / Double(total)
    }

    private var overallCard: some View {
        Card {
            HStack(spacing: AppSpacing.lg) {
                ZStack {
                    Circle()
                        .stroke(AppColor.surfaceHigh, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: overallFraction)
                        .stroke(AppColor.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(Int((overallFraction * 100).rounded()))%")
                        .font(AppFont.heading(20))
                        .foregroundStyle(AppColor.textPrimary)
                }
                .frame(width: 84, height: 84)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(session.strings.study.overallProgress)
                        .font(AppFont.bodyMedium(17))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(String(format: session.strings.study.answeredFormat,
                                answeredIds.count, session.questionPool.count))
                        .font(AppFont.caption(13))
                        .foregroundStyle(AppColor.textDim)
                }
                Spacer()
            }
        }
    }

    // MARK: - Pro prompt (free users)

    private var proPrompt: some View {
        Button { showPaywall = true } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text(String(format: session.strings.home.unlockBannerFormat, session.questionPool.count))
                    .font(AppFont.bodyMedium(14))
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

    // MARK: - Filter picker

    private var filterPicker: some View {
        Picker("", selection: $newOnly) {
            Text(session.strings.study.filterNew).tag(true)
            Text(session.strings.study.filterAll).tag(false)
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Subjects

    // Two columns on iPad (within the capped width), a single column on iPhone
    // — one flexible column is identical to the previous VStack.
    private var subjectColumns: [GridItem] {
        hSize == .regular
            ? [GridItem(.adaptive(minimum: 300), spacing: AppSpacing.cardGap)]
            : [GridItem(.flexible())]
    }

    private var subjectList: some View {
        LazyVGrid(columns: subjectColumns, spacing: AppSpacing.cardGap) {
            ForEach(session.pack.subjects) { subject in
                subjectCard(subject)
            }
        }
    }

    private func subjectCard(_ subject: Subject) -> some View {
        let allQuestions = session.questionPool.filter { $0.subjectId == subject.id }
        let answers = session.progress.allAnswers.filter { answer in
            allQuestions.contains { $0.id == answer.questionId }
        }
        let answeredCount = Set(answers.map(\.questionId)).count
        let accuracy = answers.isEmpty
            ? nil
            : ScoringLogic.scorePercent(correct: answers.filter(\.isCorrect).count, total: answers.count)
        let fraction = allQuestions.isEmpty ? 0 : Double(answeredCount) / Double(allQuestions.count)

        let newQuestions = allQuestions.filter { !answeredIds.contains($0.id) }
        let displayPool = newOnly ? newQuestions : allQuestions
        let isEmpty = displayPool.isEmpty

        return Button {
            guard isPro else { showPaywall = true; return }
            if isEmpty { return }
            activeQuiz = QuizController.makeStudy(from: displayPool, app: session)
        } label: {
            Card {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: subject.sfSymbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isEmpty ? AppColor.textDim : AppColor.accent)
                            .frame(width: 40, height: 40)
                            .background(isEmpty ? AppColor.surfaceHigh : AppColor.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))

                        Text(subject.name)
                            .font(AppFont.bodyMedium(17))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)

                        if !isPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(AppColor.textDim)
                        } else if isPro && !isEmpty {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppColor.textDim)
                        }
                    }

                    HStack {
                        if newOnly && isEmpty {
                            Text(session.strings.study.emptyNew)
                                .font(AppFont.caption(13))
                                .foregroundStyle(AppColor.success)
                        } else {
                            Text(String(format: session.strings.study.answeredFormat,
                                        answeredCount, allQuestions.count))
                                .font(AppFont.caption(13))
                                .foregroundStyle(AppColor.textDim)
                        }

                        Spacer()

                        if isPro, let accuracy {
                            Text(String(format: session.strings.study.accuracyFormat, accuracy))
                                .font(AppFont.caption(13))
                                .foregroundStyle(accuracy >= 50 ? AppColor.success : AppColor.error)
                        }
                    }

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppColor.surfaceHigh)
                            Capsule()
                                .fill(AppColor.accent)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                    .frame(height: 6)
                }
            }
            .opacity(isPro && isEmpty ? 0.55 : 1)
        }
        .buttonStyle(.plain)
    }
}
