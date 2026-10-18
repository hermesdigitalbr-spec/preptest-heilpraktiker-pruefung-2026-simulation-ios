import Foundation

/// Everything the onboarding learns about the user. Persisted in UserDefaults.
struct UserProfile: Codable, Equatable {
    enum Level: String, Codable, CaseIterable {
        case newbie, skilled, master, expert
    }

    enum Goal: String, Codable, CaseIterable {
        case passExam, knowledge, skills, overcomeBarriers
    }

    /// First name typed in onboarding — greets the user on the plan card and Home.
    var name: String?
    var level: Level?
    var goal: Goal?
    /// Id of the motivation picked in onboarding (`NicheConfig.motivations`).
    /// A plain string, so values saved by the old enum still decode as-is.
    var motivation: String?
    var examDate: Date?
    /// When the exam date was (last) chosen — anchors countdown progress rings.
    var examDateSetAt: Date?
    var dailyMinutes: Int?
    /// Weekday numbers (1 = Sunday … 7 = Saturday, Calendar convention).
    var studyDays: Set<Int> = []
    /// Preferred study hour, 0–23.
    var preferredHour: Int?
    var streakGoal: Int?
    /// Daily question count from the onboarding study plan.
    var planQuestionsPerDay: Int?
    /// Region (US state) the user will take the exam in — when the pack has regions.
    var stateId: String?
    var weakSubjectIds: Set<String> = []
    /// When the funnel was finished — anchors anything that should wait a
    /// couple of days before asking for something again.
    var onboardingCompletedAt: Date?
    var hasCompletedOnboarding: Bool = false
}
