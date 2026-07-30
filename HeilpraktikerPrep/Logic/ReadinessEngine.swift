import Foundation

/// Turns scattered practice history into one motivating "exam readiness"
/// percentage. Per subject it blends how accurate you are with how much of
/// the material you've covered; the overall score averages every subject, so
/// ignoring a topic visibly holds you back. Pure and explainable.
enum ReadinessEngine {
    /// Accuracy is worth more than raw coverage, but seeing the material
    /// still matters.
    static let accuracyWeight = 0.75
    static let coverageWeight = 0.25
    /// Coverage saturates here — you don't need to see every single question
    /// in a subject to be "covered".
    static let coverageTarget = 40
    /// Below this many answers a subject's signal is thin, so its score is
    /// scaled down proportionally (prevents a lucky 2/2 reading 100%).
    static let confidentSample = 10

    struct SubjectReadiness: Equatable, Identifiable {
        let subjectId: String
        let score: Int          // 0...100
        let answered: Int
        var id: String { subjectId }
    }

    struct Result: Equatable {
        let score: Int                       // 0...100 overall
        let bySubject: [SubjectReadiness]
    }

    /// - Parameters:
    ///   - subjectIds: every subject in the pack (untouched ones score 0).
    ///   - subjectOf: questionId → subjectId.
    static func evaluate(answers: [AnswerRecord],
                         subjectOf: [String: String],
                         subjectIds: [String]) -> Result {
        var total: [String: Int] = [:]
        var correct: [String: Int] = [:]
        var seen: [String: Set<String>] = [:]
        for a in answers {
            guard let s = subjectOf[a.questionId] else { continue }
            total[s, default: 0] += 1
            if a.isCorrect { correct[s, default: 0] += 1 }
            seen[s, default: []].insert(a.questionId)
        }

        let subjects = subjectIds.map { id -> SubjectReadiness in
            let answered = total[id] ?? 0
            guard answered > 0 else { return SubjectReadiness(subjectId: id, score: 0, answered: 0) }
            let accuracy = Double(correct[id] ?? 0) / Double(answered)
            let coverage = min(1.0, Double(seen[id]?.count ?? 0) / Double(coverageTarget))
            var blended = accuracy * accuracyWeight + coverage * coverageWeight
            // Thin-sample damping.
            if answered < confidentSample {
                blended *= Double(answered) / Double(confidentSample)
            }
            return SubjectReadiness(subjectId: id, score: Int((blended * 100).rounded()), answered: answered)
        }

        let overall = subjects.isEmpty ? 0
            : Int((Double(subjects.map(\.score).reduce(0, +)) / Double(subjects.count)).rounded())
        return Result(score: overall, bySubject: subjects)
    }
}
