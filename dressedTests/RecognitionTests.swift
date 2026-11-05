import ImageIO
import UniformTypeIdentifiers
import UIKit
import XCTest
import Vision
@testable import dressed

final class RecognitionTests: XCTestCase {
    #if targetEnvironment(simulator)
    @MainActor
    func testSimulatorClassifierUsesSupportedCPUAndCompletesInference() async throws {
        let request = VNClassifyImageRequest()
        try PrototypeGarmentRecognition.configureCompute(request)
        guard case .cpu? = request.computeDevice(for: .main) else {
            return XCTFail("Simulator classification should use a supported CPU")
        }
        let metrics = RecognitionMetrics()
        // A valid inference can still return no garment hint. Do not require a
        // particular label from a synthetic image or turn uncertainty into success.
        _ = try await PrototypeGarmentRecognition.analyze(RecognitionDemoImage.make(), metrics: metrics)
        XCTAssertTrue(metrics.snapshot().stages.contains { $0.name == "classification" })
        XCTAssertTrue(metrics.snapshot().warnings.isEmpty)
    }
    #endif

    @MainActor
    func testNativeCropDoesNotMultiplySourcePixelsByScreenScale() throws {
        let data = RecognitionDemoImage.make()
        let piece = candidate(region: NormalizedImageRegion(x: 0.25, y: 0.25, width: 0.5, height: 0.5))
        let native = try RecognitionImageSession(data: data, mode: .nativePixels, metrics: RecognitionMetrics())
        let original = try RecognitionImageSession(data: data, mode: .baseline, metrics: RecognitionMetrics())
        let crop = try XCTUnwrap(UIImage(data: native.crop(piece))?.cgImage)
        XCTAssertEqual(crop.width, 600)
        XCTAssertEqual(crop.height, 800)
        let before = try XCTUnwrap(UIImage(data: original.crop(piece))?.cgImage)
        XCTAssertGreaterThanOrEqual(before.width, crop.width)
        // Production review/saving uses the same native scale, not just the benchmark.
        let production = try XCTUnwrap(UIImage(data: SharedImportDraftStore.imageData(for: piece, in: data))?.cgImage)
        XCTAssertEqual(production.width, crop.width)
        XCTAssertEqual(production.height, crop.height)
    }

    @MainActor
    func testWholeImageFallbackDoesNotAddNativeDecodeOrChangeJPEG() throws {
        let data = RecognitionDemoImage.make()
        let piece = candidate(region: nil)
        let original = try RecognitionImageSession(data: data, mode: .baseline, metrics: RecognitionMetrics())
        let metrics = RecognitionMetrics()
        let native = try RecognitionImageSession(data: data, mode: .nativePixels, metrics: metrics)
        XCTAssertEqual(try original.crop(piece), try native.crop(piece))
        XCTAssertFalse(metrics.snapshot().stages.contains { $0.name == "prepare" })
    }

    @MainActor
    func testOrientationAndCompactLimitAreAppliedBeforeCropping() throws {
        let source = try XCTUnwrap(UIImage(data: RecognitionDemoImage.make())?.cgImage)
        let data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, source, [kCGImagePropertyOrientation: 6] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        let image = try RecognitionImageSession(data: data as Data, mode: .nativePixels, metrics: RecognitionMetrics())
        let piece = candidate(region: NormalizedImageRegion(x: 0, y: 0, width: 1, height: 1))
        let upright = try XCTUnwrap(UIImage(data: image.crop(piece))?.cgImage)
        XCTAssertEqual(upright.width, 1600)
        XCTAssertEqual(upright.height, 1200)
        let compact = try RecognitionImageSession(data: data as Data, mode: .compact, metrics: RecognitionMetrics())
        let smaller = try XCTUnwrap(UIImage(data: compact.crop(piece))?.cgImage)
        XCTAssertEqual(smaller.width, 1024)
        XCTAssertEqual(smaller.height, 768)
    }

    @MainActor
    func testInvalidImagesAndOutOfBoundsRegionsFailRatherThanCreatePieces() throws {
        XCTAssertThrowsError(try RecognitionImageSession(data: Data(), mode: .nativePixels, metrics: RecognitionMetrics()))
        let image = try RecognitionImageSession(data: RecognitionDemoImage.make(), mode: .nativePixels,
                                                metrics: RecognitionMetrics())
        XCTAssertThrowsError(try image.crop(candidate(region:
            NormalizedImageRegion(x: 0.9, y: 0, width: 0.5, height: 1))))
    }

    @MainActor
    func testCancelledRunDoesNotReturnCandidates() async throws {
        let data = RecognitionDemoImage.make()
        let task = Task {
            try await OnDeviceRecognitionPipeline.run(imageData: data, importID: UUID().uuidString)
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("A cancelled request must not return results")
        } catch is CancellationError { /* expected */ }
    }

    @MainActor
    func testOptimizedBackgroundMaskPreservesOutputForSameSyntheticInput() throws {
        let image = try XCTUnwrap(UIImage(data: RecognitionDemoImage.make())?.cgImage)
        // Test the changed arithmetic directly, independently of Vision availability.
        let before = AutomaticGarmentCutout.simpleBackgroundMask(image, optimized: false)
        let after = AutomaticGarmentCutout.simpleBackgroundMask(image, optimized: true)
        XCTAssertNotNil(before)
        XCTAssertEqual(before, after, "The fallback arithmetic optimization must preserve every output byte")
    }

    @MainActor
    func testScanlineMaskMatchesOriginalForHolesChannelsAndDisconnectedSubjects() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        for variant in 0..<6 {
            let image = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 192), format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 256, height: 192))
                UIColor.blue.setFill()
                context.fill(CGRect(x: 36, y: 24, width: 184, height: 144))
                UIColor.white.setFill()
                switch variant {
                case 0: // Enclosed white interior must remain opaque.
                    context.fill(CGRect(x: 65, y: 50, width: 126, height: 90))
                case 1: // A one-pixel channel connects the interior to the edge.
                    context.fill(CGRect(x: 65, y: 50, width: 126, height: 90))
                    context.fill(CGRect(x: 127, y: 0, width: 1, height: 70))
                case 2: // Separate foreground subjects.
                    context.fill(CGRect(x: 120, y: 0, width: 16, height: 192))
                case 3: // Many narrow row segments and connecting channels.
                    for x in stride(from: 42, to: 210, by: 8) {
                        context.fill(CGRect(x: x, y: 22, width: 2, height: 130))
                    }
                case 4: // Uniform background rejection must also match.
                    context.fill(CGRect(x: 0, y: 0, width: 256, height: 192))
                default: // Differing corners must reject the background.
                    UIColor.red.setFill()
                    context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
                }
            }
            let pixels = try XCTUnwrap(image.cgImage)
            let original = AutomaticGarmentCutout.simpleBackgroundMask(pixels, optimized: false)
            let scanline = AutomaticGarmentCutout.simpleBackgroundMask(pixels, optimized: true)
            if variant < 4 { XCTAssertNotNil(original) }
            XCTAssertEqual(original, scanline, "Output changed for topology fixture \(variant)")
        }
    }

    @MainActor
    func testScanlineMaskPreservesOutputAtOddAndNarrowDimensions() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        for size in [CGSize(width: 17, height: 29), CGSize(width: 63, height: 47),
                     CGSize(width: 311, height: 197), CGSize(width: 240, height: 511)] {
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor.blue.setFill()
                let insetX = max(2, floor(size.width * 0.15))
                let insetY = max(2, floor(size.height * 0.15))
                context.fill(CGRect(x: insetX, y: insetY,
                                    width: size.width - 2 * insetX, height: size.height - 2 * insetY))
                UIColor.white.setFill()
                context.fill(CGRect(x: size.width / 2, y: 0, width: 1, height: size.height / 2))
            }
            let pixels = try XCTUnwrap(image.cgImage)
            let original = AutomaticGarmentCutout.simpleBackgroundMask(pixels, optimized: false)
            XCTAssertNotNil(original)
            XCTAssertEqual(original, AutomaticGarmentCutout.simpleBackgroundMask(pixels, optimized: true),
                           "Output changed at \(size)")
        }
    }

    func testInterruptedDraftWithManualPieceResumesButCompletedReviewDoesNot() {
        var draft = ImportDraft(id: UUID().uuidString, schemaVersion: 1, ownerId: "synthetic-owner",
            source: ClothingSource(kind: .sharedImage, originalURL: nil, importedAt: Date()),
            temporaryImagePath: "unused-test-path", status: .processing,
            candidates: [candidate(region: nil)], createdAt: Date(), expiresAt: Date().addingTimeInterval(86400))
        XCTAssertTrue(SharedImportDraftStore.shouldRecognize(draft))
        draft.status = .review
        XCTAssertFalse(SharedImportDraftStore.shouldRecognize(draft))
        draft.candidates = []
        XCTAssertTrue(SharedImportDraftStore.shouldRecognize(draft))
        draft.status = .saved
        XCTAssertFalse(SharedImportDraftStore.shouldRecognize(draft))
    }

    func testRetryKeepsEditsSelectionAndPiecesNotFoundAgain() {
        var edited = candidate(region: nil)
        edited.name = "My edited shirt"
        edited.selected = true
        var newSuggestion = edited
        newSuggestion.name = "Shirt"
        newSuggestion.selected = false
        let manual = candidate(region: nil)
        var missed = candidate(region: nil)
        missed.suggestionSource = "Body region suggestion"
        let fresh = candidate(region: nil)
        let merged = SharedImportDraftStore.mergingSuggestions([newSuggestion, fresh],
                                                               into: [edited, manual, missed])
        XCTAssertEqual(merged.map(\.id), [edited.id, fresh.id, manual.id, missed.id])
        XCTAssertEqual(merged[0].name, "My edited shirt")
        XCTAssertTrue(merged[0].selected)
    }

    private func candidate(region: NormalizedImageRegion?) -> ImportCandidate {
        ImportCandidate(id: UUID().uuidString, name: "Synthetic shirt", category: .tops,
                        destination: .closet, temporaryCutoutPath: nil, region: region,
                        suggestionSource: nil, selected: false, tags: [], suggestedTags: [])
    }
}
