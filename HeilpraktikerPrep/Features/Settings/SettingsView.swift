import AuthenticationServices
import SwiftUI
import StoreKit

struct SettingsView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.horizontalSizeClass) private var hSize

    @State private var showResetConfirm = false
    @State private var showDeleteAccountConfirm = false
    @State private var showExamDatePicker = false
    @State private var showQuizModeSheet = false
    @State private var showStatePicker = false
    @State private var pendingRegion: Region?
    #if DEBUG
    @State private var showOnboardingResetAlert = false
    @State private var showDebugPaywall = false
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
                Text(session.strings.settings.title)
                    .font(AppFont.display(28))
                    .foregroundStyle(AppColor.textPrimary)

                practiceBlock
                accountBlock
                appearanceBlock
                generalBlock
                dangerBlock

                #if DEBUG
                debugBlock
                #endif

                footer
            }
            .padding(AppSpacing.screenMargin)
            .readableWidth(AppLayout.readableNarrow, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .alert(session.strings.settings.resetConfirmTitle, isPresented: $showResetConfirm) {
            Button(session.strings.settings.resetProgress, role: .destructive) {
                session.resetProgress()
            }
            Button(session.strings.common.cancel, role: .cancel) {}
        } message: {
            Text(session.strings.settings.resetConfirmMessage)
        }
        .alert(session.strings.settings.deleteAccountConfirmTitle, isPresented: $showDeleteAccountConfirm) {
            Button(session.strings.settings.deleteAccountConfirmButton, role: .destructive) {
                // No server-side account exists: delete the stored Apple identity
                // and wipe all associated study data so nothing user-shared remains.
                session.auth.deleteAccount()
                session.resetProgress()
            }
            Button(session.strings.common.cancel, role: .cancel) {}
        } message: {
            Text(session.strings.settings.deleteAccountConfirmMessage)
        }
        .sheet(isPresented: $showExamDatePicker) {
            // On iPad the .medium form-sheet height clips the tall graphical
            // calendar, so use the full form sheet there; iPhone keeps .medium.
            examDateSheet.presentationDetents(hSize == .regular ? [.large] : [.medium])
        }
        .sheet(isPresented: $showQuizModeSheet) {
            quizModeSheet.presentationDetents([.medium])
        }
        .sheet(isPresented: $showStatePicker) {
            statePickerSheet
        }
        // Confirm before swapping the state: question pool changes, which
        // could surprise a user who picked the row by mistake.
        .alert(session.strings.settings.stateChangeTitle,
               isPresented: Binding(get: { pendingRegion != nil },
                                    set: { if !$0 { pendingRegion = nil } })) {
            Button(session.strings.settings.stateChangeConfirm) {
                if let region = pendingRegion {
                    session.profile.stateId = region.id
                    UISelectionFeedbackGenerator().selectionChanged()
                }
                pendingRegion = nil
            }
            Button(session.strings.common.cancel, role: .cancel) {
                pendingRegion = nil
            }
        } message: {
            Text(String(format: session.strings.settings.stateChangeMessageFormat,
                        pendingRegion?.name ?? ""))
        }
    }

    // MARK: - Exam state

    private var stateLabel: String {
        guard let stateId = session.profile.stateId,
              let region = session.pack.regions?.first(where: { $0.id == stateId }) else { return "—" }
        return region.name
    }

    private var statePickerSheet: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(session.strings.settings.examState)
                .font(AppFont.heading(22))
                .foregroundStyle(AppColor.textPrimary)
            RegionPickerList(
                regions: session.pack.regions ?? [],
                searchPlaceholder: session.strings.onboarding.stateSearch,
                selectedId: session.profile.stateId
            ) { region in
                showStatePicker = false
                // Skip the confirm when the user re-picks their current state.
                guard region.id != session.profile.stateId else { return }
                pendingRegion = region
            }
        }
        .padding(AppSpacing.screenMargin)
        .background(AppColor.background.ignoresSafeArea())
    }

    // MARK: - Practice

    private var practiceBlock: some View {
        SettingsBlock(title: session.strings.settings.practiceSection) {
            SettingsTile(symbol: "rectangle.stack.fill", tint: AppColor.accent,
                         title: session.strings.settings.quizModeTitle,
                         valuePill: modeName(session.settings.feedbackMode)) {
                showQuizModeSheet = true
            }

            SettingsTile(symbol: "calendar", tint: Color(hexString: "#23A566"),
                         title: session.strings.settings.examDate,
                         valuePill: examDateLabel) {
                showExamDatePicker = true
            }

            if !(session.pack.regions ?? []).isEmpty {
                SettingsTile(symbol: "mappin.and.ellipse", tint: Color(hexString: "#2FB8C5"),
                             title: session.strings.settings.examState,
                             valuePill: stateLabel) {
                    showStatePicker = true
                }
            }

            HStack(spacing: AppSpacing.md) {
                SettingsGlyph(symbol: "bell.fill", tint: Color(hexString: "#F25C54"))
                Text(session.strings.settings.notifications)
                    .font(AppFont.bodyMedium(17))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { session.settings.notificationsEnabled },
                    set: { toggleReminder($0) }))
                    .labelsHidden()
                    .tint(AppColor.accent)
            }
            .padding(.vertical, AppSpacing.xs)

            if session.settings.notificationsEnabled {
                // Nested sub-row: connected to the toggle above by an accent rail.
                HStack(spacing: AppSpacing.md) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColor.accentSoft)
                        .frame(width: 3)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppColor.textDim)
                    Text(session.strings.settings.reminderTime)
                        .font(AppFont.body(15))
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    DatePicker("", selection: reminderTimeBinding, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(AppColor.accent)
                }
                .padding(.leading, AppSpacing.sm)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(AppMotion.smooth, value: session.settings.notificationsEnabled)
    }

    // MARK: - Account (Sign in with Apple)

    @ViewBuilder
    private var accountBlock: some View {
        SettingsBlock(title: session.strings.settings.signInTitle) {
            if session.auth.isSignedIn {
                signedInRow
            } else {
                signInRow
            }
        }
    }

    private var signInRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(session.strings.settings.signInSubtitle)
                .font(AppFont.body(15))
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            // Apple-provided button — required visual; tinted to the system
            // appearance so light/dark mode both look native.
            SignInWithAppleButton(.signIn,
                                  onRequest: { $0.requestedScopes = [.fullName] },
                                  onCompletion: { session.auth.handle(result: $0) })
                .signInWithAppleButtonStyle(session.settings.theme == .dark ? .white : .black)
                .frame(height: 48)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
    }

    private var signedInRow: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.md) {
                SettingsGlyph(symbol: "checkmark.seal.fill", tint: AppColor.success)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: session.strings.settings.signedInFormat,
                                session.auth.displayName ?? "Apple ID"))
                        .font(AppFont.bodyMedium(17))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                }
                Spacer()
                Button(session.strings.settings.signOut) {
                    session.auth.signOut()
                }
                .font(AppFont.bodyMedium(15))
                .foregroundStyle(AppColor.accent)
            }

            Divider()

            // Required by App Store Guideline 5.1.1(v): users who can create an
            // account (Sign in with Apple) must be able to delete it in-app.
            Button(role: .destructive) {
                showDeleteAccountConfirm = true
            } label: {
                Text(session.strings.settings.deleteAccount)
                    .font(AppFont.bodyMedium(15))
                    .foregroundStyle(AppColor.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceBlock: some View {
        SettingsBlock(title: session.strings.settings.appearance) {
            HStack(spacing: AppSpacing.sm) {
                themeOption(.system, label: session.strings.settings.system, symbol: "circle.lefthalf.filled")
                themeOption(.light, label: session.strings.settings.light, symbol: "sun.max.fill")
                themeOption(.dark, label: session.strings.settings.dark, symbol: "moon.stars.fill")
            }
        }
    }

    private func themeOption(_ theme: AppSettings.Theme, label: String, symbol: String) -> some View {
        let selected = session.settings.theme == theme
        return Button {
            withAnimation(AppMotion.snap) { session.settings.theme = theme }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(label)
                    .font(AppFont.caption(13))
                    .fontWeight(selected ? .bold : .medium)
            }
            .foregroundStyle(selected ? AppColor.accent : AppColor.textDim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(selected ? AppColor.accentSoft : .clear)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.row)
                    .stroke(selected ? AppColor.accent : AppColor.border, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
        }
        .buttonStyle(.plain)
    }

    // MARK: - General

    private var generalBlock: some View {
        SettingsBlock(title: session.strings.settings.generalSection) {
            SettingsTile(symbol: "arrow.clockwise", tint: AppColor.accent,
                         title: session.strings.settings.restorePurchases) {
                Task { await session.iap.restore() }
            }
            shareTile
            SettingsTile(symbol: "star.fill", tint: Color(hexString: "#F5A623"),
                         title: session.strings.settings.rateApp) {
                requestReview()
            }
            SettingsTile(symbol: "doc.text.fill", tint: Color(hexString: "#8E6FF7"),
                         title: session.strings.settings.termsOfUse) {
                open(session.pack.legal.termsUrl)
            }
            SettingsTile(symbol: "hand.raised.fill", tint: Color(hexString: "#2FB8C5"),
                         title: session.strings.settings.privacyPolicy) {
                open(session.pack.legal.privacyUrl)
            }
        }
    }

    /// Shares the App Store download link (Lei 5). Until the app is registered
    /// on ASC, appStoreUrl is empty and the pack's support page stands in.
    private var shareURL: URL {
        let raw = [session.pack.appStoreUrl, session.pack.legal.supportUrl]
            .compactMap { $0 }
            .first { !$0.isEmpty } ?? session.pack.legal.privacyUrl
        return URL(string: raw) ?? URL(filePath: "/")
    }

    private var shareTile: some View {
        ShareLink(item: shareURL) {
            SettingsTileLabel(symbol: "square.and.arrow.up", tint: Color(hexString: "#F2789F"),
                              title: session.strings.settings.shareApp, valuePill: nil)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Danger

    private var dangerBlock: some View {
        Button {
            showResetConfirm = true
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(session.strings.settings.resetProgress)
                    .font(AppFont.bodyMedium(15))
            }
            .foregroundStyle(AppColor.error)
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.md)
            .background(AppColor.errorSoft)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Footer

    private var footer: some View {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return VStack(spacing: AppSpacing.xs) {
            Image(systemName: "flame.fill")
                .font(.system(size: 16))
                .foregroundStyle(AppColor.warning.opacity(0.7))
            Text("\(session.pack.examName) · \(version) (\(build))")
                .font(AppFont.caption(12))
                .foregroundStyle(AppColor.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.sm)
    }

    // MARK: - Quiz mode

    private func modeName(_ mode: FeedbackMode) -> String {
        switch mode {
        case .learning: session.strings.settings.learningMode
        case .quick: session.strings.settings.quickMode
        case .mock: session.strings.settings.mockMode
        }
    }

    private var quizModeSheet: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            Text(session.strings.settings.quizModeTitle)
                .font(AppFont.heading(22))
                .foregroundStyle(AppColor.textPrimary)

            VStack(alignment: .leading, spacing: AppSpacing.md) {
                modeOption(.learning,
                           title: session.strings.settings.learningMode,
                           description: session.strings.settings.learningModeDesc)
                modeOption(.quick,
                           title: session.strings.settings.quickMode,
                           description: session.strings.settings.quickModeDesc)
                modeOption(.mock,
                           title: session.strings.settings.mockMode,
                           description: session.strings.settings.mockModeDesc)
            }

            PrimaryCTAButton(title: session.strings.common.done) {
                showQuizModeSheet = false
            }
        }
        .padding(AppSpacing.screenMargin)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.ignoresSafeArea())
    }

    private func modeOption(_ mode: FeedbackMode, title: String, description: String) -> some View {
        let selected = session.settings.feedbackMode == mode
        return Button {
            session.settings.feedbackMode = mode
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? AppColor.accent : AppColor.border)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.bodyMedium(17))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(description)
                        .font(AppFont.caption(13))
                        .foregroundStyle(AppColor.textSecondary)
                }
                Spacer()
            }
            .padding(AppSpacing.md)
            .background(selected ? AppColor.accentSoft : AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.row)
                    .stroke(selected ? AppColor.accent : AppColor.border, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Exam date

    private var examDateLabel: String {
        guard let date = session.profile.examDate else { return "—" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: session.pack.language)
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private var examDateSheet: some View {
        VStack(spacing: AppSpacing.lg) {
            DatePicker(
                session.strings.settings.examDate,
                selection: Binding(
                    get: { session.profile.examDate ?? .now },
                    set: {
                        session.profile.examDate = $0
                        session.profile.examDateSetAt = .now
                    }),
                in: Date.now...,
                displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(AppColor.accent)

            PrimaryCTAButton(title: session.strings.common.done) {
                if let date = session.profile.examDate {
                    let strings = session.strings.settings
                    Task { await NotificationService.scheduleExamCountdowns(examDate: date, strings: strings) }
                }
                showExamDatePicker = false
            }
        }
        .padding(AppSpacing.screenMargin)
        .background(AppColor.background.ignoresSafeArea())
    }

    // MARK: - Reminder plumbing

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    bySettingHour: session.settings.reminderHour,
                    minute: session.settings.reminderMinute,
                    second: 0, of: .now) ?? .now
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                session.settings.reminderHour = parts.hour ?? 19
                session.settings.reminderMinute = parts.minute ?? 0
                rescheduleReminder()
            })
    }

    private func rescheduleReminder() {
        guard session.settings.notificationsEnabled else { return }
        Task {
            _ = await NotificationService.enableDailyReminder(
                hour: session.settings.reminderHour,
                minute: session.settings.reminderMinute,
                title: session.strings.settings.reminderNotificationTitle,
                body: session.strings.settings.reminderNotificationBody)
        }
    }

    private func toggleReminder(_ enabled: Bool) {
        if enabled {
            Task {
                let result = await NotificationService.enableDailyReminder(
                    hour: session.settings.reminderHour,
                    minute: session.settings.reminderMinute,
                    title: session.strings.settings.reminderNotificationTitle,
                    body: session.strings.settings.reminderNotificationBody)
                session.settings.notificationsEnabled = (result == .granted)
            }
        } else {
            NotificationService.disableDailyReminder()
            session.settings.notificationsEnabled = false
        }
    }

    // MARK: - Misc helpers

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }

    // MARK: - Debug (DEBUG builds only — compiled out of App Store releases,
    // so hardcoded strings here are intentionally exempt from the
    // no-visible-literals rule)

    #if DEBUG
    private var debugBlock: some View {
        SettingsBlock(title: "🛠 Debug") {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.md) {
                    SettingsGlyph(symbol: "crown.fill", tint: AppColor.warning)
                    Text("Access state")
                        .font(AppFont.bodyMedium(17))
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { session.iap.debugEntitlement },
                        set: { session.iap.debugEntitlement = $0 })) {
                        ForEach(IAPService.DebugEntitlement.allCases) { state in
                            Text(state.label).tag(state)
                        }
                    }
                    .labelsHidden()
                    .tint(AppColor.warning)
                }
                Text(session.iap.debugEntitlement.label)
                    .font(AppFont.caption(12))
                    .foregroundStyle(AppColor.textDim)
            }
            .padding(.vertical, AppSpacing.xs)

            SettingsTile(symbol: "creditcard.fill", tint: AppColor.accent,
                         title: "Preview Paywall") {
                showDebugPaywall = true
            }

            SettingsTile(symbol: "flag.checkered", tint: AppColor.warning,
                         title: "View Onboarding") {
                session.profile.hasCompletedOnboarding = false
                showOnboardingResetAlert = true
            }
        }
        .sheet(isPresented: $showDebugPaywall) {
            PaywallView()
        }
        .alert("Onboarding reset", isPresented: $showOnboardingResetAlert) {
            Button("OK") {}
        } message: {
            Text("Flag zurückgesetzt — das Onboarding (Phase 5) erscheint beim nächsten App-Start.")
        }
    }
    #endif
}

// MARK: - Building blocks (HeilpraktikerPrep visual language, not stock iOS)

/// A floating section card with its title INSIDE, eyebrow-style.
private struct SettingsBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text(title.uppercased())
                .font(AppFont.caption(12))
                .fontWeight(.bold)
                .kerning(1.1)
                .foregroundStyle(AppColor.textDim)
            content
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero))
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardY)
    }
}

/// Soft tinted icon — colored symbol over its own soft background,
/// the same treatment as the Home mode cards and Study subjects.
private struct SettingsGlyph: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 34, height: 34)
            .background(tint.opacity(0.13))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct SettingsTileLabel: View {
    let symbol: String
    let tint: Color
    let title: String
    let valuePill: String?

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            SettingsGlyph(symbol: symbol, tint: tint)
            Text(title)
                .font(AppFont.bodyMedium(17))
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            if let valuePill {
                Text(valuePill)
                    .font(AppFont.caption(13))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColor.surfaceHigh)
                    .clipShape(Capsule())
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColor.textDim.opacity(0.6))
        }
        .padding(.vertical, AppSpacing.xs)
        .contentShape(Rectangle())
    }
}

/// Tappable row inside a SettingsBlock.
private struct SettingsTile: View {
    let symbol: String
    let tint: Color
    let title: String
    var valuePill: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsTileLabel(symbol: symbol, tint: tint, title: title, valuePill: valuePill)
        }
        .buttonStyle(.plain)
    }
}
