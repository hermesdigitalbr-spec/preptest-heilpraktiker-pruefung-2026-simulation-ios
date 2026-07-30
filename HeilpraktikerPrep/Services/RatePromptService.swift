import Foundation
import StoreKit
import UIKit

/// Asks for an App Store review at chosen moments:
/// - after every *completed* Quick quiz (quitting mid-quiz never prompts);
/// - once, for a premium user, right after their first completed quiz as
///   premium (highest-intent moment for someone who never saw the prompt land).
/// Our side throttles to once per 14 days; Apple caps at 3 shown per year and
/// gives no callback about whether the user actually rated.
@MainActor
enum RatePromptService {
    private static let lastPromptKey = "ratePrompt.lastDate.v1"
    private static let premiumPromptKey = "ratePrompt.premiumAsked.v1"
    private static let launchAskedKey = "ratePrompt.launchAsked.v1"
    private static let cooldownDays = 14.0

    /// Asks for a review the very first time the app is opened (first real
    /// entry into Home after onboarding). Fires once, ever, regardless of the
    /// shared cooldown — this is a separate, one-shot entry point from
    /// `maybeRequestAfterQuiz`.
    static func maybeRequestAtLaunch() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: launchAskedKey) else { return }
        defaults.set(true, forKey: launchAskedKey)
        // Still respect the shared cooldown/lastPromptKey bookkeeping used by
        // maybeRequestAfterQuiz, so a launch prompt doesn't get immediately
        // followed by a quiz-completion prompt.
        defaults.set(Date.now, forKey: lastPromptKey)
        requestReview()
    }

    /// A quiz must be this answered to count as a "proud moment" worth a prompt —
    /// skipping through a 50-question mock shouldn't burn an App Store slot.
    private static let minCompletionRatio = 0.8

    static func maybeRequestAfterQuiz(mode: QuizMode, finishedNaturally: Bool,
                                      answered: Int, total: Int, isPro: Bool) {
        guard finishedNaturally else { return }
        guard total > 0, Double(answered) / Double(total) >= minCompletionRatio else { return }
        let defaults = UserDefaults.standard

        // One-shot: first completed quiz (any mode) after becoming premium.
        if isPro && !defaults.bool(forKey: premiumPromptKey) {
            defaults.set(true, forKey: premiumPromptKey)
            defaults.set(Date.now, forKey: lastPromptKey)
            requestReview()
            return
        }

        // Quick 10 and a completed Mock Exam are the two proudest moments.
        guard mode == .quick10 || mode == .mock else { return }
        if let last = defaults.object(forKey: lastPromptKey) as? Date,
           Date.now.timeIntervalSince(last) < cooldownDays * 86_400 {
            return
        }
        defaults.set(Date.now, forKey: lastPromptKey)
        requestReview()
    }

    private static func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
