import Foundation

enum AutomaticImportSuggestions {
    static func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        var candidates: [ImportCandidate] = []
        #if DEBUG
        // The optional development bridge supplies multi-piece boxes when running.
        candidates = (try? await LocalGarmentRecognition().detect(imageData: imageData, importID: importID)) ?? []
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
        return await SharedImportDraftStore.addAutomaticCutouts(to: candidates, imageData: imageData)
    }
}
