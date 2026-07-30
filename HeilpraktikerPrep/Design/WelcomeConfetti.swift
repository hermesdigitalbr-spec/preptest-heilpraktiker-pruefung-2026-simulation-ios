// WelcomeConfetti.swift — one-time welcome confetti shown on the Home screen
// right after onboarding finishes (regardless of whether the paywall
// converted, was exited via the exit-intent offer, or the free path was
// taken).

import SwiftUI
import Lottie

enum WelcomeConfetti {
    /// Set by OnboardingModel.complete(into:) when onboarding finishes;
    /// consumed by HomeView on its first appearance.
    static let pendingKey = "welcome.confetti.pending"

    static func consumePending() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: pendingKey) else { return false }
        defaults.set(false, forKey: pendingKey)
        return true
    }
}

/// Non-interactive overlay that plays the confetti once and removes itself.
struct WelcomeConfettiOverlay: View {

    @Binding var isPlaying: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if isPlaying && !reduceMotion {
            LottieView(animation: .named("ConfettiWelcome"))
                .playing(loopMode: .playOnce)
                .animationDidFinish { _ in isPlaying = false }
                .allowsHitTesting(false)
                .ignoresSafeArea()
                .accessibilityHidden(true)
        }
    }
}
