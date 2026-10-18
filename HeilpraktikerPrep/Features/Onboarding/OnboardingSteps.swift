import SwiftUI

// MARK: - Shared scaffolding

/// Selectable options rise into place from below, one after the other. The
/// page itself no longer slides sideways, so this is the motion the user sees.
struct RiseIn: ViewModifier {
    let index: Int
    let shown: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 40)
            .animation(reduceMotion ? nil
                       : .spring(response: 0.48, dampingFraction: 0.82)
                           .delay(Double(index) * 0.06),
                       value: shown)
    }
}

extension View {
    func riseIn(index: Int, shown: Bool) -> some View {
        modifier(RiseIn(index: index, shown: shown))
    }
}

struct OnboardingStepHeader: View {
    let title: String
    let subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text(title)
                .font(AppFont.display(27))
                .foregroundStyle(AppColor.textPrimary)
                .lineSpacing(1)
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(AppFont.body(15))
                    .foregroundStyle(OnboardingTokens.leadText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingOptionCard: View {
    let title: String
    var detail: String?
    /// Muted note on the right of the row (e.g. what a pace is called).
    var trailingLabel: String?
    var emoji: String?
    let selected: Bool
    var checkbox = false
    var symbol: String?
    var tint: Color = AppColor.accent
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 36, height: 36)
                        .background(tint.opacity(0.14))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: tint.opacity(selected ? 0.5 : 0), radius: 8)
                }
                if let emoji {
                    Text(emoji).font(.system(size: 22))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(AppFont.heading(16))
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(AppFont.caption(13))
                            .foregroundStyle(OnboardingTokens.leadText)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: AppSpacing.sm)
                if let trailingLabel {
                    Text(trailingLabel)
                        .font(AppFont.caption(15))
                        .foregroundStyle(Color(hexString: "#6B7A90"))
                }
                if checkbox {
                    Image(systemName: selected ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? AppColor.accent : AppColor.border)
                } else if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(AppColor.accent)
                }
            }
            .padding(.horizontal, OnboardingTokens.optionPadding)
            .padding(.vertical, OnboardingTokens.optionPadding + 5)
            .frame(minHeight: 62)
            .background(AppColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: OnboardingTokens.optionRadius)
                    .stroke(selected ? AppColor.accent : OnboardingTokens.optionBorderColor,
                            lineWidth: selected ? 2 : OnboardingTokens.optionBorder)
            )
            .clipShape(RoundedRectangle(cornerRadius: OnboardingTokens.optionRadius))
            .shadow(color: AppColor.accent.opacity(selected ? 0.14 : 0), radius: 10, y: 4)
            .scaleEffect(selected ? 1.015 : 1)
            .opacity(isDisabled ? 0.35 : 1)
            .animation(AppMotion.snap, value: selected)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Single select

struct OnboardingSingleSelectStep: View {
    let title: String
    let subtitle: String?
    let options: [String]
    var details: [String]?
    var emojis: [String]?
    var icons: [String]?
    var disabledIndices: Set<Int> = []
    let selectedIndex: Int?
    let onSelect: (Int) -> Void

    @Environment(\.horizontalSizeClass) private var hSize
    @State private var appeared = false

    private static let tints: [Color] = [
        AppColor.accent,
        Color(hexString: "#8E6FF7"),
        Color(hexString: "#2FB8C5"),
        Color(hexString: "#F2789F"),
        Color(hexString: "#23A566"),
        Color(hexString: "#F5A623"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
            if hSize == .regular { Spacer(minLength: 0) }
            OnboardingStepHeader(title: title, subtitle: subtitle)
            VStack(spacing: AppSpacing.cardGap) {
                ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                    OnboardingOptionCard(
                        title: option,
                        detail: details.map { $0[index] },
                        emoji: emojis.map { $0[index] },
                        selected: selectedIndex == index,
                        symbol: icons.map { $0[index] },
                        tint: Self.tints[index % Self.tints.count],
                        isDisabled: disabledIndices.contains(index)
                    ) {
                        onSelect(index)
                    }
                    .riseIn(index: index, shown: appeared)
                }
            }
            Spacer()
        }
        .padding(OnboardingTokens.gutter)
        .onAppear { appeared = true }
    }
}

// MARK: - State picker (regions from the pack)

struct RegionPickerList: View {
    let regions: [Region]
    let searchPlaceholder: String
    let selectedId: String?
    let onSelect: (Region) -> Void

    @State private var query = ""
    @FocusState private var searching: Bool
    @State private var appeared = false

    private var filtered: [Region] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return regions }
        return regions.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColor.textDim)
                TextField(searchPlaceholder, text: $query)
                    .font(AppFont.body(16))
                    .autocorrectionDisabled()
                    .focused($searching)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(AppColor.surface)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(OnboardingTokens.surfaceBorder, lineWidth: 1))
            // The whole pill is the target, not just the glyphs inside it.
            .contentShape(Capsule())
            .onTapGesture { searching = true }

            ScrollView {
                VStack(spacing: AppSpacing.sm) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, region in
                        let selected = region.id == selectedId
                        Button {
                            hideKeyboard()
                            onSelect(region)
                        } label: {
                            HStack {
                                Text(region.name)
                                    .font(AppFont.bodyMedium(16))
                                    .foregroundStyle(AppColor.textPrimary)
                                Spacer()
                                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(selected ? AppColor.success : OnboardingTokens.optionBorderColor)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 17)
                            .frame(minHeight: 62)
                            .background(AppColor.surface)
                            .overlay(RoundedRectangle(cornerRadius: OnboardingTokens.optionRadius)
                                .stroke(selected ? AppColor.accent : OnboardingTokens.optionBorderColor,
                                        lineWidth: selected ? 2 : OnboardingTokens.optionBorder))
                            .clipShape(RoundedRectangle(cornerRadius: OnboardingTokens.optionRadius))
                        }
                        .buttonStyle(.plain)
                        .riseIn(index: min(index, 8), shown: appeared)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear { appeared = true }
        }
    }
}

struct OnboardingStateStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            OnboardingStepHeader(title: session.strings.onboarding.stateTitleFunnel,
                                 subtitle: nil)
            RegionPickerList(
                regions: session.pack.regions ?? [],
                searchPlaceholder: String(format: session.strings.onboarding.stateSearchFormat,
                                          session.regionLabel),
                selectedId: model.stateId
            ) { region in
                model.stateId = region.id
                Haptics.select()
                Task {
                    try? await Task.sleep(for: .milliseconds(320))
                    model.advance()
                }
            }
        }
        .padding(OnboardingTokens.gutter)
    }
}

// MARK: - Exam date

struct OnboardingExamDateStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel
    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            if hSize == .regular { Spacer(minLength: 0) }
            OnboardingStepHeader(title: session.strings.onboarding.examDateTitleFunnel,
                                 subtitle: session.strings.onboarding.examDateSubtitleFunnel)

            DatePicker("",
                       selection: Binding(
                           get: { model.examDate ?? Calendar.current.date(byAdding: .day, value: 38, to: .now) ?? .now },
                           set: { model.examDate = $0 }),
                       in: Date.now...,
                       displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .onChange(of: model.examDate) { _, _ in Haptics.select() }
                .tint(AppColor.accent)
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.sm)

            Spacer(minLength: AppSpacing.sm)

            if let examDate = model.examDate {
                let days = Calendar.current.dateComponents(
                    [.day],
                    from: Calendar.current.startOfDay(for: .now),
                    to: Calendar.current.startOfDay(for: examDate)).day ?? 0
                if days > 0 {
                    OnboardingPaceCard(days: days, pace: StudyPace.forDays(days))
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding(OnboardingTokens.gutter)
        .animation(AppMotion.smooth, value: model.examDate)
        .onAppear {
            // The wheel always shows a date, so the draft has to hold one too —
            // otherwise the CTA reads as disabled for no visible reason.
            if model.examDate == nil {
                model.examDate = Calendar.current.date(byAdding: .day, value: 38, to: .now)
            }
        }
    }

}

/// "38 dias restantes · RITMO ATIVO" + what that pace means. The urgency is
/// derived from the user's own date — never a manufactured countdown.
struct OnboardingPaceCard: View {
    @Environment(AppSession.self) private var session
    let days: Int
    let pace: StudyPace
    /// "%d" format for the days-left line — the date step and the minutes step
    /// word it differently.
    var daysFormat: String?

    var body: some View {
        let strings = session.strings.onboarding
        let (label, advice, tint): (String, String, Color) = switch pace {
        case .sprint: (strings.paceSprint, strings.paceAdviceSprint, AppColor.error)
        case .active: (strings.paceActive, strings.paceAdviceActive, AppColor.warning)
        case .steady: (strings.paceSteady, strings.paceAdviceSteady, AppColor.accent)
        }
        return VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack(spacing: AppSpacing.sm) {
                Text(strings.paceEmoji)
                    .font(.system(size: 16))
                Text(String(format: daysFormat ?? strings.examDateDaysLeftFormat, days))
                    .font(AppFont.strong(16))
                    .foregroundStyle(AppColor.textPrimary)
                Text(label)
                    .font(AppFont.strong(12))
                    .foregroundStyle(tint)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.14))
                    .clipShape(Capsule())
            }
            Text(advice)
                .font(AppFont.body(14))
                .foregroundStyle(OnboardingTokens.leadText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }
}

/// One-line verdict shown under a choice (e.g. daily minutes vs. exam runway).
struct OnboardingHintCard: View {
    let text: String
    let emoji: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text(emoji)
                .font(.system(size: 15))
            Text(text)
                .font(AppFont.bodyMedium(14))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
    }
}

// MARK: - Name

struct OnboardingNameStep: View {
    @Environment(AppSession.self) private var session
    @Bindable var model: OnboardingModel
    @FocusState private var focused: Bool

    var body: some View {
        let strings = session.strings.onboarding
        VStack(alignment: .leading, spacing: AppSpacing.sectionGap) {
            OnboardingStepHeader(title: strings.nameTitle, subtitle: strings.nameSubtitle)
            Text(strings.nameFieldLabel)
                .font(AppFont.heading(13))
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, -AppSpacing.md)
            TextField(strings.namePlaceholder, text: $model.name)
                .font(AppFont.body(17))
                .foregroundStyle(AppColor.textPrimary)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.continue)
                .focused($focused)
                .onSubmit { if model.displayName != nil { model.advance() } }
                .padding(AppSpacing.cardPadding)
                .background(AppColor.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
                .overlay(RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(focused ? AppColor.accent : AppColor.border, lineWidth: 1.5))
            Spacer()
        }
        .padding(OnboardingTokens.gutter)
        .onAppear { focused = true }
    }
}
