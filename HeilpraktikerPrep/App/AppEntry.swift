import SwiftUI

@main
struct HeilpraktikerPrepApp: App {
    @State private var session = HeilpraktikerPrepApp.makeSession()
    @Environment(\.scenePhase) private var scenePhase

    private static func makeSession() -> AppSession {
        let session = AppSession.bootstrap()
        // Face detection for every people photo, off the main thread, so the
        // paywall grid is already cropped around faces when it appears.
        let niche = session.pack.nicheConfig
        FaceRegionStore.shared.warmUp(students: OnboardingPhotos.all(count: niche.studentPhotoCount),
                                      hero: niche.heroImage)
        #if DEBUG
        if ScreenshotMode.isActive { ScreenshotMode.seed(session) }
        // Lets the funnel be walked end to end under `simctl`, where StoreKit
        // returns no products and the paywall would otherwise render empty.
        let info = ProcessInfo.processInfo
        if info.arguments.contains("-onboardingDebugPrices")
            || info.environment["ONBOARDING_DEBUG_PRICES"] != nil {
            DebugPrices.apply(to: session.iap, language: session.pack.language)
        }
        #endif
        return session
    }

    @ViewBuilder
    private var rootView: some View {
        if session.profile.hasCompletedOnboarding {
            MainTabView()
        } else {
            OnboardingView()
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                #if DEBUG
                if ScreenshotMode.isActive {
                    ScreenshotMode.root(session)
                } else {
                    rootView
                }
                #else
                rootView
                #endif
            }
            .animation(AppMotion.smooth, value: session.profile.hasCompletedOnboarding)
            .environment(session)
            // The pack ships in one language; dates and numbers have to follow
            // it, or a pt-BR interface renders "October" on an English phone.
            .environment(\.locale, Locale(identifier: session.pack.language))
            .onAppear {
                KeyboardDismissGesture.shared.install()
                Self.applyTheme(session.settings.theme)
                session.maintainStreak()
                session.publishWidgetSnapshot()
                session.refreshLapseReminder()
            }
            .onChange(of: session.settings.theme) { _, theme in
                Self.applyTheme(theme)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    session.maintainStreak()
                    session.publishWidgetSnapshot()
                    session.refreshLapseReminder()
                }
            }
            .onOpenURL { url in
                // Widget deep link: heilpraktiker://daily. Only honor it once the user
                // is past onboarding — otherwise the flag survives and abruptly
                // launches the daily quiz the moment onboarding finishes.
                if url.scheme == "heilpraktiker", url.host == "daily",
                   session.profile.hasCompletedOnboarding {
                    session.pendingDailyLaunch = true
                }
            }
        }
    }

    /// Theme applied at the window level so every presentation — onboarding,
    /// sheets, full-screen covers — follows it, not just the tab view.
    @MainActor
    private static func applyTheme(_ theme: AppSettings.Theme) {
        let style: UIUserInterfaceStyle = switch theme {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
            }
        }
    }
}
