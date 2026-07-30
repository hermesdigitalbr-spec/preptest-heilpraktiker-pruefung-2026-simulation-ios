import Testing
import Foundation
@testable import HeilpraktikerPrep

struct StreakLogicTests {
    private let cal = Calendar(identifier: .gregorian)
    private let today = Date(timeIntervalSince1970: 1_770_000_000)

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: today)!
    }

    @Test func consecutiveDaysEndingTodayCount() {
        let dates = [day(0), day(-1), day(-2)]
        #expect(StreakLogic.currentStreak(activityDates: dates, today: today, calendar: cal) == 3)
    }

    @Test func yesterdayWithoutTodayStillCounts() {
        let dates = [day(-1), day(-2)]
        #expect(StreakLogic.currentStreak(activityDates: dates, today: today, calendar: cal) == 2)
    }

    @Test func gapBreaksStreak() {
        let dates = [day(0), day(-2), day(-3)]
        #expect(StreakLogic.currentStreak(activityDates: dates, today: today, calendar: cal) == 1)
    }

    @Test func multipleActivitiesSameDayCountOnce() {
        let dates = [day(0), day(0), day(-1)]
        #expect(StreakLogic.currentStreak(activityDates: dates, today: today, calendar: cal) == 2)
    }

    @Test func staleHistoryIsZero() {
        let dates = [day(-5), day(-6)]
        #expect(StreakLogic.currentStreak(activityDates: dates, today: today, calendar: cal) == 0)
    }

    @Test func emptyIsZero() {
        #expect(StreakLogic.currentStreak(activityDates: [], today: today, calendar: cal) == 0)
    }
}
