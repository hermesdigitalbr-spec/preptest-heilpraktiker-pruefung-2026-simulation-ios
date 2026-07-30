import SwiftUI

/// One answer option. Visual states:
/// - idle: neutral surface
/// - selected (before reveal): accent outline
/// - revealed correct: green
/// - revealed wrong (the one the user picked): red
struct ChoiceRow: View {
    let letter: String
    let text: String
    let state: ChoiceState
    let fontScale: CGFloat
    let action: () -> Void

    @State private var checkScale: CGFloat = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    enum ChoiceState {
        case idle
        case selected
        case revealedCorrect
        case revealedWrong
        case dimmed
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                Text(letter)
                    .font(AppFont.bodyMedium(15 * fontScale))
                    .foregroundStyle(letterColor)
                    .frame(width: 28, height: 28)
                    .background(letterBackground)
                    .clipShape(Circle())

                Text(text.prefix(1).uppercased() + text.dropFirst())
                    .font(AppFont.body(17 * fontScale))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                trailingIcon
            }
            .padding(AppSpacing.cardPadding)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(borderColor, lineWidth: state == .idle || state == .dimmed ? 1 : 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.pressable)
        .animation(AppMotion.snap, value: stateKey)
        .accessibilityLabel("Option \(letter): \(text)")
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: String {
        switch state {
        case .selected: "Selected"
        case .revealedCorrect: "Correct answer"
        case .revealedWrong: "Your answer, incorrect"
        case .idle, .dimmed: ""
        }
    }

    private var stateKey: Int {
        switch state {
        case .idle: 0
        case .selected: 1
        case .revealedCorrect: 2
        case .revealedWrong: 3
        case .dimmed: 4
        }
    }

    @ViewBuilder private var trailingIcon: some View {
        switch state {
        case .revealedCorrect:
            // A single restrained pop turns the most-repeated moment in the app
            // into a quiet beat of confidence. Color + haptic carry it under
            // Reduce Motion (no scale).
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppColor.success)
                .scaleEffect(checkScale)
                .onAppear {
                    guard !reduceMotion else { return }
                    checkScale = 0.3
                    withAnimation(AppMotion.bouncy) { checkScale = 1 }
                }
        case .revealedWrong:
            Image(systemName: "xmark.circle.fill").foregroundStyle(AppColor.error)
        default:
            EmptyView()
        }
    }

    private var background: Color {
        switch state {
        case .revealedCorrect: AppColor.successSoft
        case .revealedWrong: AppColor.errorSoft
        // Dimmed (non-answer) rows recede behind the colored correct/wrong rows
        // so the eye lands on the right answer first.
        case .dimmed: AppColor.surfaceHigh
        default: AppColor.surface
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle, .dimmed: AppColor.border
        case .selected: AppColor.accent
        case .revealedCorrect: AppColor.success
        case .revealedWrong: AppColor.error
        }
    }

    private var textColor: Color {
        state == .dimmed ? AppColor.textDim : AppColor.textPrimary
    }

    private var letterColor: Color {
        switch state {
        case .selected, .revealedCorrect, .revealedWrong: .white
        default: AppColor.textSecondary
        }
    }

    private var letterBackground: Color {
        switch state {
        case .selected: AppColor.accent
        case .revealedCorrect: AppColor.success
        case .revealedWrong: AppColor.error
        default: AppColor.surfaceHigh
        }
    }
}
