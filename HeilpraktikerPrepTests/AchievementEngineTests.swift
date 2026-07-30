import Testing
import Foundation
@testable import HeilpraktikerPrep

struct AchievementEngineTests {
    private let cal = Calendar(identifier: .gregorian)
    private let t0 = Date(timeIntervalSince1970: 1_770_000_000)

    private func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: t0)! }

    private func answer(_ qid: String, correct: Bool, on date: Date) -> AnswerRecord {
        AnswerRecord(id: UUID(), questionId: qid, selectedIndex: 0,
                     isCorrect: correct, date: date, quizMode: .daily)
    }

    private func attempt(_ answers: [AnswerRecord], mode: QuizMode = .daily,
                         completed: Date? = nil) -> QuizAttempt {
        QuizAttempt(id: UUID(), mode: mode, startedAt: answers.first?.date ?? t0,
                    completedAt: completed, answers: answers, durationSeconds: 60)
    }

    // MARK: - longestStreak

    @Test func longestStreakFindsTheBestRunNotTheCurrent() {
        // A 4-day run, a gap, then a 2-day run → longest is 4.
        let dates = [day(0), day(-1), day(-2), day(-3), day(-6), day(-7)]
        #expect(AchievementEngine.longestStreak(dates: dates, calendar: cal) == 4)
    }

    @Test func longestStreakEmptyIsZero() {
        #expect(AchievementEngine.longestStreak(dates: [], calendar: cal) == 0)
    }

    // MARK: - snapshot metrics

    @Test func totalsAndPerfectQuizzes() {
        let perfect = attempt((0..<5).map { answer("q\($0)", correct: true, on: day(0)) },
                              completed: day(0))
        let flawed = attempt((0..<5).map { answer("r\($0)", correct: $0 != 0, on: day(-1)) },
                             completed: day(-1))
        let abandoned = attempt([answer("x", correct: true, on: day(-2))]) // no completedAt
        let snap = AchievementEngine.snapshot(
            attempts: [perfect, flawed, abandoned], subjectOf: [:],
            mockPassPercent: 80, calendar: cal)
        #expect(snap.totalAnswered == 11)
        #expect(snap.quizzesCompleted == 3)      // abandoned still counts as practice
        #expect(snap.perfectQuizzes == 1)        // only the all-correct, finished one
    }

    @Test func shortPerfectRunDoesNotCount() {
        let tiny = attempt((0..<3).map { answer("q\($0)", correct: true, on: day(0)) },
                           completed: day(0))
        let snap = AchievementEngine.snapshot(attempts: [tiny], subjectOf: [:],
                                              mockPassPercent: 80, calendar: cal)
        #expect(snap.perfectQuizzes == 0)        // below perfectMinQuestions
    }

    @Test func subjectMasteryNeedsEnoughSample() {
        // 25 answers in "signs", 24 correct → 96%; 3 answers in "laws".
        let map = (0..<25).reduce(into: [String: String]()) { $0["s\($1)"] = "signs" }
            .merging((0..<3).reduce(into: [String: String]()) { $0["l\($1)"] = "laws" }) { a, _ in a }
        var answers = (0..<25).map { answer("s\($0)", correct: $0 != 0, on: day(0)) }
        answers += (0..<3).map { answer("l\($0)", correct: true, on: day(0)) }
        let snap = AchievementEngine.snapshot(attempts: [attempt(answers, completed: day(0))],
                                              subjectOf: map, mockPassPercent: 80, calendar: cal)
        #expect(snap.subjectsPracticed == 2)
        #expect(snap.bestSubjectAccuracy == 96)  // laws ignored (sample < 20)
    }

    @Test func mockPassedRespectsThreshold() {
        let answers = (0..<10).map { answer("m\($0)", correct: $0 < 8, on: day(0)) } // 80%
        let snap = AchievementEngine.snapshot(
            attempts: [attempt(answers, mode: .mock, completed: day(0))],
            subjectOf: [:], mockPassPercent: 80, calendar: cal)
        #expect(snap.mockPassed)
    }

    // MARK: - status

    private func def(_ type: String, _ value: Int?) -> AchievementDef {
        AchievementDef(id: "a", title: "T", detail: "D", icon: "star", tint: "#fff",
                       criterion: .init(type: type, value: value))
    }

    @Test func statusUnlocksAtThreshold() {
        var snap = AchievementEngine.Snapshot()
        snap.totalAnswered = 500
        let status = AchievementEngine.status(for: def("totalAnswered", 500),
                                              snapshot: snap, subjectCount: 5)
        #expect(status.unlocked)
        #expect(status.fraction == 1)
    }

    @Test func statusReportsPartialProgress() {
        var snap = AchievementEngine.Snapshot()
        snap.totalAnswered = 250
        let status = AchievementEngine.status(for: def("totalAnswered", 500),
                                              snapshot: snap, subjectCount: 5)
        #expect(!status.unlocked)
        #expect(status.current == 250)
        #expect(abs(status.fraction - 0.5) < 0.0001)
    }

    @Test func allSubjectsTargetComesFromPack() {
        var snap = AchievementEngine.Snapshot()
        snap.subjectsPracticed = 5
        let status = AchievementEngine.status(for: def("allSubjects", nil),
                                              snapshot: snap, subjectCount: 5)
        #expect(status.target == 5)
        #expect(status.unlocked)
    }

    // MARK: - New Duolingo-style metrics

    /// Builds a session with an explicit start time, duration and completion.
    private func session(start: Date, answers n: Int, correct: Bool = true,
                         mode: QuizMode = .quick10, completed: Bool = false,
                         duration: Int = 60) -> QuizAttempt {
        let ans = (0..<n).map {
            AnswerRecord(id: UUID(), questionId: "q\($0)", selectedIndex: 0,
                         isCorrect: correct, date: start, quizMode: mode)
        }
        return QuizAttempt(id: UUID(), mode: mode, startedAt: start,
                           completedAt: completed ? start : nil,
                           answers: ans, durationSeconds: duration)
    }

    private func snap(_ attempts: [QuizAttempt], subjectOf: [String: String] = [:],
                      mockPass: Int = 80, bookmarks: Int = 0) -> AchievementEngine.Snapshot {
        AchievementEngine.snapshot(attempts: attempts, subjectOf: subjectOf,
                                   mockPassPercent: mockPass, bookmarkedCount: bookmarks,
                                   calendar: cal)
    }

    @Test func totalCorrectCountsOnlyRightAnswers() {
        let a = attempt((0..<10).map { answer("q\($0)", correct: $0 < 7, on: day(0)) })
        #expect(snap([a]).totalCorrect == 7)
        #expect(snap([a]).totalAnswered == 10)
    }

    @Test func daysPracticedAndComebacksFromGaps() {
        // Practiced on 3 distinct days; the −10→−1 jump is a 9-day comeback.
        let s = snap([attempt([answer("a", correct: true, on: day(0))]),
                      attempt([answer("b", correct: true, on: day(-1))]),
                      attempt([answer("c", correct: true, on: day(-10))])])
        #expect(s.daysPracticed == 3)
        #expect(s.comebacks == 1)
    }

    @Test func bestDayAnswersTakesThePeakDay() {
        // 3 + 5 answers on day 0 (two sessions), 2 on day −1 → peak is 8.
        let s = snap([attempt((0..<3).map { answer("x\($0)", correct: true, on: day(0)) }),
                      attempt((0..<5).map { answer("y\($0)", correct: true, on: day(0)) }),
                      attempt((0..<2).map { answer("z\($0)", correct: true, on: day(-1)) })])
        #expect(s.bestDayAnswers == 8)
    }

    @Test func mockScoreTracksBestAndPassFlag() {
        let pass = attempt((0..<10).map { answer("m\($0)", correct: $0 < 8, on: day(0)) },
                           mode: .mock, completed: day(0)) // 80%
        let ace = attempt((0..<10).map { answer("n\($0)", correct: true, on: day(-1)) },
                          mode: .mock, completed: day(-1)) // 100%
        let s = snap([pass, ace])
        #expect(s.bestMockPercent == 100)
        #expect(s.mockPassed)
    }

    @Test func subjectsMasteredCountsThoseAtOrAboveNinety() {
        var map = (0..<25).reduce(into: [String: String]()) { $0["s\($1)"] = "signs" }
        for i in 0..<22 { map["l\(i)"] = "laws" }
        var answers = (0..<25).map { answer("s\($0)", correct: $0 != 0, on: day(0)) } // 96%
        answers += (0..<22).map { answer("l\($0)", correct: $0 % 2 == 0, on: day(0)) } // ~50%
        let s = snap([attempt(answers)], subjectOf: map)
        #expect(s.subjectsMastered == 1) // only "signs" clears 90%
    }

    @Test func timeOfDayAndWeekendSessions() {
        let early = cal.date(bySettingHour: 6, minute: 0, second: 0, of: day(0))!
        let night = cal.date(bySettingHour: 23, minute: 0, second: 0, of: day(0))!
        // Pick a weekend day and pin it to noon so it can never also register
        // as early-bird/night-owl regardless of the machine's timezone.
        var weekendDay = day(0)
        while !cal.isDateInWeekend(weekendDay) { weekendDay = cal.date(byAdding: .day, value: 1, to: weekendDay)! }
        let weekend = cal.date(bySettingHour: 12, minute: 0, second: 0, of: weekendDay)!
        let s = snap([session(start: early, answers: 3),
                      session(start: night, answers: 3),
                      session(start: weekend, answers: 3)])
        #expect(s.earlyBirdSessions == 1)
        #expect(s.nightOwlSessions == 1)
        #expect(s.weekendSessions >= 1)
    }

    @Test func speedsterNeedsEnoughQuestionsFastAndFinished() {
        let fast = session(start: day(0), answers: 10, completed: true, duration: 50)  // 5s/q
        let slow = session(start: day(0), answers: 10, completed: true, duration: 300) // 30s/q
        let fastButQuit = session(start: day(0), answers: 10, completed: false, duration: 50)
        #expect(snap([fast]).fastQuizzes == 1)
        #expect(snap([slow]).fastQuizzes == 0)
        #expect(snap([fastButQuit]).fastQuizzes == 0) // not finished
    }

    @Test func modesAndMinutesPracticed() {
        let s = snap([session(start: day(0), answers: 5, mode: .daily, duration: 60),
                      session(start: day(0), answers: 5, mode: .timed, duration: 90),
                      session(start: day(0), answers: 5, mode: .mock, duration: 30)])
        #expect(s.modesPracticed == 3)
        #expect(s.minutesPracticed == 3) // (60+90+30)/60
    }

    @Test func collectedComesFromBookmarkCount() {
        let s = snap([attempt([answer("q", correct: true, on: day(0))])], bookmarks: 7)
        #expect(s.bookmarkedCount == 7)
        let unlocked = AchievementEngine.status(for: def("collected", 5), snapshot: s, subjectCount: 5)
        let locked = AchievementEngine.status(for: def("collected", 25), snapshot: s, subjectCount: 5)
        #expect(unlocked.unlocked)
        #expect(!locked.unlocked)
        #expect(locked.current == 7)
    }

    @Test func allSubjectsMasteredTargetComesFromPack() {
        var s = AchievementEngine.Snapshot()
        s.subjectsMastered = 5
        let status = AchievementEngine.status(for: def("allSubjectsMastered", nil),
                                              snapshot: s, subjectCount: 5)
        #expect(status.target == 5)
        #expect(status.unlocked)
    }

    @Test func singleShotTargetsDefaultToOne() {
        var s = AchievementEngine.Snapshot()
        s.earlyBirdSessions = 1
        s.comebacks = 1
        #expect(AchievementEngine.status(for: def("earlyBird", nil), snapshot: s, subjectCount: 5).unlocked)
        #expect(AchievementEngine.status(for: def("comeback", nil), snapshot: s, subjectCount: 5).unlocked)
    }

    @Test func overallAccuracyNeedsMinimumSample() {
        let big = attempt((0..<100).map { answer("q\($0)", correct: $0 < 90, on: day(0)) })
        #expect(snap([big]).overallAccuracy == 90)
        let small = attempt((0..<10).map { answer("s\($0)", correct: true, on: day(0)) })
        #expect(snap([small]).overallAccuracy == 0) // below accuracyMinSample
    }

    @Test func perfectStreakCountsConsecutiveFlawlessRuns() {
        func perfect(_ tag: String, _ d: Date) -> QuizAttempt {
            attempt((0..<5).map { answer("\(tag)\($0)", correct: true, on: d) }, completed: d)
        }
        func flawed(_ tag: String, _ d: Date) -> QuizAttempt {
            attempt((0..<5).map { answer("\(tag)\($0)", correct: $0 != 0, on: d) }, completed: d)
        }
        // a,b perfect → break → d,e,f perfect: longest flawless run is 3.
        let attempts = [perfect("a", day(-5)), perfect("b", day(-4)), flawed("c", day(-3)),
                        perfect("d", day(-2)), perfect("e", day(-1)), perfect("f", day(0))]
        #expect(snap(attempts).longestPerfectStreak == 3)
        // A quit (no completedAt) never contributes to the flawless run.
        let quitPerfect = attempt((0..<5).map { answer("z\($0)", correct: true, on: day(1)) })
        #expect(snap([quitPerfect]).longestPerfectStreak == 0)
    }
}
