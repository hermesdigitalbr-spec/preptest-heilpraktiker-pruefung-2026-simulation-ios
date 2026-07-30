import SwiftUI

/// Tactile press feedback for any tappable surface — a subtle scale + opacity
/// dip while pressed, the kinesthetic confirmation that makes iOS feel premium.
/// Honors Reduce Motion (skips the scale). Use via `.buttonStyle(.pressable)`.
struct PressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? scale : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(AppMotion.snap, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableStyle {
    static var pressable: PressableStyle { PressableStyle() }
}
