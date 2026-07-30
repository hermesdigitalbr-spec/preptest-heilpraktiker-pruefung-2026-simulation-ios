import Foundation
import Observation
import UserNotifications

enum OnboardingStep: Hashable {
    case intro
    case value1, value2
    case level, goal, taken, concern
    case pain
    case minutes, days, time
    case state
    case examDate, streakGoal, subjects, notif
    case personalizing, planReady
}

/// Draft answers + step machine for the onboarding funnel. Nothing touches the
/// real UserProfile until `complete(into:)` at the very end.
@MainActor
@Observable
final class OnboardingModel {
    let steps: [OnboardingStep]
    private(set) var index = 0

    // Draft answers
    var level: UserProfile.Level?
    var goal: UserProfile.Goal?
    var takenBefore: Int?
    var concern: Int?
    var minutes: Int?
    var studyDays: Set<Int> = [2, 3, 4, 5, 6]
    var preferredHour: Double = 18
    var stateId: String?
    var examDate: Date?
    var streakGoal: Int?
    /// Days until the chosen exam date (nil when no date picked).
    var daysUntilExam: Int? {
        guard let examDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: .now),
            to: calendar.startOfDay(for: examDate)).day ?? 0
        return days > 0 ? days : nil
    }
    var weakSubjects: Set<String> = []

    /// Funnel order (playbook): hook → instant personalization (state + exam
    /// date = the urgency anchor) → qualification (ability → history →
    /// motivation → fear) → pain mirror → method → weak topics (bridges from
    /// "we bring back what you miss") → commitment block (minutes/days/time/
    /// streak/reminder, kept contiguous) → plan → paywall.
    init(hasRegions: Bool) {
        var flow: [OnboardingStep] = [
            .intro,
            .value1, .value2,
        ]
        if hasRegions {
            flow.append(.state)
        }
        flow.append(contentsOf: [
            .examDate,
            .level, .taken, .goal, .concern,
            .pain,
            .subjects,
            .minutes, .days, .time,
            .streakGoal,
            .notif,
            .personalizing, .planReady,
        ])
        steps = flow
    }

    var current: OnboardingStep { steps[index] }

    var progress: Double {
        let linear = Double(index + 1) / Double(steps.count)
        // VSL curve: early steps fill the bar fast, later ones barely move it.
        return pow(linear, 0.55)
    }

    /// Skip is offered only on question steps — never on marketing/system pages.
    var isSkippable: Bool {
        switch current {
        case .level, .goal, .taken, .concern, .minutes, .days, .time,
             .state, .examDate, .streakGoal, .subjects:
            true
        default:
            false
        }
    }

    var canGoBack: Bool {
        index > 0 && current != .personalizing
    }

    func advance() {
        guard index + 1 < steps.count else { return }
        index += 1
    }

    func back() {
        guard canGoBack else { return }
        index -= 1
    }

    /// Persists everything into the live profile and schedules the reminder.
    func complete(into session: AppSession) {
        var profile = session.profile
        profile.level = level
        profile.goal = goal
        profile.dailyMinutes = minutes
        profile.studyDays = studyDays
        profile.preferredHour = Int(preferredHour)
        profile.stateId = stateId
        profile.streakGoal = streakGoal
        profile.weakSubjectIds = weakSubjects
        if let examDate {
            profile.examDate = examDate
            profile.examDateSetAt = .now
        }
        profile.hasCompletedOnboarding = true

        // Single funnel completion point — runs whether the paywall
        // converted, was exited via the exit-intent offer, or the free path
        // was taken. The Home screen reads this on first appearance to play
        // the one-time welcome confetti.
        UserDefaults.standard.set(true, forKey: WelcomeConfetti.pendingKey)

        let plan = PlanGenerator.makePlan(
            profile: profile,
            totalQuestions: session.content.questions.count,
            defaultDailyCount: session.pack.dailyQuestionsCount,
            today: .now,
            calendar: .current)
        profile.planQuestionsPerDay = plan.questionsPerDay

        session.profile = profile

        session.settings.reminderHour = Int(preferredHour)
        // If the user already granted permission (e.g. via exam date countdown step),
        // schedule the daily reminder silently — no dialog needed.
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            if status == .authorized || status == .provisional || status == .ephemeral {
                session.settings.notificationsEnabled = true
                _ = await NotificationService.enableDailyReminder(
                    hour: Int(preferredHour),
                    minute: 0,
                    title: session.strings.settings.reminderNotificationTitle,
                    body: session.strings.settings.reminderNotificationBody)
            }
        }
    }
}
