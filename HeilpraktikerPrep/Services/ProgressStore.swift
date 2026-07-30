import Foundation
import Observation

struct ProgressState: Codable, Equatable {
    var attempts: [QuizAttempt] = []
    var bookmarkedQuestionIds: Set<String> = []
    /// Achievements the user has already been shown the unlock celebration
    /// for — used to fire the toast only once per badge.
    var celebratedAchievementIds: Set<String> = []
    /// Streak freezes available to spend.
    var streakFreezes: Int = 1
    /// Days that were saved by spending a freeze (count toward the streak).
    var frozenDays: Set<Date> = []
    /// When the user last practiced (answered ≥1 question). Drives lapse
    /// re-engagement notifications and exam-near nudges.
    var lastPracticeDate: Date?

    init() {}
    // Tolerate older payloads saved before these fields existed.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        attempts = try c.decodeIfPresent([QuizAttempt].self, forKey: .attempts) ?? []
        bookmarkedQuestionIds = try c.decodeIfPresent(Set<String>.self, forKey: .bookmarkedQuestionIds) ?? []
        celebratedAchievementIds = try c.decodeIfPresent(Set<String>.self, forKey: .celebratedAchievementIds) ?? []
        streakFreezes = try c.decodeIfPresent(Int.self, forKey: .streakFreezes) ?? 1
        frozenDays = try c.decodeIfPresent(Set<Date>.self, forKey: .frozenDays) ?? []
        lastPracticeDate = try c.decodeIfPresent(Date.self, forKey: .lastPracticeDate)
    }
}

/// Persists user progress as a single JSON file in Documents.
/// Mutations always replace `state` with a new value, then save atomically.
@MainActor
@Observable
final class ProgressStore {
    private(set) var state: ProgressState
    private let fileURL: URL

    nonisolated static func defaultURL() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return documents.appendingPathComponent("progress.json")
    }

    init(fileURL: URL = ProgressStore.defaultURL()) {
        self.fileURL = fileURL
        self.state = Self.loadState(from: fileURL)
    }

    func record(attempt: QuizAttempt) {
        var next = state
        next.attempts.append(attempt)
        if !attempt.answers.isEmpty { next.lastPracticeDate = .now }
        commit(next)
    }

    func toggleBookmark(questionId: String) {
        var next = state
        if next.bookmarkedQuestionIds.contains(questionId) {
            next.bookmarkedQuestionIds.remove(questionId)
        } else {
            next.bookmarkedQuestionIds.insert(questionId)
        }
        commit(next)
    }

    func resetAll() {
        commit(ProgressState())
    }

    /// Marks badges as celebrated so their unlock toast won't show again.
    func markCelebrated(_ ids: Set<String>) {
        guard !ids.isSubset(of: state.celebratedAchievementIds) else { return }
        var next = state
        next.celebratedAchievementIds.formUnion(ids)
        commit(next)
    }

    /// Tops up freezes (premium perk) without ever lowering the current count.
    func ensureFreezes(atLeast minimum: Int) {
        guard state.streakFreezes < minimum else { return }
        var next = state
        next.streakFreezes = minimum
        commit(next)
    }

    /// Spends one freeze to save `day`. Returns true if a freeze was applied.
    @discardableResult
    func spendFreeze(on day: Date, remaining: Int) -> Bool {
        guard !state.frozenDays.contains(day) else { return false }
        var next = state
        next.frozenDays.insert(day)
        next.streakFreezes = remaining
        commit(next)
        return true
    }

    // MARK: - Derived

    var allAnswers: [AnswerRecord] {
        state.attempts.flatMap(\.answers)
    }

    /// Days the user practiced — any session where they answered at least one
    /// question counts, even if they quit before finishing. Keeps the streak in
    /// sync with the achievement engine's notion of practice.
    var completionDates: [Date] {
        state.attempts
            .filter { !$0.answers.isEmpty }
            .map { $0.completedAt ?? $0.startedAt }
    }

    /// Whether a daily quiz was *completed* on `now`'s calendar day. Single
    /// source of truth shared by the Home daily card and the widget snapshot so
    /// the two can never drift apart.
    func dailyDone(on now: Date = .now, calendar: Calendar = .current) -> Bool {
        state.attempts.contains { attempt in
            attempt.mode == .daily
                && (attempt.completedAt.map { calendar.isDate($0, inSameDayAs: now) } ?? false)
        }
    }

    // MARK: - Persistence

    private func commit(_ next: ProgressState) {
        state = next
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(next)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // Persistence failure must never crash a practice session;
            // state stays correct in memory and the next mutation retries.
            assertionFailure("ProgressStore save failed: \(error)")
        }
    }

    private static func loadState(from url: URL) -> ProgressState {
        guard let data = try? Data(contentsOf: url) else { return ProgressState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(ProgressState.self, from: data)) ?? ProgressState()
    }
}
