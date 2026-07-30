import UIKit

/// Window-level tap recognizer: any tap outside a text field dismisses the
/// keyboard, app-wide (sheets and covers included). `cancelsTouchesInView =
/// false` keeps every button/control working normally.
@MainActor
final class KeyboardDismissGesture: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGesture()
    private static let gestureName = "keyboard.dismiss.tap"

    func install() {
        guard let window = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first else { return }
        guard window.gestureRecognizers?.contains(where: { $0.name == Self.gestureName }) != true else { return }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.cancelsTouchesInView = false
        tap.name = Self.gestureName
        tap.delegate = self
        window.addGestureRecognizer(tap)
    }

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        // Don't fight a tap that lands on a text input.
        if let view = gesture.view?.hitTest(gesture.location(in: gesture.view), with: nil),
           view is UITextField || view is UITextView {
            return
        }
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        true
    }
}
