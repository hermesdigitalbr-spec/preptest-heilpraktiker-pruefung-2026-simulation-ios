import SwiftUI

/// Full badge wall, pushed from the Stats achievements section. Unlocked
/// badges glow in their tint; locked ones are muted with a progress bar.
struct AchievementsView: View {
    @Environment(AppSession.self) private var session

    private var statuses: [AchievementStatus] { session.achievementStatuses }
    private var unlockedCount: Int { statuses.filter(\.unlocked).count }

    // Adaptive: exactly 2 columns on iPhone, 4–5 on iPad — keeps badge tiles
    // phone-sized instead of two giant cells on a 13" screen.
    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 220), spacing: AppSpacing.cardGap)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                Text(String(format: session.strings.stats.unlockedCountFormat,
                            unlockedCount, statuses.count))
                    .font(AppFont.body(15))
                    .foregroundStyle(AppColor.textSecondary)

                LazyVGrid(columns: columns, spacing: AppSpacing.cardGap) {
                    ForEach(statuses) { status in
                        AchievementBadge(status: status, compact: false)
                    }
                }
            }
            .padding(AppSpacing.screenMargin)
            .readableWidth(AppLayout.readableWide, alignment: .leading)
        }
        .background(AppColor.background.ignoresSafeArea())
        .navigationTitle(session.strings.stats.achievements)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A single badge. `compact` is the small variant for the Stats preview row.
struct AchievementBadge: View {
    @Environment(AppSession.self) private var session
    @Environment(\.colorScheme) private var colorScheme
    let status: AchievementStatus
    var compact: Bool = false

    private var tint: Color { Color(hexString: status.def.tint) }
    private var unlocked: Bool { status.unlocked }

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            medal
            Text(status.def.title)
                .font(AppFont.bodyMedium(compact ? 13 : 15))
                .foregroundStyle(unlocked ? AppColor.textPrimary : AppColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !compact {
                // Pin the detail to a consistent two-line height so every
                // card in the grid lines up regardless of copy length.
                Text(status.def.detail)
                    .font(AppFont.caption(12))
                    .foregroundStyle(AppColor.textDim)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity)
                    .frame(height: 32, alignment: .top)
                // Always reserve the progress-bar slot — invisible when not
                // shown — so unlocked badges match locked ones in height.
                progressSlot
            }
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? AppSpacing.sm : AppSpacing.cardPadding)
        .frame(width: compact ? 104 : nil)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardY)
        .opacity(unlocked || !compact ? 1 : 0.85)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(unlocked
            ? "\(status.def.title), unlocked. \(status.def.detail)"
            : "\(status.def.title), locked. \(status.def.detail)")
        .accessibilityValue(unlocked
            ? ""
            : String(format: session.strings.stats.achievementProgressFormat,
                     status.current, status.target))
    }

    private var medal: some View {
        let size: CGFloat = compact ? 48 : 64
        return ZStack {
            Circle()
                .fill(unlocked ? tint.opacity(colorScheme == .dark ? 0.18 : 0.14) : AppColor.surfaceHigh)
                .frame(width: size, height: size)
            // Subtle glow in light mode (tint, opacity 0.15); stronger in dark (0.35).
            if unlocked {
                Circle()
                    .fill(tint)
                    .frame(width: size, height: size)
                    .blur(radius: compact ? 12 : 16)
                    .opacity(colorScheme == .dark ? 0.35 : 0.15)
            }
            iconImage
        }
    }

    /// Locked = soft gray. Unlocked dark mode = the moody white→tint gradient
    /// that pairs with the glow. Unlocked light mode = flat solid accent —
    /// no gradient washout against the soft tint background.
    @ViewBuilder
    private var iconImage: some View {
        let symbol = unlocked ? status.def.icon : "lock.fill"
        let base = Image(systemName: symbol)
            .font(.system(size: compact ? 20 : 26, weight: .semibold))
        if !unlocked {
            base.foregroundStyle(AppColor.textDim)
        } else if colorScheme == .dark {
            base.foregroundStyle(LinearGradient(
                colors: [.white, tint], startPoint: .top, endPoint: .bottom))
        } else {
            base.foregroundStyle(tint)
        }
    }

    @ViewBuilder
    private var progressSlot: some View {
        if !unlocked && status.current > 0 {
            progressBar
        } else {
            Color.clear.frame(height: 20)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.surfaceHigh)
                    Capsule().fill(tint)
                        .frame(width: max(geo.size.width * status.fraction, 4))
                }
            }
            .frame(height: 5)
            Text(String(format: session.strings.stats.achievementProgressFormat,
                        status.current, status.target))
                .font(AppFont.caption(11))
                .foregroundStyle(AppColor.textDim)
                .monospacedDigit()
        }
        .frame(height: 20)
    }
}

/// Celebration shown the first time a badge unlocks.
struct AchievementUnlockSheet: View {
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    let statuses: [AchievementStatus]

    @State private var glow = false
    @State private var rowsShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text(session.strings.stats.achievementUnlocked)
                .font(AppFont.display(24))
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.top, AppSpacing.xl)
                .padding(.bottom, AppSpacing.lg)
                .padding(.horizontal, AppSpacing.screenMargin)

            ScrollView {
                VStack(spacing: AppSpacing.md) {
                    ForEach(Array(statuses.enumerated()), id: \.element.id) { index, status in
                        unlockedRow(status)
                            .opacity(rowsShown ? 1 : 0)
                            .scaleEffect(rowsShown ? 1 : 0.85)
                            .animation(reduceMotion ? nil
                                       : AppMotion.bouncy.delay(Double(index) * 0.08),
                                       value: rowsShown)
                    }
                }
                .padding(.horizontal, AppSpacing.screenMargin)
                .padding(.bottom, AppSpacing.md)
            }
            .scrollIndicators(.hidden)

            PrimaryCTAButton(title: session.strings.common.continueButton) { dismiss() }
                .padding(AppSpacing.screenMargin)
        }
        .frame(maxWidth: AppLayout.readableNarrow, alignment: .center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AmbientBackground())
        .onAppear {
            rowsShown = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { glow = true }
        }
    }

    private func unlockedRow(_ status: AchievementStatus) -> some View {
        let tint = Color(hexString: status.def.tint)
        return HStack(spacing: AppSpacing.md) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 60, height: 60)
                Circle().fill(tint).frame(width: 60, height: 60)
                    .blur(radius: 18).opacity(glow ? 0.6 : 0.35)
                Image(systemName: status.def.icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [.white, tint],
                                                    startPoint: .top, endPoint: .bottom))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(status.def.title)
                    .font(AppFont.heading(17))
                    .foregroundStyle(AppColor.textPrimary)
                Text(status.def.detail)
                    .font(AppFont.body(14))
                    .foregroundStyle(AppColor.textSecondary)
            }
            Spacer()
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardY)
    }
}
