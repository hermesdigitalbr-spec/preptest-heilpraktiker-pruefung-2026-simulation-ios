import Testing
import Foundation
@testable import HeilpraktikerPrep

struct PassProbabilityEngineTests {
    private let t0 = Date(timeIntervalSince1970: 1_770_000_000)
    private func answers(count: Int, correct: Int) -> [AnswerRecord] {
        (0..<count).map { i in
            AnswerRecord(id: UUID(), questionId: "q\(i)", selectedIndex: 0,
                         isCorrect: i < correct,
                         date: t0.addingTimeInterval(TimeInterval(i)),
                         quizMode: .daily)
        }
    }

    @Test func zeroAnswersGivesNil() {
        // No history → not enough signal to show a number.
        #expect(PassProbabilityEngine.evaluate(answers: [], passThresholdPercent: 80) == nil)
    }

    @Test func atThresholdConvergesTo50Percent() throws {
        // 80% accuracy across enough answers to clear the damping window.
        let a = answers(count: 60, correct: 48)   // exactly 80%
        let p = try #require(PassProbabilityEngine.evaluate(answers: a, passThresholdPercent: 80))
        #expect(abs(p - 50) <= 2)
    }

    @Test func wellAboveThresholdReadsHigh() throws {
        let a = answers(count: 60, correct: 57)   // 95%
        let p = try #require(PassProbabilityEngine.evaluate(answers: a, passThresholdPercent: 80))
        #expect(p >= 80)
    }

    @Test func wellBelowThresholdReadsLow() throws {
        let a = answers(count: 60, correct: 42)   // 70%
        let p = try #require(PassProbabilityEngine.evaluate(answers: a, passThresholdPercent: 80))
        #expect(p <= 30)
    }

    @Test func thinSampleReturnsNil() {
        // 3/3 correct = 100% raw accuracy, but a 3-answer sample is below the
        // minimum signal threshold, so the engine declines to show a number.
        let a = answers(count: 3, correct: 3)
        #expect(PassProbabilityEngine.evaluate(answers: a, passThresholdPercent: 80) == nil)
    }

    @Test func usesRecentWindowNotAllHistory() throws {
        // 60 old wrong + 60 recent right → should look excellent, not balanced.
        var old = answers(count: 60, correct: 0)
        let recent = answers(count: 60, correct: 60).map { record in
            AnswerRecord(id: record.id, questionId: record.questionId,
                         selectedIndex: record.selectedIndex, isCorrect: record.isCorrect,
                         date: record.date.addingTimeInterval(1_000_000),
                         quizMode: record.quizMode)
        }
        old += recent
        let p = try #require(PassProbabilityEngine.evaluate(answers: old, passThresholdPercent: 80))
        // Sigmoid plateaus around 88 even at 100% recent accuracy — what
        // matters is that old wrongs aren't dragging this far below it.
        #expect(p >= 80)
    }
}
