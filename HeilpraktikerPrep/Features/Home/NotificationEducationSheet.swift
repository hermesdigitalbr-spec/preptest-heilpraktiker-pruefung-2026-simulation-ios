import SwiftUI

/// Shown when the user wants reminders but has already denied the system
/// prompt. iOS will never show that prompt again, so the only way through is
/// the Settings app — and most people don't know where the switch lives.
/// This sheet says exactly what they'll find there, then takes them.
struct NotificationEducationSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    /// True when iOS has already been told "no": the only road is Settings,
    /// so the three steps are shown and the button opens them. False when the
    /// system prompt has never been shown: no steps, and the button raises it.
    var deniedBefore = true
    /// Runs when the user opts in from the not-yet-asked variant.
    var onEnable: () -> Void = {}

    private var strings: UIStrings.Settings { session.strings.settings }

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            illustration
                .padding(.top, AppSpacing.xl)

            VStack(spacing: AppSpacing.sm) {
                Text(strings.notifEducationTitle)
                    .font(AppFont.display(26))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(strings.notifEducationBody)
                    .font(AppFont.body(16))
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, AppSpacing.md)
            }

            // The steps are always shown: they are what the user will need the
            // moment they say no to the prompt, and they explain the ask.
            steps
                .padding(.top, AppSpacing.xs)

            PrimaryCTAButton(title: deniedBefore ? strings.notifEducationCta : strings.notifEducationEnableCta) {
                Haptics.tap(.light)
                if deniedBefore, let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                } else {
                    onEnable()
                }
                dismiss()
            }
            Button(strings.notifEducationLater) { dismiss() }
                .font(AppFont.bodyMedium(16))
                .foregroundStyle(AppColor.accent)
                .padding(.bottom, AppSpacing.sm)
        }
        .padding(.horizontal, OnboardingTokens.gutter)
        .padding(.bottom, AppSpacing.md)
        .background(AppColor.background.ignoresSafeArea())
        // Sized to its content — a full-height sheet left half of it empty.
        .presentationDetents([.height(Self.sheetHeight)])
        .presentationDragIndicator(.visible)
    }

    private static let sheetHeight: CGFloat = 610

    /// A phone with a bell bubble — the two things the steps below talk about.
    private var illustration: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColor.accent.opacity(0.85))
                .frame(width: 74, height: 118)
                .overlay(alignment: .top) {
                    Capsule().fill(Color.white.opacity(0.35)).frame(width: 26, height: 5).padding(.top, 8)
                }
            Image(systemName: "bell.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(AppColor.warning)
                .frame(width: 56, height: 56)
                .background(Color(hexString: "#6C5CE7"), in: Circle())
                .offset(x: 26, y: 30)
        }
        .padding(.trailing, 26)
        .accessibilityHidden(true)
    }

    /// The exact three taps, worded the way iOS labels them.
    private var steps: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            step(strings.notifEducationStep1Prefix, strings.notifEducationStep1Bold, strings.notifEducationStep1Suffix)
            step(strings.notifEducationStep2Prefix, strings.notifEducationStep2Bold, "")
            HStack {
                step(strings.notifEducationStep3Prefix, strings.notifEducationStep3Bold, "")
                Spacer()
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .tint(AppColor.success)
                    .allowsHitTesting(false)
            }
        }
        .padding(AppSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surfaceHigh, in: RoundedRectangle(cornerRadius: AppRadius.hero))
    }

    private func step(_ prefix: String, _ bold: String, _ suffix: String) -> some View {
        (Text(prefix + " ").font(AppFont.body(17))
            + Text(bold).font(AppFont.heading(17))
            + Text(suffix.isEmpty ? "" : " " + suffix).font(AppFont.body(17)))
            .foregroundStyle(AppColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
