import Testing
import Foundation
@testable import HeilpraktikerPrep

struct StudyPaceTests {
    // MARK: pace bands

    @Test func sevenDaysOrLessIsSprint() {
        #expect(StudyPace.forDays(1) == .sprint)
        #expect(StudyPace.forDays(7) == .sprint)
    }

    @Test func upToThirtyDaysIsActive() {
        #expect(StudyPace.forDays(8) == .active)
        #expect(StudyPace.forDays(30) == .active)
    }

    @Test func beyondThirtyDaysIsSteady() {
        #expect(StudyPace.forDays(31) == .steady)
        #expect(StudyPace.forDays(200) == .steady)
    }

    // MARK: recommended minutes (1 question ≈ 1 minute, adherence 80%)

    @Test func recommendsSmallestOptionThatCoversTheBank() {
        // 150 questions / (30 days × 0.8) = 6.25 → 15 min
        #expect(PlanGenerator.recommendedMinutes(totalQuestions: 150, daysUntilExam: 30) == 15)
        // 600 / 24 = 25 → 30 min
        #expect(PlanGenerator.recommendedMinutes(totalQuestions: 600, daysUntilExam: 30) == 30)
    }

    @Test func recommendationCapsAtLargestOption() {
        #expect(PlanGenerator.recommendedMinutes(totalQuestions: 5000, daysUntilExam: 3) == 90)
    }

    @Test func noDateRecommendsNothing() {
        #expect(PlanGenerator.recommendedMinutes(totalQuestions: 500, daysUntilExam: nil) == nil)
    }

    // MARK: readiness forecast

    @Test func forecastStartsAtLevelAndEndsNearFull() {
        let pts = ReadinessForecast.points(startingAt: .newbie, count: 10)
        #expect(pts.count == 10)
        #expect(pts.first == ReadinessForecast.baseline(for: .newbie))
        #expect(pts.last! >= 0.9 && pts.last! <= 1.0)
        // monotonic
        #expect(zip(pts, pts.dropFirst()).allSatisfy { $0 <= $1 })
    }

    @Test func expertStartsHigherThanNewbie() {
        #expect(ReadinessForecast.baseline(for: .expert) > ReadinessForecast.baseline(for: .newbie))
        #expect(ReadinessForecast.baseline(for: nil) == ReadinessForecast.baseline(for: .newbie))
    }
}
