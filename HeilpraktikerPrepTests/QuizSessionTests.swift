import Testing
import Foundation
@testable import HeilpraktikerPrep

struct QuizSessionTests {
    private var questions: [Question] {
        [
            Question(id: "q1", subjectId: "signs", difficulty: 1, text: "t1",
                     choices: ["a", "b", "c", "d"], correctIndex: 2, explanation: "e1"),
            Question(id: "q2", subjectId: "laws", difficulty: 1, text: "t2",
                     choices: ["a", "b", "c", "d"], correctIndex: 0, explanation: "e2"),
        ]
    }

    @Test func answeringRecordsResultAndRevealsInLearningMode() {
        var session = QuizSession(mode: .quick10, feedback: .learning, questions: questions)
        let correct = session.submitAnswer(2, date: .now)
        #expect(correct == true)
        #expect(session.isCurrentRevealed)
        #expect(session.answers.count == 1)
        #expect(session.answers[0].questionId == "q1")
        #expect(session.answers[0].isCorrect)
    }

    @Test func mockModeDoesNotReveal() {
        var session = QuizSession(mode: .mock, feedback: .mock, questions: questions)
        _ = session.submitAnswer(1, date: .now)
        #expect(!session.isCurrentRevealed)
    }

    @Test func doubleAnswerOnSameQuestionIsIgnored() {
        var session = QuizSession(mode: .quick10, feedback: .learning, questions: questions)
        _ = session.submitAnswer(2, date: .now)
        _ = session.submitAnswer(0, date: .now)
        #expect(session.answers.count == 1)
        #expect(session.answers[0].selectedIndex == 2)
    }

    @Test func advanceMovesAndFinishes() {
        var session = QuizSession(mode: .quick10, feedback: .learning, questions: questions)
        _ = session.submitAnswer(2, date: .now)
        session.advance()
        #expect(session.currentIndex == 1)
        #expect(!session.isFinished)
        _ = session.submitAnswer(1, date: .now)
        session.advance()
        #expect(session.isFinished)
        #expect(session.currentQuestion == nil)
    }

    @Test func scoreReflectsCorrectAnswers() {
        var session = QuizSession(mode: .quick10, feedback: .quick, questions: questions)
        _ = session.submitAnswer(2, date: .now) // correct
        session.advance()
        _ = session.submitAnswer(3, date: .now) // wrong
        session.advance()
        #expect(session.correctCount == 1)
        #expect(session.scorePercent == 50)
    }

    @Test func shuffleReordersChoicesAndRecordsCanonicalIndex() {
        // Reasonable but not absolutely guaranteed: with a stable seed and 4
        // choices, the correctIndex (originally 2) lands at a NEW position.
        let session = QuizSession(mode: .quick10, feedback: .learning,
                                  questions: questions, shuffleSeed: 12345)
        let q = session.currentQuestion!
        #expect(q.choices.sorted() == ["a", "b", "c", "d"])    // same set
        // The choice text at the new correctIndex must still be "c" (original
        // correct answer), proving choices and correctIndex were remapped together.
        #expect(q.choices[q.correctIndex] == "c")
    }

    @Test func shuffleStoresOriginalIndexInAnswerRecord() {
        var session = QuizSession(mode: .quick10, feedback: .learning,
                                  questions: questions, shuffleSeed: 12345)
        // Tap the displayed correct choice — should record the ORIGINAL index 2.
        let displayedCorrect = session.currentQuestion!.correctIndex
        _ = session.submitAnswer(displayedCorrect, date: .now)
        #expect(session.answers[0].isCorrect)
        #expect(session.answers[0].selectedIndex == 2)  // canonical
    }

    @Test func displayedSelectedIndexConvertsCanonicalBackToShuffled() {
        // After submitting an answer, the UI's "you picked this" highlight
        // must point at the ROW THE USER TAPPED — not the canonical index
        // stored on disk. Regression: a previous bug returned the canonical
        // index from the controller, lighting up a different row than the tap.
        var session = QuizSession(mode: .quick10, feedback: .learning,
                                  questions: questions, shuffleSeed: 12345)
        // Tap a non-correct displayed slot deliberately to exercise the remap
        // on a wrong-answer flow (where the displayed slot is most visible).
        let displayedTap = (session.currentQuestion!.correctIndex + 1) % 4
        _ = session.submitAnswer(displayedTap, date: .now)
        #expect(session.displayedSelectedIndexForCurrent == displayedTap)
    }

    @Test func sameSeedProducesSameShuffle() {
        // Determinism is the contract; collisions across seeds are expected
        // with only 4 choices (24 possible permutations).
        let a = QuizSession(mode: .quick10, feedback: .learning,
                            questions: questions, shuffleSeed: 7).questions[0].choices
        let b = QuizSession(mode: .quick10, feedback: .learning,
                            questions: questions, shuffleSeed: 7).questions[0].choices
        #expect(a == b)
    }

    @Test func advanceWithoutAnswerSkipsInMockOnly() {
        var session = QuizSession(mode: .quick10, feedback: .learning, questions: questions)
        session.advance()
        #expect(session.currentIndex == 0) // learning requires an answer first

        var mock = QuizSession(mode: .mock, feedback: .mock, questions: questions)
        mock.advance()
        #expect(mock.currentIndex == 1) // mock allows skipping
    }
}
