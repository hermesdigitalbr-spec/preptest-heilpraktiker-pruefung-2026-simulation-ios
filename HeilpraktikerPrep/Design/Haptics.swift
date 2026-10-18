import UIKit

/// One vocabulary for touch feedback so the whole funnel feels consistent:
/// a *selection* tick when a choice is registered, a *tap* thud on a primary
/// action, and *success* / *warning* reserved for moments that report a result.
@MainActor
enum Haptics {
    private static let selection = UISelectionFeedbackGenerator()
    private static let notification = UINotificationFeedbackGenerator()

    /// Call just before a run of feedback so the Taptic Engine is awake and the
    /// first tick isn't swallowed.
    static func prepare() {
        selection.prepare()
        notification.prepare()
    }

    /// Picking an option, changing a plan, landing on a new wheel value.
    static func select() {
        selection.selectionChanged()
        selection.prepare()
    }

    /// A primary action the user committed to.
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    /// The big one — reserved for the affirmation screen. A success chime
    /// followed by a heavy thud, so it lands as a moment and not a tick.
    static func celebrate() {
        notification.notificationOccurred(.success)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            heavy.impactOccurred(intensity: 1.0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            heavy.impactOccurred(intensity: 0.8)
        }
    }

    /// Something finished well: the plan is built, the confetti screen lands.
    static func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    /// A gentle "careful": the chosen pace doesn't fit the exam date.
    static func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }
}
