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
    @Environment(AppSession.self) private var session

    enum ChoiceState {
        case idle
        case selected
        case revealedCorrect
        case revealedWrong
        case dimmed
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: AppSpacing.md) {
                // The letter badge becomes the verdict: a check or a cross takes
                // the letter's place on the revealed rows.
                ZStack {
                    Circle().fill(state.letterBackground)
                    if state.isRevealed {
                        Image(systemName: state == .revealedWrong ? "xmark" : "checkmark")
                            .font(.system(size: 15 * fontScale, weight: .bold))
                            .foregroundStyle(.white)
                            .scaleEffect(state == .revealedCorrect ? checkScale : 1)
                    } else {
                        Text(letter)
                            .font(AppFont.bodyMedium(15 * fontScale))
                            .foregroundStyle(state.letterColor)
                    }
                }
                .frame(width: 32, height: 32)
                .overlay(Circle().stroke(state == .dimmed ? AppColor.border : .clear, lineWidth: 1))
                .onChange(of: state) { _, newState in
                    guard newState == .revealedCorrect, !reduceMotion else { return }
                    checkScale = 0.3
                    withAnimation(AppMotion.bouncy) { checkScale = 1 }
                }

                Text(text.prefix(1).uppercased() + text.dropFirst())
                    .font(AppFont.body(17 * fontScale))
                    .foregroundStyle(state.textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(AppSpacing.cardPadding)
            .background(state.background)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(state.borderColor, lineWidth: state == .idle || state == .dimmed ? 1 : 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        }
        .buttonStyle(.pressable)
        .animation(AppMotion.snap, value: state.key)
        .accessibilityLabel(String(format: session.strings.common.a11yOptionFormat, letter, text))
        .accessibilityValue(state.accessibilityValue(session.strings.common))
    }
}

/// Shared palette so the multiple-choice row and the Verdadeiro/Falso buttons
/// read as the same component.
extension ChoiceRow.ChoiceState {
    func accessibilityValue(_ s: UIStrings.Common) -> String {
        switch self {
        case .selected: s.a11ySelected
        case .revealedCorrect: s.a11yCorrectAnswer
        case .revealedWrong: s.a11yYourAnswerWrong
        case .idle, .dimmed: ""
        }
    }

    var key: Int {
        switch self {
        case .idle: 0
        case .selected: 1
        case .revealedCorrect: 2
        case .revealedWrong: 3
        case .dimmed: 4
        }
    }

    var isRevealed: Bool {
        self == .revealedCorrect || self == .revealedWrong
    }

    var background: Color {
        switch self {
        case .revealedCorrect: AppColor.successSoft
        case .revealedWrong: AppColor.errorSoft
        // Dimmed (non-answer) rows recede behind the colored correct/wrong rows
        // so the eye lands on the right answer first.
        case .dimmed: AppColor.surfaceHigh
        default: AppColor.surface
        }
    }

    var borderColor: Color {
        switch self {
        case .idle, .dimmed: AppColor.border
        case .selected: AppColor.accent
        case .revealedCorrect: AppColor.success
        case .revealedWrong: AppColor.error
        }
    }

    var textColor: Color {
        switch self {
        case .dimmed: AppColor.textDim
        case .revealedCorrect: AppColor.success
        case .revealedWrong: AppColor.error
        default: AppColor.textPrimary
        }
    }

    var letterColor: Color {
        switch self {
        case .selected, .revealedCorrect, .revealedWrong: .white
        default: AppColor.textSecondary
        }
    }

    var letterBackground: Color {
        switch self {
        case .selected: AppColor.accent
        case .revealedCorrect: AppColor.success
        case .revealedWrong: AppColor.error
        case .dimmed: .clear
        default: AppColor.surfaceHigh
        }
    }
}
