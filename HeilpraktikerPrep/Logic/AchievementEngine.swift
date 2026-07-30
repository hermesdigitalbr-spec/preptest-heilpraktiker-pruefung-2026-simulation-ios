import Foundation

/// Pure evaluation of achievements from quiz history. No StoreKit, no UI,
/// no persistence — every value is derived from the attempts the user has
/// completed, so unlock status is naturally permanent (the underlying
/// metrics only ever grow).
enum AchievementEngine {
    /// A perfect quiz needs at least this many questions, so a 1-question
    /// fluke doesn't count.
    static let perfectMinQuestions = 5
    /// A subject must have this many answers before its accuracy can earn a
    /// mastery badge.
    static let masteryMinSample = 20
    /// Accuracy (percent) at which a subject counts as "mastered".
    static let masteryThresholdPercent = 90
    /// Hour boundaries for the time-of-day badges.
    static let earlyBirdHour = 7    // started before 07:00
    static let nightOwlHour = 22    // started at/after 22:00
    /// A "speedster" quiz: at least this many questions, averaging under this
    /// many seconds each.
    static let speedMinQuestions = 10
    static let speedMaxSecondsPerQuestion = 8
    /// A "comeback" is resuming after a gap of at least this many days.
    static let comebackGapDays = 7
    /// Overall accuracy needs at least this many answers before it can earn a
    /// badge, so a couple of lucky answers don't unlock it.
    static let accuracyMinSample = 50

    /// Aggregate metrics computed once, then reused across all criteria.
    struct Snapshot: Equatable {
        var totalAnswered = 0
        var totalCorrect = 0
        var overallAccuracy = 0       // percent, once past accuracyMinSample
        var quizzesCompleted = 0
        var perfectQuizzes = 0
        var longestPerfectStreak = 0  // consecutive flawless quizzes (≥ min size)
        var longestStreak = 0
        var bestSubjectAccuracy = 0   // percent, only subjects with enough sample
        var subjectsPracticed = 0
        var subjectsMastered = 0      // subjects at/above the mastery threshold
        var mockPassed = false
        var bestMockPercent = 0
        var bookmarkedCount = 0
        var daysPracticed = 0         // distinct calendar days with practice
        var bestDayAnswers = 0        // most questions answered in a single day
        var earlyBirdSessions = 0
        var nightOwlSessions = 0
        var weekendSessions = 0
        var comebacks = 0
        var fastQuizzes = 0
        var modesPracticed = 0
        var minutesPracticed = 0
    }

    /// - Parameters:
    ///   - subjectOf: maps a questionId to its subjectId (answers only carry
    ///     the questionId, so the caller supplies the lookup).
    ///   - mockPassPercent: the pack's mock pass threshold.
    static func snapshot(attempts: [QuizAttempt],
                         subjectOf: [String: String],
                         mockPassPercent: Int,
                         bookmarkedCount: Int = 0,
                         calendar: Calendar = .current) -> Snapshot {
        var snap = Snapshot()
        snap.bookmarkedCount = bookmarkedCount

        // A session counts as practice the moment the user answers a question —
        // even if they quit before finishing. This drives the quiz-count and
        // streak achievements, so abandoning a quiz still earns credit.
        let practiced = attempts.filter { !$0.answers.isEmpty }
        snap.quizzesCompleted = practiced.count

        let answers = attempts.flatMap(\.answers)
        snap.totalAnswered = answers.count
        snap.totalCorrect = answers.filter(\.isCorrect).count
        if snap.totalAnswered >= accuracyMinSample {
            snap.overallAccuracy =
                Int((Double(snap.totalCorrect) / Double(snap.totalAnswered) * 100).rounded())
        }
        snap.modesPracticed = Set(practiced.map(\.mode)).count
        snap.minutesPracticed = practiced.reduce(0) { $0 + max(0, $1.durationSeconds) } / 60

        // "Perfect", "mock passed" and "speedster" require genuinely finishing
        // the quiz, so they key off completedAt — you can't earn them by quitting.
        let completed = attempts.filter { $0.completedAt != nil }
        snap.perfectQuizzes = completed.filter {
            $0.answers.count >= perfectMinQuestions && $0.answers.allSatisfy(\.isCorrect)
        }.count
        snap.fastQuizzes = completed.filter {
            $0.answers.count >= speedMinQuestions && $0.durationSeconds > 0 &&
                $0.durationSeconds < $0.answers.count * speedMaxSecondsPerQuestion
        }.count

        // Longest run of consecutive flawless quizzes, in completion order.
        // Quizzes below the perfect-size minimum are ignored (neither extend
        // nor break the run) so a tiny daily doesn't reset it.
        let completedInOrder = completed.sorted {
            ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
        }
        var perfectRun = 0
        for attempt in completedInOrder where attempt.answers.count >= perfectMinQuestions {
            if attempt.answers.allSatisfy(\.isCorrect) {
                perfectRun += 1
                snap.longestPerfectStreak = max(snap.longestPerfectStreak, perfectRun)
            } else {
                perfectRun = 0
            }
        }

        // Practice days drive streak + consistency badges, derived once.
        let practiceDates = practiced.map { $0.completedAt ?? $0.startedAt }
        snap.longestStreak = longestStreak(dates: practiceDates, calendar: calendar)
        let practiceDays = Set(practiceDates.map { calendar.startOfDay(for: $0) }).sorted()
        snap.daysPracticed = practiceDays.count
        if practiceDays.count > 1 {
            for i in 1..<practiceDays.count {
                let gap = calendar.dateComponents([.day], from: practiceDays[i - 1],
                                                  to: practiceDays[i]).day ?? 0
                if gap >= comebackGapDays { snap.comebacks += 1 }
            }
        }

        // Most questions answered in a single calendar day.
        var perDay: [Date: Int] = [:]
        for answer in answers { perDay[calendar.startOfDay(for: answer.date), default: 0] += 1 }
        snap.bestDayAnswers = perDay.values.max() ?? 0

        // Time-of-day / weekend badges, keyed off when each session started.
        for attempt in practiced {
            let hour = calendar.component(.hour, from: attempt.startedAt)
            if hour < earlyBirdHour { snap.earlyBirdSessions += 1 }
            if hour >= nightOwlHour { snap.nightOwlSessions += 1 }
            if calendar.isDateInWeekend(attempt.startedAt) { snap.weekendSessions += 1 }
        }

        // Per-subject totals across every answer.
        var total: [String: Int] = [:]
        var correct: [String: Int] = [:]
        for answer in answers {
            guard let subject = subjectOf[answer.questionId] else { continue }
            total[subject, default: 0] += 1
            if answer.isCorrect { correct[subject, default: 0] += 1 }
        }
        snap.subjectsPracticed = total.keys.count
        let subjectAccuracies = total.compactMap { subject, count -> Int? in
            guard count >= masteryMinSample else { return nil }
            return Int((Double(correct[subject] ?? 0) / Double(count) * 100).rounded())
        }
        snap.bestSubjectAccuracy = subjectAccuracies.max() ?? 0
        snap.subjectsMastered = subjectAccuracies.filter { $0 >= masteryThresholdPercent }.count

        // Mock metrics: pass flag + best percentage across completed mocks.
        let mockPercents = completed.compactMap { attempt -> Int? in
            guard attempt.mode == .mock, !attempt.answers.isEmpty else { return nil }
            return Int((Double(attempt.answers.filter(\.isCorrect).count)
                        / Double(attempt.answers.count) * 100).rounded())
        }
        snap.bestMockPercent = mockPercents.max() ?? 0
        snap.mockPassed = mockPercents.contains { $0 >= mockPassPercent }

        return snap
    }

    static func longestStreak(dates: [Date], calendar: Calendar = .current) -> Int {
        let days = Set(dates.map { calendar.startOfDay(for: $0) }).sorted()
        guard !days.isEmpty else { return 0 }
        var longest = 1
        var run = 1
        for i in 1..<days.count {
            if let next = calendar.date(byAdding: .day, value: 1, to: days[i - 1]),
               calendar.isDate(next, inSameDayAs: days[i]) {
                run += 1
            } else {
                run = 1
            }
            longest = max(longest, run)
        }
        return longest
    }

    /// Evaluate one criterion into a status, given the snapshot and pack info.
    static func status(for def: AchievementDef,
                       snapshot snap: Snapshot,
                       subjectCount: Int) -> AchievementStatus {
        let c = def.criterion
        let (current, target): (Int, Int)
        switch c.type {
        case "totalAnswered":      (current, target) = (snap.totalAnswered, c.value ?? 0)
        case "totalCorrect":       (current, target) = (snap.totalCorrect, c.value ?? 0)
        case "overallAccuracy":    (current, target) = (snap.overallAccuracy, c.value ?? 0)
        case "totalQuizzes":       (current, target) = (snap.quizzesCompleted, c.value ?? 0)
        case "perfectQuizzes":     (current, target) = (snap.perfectQuizzes, c.value ?? 0)
        case "perfectStreak":      (current, target) = (snap.longestPerfectStreak, c.value ?? 0)
        case "streak":             (current, target) = (snap.longestStreak, c.value ?? 0)
        case "daysPracticed":      (current, target) = (snap.daysPracticed, c.value ?? 0)
        case "dayAnswers":         (current, target) = (snap.bestDayAnswers, c.value ?? 0)
        case "subjectMastery":     (current, target) = (snap.bestSubjectAccuracy, c.value ?? 0)
        case "subjectsMastered":   (current, target) = (snap.subjectsMastered, c.value ?? 0)
        case "allSubjects":        (current, target) = (snap.subjectsPracticed, max(subjectCount, 1))
        case "allSubjectsMastered":(current, target) = (snap.subjectsMastered, max(subjectCount, 1))
        case "mockPassed":         (current, target) = (snap.mockPassed ? 1 : 0, 1)
        case "mockScore":          (current, target) = (snap.bestMockPercent, c.value ?? 0)
        case "collected":          (current, target) = (snap.bookmarkedCount, c.value ?? 0)
        case "earlyBird":          (current, target) = (snap.earlyBirdSessions, c.value ?? 1)
        case "nightOwl":           (current, target) = (snap.nightOwlSessions, c.value ?? 1)
        case "weekendWarrior":     (current, target) = (snap.weekendSessions, c.value ?? 1)
        case "comeback":           (current, target) = (snap.comebacks, c.value ?? 1)
        case "speedster":          (current, target) = (snap.fastQuizzes, c.value ?? 1)
        case "modesExplored":      (current, target) = (snap.modesPracticed, c.value ?? 0)
        case "minutesPracticed":   (current, target) = (snap.minutesPracticed, c.value ?? 0)
        default:                   (current, target) = (0, c.value ?? 0)
        }
        return AchievementStatus(def: def, current: min(current, target), target: target)
    }
}
