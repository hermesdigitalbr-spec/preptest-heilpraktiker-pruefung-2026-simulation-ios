import Testing
import Foundation
@testable import HeilpraktikerPrep

@MainActor
struct ProgressStoreTests {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    @Test func recordsAttemptAndReloads() throws {
        let url = tempURL()
        let store = ProgressStore(fileURL: url)
        let answer = AnswerRecord(id: UUID(), questionId: "q1", selectedIndex: 0,
                                  isCorrect: true, date: .now, quizMode: .quick10)
        let attempt = QuizAttempt(id: UUID(), mode: .quick10, startedAt: .now,
                                  completedAt: .now, answers: [answer], durationSeconds: 30)
        store.record(attempt: attempt)

        let reloaded = ProgressStore(fileURL: url)
        #expect(reloaded.state.attempts.count == 1)
        #expect(reloaded.allAnswers.first?.questionId == "q1")
    }

    @Test func togglesBookmarkAndPersists() {
        let url = tempURL()
        let store = ProgressStore(fileURL: url)
        store.toggleBookmark(questionId: "q9")
        #expect(ProgressStore(fileURL: url).state.bookmarkedQuestionIds.contains("q9"))
        store.toggleBookmark(questionId: "q9")
        #expect(!store.state.bookmarkedQuestionIds.contains("q9"))
    }

    @Test func resetClearsEverything() {
        let store = ProgressStore(fileURL: tempURL())
        store.toggleBookmark(questionId: "q1")
        store.resetAll()
        #expect(store.state == ProgressState())
    }

    @Test func corruptFileFallsBackToEmptyState() throws {
        let url = tempURL()
        try Data("not json".utf8).write(to: url)
        let store = ProgressStore(fileURL: url)
        #expect(store.state == ProgressState())
    }

    // MARK: - dailyDone (single source of truth for Home + widget)

    private func dailyAttempt(mode: QuizMode, completed: Date?, on day: Date) -> QuizAttempt {
        QuizAttempt(id: UUID(), mode: mode, startedAt: day, completedAt: completed,
                    answers: [AnswerRecord(id: UUID(), questionId: "q", selectedIndex: 0,
                                           isCorrect: true, date: day, quizMode: mode)],
                    durationSeconds: 30)
    }

    @Test func dailyDoneIsTrueOnlyForTodaysCompletedDaily() {
        let cal = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 1_770_000_000)
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!
        let store = ProgressStore(fileURL: tempURL())

        #expect(!store.dailyDone(on: today, calendar: cal)) // nothing yet

        store.record(attempt: dailyAttempt(mode: .daily, completed: today, on: today))
        #expect(store.dailyDone(on: today, calendar: cal))      // completed today
        #expect(!store.dailyDone(on: yesterday, calendar: cal)) // not for another day
    }

    @Test func dailyDoneIgnoresNonDailyAndAbandoned() {
        let cal = Calendar(identifier: .gregorian)
        let today = Date(timeIntervalSince1970: 1_770_000_000)
        let store = ProgressStore(fileURL: tempURL())
        store.record(attempt: dailyAttempt(mode: .quick10, completed: today, on: today)) // non-daily
        store.record(attempt: dailyAttempt(mode: .daily, completed: nil, on: today))      // abandoned daily
        #expect(!store.dailyDone(on: today, calendar: cal))
    }
}
