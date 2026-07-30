import SwiftUI

/// Pre-flight config for the Timed Quiz: how many questions, how much clock.
struct TimedQuizSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var count = 10
    @State private var minutes = 10

    let onStart: (Int, Int) -> Void

    private let countOptions = [10, 20, 30]
    private let minuteOptions = [5, 10, 15, 20]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack {
                Text(session.strings.home.modeTimedTitle)
                    .font(AppFont.heading(22))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            optionRow(label: session.strings.home.timedQuestionsLabel,
                      options: countOptions, selection: $count)
            optionRow(label: session.strings.home.timedMinutesLabel,
                      options: minuteOptions, selection: $minutes)

            PrimaryCTAButton(title: session.strings.home.startButton) {
                onStart(count, minutes)
            }
        }
        .padding(AppSpacing.screenMargin)
        .frame(maxWidth: AppLayout.readableNarrow, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.ignoresSafeArea())
    }

    private func optionRow(label: String, options: [Int], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(label)
                .font(AppFont.caption(13))
                .foregroundStyle(AppColor.textSecondary)
            HStack(spacing: AppSpacing.sm) {
                ForEach(options, id: \.self) { option in
                    let selected = selection.wrappedValue == option
                    Button {
                        selection.wrappedValue = option
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text("\(option)")
                            .font(AppFont.bodyMedium(15))
                            .foregroundStyle(selected ? .white : AppColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(selected ? AppColor.accent : AppColor.surfaceHigh)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
