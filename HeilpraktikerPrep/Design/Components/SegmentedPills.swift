import SwiftUI

/// A row of selectable "pill" segments — the app's standard inline filter/toggle.
/// One source of truth for the chip pattern previously hand-rolled across
/// Review, Stats and the results screen (consistent spacing, haptic, press feel).
struct SegmentedPills<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let label: (Option) -> String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(options, id: \.self) { option in
                let selected = selection == option
                Button {
                    selection = option
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(label(option))
                        .font(AppFont.bodyMedium(13))
                        .foregroundStyle(selected ? .white : AppColor.textSecondary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(selected ? AppColor.accent : AppColor.surfaceHigh)
                        .clipShape(Capsule())
                }
                .buttonStyle(.pressable)
            }
        }
        .animation(AppMotion.snap, value: selection)
    }
}
