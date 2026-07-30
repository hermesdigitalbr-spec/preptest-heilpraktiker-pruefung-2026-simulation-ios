import SwiftUI
import Charts

struct StatsView: View {
    @Environment(AppSession.self) private var session

    @State private var range: Range = .week
    @State private var selectedDay: Date?

    @Environment(\.horizontalSizeClass) private var hSize

    enum Range: CaseIterable {
        case week, month, quarter

        var days: Int {
            switch self {
            case .week: 7
            case .month: 30
            case .quarter: 90
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                    Text(session.strings.stats.title)
                        .font(AppFont.display(28))
                        .foregroundStyle(AppColor.textPrimary)

                    readinessCard
                    examCountdown
                    topCards
                    activityCard
                    achievementsSection
                    subjectAnalysis
                }
                .padding(AppSpacing.screenMargin)
                .readableWidth(AppLayout.readableContent, alignment: .leading)
            }
            .background(AppColor.background.ignoresSafeArea())
            .navigationDestination(for: Subject.self) { subject in
                SubjectDetailView(subject: subject)
            }
            .navigationDestination(for: StatsRoute.self) { _ in
                AchievementsView()
            }
        }
    }

    enum StatsRoute: Hashable { case achievements }

    // MARK: - Achievements section

    @ViewBuilder
    private var achievementsSection: some View {
        let statuses = session.achievementStatuses
        if !statuses.isEmpty {
            let unlocked = statuses.filter(\.unlocked).count
            // Show unlocked first, then those closest to unlocking.
            let preview = statuses.sorted {
                ($0.unlocked ? 1 : 0, $0.fraction) > ($1.unlocked ? 1 : 0, $1.fraction)
            }.prefix(6)
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                NavigationLink(value: StatsRoute.achievements) {
                    HStack {
                        SectionLabel(text: session.strings.stats.achievements)
                        Spacer()
                        Text(String(format: session.strings.stats.unlockedCountFormat,
                                    unlocked, statuses.count))
                            .font(AppFont.caption(12))
                            .foregroundStyle(AppColor.textDim)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppColor.textDim)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: AppSpacing.cardGap) {
                        ForEach(Array(preview)) { status in
                            NavigationLink(value: StatsRoute.achievements) {
                                AchievementBadge(status: status, compact: true)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Data

    private var allAnswers: [AnswerRecord] { session.progress.allAnswers }

    private var streak: Int { session.currentStreak }

    private var overallAccuracy: Int {
        ScoringLogic.scorePercent(
            correct: allAnswers.filter(\.isCorrect).count,
            total: allAnswers.count)
    }

    private struct DayPoint: Identifiable {
        let id: Date
        let day: Date
        let answered: Int
    }

    /// Questions answered per day over the selected range (zero-filled).
    private var chartPoints: [DayPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let grouped = Dictionary(grouping: allAnswers) { calendar.startOfDay(for: $0.date) }
        return (0..<range.days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -(range.days - 1 - offset), to: today)
            else { return nil }
            return DayPoint(id: day, day: day, answered: grouped[day]?.count ?? 0)
        }
    }

    private var rangeAnswers: [AnswerRecord] {
        let calendar = Calendar.current
        guard let start = calendar.date(byAdding: .day, value: -(range.days - 1),
                                        to: calendar.startOfDay(for: .now)) else { return [] }
        return allAnswers.filter { $0.date >= start }
    }

    // MARK: - Pass probability

    private func passProbabilityColor(_ p: Int) -> Color {
        if p >= 75 { return AppColor.success }
        if p >= 40 { return AppColor.warning }
        return AppColor.error
    }

    private func passRating(_ p: Int) -> String {
        if p >= 75 { return session.strings.stats.passReadyRating }
        if p >= 40 { return session.strings.stats.passBuildingRating }
        return session.strings.stats.passDrillRating
    }

    /// The app's core promise — "am I ready to pass" — as the visual hero: a
    /// ring filled to the pass probability, color-coded, with a verbal rating.
    @ViewBuilder
    private var readinessCard: some View {
        if !allAnswers.isEmpty {
            let prob = session.passProbability
            Card {
                if let prob {
                    RingGauge(progress: Double(prob) / 100, lineWidth: 18,
                              tint: passProbabilityColor(prob),
                              track: passProbabilityColor(prob).opacity(0.16)) {
                        VStack(spacing: 2) {
                            Text(session.strings.stats.passProbabilityTitle)
                                .font(AppFont.caption(13))
                                .foregroundStyle(AppColor.textSecondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(prob)%")
                                .font(AppFont.display(34))
                                .foregroundStyle(passProbabilityColor(prob))
                                .monospacedDigit()
                            Text(passRating(prob))
                                .font(AppFont.bodyMedium(13))
                                .foregroundStyle(passProbabilityColor(prob))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: 150)
                    }
                    .frame(maxWidth: 220)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                } else {
                    // Not enough practice yet — keep the row form with a hint.
                    HStack(alignment: .center, spacing: AppSpacing.lg) {
                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(session.strings.stats.passProbabilityTitle)
                                .font(AppFont.heading(20))
                                .foregroundStyle(AppColor.textPrimary)
                            Text(session.strings.stats.passProbabilityPending)
                                .font(AppFont.caption(13))
                                .foregroundStyle(AppColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Text("—")
                            .font(AppFont.display(34))
                            .foregroundStyle(AppColor.textDim)
                    }
                }
            }
        }
    }

    // MARK: - Exam countdown ring

    private var examCountdownData: (daysLeft: Int, progress: Double)? {
        guard let examDate = session.profile.examDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let exam = calendar.startOfDay(for: examDate)
        guard let daysLeft = calendar.dateComponents([.day], from: today, to: exam).day,
              daysLeft > 0 else { return nil }

        let anchor = calendar.startOfDay(for: session.profile.examDateSetAt ?? .now)
        let total = calendar.dateComponents([.day], from: anchor, to: exam).day ?? daysLeft
        guard total > 0 else { return (daysLeft, 0.05) }
        let elapsed = Double(total - daysLeft) / Double(total)
        return (daysLeft, min(max(elapsed, 0.04), 1))
    }

    @ViewBuilder
    private var examCountdown: some View {
        if let data = examCountdownData {
            Card {
                // Compact row — the Pass Probability ring above is the hero; this
                // is a slim secondary stat so the rest of the screen stays visible.
                HStack(spacing: AppSpacing.lg) {
                    RingGauge(progress: data.progress, lineWidth: 7, tint: AppColor.accent,
                              track: AppColor.accentSoft) {
                        Image(systemName: "calendar")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(AppColor.accent)
                    }
                    .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.strings.stats.upcomingExam)
                            .font(AppFont.body(15))
                            .foregroundStyle(AppColor.textSecondary)
                        Text(String(format: session.strings.stats.daysFormat, data.daysLeft))
                            .font(AppFont.display(28))
                            .foregroundStyle(AppColor.textPrimary)
                            .monospacedDigit()
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    // MARK: - Top cards (streak with week dots, accuracy with sparkline)

    private var topCards: some View {
        HStack(spacing: AppSpacing.cardGap) {
            streakCard
            accuracyCard
        }
    }

    private var weekActivity: [Bool] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let active = Set((session.progress.completionDates
            + Array(session.progress.state.frozenDays)).map { calendar.startOfDay(for: $0) })
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today)
            else { return false }
            return active.contains(day)
        }
    }

    private var freezeCount: Int { session.progress.state.streakFreezes }

    private var streakCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                    Text("\(streak)")
                        .font(AppFont.display(28))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    if freezeCount > 0 {
                        // Shield = streak freezes in reserve.
                        HStack(spacing: 2) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 11))
                            Text("\(freezeCount)")
                                .font(AppFont.caption(12))
                                .monospacedDigit()
                        }
                        .foregroundStyle(AppColor.accent)
                    }
                }
                Text(session.strings.stats.dayStreak)
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.textSecondary)
                HStack(spacing: AppSpacing.xs) {
                    ForEach(Array(weekActivity.enumerated()), id: \.offset) { _, active in
                        ZStack {
                            Circle()
                                .fill(active ? AppColor.warning : .clear)
                                .strokeBorder(active ? .clear : AppColor.border, lineWidth: 1.5)
                            if active {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(width: 16, height: 16)
                    }
                }
                .padding(.top, 2)
            }
        }
    }

    /// Accuracy per day, last 7 days — nil when no practice that day.
    private var accuracySparkline: [Double?] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let grouped = Dictionary(grouping: allAnswers) { calendar.startOfDay(for: $0.date) }
        return (0..<7).map { offset in
            guard let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today),
                  let answers = grouped[day], !answers.isEmpty else { return nil }
            return Double(answers.filter(\.isCorrect).count) / Double(answers.count)
        }
    }

    private var accuracyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.xs) {
                    Circle().fill(accuracyColor).frame(width: 7, height: 7)
                    Text(allAnswers.isEmpty ? "—" : "\(overallAccuracy)%")
                        .font(AppFont.display(28))
                        .foregroundStyle(AppColor.textPrimary)
                }
                Text(session.strings.stats.quizAccuracy)
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.textSecondary)
                HStack(alignment: .bottom, spacing: AppSpacing.xs) {
                    ForEach(Array(accuracySparkline.enumerated()), id: \.offset) { _, value in
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(value == nil ? AppColor.surfaceHigh : accuracyColor)
                            .frame(width: 12, height: max(4, 22 * (value ?? 0.18)))
                    }
                }
                .frame(height: 22, alignment: .bottom)
                .padding(.top, 2)
            }
        }
    }

    private var accuracyColor: Color {
        overallAccuracy >= 50 ? AppColor.success : AppColor.error
    }

    // MARK: - Activity card (range picker + key numbers + volume chart)

    private func label(for range: Range) -> String {
        switch range {
        case .week: session.strings.stats.week
        case .month: session.strings.stats.month
        case .quarter: session.strings.stats.quarter
        }
    }

    private var activeDaysInRange: Int {
        let calendar = Calendar.current
        return Set(rangeAnswers.map { calendar.startOfDay(for: $0.date) }).count
    }

    private var rangeAverageScore: Int {
        ScoringLogic.scorePercent(
            correct: rangeAnswers.filter(\.isCorrect).count,
            total: rangeAnswers.count)
    }

    /// The chart point nearest the user's touch on the x-axis.
    private var selectedPoint: DayPoint? {
        guard let selectedDay else { return nil }
        return chartPoints.min {
            abs($0.day.timeIntervalSince(selectedDay)) < abs($1.day.timeIntervalSince(selectedDay))
        }
    }

    private var activityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                HStack(spacing: AppSpacing.sm) {
                    ForEach(Array(Range.allCases.enumerated()), id: \.offset) { _, option in
                        let selected = range == option
                        Button {
                            withAnimation(AppMotion.smooth) {
                                range = option
                                selectedDay = nil
                            }
                        } label: {
                            Text(label(for: option))
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

                HStack(spacing: 0) {
                    activityStat(
                        value: activeDaysInRange > 0
                            ? "\(Int((Double(rangeAnswers.count) / Double(activeDaysInRange)).rounded()))"
                            : "0",
                        label: session.strings.stats.onAverage)
                    activityStat(value: "\(rangeAnswers.count)",
                                 label: session.strings.stats.inTotal)
                    activityStat(value: rangeAnswers.isEmpty ? "—" : "\(rangeAverageScore)%",
                                 label: session.strings.stats.averageScore,
                                 dotColor: rangeAnswers.isEmpty
                                     ? nil
                                     : (rangeAverageScore >= 50 ? AppColor.success : AppColor.error))
                }

                Chart(chartPoints) { point in
                    LineMark(x: .value("Day", point.day, unit: .day),
                             y: .value("Answered", point.answered))
                        .foregroundStyle(AppColor.accent)
                        .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                        .interpolationMethod(.catmullRom)
                    AreaMark(x: .value("Day", point.day, unit: .day),
                             y: .value("Answered", point.answered))
                        .foregroundStyle(
                            LinearGradient(colors: [AppColor.accent.opacity(0.22), .clear],
                                           startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.catmullRom)
                    if range == .week {
                        PointMark(x: .value("Day", point.day, unit: .day),
                                  y: .value("Answered", point.answered))
                            .foregroundStyle(AppColor.accent)
                            .symbolSize(36)
                    }

                    // Touch marker: rule + dot + value bubble for the picked day.
                    if let selectedPoint, selectedPoint.id == point.id {
                        RuleMark(x: .value("Day", selectedPoint.day, unit: .day))
                            .foregroundStyle(AppColor.textDim.opacity(0.4))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .annotation(position: .top, spacing: 6,
                                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                                selectionBubble(selectedPoint)
                            }
                        PointMark(x: .value("Day", selectedPoint.day, unit: .day),
                                  y: .value("Answered", selectedPoint.answered))
                            .foregroundStyle(AppColor.accent)
                            .symbolSize(110)
                    }
                }
                .chartXSelection(value: $selectedDay)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == .week ? 1 : (range == .month ? 7 : 15))) { _ in
                        AxisValueLabel(format: range == .week
                                       ? .dateTime.weekday(.abbreviated)
                                       : .dateTime.day().month(.abbreviated))
                            .font(AppFont.caption(12))
                            .foregroundStyle(AppColor.textDim)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { _ in
                        AxisGridLine().foregroundStyle(AppColor.border.opacity(0.5))
                        AxisValueLabel()
                            .font(AppFont.caption(12))
                            .foregroundStyle(AppColor.textDim)
                    }
                }
                .frame(height: hSize == .regular ? 240 : 170)
            }
        }
    }

    /// Floating tooltip for the selected day: date + questions answered.
    private func selectionBubble(_ point: DayPoint) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(point.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                .font(AppFont.caption(11))
                .foregroundStyle(AppColor.textSecondary)
            Text(String(format: session.strings.stats.answeredFormat, point.answered))
                .font(AppFont.bodyMedium(13))
                .foregroundStyle(AppColor.textPrimary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(AppColor.surfaceHigh)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
        .shadow(color: AppShadow.cardColor, radius: 4, y: 2)
    }

    private func activityStat(value: String, label: String, dotColor: Color? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(AppFont.caption(13))
                .foregroundStyle(AppColor.textSecondary)
            HStack(spacing: AppSpacing.xs) {
                if let dotColor {
                    Circle().fill(dotColor).frame(width: 7, height: 7)
                }
                Text(value)
                    .font(AppFont.heading(22))
                    .foregroundStyle(AppColor.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Subject analysis (one rich card per subject)

    private var subjectAnalysis: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            SectionLabel(text: session.strings.stats.subjectAnalysis)
            VStack(spacing: AppSpacing.cardGap) {
                ForEach(session.pack.subjects) { subject in
                    subjectCard(subject)
                }
            }
        }
    }

    private struct SubjectStats {
        let accuracy: Double?
        let quizCount: Int
        let practiceSeconds: Int
        let correct: Int
        let missed: Int
    }

    private func stats(for subject: Subject) -> SubjectStats {
        let questionIds = Set(session.questionPool
            .filter { $0.subjectId == subject.id }
            .map(\.id))

        var quizCount = 0
        var practiceSeconds = 0.0
        var correct = 0
        var missed = 0

        for attempt in session.progress.state.attempts {
            let subjectAnswers = attempt.answers.filter { questionIds.contains($0.questionId) }
            guard !subjectAnswers.isEmpty else { continue }
            quizCount += 1
            // Allocate attempt time proportionally to this subject's share.
            let share = Double(subjectAnswers.count) / Double(max(attempt.answers.count, 1))
            practiceSeconds += Double(attempt.durationSeconds) * share
            correct += subjectAnswers.filter(\.isCorrect).count
            missed += subjectAnswers.filter { !$0.isCorrect }.count
        }

        let total = correct + missed
        return SubjectStats(
            accuracy: total > 0 ? Double(correct) / Double(total) : nil,
            quizCount: quizCount,
            practiceSeconds: Int(practiceSeconds.rounded()),
            correct: correct,
            missed: missed)
    }

    private func subjectCard(_ subject: Subject) -> some View {
        let stats = stats(for: subject)
        return NavigationLink(value: subject) {
            Card {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: subject.sfSymbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppColor.accent)
                        Text(subject.name)
                            .font(AppFont.bodyMedium(15))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(AppColor.textDim)
                    }

                    HStack {
                        Spacer(minLength: 0)
                        if let accuracy = stats.accuracy {
                            HStack(spacing: AppSpacing.xs) {
                                Text("\(Int((accuracy * 100).rounded()))%")
                                    .font(AppFont.bodyMedium(15))
                                    .foregroundStyle(AppColor.textPrimary)
                                Circle()
                                    .fill(accuracy >= 0.5 ? AppColor.success : AppColor.error)
                                    .frame(width: 7, height: 7)
                            }
                        } else {
                            Text("—")
                                .font(AppFont.bodyMedium(15))
                                .foregroundStyle(AppColor.textDim)
                        }
                    }

                    gradientBar(progress: stats.accuracy ?? 0)
                }
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }

    /// Segmented track with a gradient fill and a knob — the REF-style bar.
    private func gradientBar(progress: Double) -> some View {
        GeometryReader { geo in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule().fill(AppColor.surfaceHigh)
                    }
                }
                if clamped > 0 {
                    Capsule()
                        .fill(LinearGradient(colors: [AppColor.error, AppColor.warning],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width * clamped, 18))
                    Circle()
                        .fill(.white)
                        .frame(width: 16, height: 16)
                        .shadow(color: AppShadow.cardColor, radius: 2, y: 1)
                        .offset(x: max(geo.size.width * clamped - 16, 2))
                }
            }
        }
        .frame(height: 10)
    }

}
