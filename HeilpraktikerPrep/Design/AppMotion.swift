import SwiftUI

/// Animation tokens — never use literal `.spring()`/`.easeOut()` in views.
enum AppMotion {
    /// Quick UI response (selection, toggles).
    static let snap: Animation = .spring(response: 0.32, dampingFraction: 0.78)
    /// Playful emphasis (correct answer pop, celebrations).
    static let bouncy: Animation = .spring(response: 0.45, dampingFraction: 0.62)
    /// Screen/phase transitions.
    static let smooth: Animation = .easeOut(duration: 0.22)
}
