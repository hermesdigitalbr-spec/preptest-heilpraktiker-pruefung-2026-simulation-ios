import SwiftUI

/// First results screen: the score being worked out, the verdict, and how the
/// quiz moved the user toward their badges. One button leads to the details.
struct QuizResultsSummary: View {
    @Environment(AppSession.self) private var app

    let revealedScore: Int
    let revealDone: Bool
    let tint: Color
    let correct: Int
    let total: Int
    let headline: String
    let badges: [ResultBadge]
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: AppSpacing.sectionGap) {
                    ring
                    Text(revealDone ? headline : app.strings.results.calculating)
                        .font(AppFont.display(32))
                        .foregroundStyle(revealDone ? AppColor.textPrimary : AppColor.textDim)
                        .multilineTextAlignment(.center)
                        .contentTransition(.opacity)
                        .animation(AppMotion.smooth, value: revealDone)
                    if revealDone {
                        VStack(spacing: AppSpacing.cardGap) {
                            ForEach(badges) { ResultBadgeCard(badge: $0) }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(AppSpacing.screenMargin)
                .padding(.top, AppSpacing.xl)
                .readableWidth()
            }

            PrimaryCTAButton(title: app.strings.common.continueButton, action: onContinue)
                .padding(AppSpacing.screenMargin)
                .readableWidth()
                .opacity(revealDone ? 1 : 0)
                .disabled(!revealDone)
        }
        .animation(AppMotion.bouncy, value: revealDone)
    }

    private var ring: some View {
        RingGauge(progress: Double(revealedScore) / 100,
                  lineWidth: 16,
                  tint: tint,
                  track: AppColor.surfaceHigh) {
            VStack(spacing: 2) {
                Text("\(revealedScore)%")
                    .font(AppFont.display(52))
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(revealedScore)))
                Text(String(format: app.strings.results.correctOfFormat, correct, total))
                    .font(AppFont.body(17))
                    .foregroundStyle(AppColor.textSecondary)
                    .monospacedDigit()
            }
        }
        .frame(maxWidth: 220)
        .scaleEffect(revealDone ? 1 : 0.96)
        .animation(.linear(duration: 0.05), value: revealedScore)
    }
}

/// A badge shown on the summary: either just earned, or the next one within
/// reach with its progress.
struct ResultBadge: Identifiable, Equatable {
    let status: AchievementStatus
    let justUnlocked: Bool
    var id: String { status.id }

    static let maxShown = 2

    /// New unlocks first, then the locked badges closest to unlocking.
    static func pick(newlyUnlocked: [AchievementStatus], all: [AchievementStatus]) -> [ResultBadge] {
        let fresh = newlyUnlocked.map { ResultBadge(status: $0, justUnlocked: true) }
        let freshIds = Set(fresh.map(\.id))
        let next = all
            .filter { !$0.unlocked && !freshIds.contains($0.id) && $0.fraction > 0 }
            .sorted { $0.fraction > $1.fraction }
            .map { ResultBadge(status: $0, justUnlocked: false) }
        return Array((fresh + next).prefix(maxShown))
    }
}

private struct ResultBadgeCard: View {
    @Environment(AppSession.self) private var app
    let badge: ResultBadge

    private var tint: Color { Color(hexString: badge.status.def.tint) }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                message
                    .font(AppFont.body(16))
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                ProgressView(value: badge.status.fraction)
                    .tint(tint)
            }
            Spacer(minLength: 0)
            badgeIcon
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .shadow(color: AppShadow.cardColor, radius: AppShadow.cardRadius, y: AppShadow.cardY)
    }

    private var message: Text {
        let s = app.strings.results
        let format = badge.justUnlocked ? s.badgeUnlockedFormat : s.badgeNextFormat
        let parts = format.components(separatedBy: "%@")
        let title = Text(badge.status.def.title).font(AppFont.strong(16))
        guard parts.count == 2 else { return Text(String(format: format, badge.status.def.title)) }
        return Text("\(parts[0])\(title)\(parts[1])")
    }

    private var badgeIcon: some View {
        let color = badge.justUnlocked ? tint : AppColor.textDim
        return Image(systemName: badge.status.def.icon)
            .font(.system(size: 28, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: 72, height: 72)
            .background(color.opacity(0.14), in: Circle())
            .overlay(Circle().stroke(color.opacity(0.35), lineWidth: 2))
    }
}
