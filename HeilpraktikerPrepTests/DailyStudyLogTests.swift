import Testing
import Foundation
@testable import HeilpraktikerPrep

struct DailyStudyLogTests {
    private let cal = Calendar(identifier: .gregorian)

    private func attempt(_ mode: QuizMode, day: Date, seconds: Int, answers: Int, finished: Bool = true) -> QuizAttempt {
        let recs = (0..<answers).map { _ in
            AnswerRecord(id: UUID(), questionId: UUID().uuidString, selectedIndex: 0,
                         isCorrect: true, date: day, quizMode: mode)
        }
        return QuizAttempt(id: UUID(), mode: mode, startedAt: day,
                           completedAt: finished ? day : nil, answers: recs, durationSeconds: seconds)
    }

    @Test func listsSessionsNewestFirst() {
        let day = cal.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 8))!
        let later = cal.date(byAdding: .hour, value: 5, to: day)!
        let log = DailyStudyLog.build(from: [
            attempt(.quick10, day: day, seconds: 60, answers: 4),
            attempt(.mock, day: later, seconds: 60, answers: 8),
        ], calendar: cal)
        #expect(log[0].sessions.map(\.questionsAnswered) == [8, 4])
    }

    @Test func accuracyIsNilWithoutAnswers() {
        let day = cal.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 8))!
        let log = DailyStudyLog.build(from: [attempt(.quick10, day: day, seconds: 30, answers: 0)],
                                      calendar: cal)
        #expect(log[0].sessions.first?.accuracyPercent == nil)
    }

    @Test func aggregatesPerDay() {
        let d1 = cal.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 10))!
        let d2 = cal.date(byAdding: .day, value: 1, to: d1)!
        let log = DailyStudyLog.build(from: [
            attempt(.quick10, day: d1, seconds: 600, answers: 10),
            attempt(.mock, day: d1, seconds: 3600, answers: 60),
            attempt(.mock, day: d2, seconds: 900, answers: 20, finished: false),
        ], calendar: cal)
        #expect(log.count == 2)
        #expect(log[0].studySeconds == 4200)
        #expect(log[0].questionsAnswered == 70)
        #expect(log[0].completedMocks == 1)
        #expect(log[1].completedMocks == 0)
        #expect(log[0].sessions.count == 2)
        #expect(Set(log[0].sessions.map(\.questionsAnswered)) == [10, 60])
        #expect(log[0].sessions.allSatisfy { $0.accuracyPercent == 100 })
        #expect(log[1].sessions.first?.completed == false)
        let totals = DailyStudyLog.totals(of: log)
        #expect(totals.days == 2)
        #expect(totals.studySeconds == 5100)
        #expect(totals.questionsAnswered == 90)
        #expect(totals.completedMocks == 1)
    }

    @Test func emptyAttemptsGiveEmptyLog() {
        #expect(DailyStudyLog.build(from: [], calendar: cal).isEmpty)
    }
}
