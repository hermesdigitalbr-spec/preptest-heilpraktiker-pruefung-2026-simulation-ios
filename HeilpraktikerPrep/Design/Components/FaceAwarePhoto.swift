import SwiftUI
import UIKit
import Vision

/// Fills a frame of any size with an asset photo of people, cropping so the
/// detected face keeps its whole head in view (see `FaceCrop`). Until the
/// face is known it draws with the top-biased fallback; the launch warm-up
/// (`FaceRegionStore.warmUp`) makes that window invisible in practice.
struct FaceAwarePhoto: View {
    let name: String
    let width: CGFloat
    let height: CGFloat
    /// Frame the whole group (hero shot) instead of the main subject.
    var group = false

    @State private var detection: FaceRegionStore.Detection?

    init(name: String, width: CGFloat, height: CGFloat, group: Bool = false) {
        self.name = name
        self.width = width
        self.height = height
        self.group = group
        _detection = State(initialValue: FaceRegionStore.shared.cached(name, group: group))
    }

    var body: some View {
        let tile = CGSize(width: width, height: height)
        // Before detection lands, the fallback focus (upper third) is used;
        // UIImage(named:) is cached by UIKit, so the size lookup is cheap.
        let imageSize = detection?.imageSize ?? UIImage(named: name)?.size
        let layout = imageSize.map {
            FaceCrop.layout(imageSize: $0, tileSize: tile, face: detection?.face)
        }
        Color.clear
            .frame(width: width, height: height)
            .overlay {
                if let layout {
                    Image(name)
                        .resizable()
                        .frame(width: layout.renderedSize.width, height: layout.renderedSize.height)
                        .offset(layout.offset)
                } else {
                    Image(name)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                }
            }
            .clipped()
            .task(id: name) {
                guard detection == nil else { return }
                detection = await FaceRegionStore.shared.detection(for: name, group: group)
            }
    }
}

/// In-memory cache of face regions per asset, filled off the main thread.
final class FaceRegionStore: @unchecked Sendable {
    struct Detection: Sendable, Equatable {
        let imageSize: CGSize
        /// Normalised, top-left origin; nil when Vision found no face.
        let face: CGRect?
    }

    static let shared = FaceRegionStore()

    private let lock = NSLock()
    private var cache: [String: Detection] = [:]

    private static func key(_ name: String, group: Bool) -> String { group ? "group:" + name : name }

    func cached(_ name: String, group: Bool = false) -> Detection? {
        lock.withLock { cache[Self.key(name, group: group)] }
    }

    func detection(for name: String, group: Bool = false) async -> Detection? {
        if let hit = cached(name, group: group) { return hit }
        let result = await Task.detached(priority: .utility) {
            Self.detect(name, group: group)
        }.value
        if let result {
            lock.withLock { cache[Self.key(name, group: group)] = result }
        }
        return result
    }

    /// Detects every people photo the funnel and paywall show, in the
    /// background, so the paywall grid never jumps when it appears.
    func warmUp(students: [String], hero: String) {
        Task.detached(priority: .utility) {
            _ = await self.detection(for: hero, group: true)
            for name in students {
                _ = await self.detection(for: name)
            }
        }
    }

    /// Nil only when the asset can't be loaded.
    private static func detect(_ name: String, group: Bool) -> Detection? {
        guard let image = UIImage(named: name), let cgImage = image.cgImage else { return nil }
        let size = CGSize(width: cgImage.width, height: cgImage.height)
        let request = VNDetectFaceRectanglesRequest()
        do {
            try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
        } catch {
            return Detection(imageSize: size, face: nil)
        }
        let faces = (request.results ?? []).map { FaceCrop.topLeft(fromVision: $0.boundingBox) }
        return Detection(imageSize: size, face: FaceCrop.focusRegion(faces: faces, imageSize: size, group: group))
    }
}
