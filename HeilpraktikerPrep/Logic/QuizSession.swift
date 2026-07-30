import Foundation

/// Pure state machine for one quiz run. UI layers observe a copy of this via
/// their own @Observable wrapper; all transitions are explicit mutating funcs.
struct QuizSession: Equatable {
    let mode: QuizMode
    let feedback: FeedbackMode
    /// Questions in the form the UI sees — when a `shuffleSeed` was provided
    /// the choices (and `correctIndex`) have been re-ordered per session, so
    /// the same question appears in different positions on repeat exposure.
    let questions: [Question]
    /// Per-question map from displayed choice index back to the index in the
    /// original questions.json. nil = choices were not shuffled. Used at
    /// `submitAnswer` time so AnswerRecord keeps storing CANONICAL indices,
    /// which lets Review highlight the right "user picked" choice on the
    /// untouched Question loaded from the pack.
    private let displayedToOriginal: [[Int]]?

    private(set) var currentIndex: Int = 0
    private(set) var answers: [AnswerRecord] = []
    private(set) var isCurrentRevealed: Bool = false
    private(set) var isFinished: Bool = false

    init(mode: QuizMode, feedback: FeedbackMode, questions: [Question],
         shuffleSeed: UInt64? = nil) {
        self.mode = mode
        self.feedback = feedback
        if let seed = shuffleSeed {
            let (shuffled, maps) = Self.shuffleChoices(questions, seed: seed)
            self.questions = shuffled
            self.displayedToOriginal = maps
        } else {
            self.questions = questions
            self.displayedToOriginal = nil
        }
        self.isFinished = self.questions.isEmpty
    }

    var currentQuestion: Question? {
        guard !isFinished, questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    var hasAnsweredCurrent: Bool {
        guard let current = currentQuestion else { return false }
        return answers.contains { $0.questionId == current.id }
    }

    /// The user's selection for the current question, expressed as the index
    /// the UI is displaying (post-shuffle). `AnswerRecord.selectedIndex` is
    /// stored in CANONICAL form so Review/stats are stable across sessions;
    /// the choice list on screen is the shuffled order, so the UI must
    /// translate back when highlighting "you picked this".
    var displayedSelectedIndexForCurrent: Int? {
        guard let current = currentQuestion,
              let record = answers.first(where: { $0.questionId == current.id })
        else { return nil }
        guard let map = displayedToOriginal?[currentIndex] else { return record.selectedIndex }
        return map.firstIndex(of: record.selectedIndex)
    }

    var correctCount: Int { answers.filter(\.isCorrect).count }

    var scorePercent: Int { ScoringLogic.scorePercent(correct: correctCount, total: answers.count) }

    /// Records the answer for the current question. Returns whether it was
    /// correct. Repeated answers to the same question are ignored.
    @discardableResult
    mutating func submitAnswer(_ index: Int, date: Date) -> Bool {
        guard let question = currentQuestion, !hasAnsweredCurrent,
              question.choices.indices.contains(index) else { return false }
        let isCorrect = index == question.correctIndex
        // Translate the displayed pick back to its position in the original
        // pack-supplied question so downstream consumers (Review, stats) see
        // canonical indices regardless of any per-session shuffle.
        let recordedIndex = displayedToOriginal?[currentIndex][index] ?? index
        answers.append(AnswerRecord(
            id: UUID(),
            questionId: question.id,
            selectedIndex: recordedIndex,
            isCorrect: isCorrect,
            date: date,
            quizMode: mode
        ))
        if feedback == .learning {
            isCurrentRevealed = true
        }
        return isCorrect
    }

    /// Moves to the next question, or finishes after the last one.
    /// Outside mock mode the current question must be answered first.
    mutating func advance() {
        guard !isFinished else { return }
        if feedback != .mock && !hasAnsweredCurrent { return }
        isCurrentRevealed = false
        if currentIndex + 1 < questions.count {
            currentIndex += 1
        } else {
            isFinished = true
        }
    }

    // MARK: - Choice shuffling

    /// Returns a copy of each question whose `choices` (and `correctIndex`)
    /// have been deterministically shuffled, plus per-question maps from the
    /// new (displayed) order back to the original index.
    private static func shuffleChoices(_ questions: [Question], seed: UInt64)
        -> ([Question], [[Int]]) {
        var rng = SeededGenerator(seed: seed)
        var newQuestions: [Question] = []
        var maps: [[Int]] = []
        newQuestions.reserveCapacity(questions.count)
        maps.reserveCapacity(questions.count)
        for question in questions {
            // mapped[displayedIndex] = original index in question.choices.
            let mapped = Array(0..<question.choices.count).shuffled(using: &rng)
            let shuffledChoices = mapped.map { question.choices[$0] }
            let newCorrectIndex = mapped.firstIndex(of: question.correctIndex) ?? question.correctIndex
            newQuestions.append(Question(
                id: question.id,
                subjectId: question.subjectId,
                difficulty: question.difficulty,
                text: question.text,
                choices: shuffledChoices,
                correctIndex: newCorrectIndex,
                explanation: question.explanation,
                states: question.states,
                imageName: question.imageName,
                imageURL: question.imageURL,
                imageSource: question.imageSource))
            maps.append(mapped)
        }
        return (newQuestions, maps)
    }
}
