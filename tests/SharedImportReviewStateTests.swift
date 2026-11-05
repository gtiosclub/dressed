import Foundation

@main
struct SharedImportReviewStateTests {
    static func main() throws {
        let now = Date()
        func candidate(_ id: String) -> ImportCandidate {
            ImportCandidate(id: id, name: "Shirt", category: .tops, destination: .closet,
                            temporaryCutoutPath: nil, region: nil, suggestionSource: "Test",
                            selected: false, tags: [], suggestedTags: [])
        }
        let first = UUID().uuidString, second = UUID().uuidString
        var draft = ImportDraft(id: UUID().uuidString, schemaVersion: 1, ownerId: "test-owner",
                                source: ClothingSource(kind: .sharedImage, originalURL: nil, importedAt: now),
                                temporaryImagePath: "Inbox/test.jpg", status: .review,
                                candidates: [candidate(first), candidate(second)], createdAt: now,
                                expiresAt: now.addingTimeInterval(3600))
        SharedImportReviewState.review(first, selected: true, in: &draft)
        precondition(draft.candidates[0].selected && !draft.candidates[1].selected)
        precondition(draft.hasFinishedPieceReview == false)
        SharedImportReviewState.review(second, selected: false, in: &draft)
        SharedImportReviewState.review(second, selected: false, in: &draft)
        precondition(draft.hasFinishedPieceReview == true && draft.reviewedCandidateIDs?.count == 2)

        draft.candidates[0].name = "My edited shirt"
        draft.candidates[0].outline = [NormalizedImagePoint(x: 0, y: 0),
                                       NormalizedImagePoint(x: 1, y: 0), NormalizedImagePoint(x: 0, y: 1)]
        SharedImportReviewState.remove(second, from: &draft)
        SharedImportReviewState.merge([candidate(first), candidate(second)], into: &draft)
        precondition(draft.candidates.count == 1 && draft.candidates[0].name == "My edited shirt")
        precondition(draft.candidates[0].outline?.count == 3 && draft.candidates[0].selected)
        precondition(draft.hasFinishedPieceReview == true)

        let third = UUID().uuidString
        SharedImportReviewState.merge([candidate(third), candidate(third)], into: &draft)
        precondition(draft.candidates.count == 2 && draft.hasFinishedPieceReview == false)
        precondition(!draft.candidates[1].selected)
        draft.outfitName = "Friday outfit"
        draft.saveMode = .individualPieces
        let data = try JSONEncoder().encode(draft)
        let restored = try JSONDecoder().decode(ImportDraft.self, from: data)
        precondition(restored.outfitName == "Friday outfit" && restored.saveMode == .individualPieces)
        precondition(restored.reviewedCandidateIDs == draft.reviewedCandidateIDs)
        precondition(restored.removedCandidateIDs == draft.removedCandidateIDs)

        // Pre-change drafts have none of the new review metadata.
        var json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        for key in ["outfitName", "saveMode", "reviewedCandidateIDs", "removedCandidateIDs", "hasFinishedPieceReview"] {
            json.removeValue(forKey: key)
        }
        let legacy = try JSONDecoder().decode(ImportDraft.self, from: JSONSerialization.data(withJSONObject: json))
        precondition(legacy.saveMode == nil && legacy.outfitName == nil)
        precondition(legacy.candidates.count == 2)
        print("PASS: approve/skip, completion, retry preservation, removed pieces, deduplication, resume metadata, legacy drafts")
    }
}
