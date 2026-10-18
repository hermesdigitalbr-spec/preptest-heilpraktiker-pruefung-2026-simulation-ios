import CoreGraphics
import Foundation
import Testing
@testable import HeilpraktikerPrep

struct FaceCropTests {
    /// 3:4 portrait, like the studentNN assets.
    private let portrait = CGSize(width: 360, height: 480)

    /// Visible window in normalised image coordinates.
    private func window(_ r: FaceCrop.Result, tile: CGSize) -> CGRect {
        let left = (r.renderedSize.width - tile.width) / 2 - r.offset.width
        let top = (r.renderedSize.height - tile.height) / 2 - r.offset.height
        return CGRect(x: left / r.renderedSize.width, y: top / r.renderedSize.height,
                      width: tile.width / r.renderedSize.width, height: tile.height / r.renderedSize.height)
    }

    private func approx(_ a: CGFloat, _ b: CGFloat) -> Bool { abs(a - b) < 0.001 }

    @Test func fillsTileWithoutLetterbox() {
        let tile = CGSize(width: 132, height: 72)
        let r = FaceCrop.layout(imageSize: portrait, tileSize: tile, face: nil)
        #expect(r.renderedSize.width >= tile.width - 0.001)
        #expect(r.renderedSize.height >= tile.height - 0.001)
        let w = window(r, tile: tile)
        #expect(w.minY >= -0.001 && w.maxY <= 1.001 && w.minX >= -0.001 && w.maxX <= 1.001)
    }

    @Test func faceNearTopStaysVisibleInWideTile() {
        let tile = CGSize(width: 132, height: 72)
        let face = CGRect(x: 0.4, y: 0.08, width: 0.2, height: 0.15)
        let w = window(FaceCrop.layout(imageSize: portrait, tileSize: tile, face: face), tile: tile)
        #expect(w.minY <= face.minY - face.height * 0.25)
        #expect(w.maxY >= face.maxY)
    }

    @Test func faceNearBottomStaysVisible() {
        let tile = CGSize(width: 132, height: 72)
        let face = CGRect(x: 0.4, y: 0.7, width: 0.2, height: 0.15)
        let w = window(FaceCrop.layout(imageSize: portrait, tileSize: tile, face: face), tile: tile)
        #expect(w.minY <= face.minY)
        #expect(w.maxY >= face.maxY)
    }

    @Test func narrowTileCentresHorizontallyOnFace() {
        let tile = CGSize(width: 40, height: 160)
        let face = CGRect(x: 0.7, y: 0.2, width: 0.15, height: 0.12)
        let w = window(FaceCrop.layout(imageSize: portrait, tileSize: tile, face: face), tile: tile)
        #expect(w.minX <= face.minX && w.maxX >= face.maxX)
        #expect(approx(w.minY, 0) && approx(w.maxY, 1))
    }

    @Test func noFaceFallsBackToUpperThird() {
        let tile = CGSize(width: 132, height: 72)
        let w = window(FaceCrop.layout(imageSize: portrait, tileSize: tile, face: nil), tile: tile)
        #expect(approx(w.midY, FaceCrop.fallbackFocus.y))
        #expect(approx(w.midX, 0.5))
    }

    @Test func faceLargerThanWindowKeepsFaceCentre() {
        let tile = CGSize(width: 200, height: 40)
        let face = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.4)
        let w = window(FaceCrop.layout(imageSize: portrait, tileSize: tile, face: face), tile: tile)
        #expect(approx(w.midY, face.midY))
    }

    @Test func degenerateSizesDoNotCrash() {
        let r = FaceCrop.layout(imageSize: .zero, tileSize: CGSize(width: 10, height: 10), face: nil)
        #expect(r.offset == .zero)
    }

    @Test func visionBoxIsFlippedToTopLeft() {
        let box = FaceCrop.topLeft(fromVision: CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.2))
        #expect(approx(box.minY, 0.1) && approx(box.minX, 0.1))
    }

    @Test func focusPicksLargestPlausibleFace() {
        let subject = CGRect(x: 0.3, y: 0.2, width: 0.3, height: 0.225)
        let side = CGRect(x: 0.0, y: 0.5, width: 0.15, height: 0.11)
        let torso = CGRect(x: 0.2, y: 0.1, width: 0.3, height: 0.8)   // not face-shaped
        #expect(FaceCrop.focusRegion(faces: [side, torso, subject], imageSize: portrait) == subject)
        #expect(FaceCrop.focusRegion(faces: [], imageSize: portrait) == nil)
    }

    @Test func groupFocusIsUnionOfFaces() {
        let a = CGRect(x: 0.1, y: 0.3, width: 0.1, height: 0.15)
        let b = CGRect(x: 0.7, y: 0.32, width: 0.1, height: 0.15)
        let region = FaceCrop.focusRegion(faces: [a, b], imageSize: CGSize(width: 1024, height: 687), group: true)
        #expect(region == a.union(b))
    }

    @Test func paywallRowsDecodeWithDefaultAndClamp() throws {
        let dec = JSONDecoder()
        #expect(try dec.decode(NicheConfig.self, from: Data("{}".utf8)).paywallPhotoRows == 3)
        #expect(try dec.decode(NicheConfig.self, from: Data(#"{"paywallPhotoRows":4}"#.utf8)).paywallPhotoRows == 4)
        #expect(try dec.decode(NicheConfig.self, from: Data(#"{"paywallPhotoRows":40}"#.utf8)).paywallPhotoRows == 6)
    }
}
