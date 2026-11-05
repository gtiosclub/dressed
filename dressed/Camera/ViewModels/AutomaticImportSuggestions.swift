import Foundation

enum AutomaticImportSuggestions {
    struct ReviewResult {
        var candidates: [ImportCandidate]
        var possibleMissing: [PossibleMissingPiece]
    }

    static func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        try await review(imageData: imageData, importID: importID).candidates
    }

    // Same fallback chain as detect, but also surfaces "possible missing piece"
    // hints so review can ask for another photo instead of auto-saving.
    static func review(imageData: Data, importID: String) async throws -> ReviewResult {
        var hints: [PossibleMissingPiece] = []
        var candidates: [ImportCandidate] = []
        #if DEBUG
        // The optional development bridge supplies multi-piece boxes and clue
        // hints when running.
        if let outcome = try? await LocalGarmentRecognition().recognize(imageData: imageData, importID: importID) {
            candidates = outcome.candidates
            hints = outcome.possibleMissing
        }
        #endif
        if candidates.isEmpty {
            candidates = (try? await OnDeviceGarmentRegions.detect(imageData: imageData, importID: importID)) ?? []
        }
        if candidates.isEmpty, let suggestion = try? await PrototypeGarmentRecognition.analyze(imageData) {
            candidates = [ImportCandidate(
                id: SharedImportDraftStore.stableID(importID: importID, part: "whole-image"),
                name: suggestion.name,
                category: suggestion.category,
                destination: .closet,
                temporaryCutoutPath: nil,
                region: nil,
                suggestionSource: "On-device suggestion",
                selected: false,
                tags: [],
                suggestedTags: []
            )]
        }
        if candidates.isEmpty {
            candidates = [ImportCandidate(
                id: SharedImportDraftStore.stableID(importID: importID, part: "whole-image"),
                name: "Piece",
                category: .other,
                destination: .closet,
                temporaryCutoutPath: nil,
                region: nil,
                suggestionSource: "Review this photo",
                selected: false,
                tags: [],
                suggestedTags: []
            )]
        }
        return ReviewResult(
            candidates: await SharedImportDraftStore.addAutomaticCutouts(to: candidates, imageData: imageData),
            possibleMissing: hints
        )
    }
}
