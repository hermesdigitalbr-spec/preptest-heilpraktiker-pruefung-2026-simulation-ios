import Foundation

struct SubjectBreakdown: Equatable, Identifiable {
    let subjectId: String
    let correct: Int
    let total: Int

    var id: String { subjectId }
    var accuracy: Double { total > 0 ? Double(correct) / Double(total) : 0 }
}

enum ScoringLogic {
    static func scorePercent(correct: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return Int((Double(correct) / Double(total) * 100).rounded())
    }

    /// Groups answers by the subject of the question they belong to.
    /// Answers to unknown question ids are ignored.
    static func breakdown(answers: [AnswerRecord], questions: [Question]) -> [SubjectBreakdown] {
        let subjectByQuestionId = Dictionary(uniqueKeysWithValues: questions.map { ($0.id, $0.subjectId) })
        var correctBySubject: [String: Int] = [:]
        var totalBySubject: [String: Int] = [:]

        for answer in answers {
            guard let subjectId = subjectByQuestionId[answer.questionId] else { continue }
            totalBySubject[subjectId, default: 0] += 1
            if answer.isCorrect {
                correctBySubject[subjectId, default: 0] += 1
            }
        }

        return totalBySubject.keys.sorted().map { subjectId in
            SubjectBreakdown(
                subjectId: subjectId,
                correct: correctBySubject[subjectId] ?? 0,
                total: totalBySubject[subjectId] ?? 0
            )
        }
    }
}
