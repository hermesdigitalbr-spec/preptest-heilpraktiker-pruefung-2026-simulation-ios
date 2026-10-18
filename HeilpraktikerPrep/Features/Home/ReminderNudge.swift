import SwiftUI
import UserNotifications

/// A second, quieter chance to turn on reminders for people who said no (or
/// nothing) during onboarding.
///
/// It waits a couple of days before appearing, asks once per long cooldown, and
/// can be dismissed — the system prompt itself is a one-shot, so the only
/// honest way to re-ask is to send the user to Settings once they've denied it.
@MainActor
struct ReminderNudge: View {
    @Environment(AppSession.self) private var session

    @State private var status: UNAuthorizationStatus?
    @State private var dismissed = false
    @State private var showEducation = false

    /// Don't ask before the habit has had a chance to form.
    private static let minimumDaysInstalled = 2.0
    private static let cooldownDays = 21.0
    private static let dismissedKey = "reminderNudge.dismissedAt.v1"

    private var strings: UIStrings.Settings { session.strings.settings }

    var body: some View {
        if shouldShow {
            content
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var shouldShow: Bool {
        guard !dismissed, !session.settings.notificationsEnabled else { return false }
        guard let status, status == .notDetermined || status == .denied else { return false }
        if let finished = session.profile.onboardingCompletedAt,
           Date.now.timeIntervalSince(finished) < Self.minimumDaysInstalled * 86_400 {
            return false
        }
        if let last = UserDefaults.standard.object(forKey: Self.dismissedKey) as? Date,
           Date.now.timeIntervalSince(last) < Self.cooldownDays * 86_400 {
            return false
        }
        return true
    }

    private var content: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColor.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(strings.reminderNudgeTitle)
                    .font(AppFont.heading(15))
                    .foregroundStyle(AppColor.textPrimary)
                Text(strings.reminderNudgeBody)
                    .font(AppFont.body(13))
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: AppSpacing.xs)
            Button(strings.reminderNudgeCta) { enable() }
                .font(AppFont.heading(14))
                .foregroundStyle(AppColor.accent)
            Button {
                dismissForNow()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppColor.textDim)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface, in: RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
            .stroke(AppColor.border, lineWidth: 1))
        .task { status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus }
        .sheet(isPresented: $showEducation, onDismiss: { dismissForNow() }) {
            NotificationEducationSheet()
        }
    }

    /// `notDetermined` still gets the real system prompt; `denied` can only be
    /// undone in Settings, and `enableDailyReminder` opens it.
    private func enable() {
        Haptics.tap(.light)
        // Denied before: the system prompt is gone for good, so explain the
        // Settings path instead of dropping the user there unannounced.
        if status == .denied {
            showEducation = true
            return
        }
        let hour = session.settings.reminderHour
        Task {
            let result = await NotificationService.enableDailyReminder(
                hour: hour, minute: session.settings.reminderMinute,
                title: strings.reminderNotificationTitle,
                body: strings.reminderNotificationBody)
            if case .granted = result {
                session.settings.notificationsEnabled = true
                Haptics.success()
                if let date = session.profile.examDate {
                    await NotificationService.scheduleExamCountdowns(examDate: date, strings: strings)
                }
            }
            status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            withAnimation(AppMotion.smooth) { dismissed = true }
        }
    }

    private func dismissForNow() {
        UserDefaults.standard.set(Date.now, forKey: Self.dismissedKey)
        withAnimation(AppMotion.smooth) { dismissed = true }
    }
}
