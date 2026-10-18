#!/usr/bin/env swift
// Contact sheet of every people photo cropped the way the app crops it.
//
//   swift scripts/face-crop-preview.swift <dir-with-studentNN.jpg> <out.png>
//
// <dir> is searched recursively (an app root, its Assets.xcassets or the
// Onboarding folder all work) for studentNN*.jpg/png and heroGroup*.jpg/png.
// Each student row: the original with Vision's face box, then the paywall
// tile on iPhone 17 Pro, iPhone SE/mini and iPad 13", then the intro marquee
// tile. The hero group is drawn at the "lugar certo" frame for each device.
//
// The crop math below is a verbatim copy of
// TestBase/Design/Components/FaceCrop.swift (between the BEGIN/END markers);
// the script refuses to run if the two ever drift apart.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Vision

// BEGIN FaceCrop
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
// END FaceCrop

// MARK: - Drift guard

func checkNoDrift() {
    let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).standardizedFileURL
    var root = scriptURL.deletingLastPathComponent()
    if root.lastPathComponent == "scripts" { root = root.deletingLastPathComponent() }
    let sourceURL = root.appendingPathComponent("TestBase/Design/Components/FaceCrop.swift")
    guard let script = try? String(contentsOf: scriptURL, encoding: .utf8),
          let source = try? String(contentsOf: sourceURL, encoding: .utf8) else {
        FileHandle.standardError.write("warning: could not compare with FaceCrop.swift\n".data(using: .utf8)!)
        return
    }
    guard let begin = script.range(of: "// BEGIN FaceCrop\n"),
          let end = script.range(of: "// END FaceCrop") else { return }
    let copy = String(script[begin.upperBound..<end.lowerBound])
    let body = source.components(separatedBy: "\n").drop { !$0.hasPrefix("///") && !$0.hasPrefix("enum") }
    if copy.trimmingCharacters(in: .whitespacesAndNewlines)
        != body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) {
        FileHandle.standardError.write("error: FaceCrop copy in this script differs from \(sourceURL.path)\n".data(using: .utf8)!)
        exit(2)
    }
}

// MARK: - Geometry of the real screens (points)

struct Device {
    let name: String
    let paywallTile: CGSize
    let heroFrame: CGSize
}

/// Paywall slide 1: 7 x 4 tiles, 4pt gaps, in the art area of the slide.
/// Art width = screen - 2 x 20 (paywall margin) - 2 x 20 (slide padding);
/// art height = min(300, slide height - 124 - 28). Slide heights measured in
/// the simulator (see FACE_CROP_PATCH.md).
func paywallTile(artWidth: CGFloat, artHeight: CGFloat) -> CGSize {
    CGSize(width: (artWidth - 4 * 6) / 7, height: (artHeight - 4 * 3) / 4)
}

let devices: [Device] = [
    Device(name: "iPhone 17 Pro", paywallTile: paywallTile(artWidth: 402 - 80, artHeight: 206),
           heroFrame: CGSize(width: 402 - 48, height: 250)),
    Device(name: "iPhone SE", paywallTile: paywallTile(artWidth: 375 - 80, artHeight: 110),
           heroFrame: CGSize(width: 375 - 48, height: 250)),
    Device(name: "iPad 13\"", paywallTile: paywallTile(artWidth: 1032 - 80, artHeight: 300),
           heroFrame: CGSize(width: 700 - 48, height: 250)),
]
let marqueeTile = CGSize(width: 118, height: 118 * 4 / 3)

// MARK: - Images + Vision

func loadImage(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func detectFace(_ image: CGImage, group: Bool = false) -> CGRect? {
    let request = VNDetectFaceRectanglesRequest()
    try? VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    let faces = (request.results ?? []).map { FaceCrop.topLeft(fromVision: $0.boundingBox) }
    return FaceCrop.focusRegion(faces: faces, imageSize: CGSize(width: image.width, height: image.height), group: group)
}

func findPhotos(in dir: URL) -> (students: [URL], hero: URL?) {
    let exts = ["jpg", "jpeg", "png"]
    var students: [URL] = []
    var hero: URL?
    let walker = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
    while let url = walker?.nextObject() as? URL {
        guard exts.contains(url.pathExtension.lowercased()) else { continue }
        let name = url.deletingPathExtension().lastPathComponent
        if name.range(of: #"^student\d\d"#, options: .regularExpression) != nil,
           !students.contains(where: { $0.deletingPathExtension().lastPathComponent == name }) {
            students.append(url)
        } else if name.hasPrefix("heroGroup"), hero == nil {
            hero = url
        }
    }
    return (students.sorted { $0.lastPathComponent < $1.lastPathComponent }, hero)
}

// MARK: - Drawing (top-left coordinates)

let cellHeight: CGFloat = 150
let pad: CGFloat = 12

func displaySize(_ tile: CGSize, height: CGFloat) -> CGSize {
    let s = height / tile.height
    let w = tile.width * s
    return w > 420 ? CGSize(width: 420, height: tile.height * 420 / tile.width) : CGSize(width: w, height: height)
}

var cutFaces: [String] = []

/// True when the face box itself (not just the padding) leaves the tile.
func faceIsCut(_ r: FaceCrop.Result, face: CGRect, tile: CGSize) -> Bool {
    let left = (r.renderedSize.width - tile.width) / 2 - r.offset.width
    let top = (r.renderedSize.height - tile.height) / 2 - r.offset.height
    let box = CGRect(x: face.minX * r.renderedSize.width - left, y: face.minY * r.renderedSize.height - top,
                     width: face.width * r.renderedSize.width, height: face.height * r.renderedSize.height)
    return !CGRect(origin: .zero, size: tile).insetBy(dx: -0.5, dy: -0.5).contains(box)
}

func drawCrop(_ ctx: CGContext, image: CGImage, face: CGRect?, tile: CGSize, at origin: CGPoint,
              display: CGSize, label: String = "") {
    let imageSize = CGSize(width: image.width, height: image.height)
    let r = FaceCrop.layout(imageSize: imageSize, tileSize: tile, face: face)
    if let face, faceIsCut(r, face: face, tile: tile) { cutFaces.append(label) }
    let k = display.width / tile.width
    let rendered = CGSize(width: r.renderedSize.width * k, height: r.renderedSize.height * k)
    let imgOrigin = CGPoint(x: origin.x + (display.width - rendered.width) / 2 + r.offset.width * k,
                            y: origin.y + (display.height - rendered.height) / 2 + r.offset.height * k)
    ctx.saveGState()
    ctx.clip(to: CGRect(origin: origin, size: display))
    drawImage(ctx, image, CGRect(origin: imgOrigin, size: rendered))
    ctx.restoreGState()
    ctx.setStrokeColor(NSColor.gray.cgColor)
    ctx.setLineWidth(1)
    ctx.stroke(CGRect(origin: origin, size: display))
}

/// The context is flipped to top-left; flip back locally so the image is upright.
func drawImage(_ ctx: CGContext, _ image: CGImage, _ rect: CGRect) {
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.maxY)
    ctx.scaleBy(x: 1, y: -1)
    ctx.draw(image, in: CGRect(origin: .zero, size: rect.size))
    ctx.restoreGState()
}

func drawText(_ text: String, at point: CGPoint, size: CGFloat = 13, color: NSColor = .black) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .semibold),
                                                .foregroundColor: color]
    NSAttributedString(string: text, attributes: attrs).draw(at: point)
}

// MARK: - Main

checkNoDrift()
let args = CommandLine.arguments
guard args.count >= 3 else {
    print("usage: swift scripts/face-crop-preview.swift <dir-with-studentNN.jpg> <out.png>")
    exit(1)
}
let (students, hero) = findPhotos(in: URL(fileURLWithPath: args[1]))
guard !students.isEmpty || hero != nil else { print("no studentNN / heroGroup images under \(args[1])"); exit(1) }

let tiles = devices.map { ($0.name, $0.paywallTile) } + [("marquee", marqueeTile)]
let columns: [(String, CGSize)] = [("original", CGSize(width: 3, height: 4))] + tiles
let widths = columns.map { displaySize($0.1, height: cellHeight).width }
let studentRowWidth = pad + CGFloat(columns.count) * pad + widths.reduce(0, +) + 90
let heroDisplay = devices.map { displaySize($0.heroFrame, height: cellHeight) }
let heroRowWidth = pad + 90 + heroDisplay.reduce(0) { $0 + $1.width + pad } + cellHeight * 1.6
let width = max(studentRowWidth, heroRowWidth)
let headerH: CGFloat = 30
let height = headerH + CGFloat(students.count) * (cellHeight + pad) + (hero == nil ? 0 : cellHeight + pad * 3 + headerH) + pad

let scale: CGFloat = 1
guard let ctx = CGContext(data: nil, width: Int(width * scale), height: Int(height * scale), bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
ctx.translateBy(x: 0, y: height)
ctx.scaleBy(x: 1, y: -1)
ctx.setFillColor(NSColor.white.cgColor)
ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: true)

var x = pad + 90
for (i, col) in columns.enumerated() {
    let t = col.1
    let label = i == 0 ? col.0 : "\(col.0) \(Int(t.width))x\(Int(t.height))"
    drawText(label, at: CGPoint(x: x, y: 8), size: 11)
    x += widths[i] + pad
}

var y = headerH
var noFace: [String] = []
for url in students {
    guard let image = loadImage(url) else { continue }
    let name = url.deletingPathExtension().lastPathComponent
    let face = detectFace(image)
    if face == nil { noFace.append(name) }
    drawText(name, at: CGPoint(x: pad, y: y + 4), size: 12)
    if face == nil { drawText("NO FACE", at: CGPoint(x: pad, y: y + 22), size: 11, color: .red) }
    var cx = pad + 90
    // Original with the face box.
    let orig = CGRect(x: cx, y: y, width: widths[0], height: cellHeight)
    drawImage(ctx, image, orig)
    if let face {
        ctx.setStrokeColor(NSColor.red.cgColor)
        ctx.setLineWidth(1.5)
        ctx.stroke(CGRect(x: orig.minX + face.minX * orig.width, y: orig.minY + face.minY * orig.height,
                          width: face.width * orig.width, height: face.height * orig.height))
    }
    cx += widths[0] + pad
    for (i, tile) in tiles.enumerated() {
        let d = displaySize(tile.1, height: cellHeight)
        drawCrop(ctx, image: image, face: face, tile: tile.1, at: CGPoint(x: cx, y: y), display: d,
                 label: "\(name) @ \(tile.0)")
        cx += widths[i + 1] + pad
    }
    y += cellHeight + pad
}

if let hero, let image = loadImage(hero) {
    y += pad * 2
    let face = detectFace(image, group: true)
    drawText("heroGroup" + (face == nil ? "  NO FACE" : ""), at: CGPoint(x: pad, y: y), size: 12,
             color: face == nil ? .red : .black)
    var cx = pad + 90
    for (i, device) in devices.enumerated() {
        drawText("\(device.name) \(Int(device.heroFrame.width))x250", at: CGPoint(x: cx, y: y), size: 11)
        drawCrop(ctx, image: image, face: face, tile: device.heroFrame,
                 at: CGPoint(x: cx, y: y + headerH - 8), display: heroDisplay[i],
                 label: "heroGroup @ \(device.name)")
        cx += heroDisplay[i].width + pad
    }
    let aspect = CGFloat(image.width) / CGFloat(image.height)
    let orig = CGRect(x: cx, y: y + headerH - 8, width: cellHeight * aspect, height: cellHeight)
    drawImage(ctx, image, orig)
    if let face {
        ctx.setStrokeColor(NSColor.red.cgColor)
        ctx.stroke(CGRect(x: orig.minX + face.minX * orig.width, y: orig.minY + face.minY * orig.height,
                          width: face.width * orig.width, height: face.height * orig.height))
    }
}

guard let out = ctx.makeImage(),
      let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: args[2]) as CFURL,
                                                 "public.png" as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(dest, out, nil)
CGImageDestinationFinalize(dest)
print("\(students.count) students\(hero == nil ? "" : " + heroGroup") -> \(args[2])")
print(cutFaces.isEmpty ? "face box inside every tile" : "FACE CUT: \(cutFaces.joined(separator: ", "))")
if !noFace.isEmpty { print("no face detected: \(noFace.joined(separator: ", "))") }
