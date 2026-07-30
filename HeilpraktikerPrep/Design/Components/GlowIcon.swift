import SwiftUI

/// Pikit-style glowing icon: a soft radial halo behind a light symbol with
/// layered colored shadows — light produced in code, no image assets.
/// Micro-animation: the halo "breathes" and the symbol floats gently.
/// Honors Reduce Motion (renders static).
struct GlowIcon: View {
    let symbol: String
    var tint: Color = AppColor.accent
    var size: CGFloat = 120
    var animationDuration: Double = 2.4
    var animated = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var breathing = false

    private var shouldAnimate: Bool { animated && !reduceMotion }

    /// Top gradient stop: white in dark mode (bright against dark bg),
    /// tint in light mode (avoids invisible white-on-white).
    private var iconTopColor: Color { colorScheme == .dark ? .white : tint }

    var body: some View {
        ZStack {
            // Halo: subtle and tight around the symbol — ambience, not a spotlight.
            Circle()
                .fill(tint)
                .frame(width: size * 0.78, height: size * 0.78)
                .blur(radius: size * 0.26)
                .opacity(breathing ? 0.30 : 0.20)
                .scaleEffect(breathing ? 1.07 : 1.0)
            Image(systemName: symbol)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [iconTopColor, tint.opacity(0.9)],
                                   startPoint: .top, endPoint: .bottom))
                .shadow(color: tint.opacity(breathing ? 0.7 : 0.55), radius: size * 0.09)
                .offset(y: breathing ? -size * 0.025 : size * 0.015)
        }
        .frame(width: size * 1.3, height: size * 1.3)
        .onAppear {
            guard shouldAnimate else { return }
            withAnimation(.easeInOut(duration: animationDuration).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

/// Gentle vertical drift for cards/illustrations — the "alive" feel without
/// stealing attention. Honors Reduce Motion.
struct GentleFloat: ViewModifier {
    var amplitude: CGFloat = 4
    var duration: Double = 3.2

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var up = false

    func body(content: Content) -> some View {
        content
            .offset(y: up ? -amplitude : amplitude)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    up = true
                }
            }
    }
}

extension View {
    func gentleFloat(amplitude: CGFloat = 4, duration: Double = 3.2) -> some View {
        modifier(GentleFloat(amplitude: amplitude, duration: duration))
    }
}

/// Ambient backdrop: two soft blurred color blobs over the app background.
/// Gives screens depth without competing with content.
struct AmbientBackground: View {
    var primary: Color = AppColor.accent
    var secondary: Color = Color(hexString: "#8E6FF7")

    var body: some View {
        ZStack {
            AppColor.background
            Circle()
                .fill(primary.opacity(0.16))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: -130, y: -260)
            Circle()
                .fill(secondary.opacity(0.10))
                .frame(width: 300, height: 300)
                .blur(radius: 100)
                .offset(x: 150, y: 290)
        }
        .ignoresSafeArea()
    }
}


extension View {
    /// Resigns any active text field — call when leaving screens that had one.
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                        to: nil, from: nil, for: nil)
    }
}
