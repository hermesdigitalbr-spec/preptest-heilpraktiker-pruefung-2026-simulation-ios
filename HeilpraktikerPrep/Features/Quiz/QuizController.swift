import Foundation
import Observation

/// UI-facing wrapper around the pure `QuizSession`: adds wall-clock time,
/// optional countdown, bookmarks and attempt recording.
@MainActor
@Observable
final class QuizController {
    private(set) var session: QuizSession
    /// nil = untimed. Seconds for timed/mock modes.
    let timeLimitSeconds: Int?

    private(set) var elapsedSeconds = 0
    private(set) var timeExpired = false
    private(set) var didRecord = false

    private let progress: ProgressStore
    private var ticker: Task<Void, Never>?

    var mode: QuizMode { session.mode }

    var remainingSeconds: Int? {
        timeLimitSeconds.map { max(0, $0 - elapsedSeconds) }
    }

    init(session: QuizSession, timeLimitSeconds: Int?, progress: ProgressStore) {
        self.session = session
        self.timeLimitSeconds = timeLimitSeconds
        self.progress = progress
    }

    // MARK: - Mode factory

    static func make(mode: QuizMode, app: AppSession) -> QuizController? {
        let pool = app.questionPool
        let pack = app.pack
        let answeredIds = Set(app.progress.allAnswers.map(\.questionId))

        var questions: [Question]
        var feedback: FeedbackMode = app.settings.feedbackMode
        var limit: Int?

        switch mode {
        case .daily:
            // Bias the daily set toward the subjects the user is actually
            // weakest at (worst readiness first), falling back to the topics
            // they flagged at onboarding before there's any history. Push the
            // weak ratio up when the exam is near and pass odds are low.
            let readiness = app.readiness
            var weakOrdered = readiness.bySubject
                .filter { $0.answered > 0 && $0.score < Self.dailyWeakScoreThreshold }
                .sorted { $0.score < $1.score }
                .map(\.subjectId)
            if weakOrdered.isEmpty { weakOrdered = Array(app.profile.weakSubjectIds) }
            questions = QuestionSelector.daily(
                from: pool,
                weakSubjectIds: weakOrdered,
                answeredIds: answeredIds,
                count: app.profile.planQuestionsPerDay ?? pack.dailyQuestionsCount,
                weakRatio: Self.dailyWeakRatio(passProbability: app.passProbability,
                                               daysUntilExam: Self.daysUntil(app.profile.examDate)),
                seed: Self.daySeed())
        case .quick10:
            questions = QuestionSelector.quick(
                from: pool, count: pack.quickQuizCount, seed: .random(in: .min ... .max))
        case .timed:
            // Default config; the Home sheet uses makeTimed for custom setups.
            questions = QuestionSelector.quick(
                from: pool, count: pack.quickQuizCount, seed: .random(in: .min ... .max))
            feedback = .quick
            limit = 10 * 60
        case .missed:
            questions = QuestionSelector.missed(from: pool, history: app.progress.allAnswers)
        case .review:
            questions = QuestionSelector.review(
                from: pool, history: app.progress.allAnswers,
                count: app.profile.planQuestionsPerDay ?? pack.dailyQuestionsCount)
        case .collected:
            questions = pool.filter { app.progress.state.bookmarkedQuestionIds.contains($0.id) }
        case .mock:
            questions = QuestionSelector.mock(
                from: pool, count: pack.mockExam.questionCount, seed: .random(in: .min ... .max))
            feedback = .mock
            limit = pack.mockExam.minutes * 60
        case .custom:
            // Custom uses makeCustom(subjectIds:count:) below.
            return nil
        }

        guard !questions.isEmpty else { return nil }
        return QuizController(
            session: QuizSession(mode: mode, feedback: feedback, questions: questions,
                                 shuffleSeed: .random(in: .min ... .max)),
            timeLimitSeconds: limit,
            progress: app.progress)
    }

    /// Timed quiz with user-chosen size and clock (from the Home sheet).
    static func makeTimed(count: Int, minutes: Int, app: AppSession) -> QuizController? {
        let questions = QuestionSelector.quick(
            from: app.questionPool, count: count, seed: .random(in: .min ... .max))
        guard !questions.isEmpty else { return nil }
        return QuizController(
            session: QuizSession(mode: .timed, feedback: .quick, questions: questions,
                                 shuffleSeed: .random(in: .min ... .max)),
            timeLimitSeconds: minutes * 60,
            progress: app.progress)
    }

    static func makeCustom(subjectIds: Set<String>, count: Int, app: AppSession) -> QuizController? {
        let questions = QuestionSelector.custom(
            from: app.questionPool, subjectIds: subjectIds,
            count: count, seed: .random(in: .min ... .max))
        guard !questions.isEmpty else { return nil }
        return QuizController(
            session: QuizSession(mode: .custom, feedback: app.settings.feedbackMode, questions: questions,
                                 shuffleSeed: .random(in: .min ... .max)),
            timeLimitSeconds: nil,
            progress: app.progress)
    }

    /// Study-tab sessions: draws from a pre-filtered pool (new-only or all for subject).
    static func makeStudy(from pool: [Question], app: AppSession) -> QuizController? {
        let questions = QuestionSelector.quick(
            from: pool, count: min(10, pool.count), seed: .random(in: .min ... .max))
        guard !questions.isEmpty else { return nil }
        return QuizController(
            session: QuizSession(mode: .custom, feedback: app.settings.feedbackMode, questions: questions,
                                 shuffleSeed: .random(in: .min ... .max)),
            timeLimitSeconds: nil,
            progress: app.progress)
    }

    /// Same seed for the whole calendar day → reopening daily quiz shows the same set.
    private static func daySeed(for date: Date = .now, calendar: Calendar = .current) -> UInt64 {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year: Int = parts.year ?? 0
        let month: Int = parts.month ?? 0
        let day: Int = parts.day ?? 0
        let combined: Int = year * 10_000 + month * 100 + day
        return UInt64(combined)
    }

    // MARK: - Adaptive daily tuning

    /// A subject below this readiness score counts as "weak" for the daily mix.
    static let dailyWeakScoreThreshold = 70

    /// How heavily the daily set leans on weak subjects. Cranks up when the
    /// exam is close and pass odds are low — that's when focus matters most.
    static func dailyWeakRatio(passProbability: Int?, daysUntilExam: Int?) -> Double {
        if let pass = passProbability, let days = daysUntilExam, pass < 65, days < 7 {
            return 0.75
        }
        return 0.6
    }

    /// Whole days from today until the exam, or nil if unset/past.
    static func daysUntil(_ examDate: Date?, calendar: Calendar = .current, now: Date = .now) -> Int? {
        guard let examDate else { return nil }
        let days = calendar.dateComponents([.day],
                                           from: calendar.startOfDay(for: now),
                                           to: calendar.startOfDay(for: examDate)).day
        guard let days, days > 0 else { return nil }
        return days
    }

    // MARK: - Lifecycle

    func start() {
        guard ticker == nil else { return }
        ticker = Task { [weak self] in
            while let self, !Task.isCancelled, !self.session.isFinished, !self.timeExpired {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.elapsedSeconds += 1
                if let remaining = self.remainingSeconds, remaining <= 0 {
                    self.timeExpired = true
                }
            }
        }
    }

    func stop() {
        ticker?.cancel()
        ticker = nil
    }

    // MARK: - Session passthrough

    @discardableResult
    func submit(_ index: Int) -> Bool {
        session.submitAnswer(index, date: .now)
    }

    func advance() {
        session.advance()
    }

    var selectedIndexForCurrent: Int? {
        session.displayedSelectedIndexForCurrent
    }

    // MARK: - Bookmarks

    var isCurrentBookmarked: Bool {
        guard let current = session.currentQuestion else { return false }
        return progress.state.bookmarkedQuestionIds.contains(current.id)
    }

    func toggleBookmark() {
        guard let current = session.currentQuestion else { return }
        progress.toggleBookmark(questionId: current.id)
    }

    // MARK: - Recording

    /// Saves the attempt exactly once. `finished` distinguishes a natural
    /// completion (or expired timer) from an early quit. Partial attempts keep
    /// their answers and count as practice — they earn streaks plus the
    /// quiz-count and answered achievements. Leaving `completedAt` nil only
    /// gates the rewards that require actually finishing: the "perfect" and
    /// "mock passed" badges, and the home daily-done card (so a quit daily can
    /// still be resumed today rather than being locked out).
    func recordAttempt(finished: Bool = true) {
        guard !didRecord, !session.answers.isEmpty else { return }
        didRecord = true
        stop()
        let didComplete = finished || session.isFinished || timeExpired
        progress.record(attempt: QuizAttempt(
            id: UUID(),
            mode: session.mode,
            startedAt: Date().addingTimeInterval(-Double(elapsedSeconds)),
            completedAt: didComplete ? .now : nil,
            answers: session.answers,
            durationSeconds: elapsedSeconds))
    }
}
