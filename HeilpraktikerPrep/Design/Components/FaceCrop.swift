import CoreGraphics

/// Pure crop math for filling a tile with a photo of people without cutting
/// their heads off. No UIKit/SwiftUI on purpose: the same file is compiled
/// into `scripts/face-crop-preview.swift` to render contact sheets on macOS.
///
/// Coordinates: `face` is normalised to the image (0...1) with a TOP-LEFT
/// origin. `offset` is how far the rendered image's centre moves from the
/// tile's centre (SwiftUI `.offset` semantics).
enum FaceCrop {
    struct Result: Equatable {
        let renderedSize: CGSize
        let offset: CGSize
    }

    /// Room kept above the top of the face box (forehead/hair), as a fraction
    /// of the face height. Vision's box starts around the eyebrows.
    static let headroom: CGFloat = 0.6
    /// Room kept below the face box (chin), as a fraction of the face height.
    static let chinRoom: CGFloat = 0.25
    /// Room kept on each side of the face box, as a fraction of its width.
    static let sideRoom: CGFloat = 0.25
    /// Where the window centres when no face was found: people photos keep
    /// the head in the upper third.
    static let fallbackFocus = CGPoint(x: 0.5, y: 0.3)

    static func layout(imageSize: CGSize, tileSize: CGSize, face: CGRect?) -> Result {
        guard imageSize.width > 0, imageSize.height > 0,
              tileSize.width > 0, tileSize.height > 0 else {
            return Result(renderedSize: tileSize, offset: .zero)
        }
        let scale = max(tileSize.width / imageSize.width, tileSize.height / imageSize.height)
        let rendered = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)

        let x: CGFloat
        let y: CGFloat
        if let face, face.width > 0, face.height > 0 {
            let top = face.minY - face.height * headroom
            let bottom = face.maxY + face.height * chinRoom
            let left = face.minX - face.width * sideRoom
            let right = face.maxX + face.width * sideRoom
            y = axisOrigin(low: max(0, top) * rendered.height,
                           high: min(1, bottom) * rendered.height,
                           faceCenter: face.midY * rendered.height,
                           window: tileSize.height, length: rendered.height)
            x = axisOrigin(low: max(0, left) * rendered.width,
                           high: min(1, right) * rendered.width,
                           faceCenter: face.midX * rendered.width,
                           window: tileSize.width, length: rendered.width)
        } else {
            y = clamp(fallbackFocus.y * rendered.height - tileSize.height / 2,
                      0, rendered.height - tileSize.height)
            x = clamp(fallbackFocus.x * rendered.width - tileSize.width / 2,
                      0, rendered.width - tileSize.width)
        }
        let offset = CGSize(width: (rendered.width - tileSize.width) / 2 - x,
                            height: (rendered.height - tileSize.height) / 2 - y)
        return Result(renderedSize: rendered, offset: offset)
    }

    /// Start of the visible window along one axis (in rendered points).
    /// The padded face region is shown whole when it fits — centred in the
    /// window — otherwise the window centres on the face itself.
    private static func axisOrigin(low: CGFloat, high: CGFloat, faceCenter: CGFloat,
                                   window: CGFloat, length: CGFloat) -> CGFloat {
        let center = high - low <= window ? (low + high) / 2 : faceCenter
        return clamp(center - window / 2, 0, length - window)
    }

    private static func clamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
        min(max(value, lower), max(lower, upper))
    }

    /// Picks the face to keep from Vision's boxes (already top-left,
    /// normalised): the largest plausible one — the photo's subject. A union
    /// of faces pulled portraits toward a hugging relative at the edge, and
    /// Vision now and then returns a torso-tall box, so boxes whose real
    /// (pixel) proportions aren't face-like are ignored.
    /// With `group` (the hero shot), keeps the union of every plausible face
    /// at least 40% the height of the largest, so the crop frames the group.
    static func focusRegion(faces: [CGRect], imageSize: CGSize, group: Bool = false) -> CGRect? {
        let plausible = faces.filter { box in
            let ratio = (box.height * imageSize.height) / max(box.width * imageSize.width, 1)
            return ratio > 0.6 && ratio < 1.7
        }
        guard let largest = plausible.max(by: { $0.width * $0.height < $1.width * $1.height }) else {
            return nil
        }
        guard group else { return largest }
        return plausible
            .filter { $0.height >= largest.height * 0.4 }
            .reduce(largest) { $0.union($1) }
    }

    /// Vision returns boxes with a bottom-left origin; flips to top-left.
    static func topLeft(fromVision box: CGRect) -> CGRect {
        CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
    }
}
