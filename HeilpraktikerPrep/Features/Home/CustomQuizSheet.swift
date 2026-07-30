import SwiftUI

/// Build-your-own quiz: pick subjects and question count.
struct CustomQuizSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSubjectIds: Set<String> = []
    @State private var count = 10

    let onStart: (Set<String>, Int) -> Void

    private let countOptions = [10, 20, 30]

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
            HStack {
                Text(session.strings.home.modeCustomTitle)
                    .font(AppFont.heading())
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

            VStack(spacing: AppSpacing.cardGap) {
                ForEach(session.pack.subjects) { subject in
                    subjectRow(subject)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                ForEach(countOptions, id: \.self) { option in
                    let selected = count == option
                    Button {
                        count = option
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        Text("\(option)")
                            .font(AppFont.bodyMedium(17))
                            .foregroundStyle(selected ? .white : AppColor.textPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(selected ? AppColor.accent : AppColor.surfaceHigh)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.chip))
                    }
                    .buttonStyle(.plain)
                }
            }

            PrimaryCTAButton(title: session.strings.home.startButton,
                             isEnabled: !selectedSubjectIds.isEmpty) {
                onStart(selectedSubjectIds, count)
            }
        }
        .padding(AppSpacing.screenMargin)
        .frame(maxWidth: AppLayout.readableNarrow, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(AppColor.background.ignoresSafeArea())
    }

    private func subjectRow(_ subject: Subject) -> some View {
        let selected = selectedSubjectIds.contains(subject.id)
        return Button {
            if selected {
                selectedSubjectIds.remove(subject.id)
            } else {
                selectedSubjectIds.insert(subject.id)
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: subject.sfSymbol)
                    .foregroundStyle(selected ? AppColor.accent : AppColor.textDim)
                    .frame(width: 24)
                Text(subject.name)
                    .font(AppFont.bodyMedium(17))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Image(systemName: selected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(selected ? AppColor.accent : AppColor.border)
            }
            .padding(AppSpacing.md)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.row)
                    .stroke(selected ? AppColor.accent : AppColor.border, lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.row))
        }
        .buttonStyle(.plain)
    }
}
