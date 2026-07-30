import SwiftUI

/// Tile in the Home quiz-mode grid. Falls back to an SF Symbol until the
/// niche illustration pack lands in ContentPack/Illustrations.
struct QuizModeCard: View {
    @Environment(AppSession.self) private var session

    let title: String
    let subtitle: String
    let sfSymbol: String
    let tint: Color
    var info: String?
    var showsProBadge = false
    let action: () -> Void

    @State private var showInfo = false
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        let iconSide: CGFloat = hSize == .regular ? 52 : 44
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: sfSymbol)
                    .font(.system(size: hSize == .regular ? 26 : 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: iconSide, height: iconSide)
                    .background(tint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
                Spacer(minLength: 0)
                if showsProBadge { ProBadge() }
                if let info, !info.isEmpty {
                    Button {
                        showInfo = true
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(AppColor.textDim)
                            .padding(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(session.strings.home.modeInfoTitle))
                    .alert(session.strings.home.modeInfoTitle,
                           isPresented: $showInfo,
                           actions: {
                               Button(session.strings.home.modeInfoDismiss, role: .cancel) {}
                           },
                           message: { Text(info) })
                }
            }
            Text(title)
                .font(AppFont.bodyMedium(17))
                .foregroundStyle(AppColor.textPrimary)
            Text(subtitle)
                .font(AppFont.caption(13))
                .foregroundStyle(AppColor.textDim)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: hSize == .regular ? 156 : 132)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardY)
        .contentShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.pressable)
    }
}
