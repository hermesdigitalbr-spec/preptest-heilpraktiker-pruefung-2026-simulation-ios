import Foundation

enum PlanGenerator {
    private static let minPerDay = 5
    private static let maxPerDay = 40
    /// Assume the user actually practices on ~80% of remaining days.
    private static let adherence = 0.8

    static func makePlan(profile: UserProfile,
                         totalQuestions: Int,
                         defaultDailyCount: Int,
                         today: Date,
                         calendar: Calendar) -> StudyPlan {
        // Hard cap: what the user said they have time for (~1 question/minute).
        // If they skipped the step, fall back to the pack default.
        let timeCap = profile.dailyMinutes.map { min($0, maxPerDay) } ?? defaultDailyCount

        guard let examDate = profile.examDate else {
            return StudyPlan(questionsPerDay: timeCap, daysUntilExam: nil)
        }
        let start = calendar.startOfDay(for: today)
        let end = calendar.startOfDay(for: examDate)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0
        guard days > 0 else {
            return StudyPlan(questionsPerDay: timeCap, daysUntilExam: nil)
        }

        // Minimum needed to cover all questions before the exam.
        let effectiveDays = max(1.0, Double(days) * adherence)
        let urgency = Int((Double(totalQuestions) / effectiveDays).rounded(.up))

        // Respect the user's time: never exceed their cap, never go below minimum.
        let perDay = max(minPerDay, min(urgency, timeCap))
        return StudyPlan(questionsPerDay: perDay, daysUntilExam: days)
    }
}
