import Testing
import Foundation
@testable import HeilpraktikerPrep

struct ScoringLogicTests {
    @Test func percentRoundsCorrectly() {
        #expect(ScoringLogic.scorePercent(correct: 2, total: 3) == 67)
        #expect(ScoringLogic.scorePercent(correct: 1, total: 3) == 33)
        #expect(ScoringLogic.scorePercent(correct: 3, total: 3) == 100)
        #expect(ScoringLogic.scorePercent(correct: 0, total: 0) == 0)
    }

    @Test func breakdownGroupsBySubject() {
        let q1 = Question(id: "a", subjectId: "signs", difficulty: 1, text: "t",
                          choices: ["x", "y"], correctIndex: 0, explanation: "e")
        let q2 = Question(id: "b", subjectId: "laws", difficulty: 1, text: "t",
                          choices: ["x", "y"], correctIndex: 0, explanation: "e")
        let answers = [
            AnswerRecord(id: UUID(), questionId: "a", selectedIndex: 0, isCorrect: true, date: .now, quizMode: .quick10),
            AnswerRecord(id: UUID(), questionId: "b", selectedIndex: 1, isCorrect: false, date: .now, quizMode: .quick10),
        ]
        let result = ScoringLogic.breakdown(answers: answers, questions: [q1, q2])
        #expect(result.count == 2)
        #expect(result.first { $0.subjectId == "signs" }?.accuracy == 1.0)
        #expect(result.first { $0.subjectId == "laws" }?.accuracy == 0.0)
    }

    @Test func breakdownIgnoresAnswersToUnknownQuestions() {
        let answers = [
            AnswerRecord(id: UUID(), questionId: "ghost", selectedIndex: 0, isCorrect: true, date: .now, quizMode: .daily)
        ]
        #expect(ScoringLogic.breakdown(answers: answers, questions: []).isEmpty)
    }
}
