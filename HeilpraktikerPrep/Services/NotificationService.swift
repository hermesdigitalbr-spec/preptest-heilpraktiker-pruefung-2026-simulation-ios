import Foundation
import UIKit
import UserNotifications

/// Local-only notifications: one daily practice reminder.
enum NotificationService {
    private static let reminderId = "daily.practice.reminder"

    enum EnableResult {
        case granted      // dialog shown and approved, or was already authorized
        case denied       // previously denied — opened Settings for the user
        case failed       // scheduling error after authorization
    }

    /// Requests permission (if not yet determined) and schedules the daily reminder.
    /// If already denied, opens the system Settings page instead of silently failing.
    @MainActor
    static func enableDailyReminder(hour: Int, minute: Int = 0, title: String, body: String) async -> EnableResult {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus

        switch status {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return .denied }
        case .authorized, .provisional, .ephemeral:
            break  // already good — just reschedule
        case .denied:
            // System won't show the dialog again; send user to Settings.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return .denied
        @unknown default:
            return .denied
        }

        return await schedule(hour: hour, minute: minute, title: title, body: body, center: center)
    }

    private static func schedule(hour: Int, minute: Int, title: String, body: String,
                                  center: UNUserNotificationCenter) async -> EnableResult {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute

        let request = UNNotificationRequest(
            identifier: reminderId,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true))

        center.removePendingNotificationRequests(withIdentifiers: [reminderId])
        do {
            try await center.add(request)
            return .granted
        } catch {
            return .failed
        }
    }

    static func disableDailyReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderId])
    }

    // MARK: - Lapse re-engagement

    private static let lapseId = "lapse.reengage"

    /// Schedules a one-shot "come back" nudge at `fireDate`, replacing any
    /// previous one. Only schedules if notifications are ALREADY authorized —
    /// this is a silent background nudge, never a moment to prompt. A fire date
    /// in the past (or under a minute away) is skipped.
    @MainActor
    static func scheduleLapseReminder(fireDate: Date, title: String, body: String) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional || status == .ephemeral else {
            center.removePendingNotificationRequests(withIdentifiers: [lapseId])
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: [lapseId])
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 60 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: lapseId,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        try? await center.add(request)
    }

    static func cancelLapseReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [lapseId])
    }

    // MARK: - Exam countdown notifications

    private static let countdownIds = ["exam.30d", "exam.14d", "exam.7d", "exam.3d", "exam.day"]

    /// Pure, testable selection: which countdown ids fire (and on what day) for an
    /// exam on `examDate` relative to `now`. Each fires at 08:00 on its day; days
    /// strictly before today are skipped. The guard is `fireDay >= today`, so a
    /// same-day reminder (e.g. the exam set to today → "exam.day") still schedules.
    static func examCountdownFireDays(examDate: Date, now: Date = .now,
                                      calendar: Calendar = .current) -> [(id: String, fireDay: Date)] {
        let today = calendar.startOfDay(for: now)
        let examDay = calendar.startOfDay(for: examDate)
        let offsets: [(days: Int, id: String)] = [
            (30, "exam.30d"), (14, "exam.14d"), (7, "exam.7d"), (3, "exam.3d"), (0, "exam.day"),
        ]
        return offsets.compactMap { offset in
            guard let fireDay = calendar.date(byAdding: .day, value: -offset.days, to: examDay),
                  fireDay >= today else { return nil }
            return (offset.id, fireDay)
        }
    }

    /// Requests authorization if needed, then schedules (or reschedules) the five
    /// exam-day countdown notifications. Silently skips any date already in the past.
    @MainActor
    static func scheduleExamCountdowns(examDate: Date, strings: UIStrings.Settings) async {
        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus

        switch status {
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            guard granted else { return }
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return
        }

        center.removePendingNotificationRequests(withIdentifiers: countdownIds)

        let calendar = Calendar.current
        let copy: [String: (title: String, body: String)] = [
            "exam.30d": (strings.examNotif30DayTitle, strings.examNotif30DayBody),
            "exam.14d": (strings.examNotif14DayTitle, strings.examNotif14DayBody),
            "exam.7d":  (strings.examNotif7DayTitle,  strings.examNotif7DayBody),
            "exam.3d":  (strings.examNotif3DayTitle,  strings.examNotif3DayBody),
            "exam.day": (strings.examNotifDayTitle,   strings.examNotifDayBody),
        ]

        for (id, fireDay) in examCountdownFireDays(examDate: examDate, calendar: calendar) {
            guard let text = copy[id] else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: fireDay)
            components.hour = 8
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = text.title
            content.body = text.body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: id,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            try? await center.add(request)
        }
    }
}
