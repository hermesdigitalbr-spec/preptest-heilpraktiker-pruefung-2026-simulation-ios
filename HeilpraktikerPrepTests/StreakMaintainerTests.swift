import Testing
import Foundation
@testable import HeilpraktikerPrep

struct StreakMaintainerTests {
    private let cal = Calendar(identifier: .gregorian)
    private let today = Date(timeIntervalSince1970: 1_770_000_000)
    private func day(_ o: Int) -> Date { cal.date(byAdding: .day, value: o, to: today)! }

    @Test func bridgesASingleMissedDay() {
        // Active through day -2, missed yesterday → freeze yesterday.
        let d = StreakMaintainer.decide(
            activityDays: [day(-2), day(-3)], frozenDays: [], freezes: 1,
            today: today, calendar: cal)
        #expect(d?.dayToFreeze == cal.startOfDay(for: day(-1)))
        #expect(d?.freezesRemaining == 0)
    }

    @Test func noFreezeWhenYesterdayWasActive() {
        let d = StreakMaintainer.decide(
            activityDays: [day(-1), day(-2)], frozenDays: [], freezes: 1,
            today: today, calendar: cal)
        #expect(d == nil)
    }

    @Test func noFreezeForMultiDayGap() {
        // Missed both yesterday and the day before → already broken.
        let d = StreakMaintainer.decide(
            activityDays: [day(-3)], frozenDays: [], freezes: 1,
            today: today, calendar: cal)
        #expect(d == nil)
    }

    @Test func noFreezeWhenNoneLeft() {
        let d = StreakMaintainer.decide(
            activityDays: [day(-2)], frozenDays: [], freezes: 0,
            today: today, calendar: cal)
        #expect(d == nil)
    }

    @Test func idempotentWhenYesterdayAlreadyFrozen() {
        let d = StreakMaintainer.decide(
            activityDays: [day(-2)], frozenDays: [day(-1)], freezes: 1,
            today: today, calendar: cal)
        #expect(d == nil)
    }

    @Test func frozenDayKeepsStreakAlive() {
        // Practiced today and day-2, yesterday frozen → streak of 3.
        let streak = StreakLogic.currentStreak(
            activityDates: [today, day(-2)], frozenDays: [day(-1)],
            today: today, calendar: cal)
        #expect(streak == 3)
    }
}
