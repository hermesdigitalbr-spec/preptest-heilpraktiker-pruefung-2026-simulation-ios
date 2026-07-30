import Foundation

/// Spaced repetition (Leitner system). Each question's box and due date are
/// DERIVED from its answer history — nothing extra is persisted, so the
/// schedule is always consistent with what actually happened. A wrong answer
/// drops a card to box 0 (review now); each correct answer promotes it to a
/// longer interval until it's effectively mastered.
enum SRSScheduler {
    /// Days until the next review, indexed by box. Box 0 is due immediately.
    static let intervals: [Int] = [0, 1, 3, 7, 16, 35]
    static var maxBox: Int { intervals.count - 1 }

    struct Card: Equatable {
        let questionId: String
        let box: Int
        let due: Date
        let lastSeen: Date
        var isMastered: Bool { box >= SRSScheduler.maxBox }
    }

    /// Replays one question's answers (any order) into its current card.
    /// Returns nil if the question was never answered.
    static func card(questionId: String,
                     answers: [AnswerRecord],
                     calendar: Calendar = .current) -> Card? {
        let history = answers
            .filter { $0.questionId == questionId }
            .sorted { $0.date < $1.date }
        guard let last = history.last else { return nil }

        var box = 0
        for answer in history {
            box = answer.isCorrect ? min(box + 1, maxBox) : 0
        }
        let due = calendar.date(byAdding: .day, value: intervals[box],
                                to: calendar.startOfDay(for: last.date)) ?? last.date
        return Card(questionId: questionId, box: box, due: due, lastSeen: last.date)
    }

    /// All cards due for review at `now`, most urgent first (lowest box, then
    /// oldest due). Mastered cards naturally fall out until their long
    /// interval elapses.
    static func dueCards(history: [AnswerRecord],
                         now: Date = .now,
                         calendar: Calendar = .current) -> [Card] {
        let ids = Set(history.map(\.questionId))
        let today = calendar.startOfDay(for: now)
        return ids.compactMap { card(questionId: $0, answers: history, calendar: calendar) }
            .filter { $0.due <= today }
            .sorted { ($0.box, $0.due) < ($1.box, $1.due) }
    }
}
