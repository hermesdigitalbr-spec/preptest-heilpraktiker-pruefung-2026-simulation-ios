import SwiftUI

struct ProBadge: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        Text(session.strings.common.pro)
            .font(AppFont.caption(12))
            .fontWeight(.bold)
            .foregroundStyle(AppColor.onWarning)
            .padding(.horizontal, AppSpacing.xs)
            .padding(.vertical, 2)
            .background(AppColor.warning)
            .clipShape(Capsule())
    }
}
