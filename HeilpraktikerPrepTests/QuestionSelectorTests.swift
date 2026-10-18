import Testing
import Foundation
@testable import HeilpraktikerPrep

struct QuestionSelectorTests {
    private func question(_ id: String, subject: String) -> Question {
        Question(id: id, subjectId: subject, difficulty: 1, text: "t",
                 choices: ["a", "b", "c", "d"], correctIndex: 0, explanation: "e")
    }

    private func imageQuestion(_ id: String, subject: String) -> Question {
        Question(id: id, subjectId: subject, difficulty: 1, text: "t",
                 choices: ["a", "b", "c", "d"], correctIndex: 0, explanation: "e", imageName: id)
    }

    private func isImage(_ q: Question) -> Bool { q.imageName != nil || q.imageURL != nil }

    private var pool: [Question] {
        (1...20).map { question("signs-\($0)", subject: "signs") } +
        (1...20).map { question("laws-\($0)", subject: "laws") } +
        (1...10).map { question("safety-\($0)", subject: "safety") }
    }

    @Test func sameSeedGivesSameSelection() {
        let a = QuestionSelector.quick(from: pool, count: 10, seed: 42)
        let b = QuestionSelector.quick(from: pool, count: 10, seed: 42)
        #expect(a.map(\.id) == b.map(\.id))
    }

    @Test func differentSeedsGiveDifferentSelections() {
        let a = QuestionSelector.quick(from: pool, count: 10, seed: 1)
        let b = QuestionSelector.quick(from: pool, count: 10, seed: 2)
        #expect(a.map(\.id) != b.map(\.id))
    }

    @Test func dailyPrioritizesWeakSubjects() {
        let selected = QuestionSelector.daily(
            from: pool, weakSubjectIds: ["safety"], answeredIds: [], count: 10, seed: 7)
        let safetyCount = selected.filter { $0.subjectId == "safety" }.count
        #expect(selected.count == 10)
        #expect(safetyCount >= 5)
    }

    @Test func dailyAvoidsAlreadyAnsweredWhenPossible() {
        let answered = Set(pool.prefix(40).map(\.id))
        let selected = QuestionSelector.daily(
            from: pool, weakSubjectIds: [], answeredIds: answered, count: 10, seed: 7)
        #expect(selected.allSatisfy { !answered.contains($0.id) })
    }

    @Test func dailyWeakRatioControlsWeakShare() {
        let high = QuestionSelector.daily(
            from: pool, weakSubjectIds: ["safety"], answeredIds: [],
            count: 10, weakRatio: 0.9, seed: 7)
        #expect(high.filter { $0.subjectId == "safety" }.count >= 8)
    }

    @Test func dailyOrdersWeakSubjectsByPriority() {
        // "safety" is listed first (weakest) → it dominates the weak slots.
        let selected = QuestionSelector.daily(
            from: pool, weakSubjectIds: ["safety", "laws"], answeredIds: [],
            count: 10, weakRatio: 0.9, seed: 7)
        let safety = selected.filter { $0.subjectId == "safety" }.count
        let laws = selected.filter { $0.subjectId == "laws" }.count
        #expect(safety > laws)
    }

    @MainActor
    @Test func dailyWeakRatioRisesWhenExamNearAndOddsLow() {
        #expect(QuizController.dailyWeakRatio(passProbability: 55, daysUntilExam: 5) == 0.75)
        #expect(QuizController.dailyWeakRatio(passProbability: 80, daysUntilExam: 5) == 0.6)
        #expect(QuizController.dailyWeakRatio(passProbability: 55, daysUntilExam: 20) == 0.6)
        #expect(QuizController.dailyWeakRatio(passProbability: nil, daysUntilExam: nil) == 0.6)
    }

    @Test func missedReturnsOnlyQuestionsWhoseLatestAnswerIsWrong() {
        let early = Date(timeIntervalSince1970: 1000)
        let late = Date(timeIntervalSince1970: 2000)
        let history = [
            // wrong then corrected → not missed
            AnswerRecord(id: UUID(), questionId: "signs-1", selectedIndex: 1, isCorrect: false, date: early, quizMode: .daily),
            AnswerRecord(id: UUID(), questionId: "signs-1", selectedIndex: 0, isCorrect: true, date: late, quizMode: .daily),
            // correct then wrong → missed
            AnswerRecord(id: UUID(), questionId: "laws-1", selectedIndex: 0, isCorrect: true, date: early, quizMode: .daily),
            AnswerRecord(id: UUID(), questionId: "laws-1", selectedIndex: 2, isCorrect: false, date: late, quizMode: .daily),
        ]
        let missed = QuestionSelector.missed(from: pool, history: history)
        #expect(missed.map(\.id) == ["laws-1"])
    }

    @Test func mockDistributesProportionallyAndRespectsCount() {
        let selected = QuestionSelector.mock(from: pool, count: 10, seed: 3)
        #expect(selected.count == 10)
        let signs = selected.filter { $0.subjectId == "signs" }.count
        let laws = selected.filter { $0.subjectId == "laws" }.count
        let safety = selected.filter { $0.subjectId == "safety" }.count
        // 20/20/10 pool → expect roughly 4/4/2
        #expect(signs >= 3 && laws >= 3 && safety >= 1)
        #expect(Set(selected.map(\.id)).count == 10)
    }

    @Test func customFiltersBySubjects() {
        let selected = QuestionSelector.custom(from: pool, subjectIds: ["safety"], count: 5, seed: 9)
        #expect(selected.count == 5)
        #expect(selected.allSatisfy { $0.subjectId == "safety" })
    }

    @Test func countLargerThanPoolReturnsWholePool() {
        let selected = QuestionSelector.quick(from: Array(pool.prefix(3)), count: 10, seed: 1)
        #expect(selected.count == 3)
    }

    // MARK: - First-3-quizzes image guarantee

    private var textOnlySelection: [Question] {
        (1...10).map { question("laws-\($0)", subject: "laws") }
    }

    private var imageBackedPool: [Question] {
        textOnlySelection + (1...5).map { imageQuestion("signs-\($0)", subject: "signs") }
    }

    @Test func injectsImageInFirstThreeQuizzesAndNeverAtSlotZero() {
        for attempt in 0..<3 {
            for _ in 0..<80 {
                let result = QuestionSelector.injectImageIfNeeded(
                    into: textOnlySelection, pool: imageBackedPool,
                    attemptsDone: attempt, seenImageIds: [])
                let imageIdx = result.firstIndex(where: isImage)
                #expect(imageIdx != nil)   // image is guaranteed present
                #expect(imageIdx != 0)     // and never pinned to the first slot
                #expect(result.count == textOnlySelection.count)
            }
        }
    }

    @Test func injectedImagePositionIsShuffledAcrossPlays() {
        var positions = Set<Int>()
        for _ in 0..<80 {
            let result = QuestionSelector.injectImageIfNeeded(
                into: textOnlySelection, pool: imageBackedPool,
                attemptsDone: 0, seenImageIds: [])
            if let idx = result.firstIndex(where: isImage) { positions.insert(idx) }
        }
        // Genuinely shuffled — lands in several different slots, not one fixed spot.
        #expect(positions.count >= 3)
    }

    @Test func existingImageIsShuffledOffSlotZero() {
        // Image deliberately placed FIRST in the base selection (as the
        // weak-subject-ordered daily set can do).
        let selected = [imageQuestion("signs-1", subject: "signs")]
            + (1...9).map { question("laws-\($0)", subject: "laws") }
        for _ in 0..<80 {
            let result = QuestionSelector.injectImageIfNeeded(
                into: selected, pool: selected, attemptsDone: 0, seenImageIds: [])
            let imageIdx = result.firstIndex(where: isImage)
            #expect(imageIdx != nil)
            #expect(imageIdx != 0)   // must be moved off the first slot
            #expect(Set(result.map(\.id)) == Set(selected.map(\.id)))
        }
    }

    @Test func doesNotInjectAfterThreeQuizzes() {
        let result = QuestionSelector.injectImageIfNeeded(
            into: textOnlySelection, pool: imageBackedPool,
            attemptsDone: 3, seenImageIds: [])
        #expect(result.map(\.id) == textOnlySelection.map(\.id))  // untouched
        #expect(!result.contains(where: isImage))
    }

    @Test func injectionIsReproducibleWithFixedSeed() {
        let a = QuestionSelector.injectImageIfNeeded(
            into: textOnlySelection, pool: imageBackedPool,
            attemptsDone: 0, seenImageIds: [], seed: 123)
        let b = QuestionSelector.injectImageIfNeeded(
            into: textOnlySelection, pool: imageBackedPool,
            attemptsDone: 0, seenImageIds: [], seed: 123)
        #expect(a.map(\.id) == b.map(\.id))
    }

    @Test func quickInjectsImageForNewUsersAndSkipsWhenNoImages() {
        let result = QuestionSelector.quick(from: imageBackedPool, count: 5, seed: 9,
                                            quicksDoneCount: 0, seenImageQuestionIds: [])
        #expect(result.contains(where: isImage))
        #expect(result.first.map(isImage) == false)
        let textOnly = QuestionSelector.quick(from: textOnlySelection, count: 5, seed: 9,
                                              quicksDoneCount: 0, seenImageQuestionIds: [])
        #expect(!textOnly.contains(where: isImage))
        #expect(textOnly.map(\.id) == QuestionSelector.quick(from: textOnlySelection, count: 5, seed: 9).map(\.id))
    }
}
