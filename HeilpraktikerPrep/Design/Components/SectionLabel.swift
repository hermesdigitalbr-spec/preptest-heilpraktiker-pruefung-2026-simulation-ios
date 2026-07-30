import SwiftUI

/// Eyebrow caption used as a section header.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.heading(17))
            .foregroundStyle(AppColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
