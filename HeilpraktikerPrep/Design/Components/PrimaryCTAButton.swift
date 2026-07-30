import SwiftUI

/// The app's main call-to-action: large, high-contrast, with haptic feedback.
struct PrimaryCTAButton: View {
    let title: String
    var isEnabled: Bool = true
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Text(title)
                .font(AppFont.bodyMedium(17))
                .foregroundStyle(.white)
                // Cap the CTA at a sensible width on iPad so it doesn't stretch
                // into a giant bar across the readable column; full width on iPhone.
                .frame(maxWidth: hSize == .regular ? AppLayout.ctaMaxWidth : .infinity)
                .frame(height: 52)
                .background(isEnabled ? AppColor.accent : AppColor.textDim)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.button))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressable)
        .disabled(!isEnabled)
        .animation(AppMotion.smooth, value: isEnabled)
    }
}
