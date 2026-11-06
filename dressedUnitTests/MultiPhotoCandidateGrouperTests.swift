import XCTest
import UIKit
import Vision
@testable import dressed

final class MultiPhotoCandidateGrouperTests: XCTestCase {
    func testOutfitMergesMatchingGarmentAcrossPhotosAndKeepsSightings() {
        let observations = [
            observation(photoId: "front", name: "Jacket", category: .outerwear),
            observation(photoId: "back", name: "Jacket", category: .outerwear)
        ]

        let candidates = MultiPhotoCandidateGrouper.outfitCandidates(
            from: observations,
            importID: "test-import"
        )

        XCTAssertEqual(candidates.count, 1)
        XCTAssertEqual(candidates[0].sightings?.map(\.photoId), ["front", "back"])
    }

    func testOutfitKeepsDifferentGarmentsAndSamePhotoDetectionsSeparate() {
        let observations = [
            observation(photoId: "front", name: "Jacket", category: .outerwear),
            observation(photoId: "front", name: "Shirt", category: .tops),
            observation(photoId: "back", name: "Jacket", category: .outerwear),
            observation(photoId: "back", name: "Jacket", category: .outerwear)
        ]

        let candidates = MultiPhotoCandidateGrouper.outfitCandidates(
            from: observations,
            importID: "test-import"
        )

        XCTAssertEqual(candidates.count, 3)
        XCTAssertEqual(candidates.filter { $0.name == "Jacket" }.count, 2)
        XCTAssertEqual(candidates.first { $0.sightings?.count == 2 }?.sightings?.count, 2)
    }

    func testOneItemUsesMostSupportedGuessAndKeepsDisagreementEvidence() {
        let observations = [
            observation(photoId: "front", name: "Jacket", category: .outerwear, confidence: 0.62),
            observation(photoId: "side", name: "Jacket", category: .outerwear, confidence: 0.67),
            observation(photoId: "back", name: "Coat", category: .outerwear, confidence: 0.98)
        ]

        let candidate = MultiPhotoCandidateGrouper.oneItemCandidate(
            from: observations,
            importID: "test-import"
        )

        XCTAssertEqual(candidate?.name, "Jacket")
        XCTAssertEqual(candidate?.category, .outerwear)
        XCTAssertEqual(candidate?.sightings?.count, 3)
        XCTAssertTrue(candidate?.sightings?.contains(where: { $0.name == "Coat" }) == true)
    }

    func testGenericFallbacksAreNotMergedAsOutfitPieces() {
        let observations = [
            observation(photoId: "first", name: "Piece", category: .other),
            observation(photoId: "second", name: "Piece", category: .other)
        ]

        let candidates = MultiPhotoCandidateGrouper.outfitCandidates(
            from: observations,
            importID: "test-import"
        )

        XCTAssertEqual(candidates.count, 2)
    }

    func testSplitSightingCreatesUnselectedStablePiece() {
        let observations = [
            observation(photoId: "front", name: "Jacket", category: .outerwear),
            observation(photoId: "back", name: "Jacket", category: .outerwear)
        ]
        let candidate = try! XCTUnwrap(
            MultiPhotoCandidateGrouper.outfitCandidates(from: observations, importID: "test-import").first
        )
        let sighting = try! XCTUnwrap(candidate.sightings?.last)

        let split = try! XCTUnwrap(
            MultiPhotoCandidateGrouper.splitSighting(sighting, from: candidate, importID: "test-import")
        )

        XCTAssertEqual(split.updated.sightings?.count, 1)
        XCTAssertEqual(split.separated.sightings?.count, 1)
        XCTAssertEqual(split.separated.name, sighting.name)
        XCTAssertFalse(split.separated.selected)
        XCTAssertNotEqual(split.updated.id, split.separated.id)
        XCTAssertNil(
            MultiPhotoCandidateGrouper.splitSighting(sighting, from: split.separated, importID: "test-import")
        )
    }

    func testMergeCandidatesKeepsTargetIdentityAndCombinesSightings() {
        let observations = [
            observation(photoId: "photo-a", name: "Jacket", category: .outerwear),
            observation(photoId: "photo-b", name: "Coat", category: .outerwear)
        ]
        var candidates = MultiPhotoCandidateGrouper.outfitCandidates(from: observations, importID: "test-import")
        let target = candidates[0]
        candidates[1].selected = true

        let merged = try! XCTUnwrap(MultiPhotoCandidateGrouper.mergeCandidates(candidates[1], into: target))

        XCTAssertEqual(merged.id, target.id)
        XCTAssertEqual(merged.name, target.name)
        XCTAssertEqual(merged.sightings?.count, 2)
        XCTAssertTrue(merged.selected)
    }

    func testOutfitUsesFeaturePrintAcrossDifferentNamesButNotCategories() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120)).image { context in
            UIColor.systemRed.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 120))
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 20, y: 20, width: 80, height: 80))
        }
        let imageData = try XCTUnwrap(image.pngData())
        let generatedPrint = await MultiPhotoCandidateGrouper.featurePrint(from: imageData)
        let featurePrint = try XCTUnwrap(generatedPrint)
        let observations = [
            observation(photoId: "front", name: "Jacket", category: .outerwear, featurePrint: featurePrint),
            observation(photoId: "back", name: "Coat", category: .outerwear, featurePrint: featurePrint),
            observation(photoId: "detail", name: "Shirt", category: .tops, featurePrint: featurePrint)
        ]

        let candidates = MultiPhotoCandidateGrouper.outfitCandidates(from: observations, importID: "test-import")

        XCTAssertEqual(candidates.count, 2)
        XCTAssertEqual(candidates.first(where: { $0.category == .outerwear })?.sightings?.count, 2)
        XCTAssertEqual(candidates.first(where: { $0.category == .tops })?.sightings?.count, 1)
    }

    func testOneItemWeightsVoteByConfidenceNotPhotoCount() {
        let observations = [
            observation(photoId: "front", name: "T-Shirt", category: .tops, confidence: 0.2),
            observation(photoId: "side", name: "T-Shirt", category: .tops, confidence: 0.2),
            observation(photoId: "back", name: "Jacket", category: .outerwear, confidence: 0.9)
        ]

        let candidate = MultiPhotoCandidateGrouper.oneItemCandidate(from: observations, importID: "test-import")

        XCTAssertEqual(candidate?.category, .outerwear)
        XCTAssertEqual(candidate?.name, "Jacket")
        XCTAssertEqual(candidate?.sightings?.first?.photoId, "back")
        XCTAssertTrue(candidate.map(MultiPhotoCandidateGrouper.photosDisagree) == true)
    }

    func testOneItemAgreementAndGenericFallbacksDoNotFlagDisagreement() {
        let observations = [
            observation(photoId: "front", name: "Jacket", category: .outerwear, confidence: 0.7),
            observation(photoId: "back", name: "Piece", category: .other)
        ]

        let candidate = try! XCTUnwrap(
            MultiPhotoCandidateGrouper.oneItemCandidate(from: observations, importID: "test-import")
        )

        XCTAssertEqual(candidate.category, .outerwear)
        XCTAssertFalse(MultiPhotoCandidateGrouper.photosDisagree(candidate))
    }

    func testSplittingRepresentativeSightingMovesCandidateRegion() {
        let observations = [
            observation(photoId: "front", name: "Jacket", category: .outerwear,
                        region: NormalizedImageRegion(x: 0.1, y: 0.1, width: 0.5, height: 0.5)),
            observation(photoId: "back", name: "Jacket", category: .outerwear,
                        region: NormalizedImageRegion(x: 0.3, y: 0.2, width: 0.4, height: 0.6))
        ]
        let candidate = try! XCTUnwrap(
            MultiPhotoCandidateGrouper.outfitCandidates(from: observations, importID: "test-import").first
        )
        let representative = try! XCTUnwrap(candidate.sightings?.first)

        let split = try! XCTUnwrap(
            MultiPhotoCandidateGrouper.splitSighting(representative, from: candidate, importID: "test-import")
        )

        XCTAssertEqual(split.updated.region?.x, 0.3)
        XCTAssertEqual(split.updated.sightings?.map(\.photoId), ["back"])
    }

    private func observation(
        photoId: String,
        name: String,
        category: ClothingCategory,
        confidence: Double? = nil,
        featurePrint: VNFeaturePrintObservation? = nil,
        region: NormalizedImageRegion = NormalizedImageRegion(x: 0.1, y: 0.1, width: 0.8, height: 0.8)
    ) -> PhotoCandidateObservation {
        PhotoCandidateObservation(
            photoId: photoId,
            candidate: ImportCandidate(
                id: UUID().uuidString,
                name: name,
                category: category,
                destination: .closet,
                temporaryCutoutPath: nil,
                region: region,
                suggestionSource: "Test",
                selected: false,
                tags: [],
                suggestedTags: []
            ),
            confidence: confidence,
            featurePrint: featurePrint
        )
    }
}