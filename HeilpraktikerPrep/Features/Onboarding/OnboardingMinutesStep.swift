import SwiftUI

/// "Quanto tempo você tem por dia?" — the commitment step. Picking an amount
/// keeps the page (the verdict against the exam date is the point), and the
/// Continue button in `OnboardingView` raises the notification prompt.
struct OnboardingMinutesStep: View {
    @Environment(AppSession.self) private var session
    let model: OnboardingModel
    @State private var appeared = false
    /// Called after a pick when there is no exam date: with nothing to weigh
    /// the choice against, there is no verdict to read, so the page moves on
    /// by itself (the caller raises the notification prompt first).
    var onPickWithoutDate: () -> Void = {}

    private var strings: UIStrings.Onboarding { session.strings.onboarding }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            OnboardingStepHeader(title: strings.minutesTitleFunnel,
                                 subtitle: strings.minutesSubtitle)

            VStack(spacing: AppSpacing.cardGap) {
                ForEach(Array(PlanGenerator.minuteOptions.enumerated()), id: \.offset) { index, value in
                    OnboardingOptionCard(
                        title: String(format: strings.amountPerDayFormat,
                                      Self.amountLabel(for: value, strings: strings)),
                        trailingLabel: paceLabels[index],
                        selected: model.minutes == value
                    ) {
                        Haptics.select()
                        withAnimation(AppMotion.bouncy) { model.minutes = value }
                        if model.daysUntilExam == nil {
                            Task {
                                try? await Task.sleep(for: .milliseconds(350))
                                onPickWithoutDate()
                            }
                        }
                    }
                    .riseIn(index: index, shown: appeared)
                }
            }
            .onAppear { appeared = true }

            Spacer(minLength: AppSpacing.sm)

            if let days = model.daysUntilExam {
                OnboardingPaceCard(days: days,
                                   pace: StudyPace.forDays(days),
                                   daysFormat: strings.minutesDaysLeftFormat)
            }

            if let hint {
                OnboardingHintCard(text: hint.text,
                                   emoji: hint.fits ? strings.hintEmojiFits : strings.hintEmojiTight,
                                   tint: hint.fits ? AppColor.success : AppColor.warning)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(OnboardingTokens.gutter)
        .animation(AppMotion.smooth, value: model.minutes)
        .onChange(of: hint?.fits) { _, fits in
            if fits == false { Haptics.warning() }
        }
    }

    /// Each amount carries the name of the rhythm it buys — the number alone
    /// says nothing about what the day will feel like.
    private var paceLabels: [String] {
        [strings.minutesPaceSlow, strings.minutesPaceBalanced,
         strings.minutesPaceFast, strings.minutesPaceIntense]
    }

    /// 15 → "15 min", 60 → "1 h", 90 → "1h30". The "/ dia" suffix is added by
    /// the caller, so the same amount also reads naturally inside a sentence.
    static func amountLabel(for value: Int, strings: UIStrings.Onboarding) -> String {
        guard value >= 60 else { return String(format: strings.minutesPerDayFormat, value) }
        let hours = value / 60, rest = value % 60
        guard rest > 0 else { return String(format: strings.hoursPerDayFormat, hours) }
        return String(format: strings.hoursMinutesPerDayFormat, hours, rest)
    }

    /// Verdict on the chosen daily minutes against the exam runway — mirrors
    /// the plan's own math, so the advice and the plan never disagree.
    private var hint: (text: String, fits: Bool)? {
        guard let chosen = model.minutes, let days = model.daysUntilExam,
              let recommended = PlanGenerator.recommendedMinutes(
                  totalQuestions: session.content.questions.count, daysUntilExam: days)
        else { return nil }
        if chosen >= recommended { return (strings.minutesHintFits, true) }
        // Same wording as the option the user would have to pick — "1 h / dia",
        // never "60 min por dia" for the same amount.
        let suggestion = String(format: strings.amountPerDayFormat,
                                Self.amountLabel(for: recommended, strings: strings))
        return (String(format: strings.minutesHintTightFormat, days, suggestion), false)
    }

}
