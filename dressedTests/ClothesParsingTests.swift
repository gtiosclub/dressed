import CoreGraphics
import CoreML
import UIKit
import XCTest
@testable import dressed

final class ClothesParsingTests: XCTestCase {
    private let side = 100

    private func labelMap(_ blocks: [(ClothesParser.Label, x: Int, y: Int, w: Int, h: Int)]) -> [UInt8] {
        var map = [UInt8](repeating: 0, count: side * side)
        for block in blocks {
            for y in block.y..<(block.y + block.h) {
                for x in block.x..<(block.x + block.w) { map[y * side + x] = block.0.rawValue }
            }
        }
        return map
    }

    func testShoesMergeAndSkinHairAndFaceNeverBecomePieces() {
        let pieces = ClothesParser.pieces(labels: labelMap([
            (.hair, 40, 0, 20, 8), (.face, 40, 8, 20, 10), (.leftArm, 0, 20, 15, 30),
            (.upperClothes, 25, 20, 50, 30), (.pants, 30, 50, 40, 30), (.rightLeg, 30, 80, 10, 10),
            (.leftShoe, 25, 92, 10, 5), (.rightShoe, 65, 92, 10, 5),
        ]), width: side, height: side)
        XCTAssertEqual(pieces.map(\.part), ["top", "pants", "shoes"])
        let shoes = pieces[2].region
        XCTAssertLessThan(shoes.x, 0.26)
        XCTAssertGreaterThan(shoes.x + shoes.width, 0.74, "Both shoes are one piece")
    }

    func testLargerDressAbsorbsTopAndLargerTopAbsorbsDress() {
        let dress = ClothesParser.pieces(labels: labelMap([
            (.upperClothes, 30, 10, 40, 10), (.dress, 30, 20, 40, 60),
        ]), width: side, height: side)
        XCTAssertEqual(dress.map(\.part), ["dress"])
        XCTAssertEqual(dress[0].region.y, 0.09, accuracy: 0.001)
        let top = ClothesParser.pieces(labels: labelMap([
            (.upperClothes, 30, 10, 40, 50), (.dress, 30, 60, 40, 10),
        ]), width: side, height: side)
        XCTAssertEqual(top.map(\.part), ["top"])
    }

    func testSmallGarmentsAndSpecksAreDroppedButSmallAccessoriesStay() {
        let pieces = ClothesParser.pieces(labels: labelMap([
            (.skirt, 10, 10, 10, 10),          // 1% garment: dropped
            (.hat, 50, 0, 8, 5),               // 0.4% accessory: kept
            (.pants, 20, 40, 40, 40), (.pants, 90, 90, 3, 3), // speck is not part of the box
        ]), width: side, height: side)
        XCTAssertEqual(pieces.map(\.part), ["pants", "hat"])
        XCTAssertLessThan(pieces[0].region.x + pieces[0].region.width, 0.7)
    }

    func testCutoutIsCroppedWithTransparentOutsideAndOpaqueGarment() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let photo = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 400), format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 400, height: 400))
        }
        // A diamond, so the cutout's corners lie outside the garment.
        var pixels = [UInt8](repeating: 0, count: side * side)
        for y in 0..<side {
            for x in 0..<side where abs(x - 50) + abs(y - 50) < 30 { pixels[y * side + x] = 255 }
        }
        let mask = GarmentMask(width: side, height: side, pixels: pixels)
        let png = try XCTUnwrap(GarmentImage.cutout(of: XCTUnwrap(photo.cgImage), mask: mask))
        let cutout = try XCTUnwrap(UIImage(data: png)?.cgImage)
        XCTAssertEqual(Double(cutout.width), 240, accuracy: 8)
        let alpha = try alphaValues(cutout)
        for corner in [0, cutout.width - 1, alpha.count - cutout.width, alpha.count - 1] {
            XCTAssertEqual(alpha[corner], 0)
        }
        XCTAssertEqual(alpha[cutout.height / 2 * cutout.width + cutout.width / 2], 255)
        let soft = alpha.filter { $0 > 0 && $0 < 255 }.count
        XCTAssertGreaterThan(soft, 0, "The edge is feathered")
        XCTAssertLessThan(soft, alpha.count / 8, "The edge stays narrow")
    }

    func testMaskSurvivesPNGRoundTripAndEmptyMaskHasNoCutout() throws {
        var pixels = [UInt8](repeating: 0, count: 64 * 32)
        pixels[10 * 64 + 20] = 255
        let mask = GarmentMask(width: 64, height: 32, pixels: pixels)
        let decoded = try XCTUnwrap(GarmentMask(pngData: XCTUnwrap(mask.pngData)))
        XCTAssertEqual(decoded.pixels, pixels)
        let empty = GarmentMask(width: 64, height: 32, pixels: [UInt8](repeating: 0, count: 64 * 32))
        XCTAssertNil(empty.region())
        let image = try XCTUnwrap(UIImage(data: RecognitionDemoImage.make())?.cgImage)
        XCTAssertNil(GarmentImage.cutout(of: image, mask: empty))
    }

    @MainActor
    func testImportCutoutsNeverUseTheBackgroundFloodFill() async throws {
        #if targetEnvironment(simulator)
        // Vision's foreground mask cannot run here, so only the fallback decides the result.
        let data = RecognitionDemoImage.make()
        let clean = try await AutomaticGarmentCutout.png(from: data, allowsBackgroundFill: false)
        XCTAssertNil(clean, "Imports keep the clean rectangle")
        #endif
    }

    /// Runs the real model when TEST_RUNNER_CLOTHES_MODEL_PATH and TEST_RUNNER_CLOTHES_PHOTO_PATH are set.
    func testConvertedModelRunsInThisRuntime() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let model = environment["CLOTHES_MODEL_PATH"], let photo = environment["CLOTHES_PHOTO_PATH"] else {
            throw XCTSkip("No parsing model configured")
        }
        let loaded = try await ClothesParser.load(modelAt: URL(fileURLWithPath: model))
        let image = try XCTUnwrap(GarmentImage.upright(Data(contentsOf: URL(fileURLWithPath: photo))))
        let start = Date()
        let pieces = try ClothesParser.parse(image, model: loaded)
        print("Parsed \(pieces.map(\.part)) in \(Date().timeIntervalSince(start)) s")
        XCTAssertTrue(pieces.contains { $0.part == "top" })
        XCTAssertTrue(pieces.contains { $0.part == "pants" })
    }

    private func alphaValues(_ image: CGImage) throws -> [UInt8] {
        var rgba = [UInt8](repeating: 0, count: image.width * image.height * 4)
        try rgba.withUnsafeMutableBytes { bytes in
            let context = try XCTUnwrap(CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        return stride(from: 3, to: rgba.count, by: 4).map { rgba[$0] }
    }
}
