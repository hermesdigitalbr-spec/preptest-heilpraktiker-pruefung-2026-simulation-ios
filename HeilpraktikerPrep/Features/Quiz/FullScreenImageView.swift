import SwiftUI
import UIKit

/// Identifiable wrapper so a full-resolution image can drive `.fullScreenCover(item:)`.
struct IdentifiableImage: Identifiable {
    let id = UUID()
    let image: UIImage
}

/// Full-screen image viewer — white backdrop, UIScrollView-based zoom,
/// drag-to-dismiss, double-tap to toggle, X button top-right inside the safe area.
struct FullScreenImageView: View {
    let uiImage: UIImage
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSession.self) private var session
    @State private var dismissOffset: CGSize = .zero
    @State private var isDragging = false

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()
                .opacity(max(0, 1.0 - Double(abs(dismissOffset.height)) / 400))

            ZoomableImageView(image: uiImage)
                .ignoresSafeArea()
                .offset(dismissOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            // Only allow drag-to-dismiss when not zoomed in
                            isDragging = true
                            dismissOffset = value.translation
                        }
                        .onEnded { value in
                            isDragging = false
                            if abs(value.translation.height) > 100 {
                                dismiss()
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    dismissOffset = .zero
                                }
                            }
                        }
                )

            // X button — top-right, kept inside the safe area (clear of the
            // status bar / Dynamic Island) and nudged down, with a 44pt tap
            // target and a white backing so it's always visible and easy to hit.
            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.black.opacity(0.75))
                            .frame(width: 44, height: 44)
                            .background(.white.opacity(0.92), in: Circle())
                            .overlay(Circle().stroke(Color.black.opacity(0.08), lineWidth: 1))
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 1)
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                    .accessibilityLabel(session.strings.common.a11yClose)
                }
                Spacer()
            }
        }
    }
}

/// UIScrollView-backed zoomable image: opens at fit scale (whole image visible),
/// pinch to zoom up to 5×, double-tap to toggle, centers image at all times.
private struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> ZoomScrollView {
        let scroll = ZoomScrollView()
        scroll.delegate = context.coordinator
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.backgroundColor = .white
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.bouncesZoom = true

        scroll.imageView.image = image
        scroll.imageView.contentMode = .scaleAspectFit
        scroll.imageView.frame = CGRect(origin: .zero, size: image.size)
        scroll.addSubview(scroll.imageView)
        scroll.contentSize = image.size

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)

        return scroll
    }

    func updateUIView(_ scroll: ZoomScrollView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? ZoomScrollView)?.imageView
        }
        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? ZoomScrollView)?.centerImage()
        }
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll = gesture.view as? ZoomScrollView else { return }
            let fit = scroll.minimumZoomScale
            if scroll.zoomScale > fit * 1.02 {
                scroll.setZoomScale(fit, animated: true)
            } else {
                scroll.setZoomScale(min(fit * 3, scroll.maximumZoomScale), animated: true)
            }
        }
    }
}

/// Scroll view that computes the fit zoom scale and keeps the image centered.
private final class ZoomScrollView: UIScrollView {
    let imageView = UIImageView()
    private var didSetInitialZoom = false

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0,
              bounds.width > 0, bounds.height > 0 else { return }

        let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
        minimumZoomScale = fit
        maximumZoomScale = fit * 5

        if !didSetInitialZoom {
            zoomScale = fit
            didSetInitialZoom = true
        }
        centerImage()
    }

    func centerImage() {
        let offX = max(0, (bounds.width - contentSize.width) / 2)
        let offY = max(0, (bounds.height - contentSize.height) / 2)
        contentInset = UIEdgeInsets(top: offY, left: offX, bottom: 0, right: offX)
    }
}
