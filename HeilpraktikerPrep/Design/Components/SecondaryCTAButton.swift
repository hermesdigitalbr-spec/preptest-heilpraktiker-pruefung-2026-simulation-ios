import SwiftUI

/// The quieter sibling of `PrimaryCTAButton`: same size and shape, white fill.
/// Used where the screen offers a real second choice ("Ainda não tenho data"),
/// which deserves a button rather than a text link.
struct SecondaryCTAButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(AppFont.bodyMedium(17))
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: hSize == .regular ? AppLayout.ctaMaxWidth : .infinity)
                .frame(height: 56)
                .background(AppColor.surface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(OnboardingTokens.surfaceBorder, lineWidth: 1))
                .shadow(color: Color(red: 20 / 255, green: 40 / 255, blue: 70 / 255).opacity(0.08),
                        radius: 9, y: 4)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
    }
}
