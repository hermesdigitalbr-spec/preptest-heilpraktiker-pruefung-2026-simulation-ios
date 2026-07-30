import Testing
import Foundation
@testable import HeilpraktikerPrep

struct SRSSchedulerTests {
    private let cal = Calendar(identifier: .gregorian)
    private let t0 = Date(timeIntervalSince1970: 1_770_000_000)
    private func day(_ o: Int) -> Date { cal.date(byAdding: .day, value: o, to: t0)! }

    private func ans(_ qid: String, _ correct: Bool, _ date: Date) -> AnswerRecord {
        AnswerRecord(id: UUID(), questionId: qid, selectedIndex: 0,
                     isCorrect: correct, date: date, quizMode: .daily)
    }

    @Test func firstCorrectGoesToBoxOneDueNextDay() {
        let card = SRSScheduler.card(questionId: "q", answers: [ans("q", true, day(0))], calendar: cal)!
        #expect(card.box == 1)
        #expect(cal.isDate(card.due, inSameDayAs: day(1)))
    }

    @Test func wrongResetsToBoxZeroDueNow() {
        // correct twice then wrong → back to box 0.
        let card = SRSScheduler.card(questionId: "q", answers: [
            ans("q", true, day(-5)), ans("q", true, day(-4)), ans("q", false, day(0))
        ], calendar: cal)!
        #expect(card.box == 0)
        #expect(cal.isDate(card.due, inSameDayAs: day(0)))
    }

    @Test func consecutiveCorrectAdvanceIntervals() {
        let card = SRSScheduler.card(questionId: "q", answers: [
            ans("q", true, day(-10)), ans("q", true, day(-9)), ans("q", true, day(0))
        ], calendar: cal)!
        #expect(card.box == 3)                 // 3 corrects → box 3
        #expect(cal.isDate(card.due, inSameDayAs: day(7)))  // intervals[3] == 7
    }

    @Test func boxCapsAtMastered() {
        let answers = (0..<10).map { ans("q", true, day(-10 + $0)) }
        let card = SRSScheduler.card(questionId: "q", answers: answers, calendar: cal)!
        #expect(card.box == SRSScheduler.maxBox)
        #expect(card.isMastered)
    }

    @Test func neverAnsweredHasNoCard() {
        #expect(SRSScheduler.card(questionId: "q", answers: [], calendar: cal) == nil)
    }

    @Test func dueCardsExcludeNotYetDueAndSortByUrgency() {
        let history = [
            ans("weak", false, day(0)),                       // box 0, due today
            ans("ok", true, day(0)),                          // box 1, due tomorrow → not due
            ans("mid", true, day(-9)), ans("mid", true, day(-8)) // box 2, due day(-8)+3=-5 → due
        ]
        let due = SRSScheduler.dueCards(history: history, now: day(0), calendar: cal)
        #expect(due.map(\.questionId) == ["weak", "mid"])     // urgency: box0 before box2; "ok" excluded
    }
}
