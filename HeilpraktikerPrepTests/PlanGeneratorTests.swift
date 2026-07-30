import Testing
import Foundation
@testable import HeilpraktikerPrep

struct PlanGeneratorTests {
    private let cal = Calendar(identifier: .gregorian)
    private let today = Date(timeIntervalSince1970: 1_770_000_000)

    @Test func planScalesToExamDate() {
        var profile = UserProfile()
        profile.examDate = cal.date(byAdding: .day, value: 30, to: today)
        let plan = PlanGenerator.makePlan(
            profile: profile, totalQuestions: 150, defaultDailyCount: 10,
            today: today, calendar: cal)
        #expect(plan.daysUntilExam == 30)
        // 150 questions over 30 days at 80% available days → ceil(150/24) = 7, min clamp 5
        #expect(plan.questionsPerDay == 7)
    }

    @Test func planWithoutExamDateUsesDefault() {
        let plan = PlanGenerator.makePlan(
            profile: UserProfile(), totalQuestions: 150, defaultDailyCount: 10,
            today: today, calendar: cal)
        #expect(plan.daysUntilExam == nil)
        #expect(plan.questionsPerDay == 10)
    }

    @Test func planClampsForVeryNearExam() {
        var profile = UserProfile()
        profile.examDate = cal.date(byAdding: .day, value: 2, to: today)
        let plan = PlanGenerator.makePlan(
            profile: profile, totalQuestions: 500, defaultDailyCount: 10,
            today: today, calendar: cal)
        #expect(plan.questionsPerDay <= 40)
    }

    @Test func pastExamDateBehavesLikeNoDate() {
        var profile = UserProfile()
        profile.examDate = cal.date(byAdding: .day, value: -3, to: today)
        let plan = PlanGenerator.makePlan(
            profile: profile, totalQuestions: 150, defaultDailyCount: 10,
            today: today, calendar: cal)
        #expect(plan.daysUntilExam == nil)
        #expect(plan.questionsPerDay == 10)
    }
}
