import Foundation

/// A badge definition, supplied by the ContentPack so each niche ships its
/// own set without Swift changes. The `criterion` says how to evaluate it
/// against the user's history.
struct AchievementDef: Codable, Equatable, Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String      // SF Symbol
    let tint: String      // hex
    let criterion: Criterion

    struct Criterion: Codable, Equatable {
        /// One of: totalAnswered, totalCorrect, overallAccuracy, totalQuizzes,
        /// perfectQuizzes, perfectStreak, streak, daysPracticed, dayAnswers,
        /// subjectMastery, subjectsMastered, allSubjects, allSubjectsMastered,
        /// mockPassed, mockScore, collected, earlyBird, nightOwl,
        /// weekendWarrior, comeback, speedster, modesExplored, minutesPracticed.
        let type: String
        /// Threshold for the metric (e.g. 500 answered, 7-day streak, 90%).
        /// Omitted for criteria that derive their target from the pack
        /// (allSubjects/allSubjectsMastered → subject count) or are boolean /
        /// single-shot (mockPassed, earlyBird, nightOwl, comeback, speedster → 1).
        let value: Int?
    }
}

/// Evaluated state of one achievement for the current user.
struct AchievementStatus: Identifiable, Equatable {
    let def: AchievementDef
    let current: Int
    let target: Int

    var id: String { def.id }
    var unlocked: Bool { current >= target && target > 0 }
    /// 0...1 progress toward unlocking (1 once unlocked).
    var fraction: Double {
        guard target > 0 else { return unlocked ? 1 : 0 }
        return min(1, Double(current) / Double(target))
    }
}
