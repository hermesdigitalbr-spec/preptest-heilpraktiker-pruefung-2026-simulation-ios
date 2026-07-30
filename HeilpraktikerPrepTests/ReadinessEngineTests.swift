import Testing
import Foundation
@testable import HeilpraktikerPrep

struct ReadinessEngineTests {
    private let t0 = Date(timeIntervalSince1970: 1_770_000_000)

    private func answers(subject: String, prefix: String, count: Int, correct: Int) -> [AnswerRecord] {
        (0..<count).map { i in
            AnswerRecord(id: UUID(), questionId: "\(prefix)\(i)", selectedIndex: 0,
                         isCorrect: i < correct, date: t0, quizMode: .daily)
        }
    }

    @Test func untouchedSubjectsDragScoreDown() {
        // Perfectly covered "signs", nothing else → overall well below 100.
        let a = answers(subject: "signs", prefix: "s", count: 40, correct: 40)
        let map = Dictionary(a.map { ($0.questionId, "signs") }, uniquingKeysWith: { x, _ in x })
        let r = ReadinessEngine.evaluate(answers: a, subjectOf: map,
                                         subjectIds: ["signs", "laws", "safety", "alcohol", "parking"])
        #expect(r.bySubject.first { $0.subjectId == "signs" }!.score == 100)
        #expect(r.bySubject.first { $0.subjectId == "laws" }!.score == 0)
        #expect(r.score == 20)   // 100 + 0*4, averaged over 5
    }

    @Test func thinSampleIsDamped() {
        // 2/2 correct in one subject: accuracy 100% but only 2 answers.
        let a = answers(subject: "signs", prefix: "s", count: 2, correct: 2)
        let map = Dictionary(a.map { ($0.questionId, "signs") }, uniquingKeysWith: { x, _ in x })
        let r = ReadinessEngine.evaluate(answers: a, subjectOf: map, subjectIds: ["signs"])
        // accuracy 1.0*0.75 + coverage(2/40)*0.25 ≈ 0.7625, *2/10 damping ≈ 0.1525 → ~15
        #expect(r.bySubject[0].score < 20)
    }

    @Test func emptyHistoryIsZero() {
        let r = ReadinessEngine.evaluate(answers: [], subjectOf: [:], subjectIds: ["signs", "laws"])
        #expect(r.score == 0)
    }

    @Test func fullMasteryScoresHigh() {
        var all: [AnswerRecord] = []
        var map: [String: String] = [:]
        for s in ["signs", "laws"] {
            let a = answers(subject: s, prefix: s, count: 40, correct: 38) // 95%
            all += a
            for x in a { map[x.questionId] = s }
        }
        let r = ReadinessEngine.evaluate(answers: all, subjectOf: map, subjectIds: ["signs", "laws"])
        #expect(r.score >= 90)
    }
}
