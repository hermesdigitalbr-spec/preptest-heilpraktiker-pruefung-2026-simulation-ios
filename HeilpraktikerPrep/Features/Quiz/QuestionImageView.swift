import SwiftUI

/// Thumbnail card shown inside a quiz question.
/// Tapping anywhere on the card (or the expand button) opens the fullscreen viewer.
/// Supports local assets (imageName) and remote/base64 URLs (imageURL).
/// Renders nothing for text-only questions, so it's safe to drop into any layout.
struct QuestionImageView: View {
    let question: Question
    var height: CGFloat = 150

    @State private var remoteImage: UIImage?
    @State private var fullScreenImage: IdentifiableImage?

    private var bundledImageName: String? {
        guard let name = question.imageName, !name.isEmpty,
              UIImage(named: name) != nil else { return nil }
        return name
    }

    var body: some View {
        Group {
            if let name = bundledImageName {
                card(Image(name))
            } else if let img = remoteImage {
                card(Image(uiImage: img))
            }
        }
        .task(id: question.imageURL ?? "") {
            remoteImage = await loadRemoteImage()
        }
        .fullScreenCover(item: $fullScreenImage) { wrapper in
            FullScreenImageView(uiImage: wrapper.image)
        }
    }

    @ViewBuilder
    private func card(_ image: Image) -> some View {
        ZStack(alignment: .topTrailing) {
            image
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .contentShape(Rectangle())
                .onTapGesture { openFullScreen() }

            // Expand button — top-right, matches CDL expand affordance
            Button { openFullScreen() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.45))
                    .clipShape(Circle())
            }
            .padding(AppSpacing.sm)
            .accessibilityLabel("Bild vergrößern")
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .padding(AppSpacing.md)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.card))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.card)
                .stroke(AppColor.border, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private func openFullScreen() {
        let img: UIImage? = {
            if let name = bundledImageName { return UIImage(named: name) }
            return remoteImage
        }()
        if let img { fullScreenImage = IdentifiableImage(image: img) }
    }

    private func loadRemoteImage() async -> UIImage? {
        if bundledImageName != nil { return nil }
        guard let urlString = question.imageURL, !urlString.isEmpty else { return nil }
        if urlString.hasPrefix("data:") {
            return await Task.detached(priority: .userInitiated) {
                guard let commaIdx = urlString.firstIndex(of: ",") else { return nil }
                let b64 = String(urlString[urlString.index(after: commaIdx)...])
                guard let data = Data(base64Encoded: b64, options: .ignoreUnknownCharacters) else { return nil }
                return UIImage(data: data)
            }.value
        }
        guard let url = URL(string: urlString) else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}
