import Foundation
import Observation
import UserNotifications

enum OnboardingStep: Hashable {
    case intro
    case state
    case examDate
    case name
    case motivation
    case firstTime
    case affirmation
    case level
    case rightPlace
    case reviews
    case minutes
    case personalizing
    case planReady
}

/// Draft answers + step machine for the onboarding funnel. Nothing touches the
/// real UserProfile until `complete(into:)` at the very end.
@MainActor
@Observable
final class OnboardingModel {
    let steps: [OnboardingStep]
    private(set) var index = 0

    // Draft answers
    var name = ""
    var level: UserProfile.Level?
    var motivation: String?
    /// 0 = first attempt, 1 = has taken the exam before.
    var firstTime: Int?
    var minutes: Int?
    var studyDays: Set<Int> = [2, 3, 4, 5, 6]
    var preferredHour: Double = 18
    var stateId: String?
    var examDate: Date?
    /// True once the notification prompt has been shown, whatever the answer.
    var askedForPush = false

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

    /// Trimmed first name, nil when the step was skipped or left blank.
    var displayName: String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Urgency band for the chosen exam date.
    var pace: StudyPace? { daysUntilExam.map(StudyPace.forDays) }

    /// Funnel order (protótipo aprovado 2026-09-11): abertura → estado → data
    /// da prova (a âncora de urgência) → nome → motivação → histórico →
    /// afirmação → nível → prova social (lugar certo + avaliações) →
    /// compromisso diário (minutos + permissão de notificação) → plano →
    /// paywall.
    init(hasRegions: Bool) {
        var flow: [OnboardingStep] = [.intro]
        if hasRegions { flow.append(.state) }
        flow.append(contentsOf: [
            .examDate,
            .name,
            .motivation,
            .firstTime,
            .affirmation,
            .level,
            .rightPlace,
            .reviews,
            .minutes,
            .personalizing,
            .planReady,
        ])
        steps = flow
    }

    var current: OnboardingStep { steps[index] }

    var progress: Double {
        let linear = Double(index + 1) / Double(steps.count)
        // VSL curve: early steps fill the bar fast, later ones barely move it.
        return pow(linear, 0.55)
    }

    /// The intro and the finished plan carry no chrome; the building screen
    /// keeps the progress bar (but not the back arrow) so the funnel still
    /// reads as moving forward.
    var showsChrome: Bool {
        switch current {
        case .intro, .planReady: false
        default: true
        }
    }

    var canGoBack: Bool {
        index > 0 && current != .personalizing && current != .planReady
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
        profile.name = displayName
        profile.level = level
        profile.motivation = motivation
        profile.dailyMinutes = minutes
        profile.studyDays = studyDays
        profile.preferredHour = Int(preferredHour)
        profile.stateId = stateId
        if let examDate {
            profile.examDate = examDate
            profile.examDateSetAt = .now
        }
        profile.hasCompletedOnboarding = true
        profile.onboardingCompletedAt = .now

        // Single funnel completion point — runs whether the paywall converted,
        // was exited via the exit-intent offer, or the free path was taken.
        // Home reads this on first appearance to play the welcome confetti.
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

        // Permission was requested on the minutes step; if it was granted,
        // schedule the daily reminder (and the exam countdown) silently.
        let strings = session.strings.settings
        let hour = Int(preferredHour)
        let date = examDate
        Task {
            let center = UNUserNotificationCenter.current()
            let status = await center.notificationSettings().authorizationStatus
            guard status == .authorized || status == .provisional || status == .ephemeral else { return }
            session.settings.notificationsEnabled = true
            _ = await NotificationService.enableDailyReminder(
                hour: hour, minute: 0,
                title: strings.reminderNotificationTitle,
                body: strings.reminderNotificationBody,
                openSettingsIfDenied: false)
            if let date {
                await NotificationService.scheduleExamCountdowns(examDate: date, strings: strings)
            }
        }
    }
}
