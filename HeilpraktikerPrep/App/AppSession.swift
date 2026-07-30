import Foundation
import Observation
import SwiftUI
import WidgetKit

/// Global app state: validated content, user progress and profile.
/// Created once at launch and injected via .environment.
@MainActor
@Observable
final class AppSession {
    let content: ContentBundle
    let progress: ProgressStore
    let settings = AppSettings()
    let iap: IAPService
    let auth = AppleAuthService()

    var profile: UserProfile {
        didSet { Self.persist(profile) }
    }

    var strings: UIStrings { content.strings }
    var pack: PackConfig { content.pack }

    /// Questions visible to this user: universal ones plus the ones scoped to
    /// their chosen region. With no region chosen (or no regions in the pack),
    /// region-scoped questions are excluded only when a region system exists.
    var questionPool: [Question] {
        content.questions.filter { question in
            guard let states = question.states, !states.isEmpty else { return true }
            guard let stateId = profile.stateId else { return false }
            return states.contains(stateId)
        }
    }

    init(content: ContentBundle, progress: ProgressStore? = nil, profile: UserProfile? = nil) {
        self.content = content
        self.progress = progress ?? ProgressStore()
        self.profile = profile ?? Self.loadProfile()
        self.iap = IAPService(products: content.pack.products)
        AppColor.accent = Color(hexString: content.pack.accentHex)
    }

    /// Spaced-repetition cards due for review right now.
    var reviewDueCount: Int {
        SRSScheduler.dueCards(history: progress.allAnswers).count
    }

    // MARK: - Streak freeze

    /// Premium gets a standing reserve of freezes; free users keep their one.
    static let premiumFreezeReserve = 3

    /// Set when a freeze was just spent, so the UI can celebrate it once.
    var justFrozenDay: Date?

    /// Set by a `heilpraktiker://daily` deep link (widget tap) so Home jumps into
    /// the daily quiz. Consumed and reset by HomeView.
    var pendingDailyLaunch = false

    /// Current streak, counting days saved by freezes.
    var currentStreak: Int {
        StreakLogic.currentStreak(
            activityDates: progress.completionDates,
            frozenDays: Array(progress.state.frozenDays),
            today: .now, calendar: .current)
    }

    /// Tops up premium freezes, then spends one to bridge a single missed day
    /// if the streak is at risk. Call when the app becomes active.
    func maintainStreak(now: Date = .now) {
        if iap.isPro { progress.ensureFreezes(atLeast: Self.premiumFreezeReserve) }
        guard let decision = StreakMaintainer.decide(
            activityDays: Set(progress.completionDates),
            frozenDays: progress.state.frozenDays,
            freezes: progress.state.streakFreezes,
            today: now) else { return }
        if progress.spendFreeze(on: decision.dayToFreeze, remaining: decision.freezesRemaining) {
            justFrozenDay = decision.dayToFreeze
        }
    }

    /// (Re)schedules a single lapse re-engagement nudge for 3 days after the
    /// user last practiced. No-ops silently if notifications aren't authorized
    /// (never prompts here). Call when the app becomes active and after a quiz.
    func refreshLapseReminder(now: Date = .now) {
        guard let last = progress.state.lastPracticeDate else {
            NotificationService.cancelLapseReminder()
            return
        }
        let fireDate = last.addingTimeInterval(3 * 86_400)
        let streak = currentStreak
        let s = strings.settings
        let title = s.lapseNotifTitle
        let body = streak >= 1 ? String(format: s.lapseNotifStreakFormat, streak) : s.lapseNotifBody
        Task { await NotificationService.scheduleLapseReminder(fireDate: fireDate, title: title, body: body) }
    }

    /// Wipes all progress, then immediately re-syncs the widget snapshot and the
    /// lapse reminder. Republishing stops the widget from showing a stale streak/
    /// readiness, and refreshing the lapse reminder (lastPracticeDate is now nil)
    /// cancels any pending "your streak is waiting" nudge.
    func resetProgress() {
        progress.resetAll()
        publishWidgetSnapshot()
        refreshLapseReminder()
    }

    // MARK: - Widget

    /// Publishes the current state to the shared App Group and refreshes the
    /// home/lock-screen widgets. Call when the app foregrounds or after a quiz.
    func publishWidgetSnapshot(now: Date = .now) {
        let calendar = Calendar.current
        let daysToExam: Int? = profile.examDate.flatMap { exam in
            let d = calendar.dateComponents([.day], from: calendar.startOfDay(for: now),
                                            to: calendar.startOfDay(for: exam)).day
            return (d ?? 0) > 0 ? d : nil
        }
        let dailyDone = progress.dailyDone(on: now, calendar: calendar)
        let snapshot = WidgetSnapshot(
            examShortName: pack.examShortName,
            daysToExam: daysToExam,
            streak: currentStreak,
            dailyDone: dailyDone,
            dailyTarget: profile.planQuestionsPerDay ?? pack.dailyQuestionsCount,
            readiness: passProbability ?? 0,
            accentHex: pack.accentHex)
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Per-subject readiness snapshot (used by achievements / future drilldowns).
    var readiness: ReadinessEngine.Result {
        ReadinessEngine.evaluate(
            answers: progress.allAnswers,
            subjectOf: subjectByQuestionId,
            subjectIds: pack.subjects.map(\.id))
    }

    /// Estimated probability (0–100) that the user would pass the real exam
    /// right now, based on recent practice accuracy versus the pack's pass
    /// mark. A motivating heuristic, not a guarantee.
    var passProbability: Int? {
        PassProbabilityEngine.evaluate(
            answers: progress.allAnswers,
            passThresholdPercent: pack.mockExam.passPercent)
    }

    // MARK: - Achievements

    /// Maps every question to its subject, for subject-based achievements.
    private var subjectByQuestionId: [String: String] {
        Dictionary(content.questions.map { ($0.id, $0.subjectId) }, uniquingKeysWith: { a, _ in a })
    }

    /// Evaluated achievement statuses in pack order (empty if the pack ships none).
    var achievementStatuses: [AchievementStatus] {
        guard let defs = pack.achievements, !defs.isEmpty else { return [] }
        let snap = AchievementEngine.snapshot(
            attempts: progress.state.attempts,
            subjectOf: subjectByQuestionId,
            mockPassPercent: pack.mockExam.passPercent,
            bookmarkedCount: progress.state.bookmarkedQuestionIds.count)
        return defs.map {
            AchievementEngine.status(for: $0, snapshot: snap, subjectCount: pack.subjects.count)
        }
    }

    /// Newly-unlocked badges the user hasn't seen celebrated yet.
    var uncelebratedUnlocks: [AchievementStatus] {
        achievementStatuses.filter {
            $0.unlocked && !progress.state.celebratedAchievementIds.contains($0.id)
        }
    }

    /// Loads the bundled content pack. A broken pack is a build-time content
    /// bug: crash loudly in DEBUG, degrade to an unvalidated load in Release.
    static func bootstrap() -> AppSession {
        do {
            return AppSession(content: try ContentLoader.loadValidated())
        } catch {
            #if DEBUG
            fatalError("ContentPack failed to load: \(error)")
            #else
            // Last resort: load without validation; decoding errors here would
            // mean a truncated bundle, which Apple's install pipeline prevents.
            guard let content = try? ContentLoader.load() else {
                preconditionFailure("ContentPack unreadable: \(error)")
            }
            return AppSession(content: content)
            #endif
        }
    }

    // MARK: - Profile persistence

    private static let profileKey = "profile.v1"

    private static func loadProfile() -> UserProfile {
        guard let data = UserDefaults.standard.data(forKey: profileKey),
              let profile = try? JSONDecoder().decode(UserProfile.self, from: data) else {
            return UserProfile()
        }
        return profile
    }

    private static func persist(_ profile: UserProfile) {
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
    }
}
