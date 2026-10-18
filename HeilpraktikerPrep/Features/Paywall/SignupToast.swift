import SwiftUI

/// The "Fulano S. se inscreveu" notice that drops in over the paywall.
///
/// The names come from the pack and the timing is generated on device — no
/// purchase is being reported. Operator's call (2026-09-11); the App Review
/// risk of presenting invented activity as real is on record.
struct SignupToast: View {
    let strings: UIStrings.Paywall

    /// Each notice stays up for one of these, in turn — an uneven rhythm reads
    /// as live activity, a metronome does not. One second of nothing between.
    private static let dwell: [Duration] = [.seconds(2), .seconds(3), .seconds(2), .seconds(4)]
    private static let gap = Duration.seconds(1)
    private static let firstDelay = Duration.seconds(1.5)
    /// Every few notices the pace breaks into a burst: names swap fast, one at
    /// a time — never two on screen at once.
    private static let burstEvery = 4
    private static let burstSize = 3
    private static let burstDwell = Duration.milliseconds(550)
    private static let burstGap = Duration.milliseconds(120)

    /// The one name on screen. Never two at once — a burst just swaps it fast.
    @State private var current: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack(alignment: .top) {
            if let current {
                toast(current)
                    .id(current)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .task { await run() }
        .accessibilityHidden(true)
    }

    private func toast(_ name: String) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(AppColor.success, in: Circle())
            Text(String(format: strings.signupToastFormat, name))
                .font(AppFont.heading(14))
                .foregroundStyle(.white)
        }
        .padding(.leading, 8)
        .padding(.trailing, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(PaywallDark.stroke, lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 14, y: 8)
    }

    /// Cycles the names in a shuffled order so the same one does not come back
    /// twice in a row. Every fourth beat is a burst: three sign-ups in about
    /// two seconds, swapping in place.
    private func run() async {
        var names = strings.signupToastNames
        guard !names.isEmpty else { return }
        names.shuffle()
        var index = 0
        var beat = 0
        func next() -> String {
            let name = names[index]
            index += 1
            if index == names.count { names.shuffle(); index = 0 }
            return name
        }
        func push(_ name: String) {
            withAnimation(reduceMotion ? nil : AppMotion.bouncy) { current = name }
            // A light tap every time a notice lands — felt, not heard.
            Haptics.tap(.light)
        }
        func clear() {
            withAnimation(reduceMotion ? nil : AppMotion.smooth) { current = nil }
        }
        try? await Task.sleep(for: Self.firstDelay)
        while !Task.isCancelled {
            if beat % Self.burstEvery == Self.burstEvery - 1 {
                // The burst: names swap in place, fast, one at a time.
                for i in 0..<Self.burstSize {
                    push(next())
                    try? await Task.sleep(for: Self.burstDwell)
                    if i < Self.burstSize - 1 {
                        clear()
                        try? await Task.sleep(for: Self.burstGap)
                    }
                }
            } else {
                push(next())
                try? await Task.sleep(for: Self.dwell[beat % Self.dwell.count])
            }
            clear()
            try? await Task.sleep(for: Self.gap)
            beat += 1
        }
    }
}
