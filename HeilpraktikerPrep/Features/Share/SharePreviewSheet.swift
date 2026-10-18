import SwiftUI

/// What the user is about to send, exactly as rendered, with the share button
/// underneath — no surprises once the system sheet opens.
struct SharePreviewSheet: View {
    let image: UIImage
    let title: String
    let cta: String
    let onShare: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Text(title)
                .font(AppFont.display(22))
                .foregroundStyle(AppColor.textPrimary)
                .padding(.top, AppSpacing.xl)
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.hero))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                .padding(.horizontal, AppSpacing.xl)
            Spacer(minLength: 0)
            PrimaryCTAButton(title: cta, action: onShare)
                .padding(.horizontal, OnboardingTokens.gutter)
                .padding(.bottom, AppSpacing.md)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColor.background.ignoresSafeArea())
    }
}
