import SwiftUI

/// Circular progress ring with a knob at the progress point and free-form
/// center content. Used for the exam countdown and the results score.
struct RingGauge<Center: View>: View {
    /// 0...1
    let progress: Double
    var lineWidth: CGFloat = 16
    var tint: Color = AppColor.accent
    var track: Color = AppColor.surfaceHigh
    @ViewBuilder let center: Center

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let radius = (side - lineWidth) / 2
            let clamped = min(max(progress, 0), 1)

            ZStack {
                // Inset by half the stroke so the arc centerline sits at
                // `radius`, matching the knob's orbit — a bare .stroke
                // straddles the frame edge and leaves the knob lineWidth/2
                // inside the arc.
                Circle()
                    .inset(by: lineWidth / 2)
                    .stroke(track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: clamped)
                    .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                // Knob with a surface-colored halo so it reads as a distinct
                // marker instead of merging with the arc into a blob.
                ZStack {
                    Circle()
                        .fill(AppColor.surface)
                        .frame(width: lineWidth * 2.1, height: lineWidth * 2.1)
                    Circle()
                        .fill(tint)
                        .frame(width: lineWidth * 1.3, height: lineWidth * 1.3)
                }
                .shadow(color: AppShadow.cardColor, radius: 3, y: 1)
                .offset(y: -radius)
                .rotationEffect(.degrees(clamped * 360))

                center
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .animation(AppMotion.smooth, value: progress)
    }
}
