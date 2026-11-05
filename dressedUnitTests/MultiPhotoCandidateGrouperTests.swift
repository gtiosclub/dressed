import XCTest
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

    private func observation(
        photoId: String,
        name: String,
        category: ClothingCategory,
        confidence: Double? = nil
    ) -> PhotoCandidateObservation {
        PhotoCandidateObservation(
            photoId: photoId,
            candidate: ImportCandidate(
                id: UUID().uuidString,
                name: name,
                category: category,
                destination: .closet,
                temporaryCutoutPath: nil,
                region: NormalizedImageRegion(x: 0.1, y: 0.1, width: 0.8, height: 0.8),
                suggestionSource: "Test",
                selected: false,
                tags: [],
                suggestedTags: []
            ),
            confidence: confidence
        )
    }
}