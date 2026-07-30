import Testing
import Foundation
@testable import HeilpraktikerPrep

struct NotificationServiceTests {
    private let cal = Calendar(identifier: .gregorian)
    private let now = Date(timeIntervalSince1970: 1_770_000_000)

    private func ids(examInDays: Int) -> [String] {
        let exam = cal.date(byAdding: .day, value: examInDays, to: now)!
        return NotificationService.examCountdownFireDays(examDate: exam, now: now, calendar: cal).map(\.id)
    }

    @Test func allFiveScheduleWhenExamIs30DaysOut() {
        #expect(ids(examInDays: 30) == ["exam.30d", "exam.14d", "exam.7d", "exam.3d", "exam.day"])
    }

    @Test func pastOffsetsAreSkipped() {
        // 10 days out → the 30- and 14-day reminders are already in the past.
        #expect(ids(examInDays: 10) == ["exam.7d", "exam.3d", "exam.day"])
    }

    @Test func sameDayExamStillSchedulesExamDay() {
        // Regression guard for the `fireDay >= today` fix: an exam set to today
        // must still schedule the day-of reminder (previously dropped by `>`).
        let fire = NotificationService.examCountdownFireDays(examDate: now, now: now, calendar: cal)
        #expect(fire.map(\.id) == ["exam.day"])
        #expect(cal.isDate(fire[0].fireDay, inSameDayAs: now))
    }

    @Test func pastExamSchedulesNothing() {
        #expect(ids(examInDays: -1).isEmpty)
    }
}
