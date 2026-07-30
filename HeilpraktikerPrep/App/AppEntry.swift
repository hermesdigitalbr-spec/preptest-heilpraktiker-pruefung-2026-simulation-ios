import SwiftUI

@main
struct HeilpraktikerPrepApp: App {
    @State private var session = HeilpraktikerPrepApp.makeSession()
    @Environment(\.scenePhase) private var scenePhase

    private static func makeSession() -> AppSession {
        let session = AppSession.bootstrap()
        #if DEBUG
        if ScreenshotMode.isActive { ScreenshotMode.seed(session) }
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
