import Foundation

/// Which quiz modes are free vs gated. The reviewer-friendly free path:
/// daily questions are always free; quick quizzes are free a limited number
/// of times (pack-configurable), everything else is PRO.
enum ProAccess {
    static func isLocked(mode: QuizMode,
                         isPro: Bool,
                         quickQuizzesUsed: Int = 0,
                         freeQuickQuizzes: Int = .max,
                         dailyQuizzesUsed: Int = 0,
                         freeDailyQuizzes: Int = .max) -> Bool {
        guard !isPro else { return false }
        switch mode {
        case .daily:
            return dailyQuizzesUsed >= freeDailyQuizzes
        case .quick10:
            return quickQuizzesUsed >= freeQuickQuizzes
        case .timed, .missed, .collected, .mock, .custom, .review:
            return true
        }
    }

    static func remainingFreeQuickQuizzes(used: Int, allowance: Int) -> Int {
        max(0, allowance - used)
    }

    static func remainingFreeDailyQuizzes(used: Int, allowance: Int) -> Int {
        max(0, allowance - used)
    }
}
