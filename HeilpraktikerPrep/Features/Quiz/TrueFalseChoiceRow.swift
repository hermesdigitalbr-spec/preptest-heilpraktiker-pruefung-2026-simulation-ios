import SwiftUI

/// Verdadeiro/Falso variant of `ChoiceRow`: exactly two large, always-in-place
/// buttons. The badge shows the pack's short token ("V"/"F", "T"/"F") until the
/// answer is revealed, then turns into the verdict like the lettered rows do.
/// Same states and palette as `ChoiceRow`.
struct TrueFalseChoiceRow: View {
    let letter: String
    let text: String
    let isTrue: Bool
    let state: ChoiceRow.ChoiceState
    let fontScale: CGFloat
    let action: () -> Void

    @State private var iconScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppSession.self) private var session

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle().fill(state == .idle ? idleTint.opacity(0.14) : state.letterBackground)
                    if state.isRevealed {
                        Image(systemName: state == .revealedWrong ? "xmark" : "checkmark")
                            .font(.system(size: 16 * fontScale, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(iconScale)
                    } else {
                        Text(letter)
                            .font(AppFont.heading(17 * fontScale))
                            .foregroundStyle(state == .idle ? idleTint : state.letterColor)
                    }
                }
                .frame(width: 36, height: 36)
                .overlay(Circle().stroke(state == .dimmed ? AppColor.border : .clear, lineWidth: 1))

                Text(text)
                    .font(AppFont.heading(19 * fontScale))
                    .foregroundStyle(state.textColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .background(state.background)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(state.borderColor, lineWidth: state == .idle || state == .dimmed ? 1 : 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.pressable)
        .animation(AppMotion.snap, value: state.key)
        .onChange(of: state) { _, new in
            guard new.isRevealed, !reduceMotion else { return }
            iconScale = 0.3
            withAnimation(AppMotion.bouncy) { iconScale = 1 }
        }
        .accessibilityLabel(text)
        .accessibilityValue(state.accessibilityValue(session.strings.common))
    }

    /// Before answering, the two sides are told apart by color as well as token.
    private var idleTint: Color { isTrue ? AppColor.success : AppColor.error }
}
