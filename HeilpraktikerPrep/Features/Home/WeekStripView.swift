import SwiftUI

/// Current week with activity markers and the streak flame.
struct WeekStripView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bounceTrigger = 0

    private static let streakMilestones: Set<Int> = [7, 14, 30, 100, 365]

    var body: some View {
        Card {
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.date) { day in
                    VStack(spacing: AppSpacing.xs) {
                        Text(day.initial)
                            .font(AppFont.caption(12))
                            .foregroundStyle(day.isToday ? AppColor.accent : AppColor.textDim)
                        dayCircle(for: day)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            // Celebrate a streak milestone with a single flame bounce.
            guard !reduceMotion, Self.streakMilestones.contains(session.currentStreak) else { return }
            bounceTrigger += 1
        }
    }

    private struct DayCell {
        let date: Date
        let initial: String
        let dayNumber: Int
        let isToday: Bool
        let isActive: Bool
        let isPast: Bool
    }

    /// Reading order of the week at a glance:
    /// past = outlined (history), gray flame when practiced; today = highlighted
    /// (orange flame when practiced); future = faded (not here yet).
    @ViewBuilder
    private func dayCircle(for day: DayCell) -> some View {
        ZStack {
            if day.isToday {
                if day.isActive {
                    Circle().fill(AppColor.warning)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .symbolEffect(.bounce, value: bounceTrigger)
                } else {
                    Circle().fill(AppColor.accentSoft)
                    Text("\(day.dayNumber)")
                        .font(AppFont.bodyMedium(13))
                        .foregroundStyle(AppColor.accent)
                }
            } else if day.isPast {
                if day.isActive {
                    Circle().fill(AppColor.surfaceHigh)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(AppColor.textDim)
                } else {
                    Circle().stroke(AppColor.border, lineWidth: 1.5)
                    Text("\(day.dayNumber)")
                        .font(AppFont.body(13))
                        .foregroundStyle(AppColor.textSecondary)
                }
            } else {
                Text("\(day.dayNumber)")
                    .font(AppFont.body(13))
                    .foregroundStyle(AppColor.textDim.opacity(0.45))
            }
        }
        .frame(width: hSize == .regular ? 40 : 32, height: hSize == .regular ? 40 : 32)
        .overlay(
            Circle().stroke(day.isToday ? AppColor.accent : .clear, lineWidth: 2)
        )
    }

    private var weekDays: [DayCell] {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: session.pack.language)
        let today = calendar.startOfDay(for: .now)
        guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start else { return [] }
        let activeDays = Set(session.progress.completionDates.map { calendar.startOfDay(for: $0) })
        let symbols = calendar.veryShortWeekdaySymbols

        return (0..<7).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: weekStart) else { return nil }
            let weekdayIndex = calendar.component(.weekday, from: date) - 1
            return DayCell(
                date: date,
                initial: symbols[weekdayIndex],
                dayNumber: calendar.component(.day, from: date),
                isToday: date == today,
                isActive: activeDays.contains(date),
                isPast: date < today)
        }
    }
}
