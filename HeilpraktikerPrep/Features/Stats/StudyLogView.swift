import SwiftUI

/// The full study record: totals on top, then every day with study, grouped by
/// month. Tapping a day opens the sessions it holds. Plain numbers only — the
/// user reads them (and screenshots them) to back a refund claim.
struct StudyLogView: View {
    @Environment(AppSession.self) private var session
    @State private var expandedDays: Set<Date> = []

    private var days: [DailyStudyDay] {
        DailyStudyLog.build(from: session.progress.state.attempts).reversed()
    }

    var body: some View {
        ScrollView {
            let days = days
            let months = Dictionary(grouping: days) { monthStart($0.day) }
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                totalsCard(DailyStudyLog.totals(of: days))
                ForEach(months.keys.sorted(by: >), id: \.self) { month in
                    monthSection(month, days: months[month] ?? [])
                }
            }
            .padding(AppSpacing.screenMargin)
            .readableWidth()
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(session.strings.stats.dailyLogTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Totals

    private func totalsCard(_ totals: DailyStudyLog.Totals) -> some View {
        let strings = session.strings.stats
        return Card {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2),
                      spacing: AppSpacing.md) {
                totalCell(hoursMinutes(totals.studySeconds), strings.practiceTime)
                totalCell("\(totals.days)", strings.studyLogDays)
                totalCell("\(totals.questionsAnswered)", strings.questionsAnswered)
                totalCell("\(totals.completedMocks)", strings.studyLogMocks)
            }
        }
    }

    private func totalCell(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(AppFont.heading(20))
                .foregroundStyle(AppColor.textPrimary)
                .monospacedDigit()
            Text(label)
                .font(AppFont.caption(12))
                .foregroundStyle(AppColor.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Month

    private func monthSection(_ month: Date, days: [DailyStudyDay]) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            SectionLabel(text: month.formatted(.dateTime.month(.wide).year()
                .locale(session.pack.contentLocale)))
            Card {
                VStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        if index > 0 { Divider().padding(.vertical, AppSpacing.xs) }
                        dayRow(day)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func dayRow(_ day: DailyStudyDay) -> some View {
        let strings = session.strings.stats
        let expanded = expandedDays.contains(day.day)
        Button {
            withAnimation(AppMotion.smooth) {
                if expanded { expandedDays.remove(day.day) } else { expandedDays.insert(day.day) }
            }
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(day.day.formatted(.dateTime.day().month(.abbreviated)
                        .locale(session.pack.contentLocale)))
                        .font(AppFont.bodyMedium(15))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Text(hoursMinutes(day.studySeconds))
                        .font(AppFont.bodyMedium(15))
                        .foregroundStyle(AppColor.textPrimary)
                        .monospacedDigit()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColor.textDim)
                        .rotationEffect(.degrees(expanded ? 90 : 0))
                }
                HStack(spacing: AppSpacing.sm) {
                    Text(String(format: strings.dailyLogQuestionsFormat, day.questionsAnswered))
                    Text(String(format: strings.dailyLogMocksFormat, day.completedMocks))
                }
                .font(AppFont.caption(12))
                .foregroundStyle(AppColor.textDim)
                .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        if expanded {
            VStack(spacing: AppSpacing.xs) {
                ForEach(day.sessions) { sessionRow($0) }
            }
            .padding(.top, AppSpacing.xs)
            .padding(.leading, AppSpacing.md)
            .transition(.opacity)
        }
    }

    private func sessionRow(_ item: StudySession) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Text(item.startedAt.formatted(.dateTime.hour().minute()
                .locale(session.pack.contentLocale)))
                .foregroundStyle(AppColor.textDim)
            Text(modeName(item.mode))
                .foregroundStyle(AppColor.textSecondary)
                .lineLimit(1)
            Spacer(minLength: AppSpacing.xs)
            Text(hoursMinutes(item.durationSeconds))
                .foregroundStyle(AppColor.textDim)
            if let accuracy = item.accuracyPercent {
                Text(String(format: session.strings.study.accuracyFormat, accuracy))
                    .foregroundStyle(AppColor.textDim)
            }
        }
        .font(AppFont.caption(12))
        .monospacedDigit()
    }

    // MARK: - Formatting

    private func monthStart(_ day: Date) -> Date {
        let parts = Calendar.current.dateComponents([.year, .month], from: day)
        return Calendar.current.date(from: parts) ?? day
    }

    private func hoursMinutes(_ seconds: Int) -> String {
        let strings = session.strings.stats
        let minutes = seconds / 60
        guard minutes >= 60 else { return String(format: strings.dailyLogMinutesFormat, minutes) }
        return String(format: strings.dailyLogHoursFormat, minutes / 60, minutes % 60)
    }

    private func modeName(_ mode: QuizMode) -> String {
        let home = session.strings.home
        switch mode {
        case .daily: return home.dailyQuestionsTitle
        case .quick10: return home.modeQuick10Title
        case .timed: return home.modeTimedTitle
        case .missed: return home.modeMissedTitle
        case .collected: return home.modeCollectedTitle
        case .mock: return home.modeMockTitle
        case .custom: return home.modeCustomTitle
        case .review: return home.modeReviewTitle
        }
    }
}
