import Foundation

@MainActor
struct SharedImportSaveCoordinator {
    let closet: PrototypeClosetStore
    let outfits: PrototypeOutfitStore

    func confirm(draft: ImportDraft, imageData: Data, outfitName: String) throws -> Outfit {
        guard draft.expiresAt > Date(), draft.status == .review,
              closet.belongs(to: draft.ownerId), outfits.belongs(to: draft.ownerId),
              UUID(uuidString: draft.id) != nil else {
            throw SharedImportDraftError.invalidDraft
        }
        let selected = draft.candidates.filter(\.selected)
        guard !selected.isEmpty else { throw SharedImportDraftError.noSelection }
        guard selected.allSatisfy({ $0.destination == .closet && !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
              Set(selected.map(\.id)).count == selected.count else {
            throw SharedImportDraftError.invalidDraft
        }

        let outfitID = SharedImportDraftStore.stableID(importID: draft.id, part: "outfit")
        if let existing = outfits.outfits.first(where: { $0.id == outfitID }) {
            guard existing.ownerId == draft.ownerId,
                  Set(existing.placements.map(\.itemId)) == Set(selected.map(\.id)) else {
                throw SharedImportDraftError.invalidDraft
            }
            return existing
        }

        // Validate and crop every selected image before the first write.
        let images = try selected.map { try SharedImportDraftStore.imageData(for: $0, in: imageData) }
        let newIDs = Set(selected.map(\.id).filter { closet.item(id: $0) == nil })
        do {
            for (candidate, crop) in zip(selected, images) {
                try closet.save(imageData: crop, draftId: candidate.id,
                                name: candidate.name, category: candidate.category)
            }
            let placements = selected.enumerated().map { index, candidate in
                OutfitPlacement(
                    itemId: candidate.id,
                    centerX: selected.count == 1 ? 0.5 : (index % 2 == 0 ? 0.3 : 0.7),
                    centerY: selected.count == 1 ? 0.5 : min(0.25 + Double(index / 2) * 0.25, 0.8),
                    width: selected.count == 1 ? 0.55 : 0.42,
                    rotationDegrees: 0,
                    layer: index
                )
            }
            return try outfits.save(id: outfitID, name: outfitName,
                                    placements: placements, availableItems: closet.items)
        } catch {
            // The draft remains queued for a stable-ID retry. Never leave an outfit
            // pointing at pieces that failed to save.
            for candidate in selected where newIDs.contains(candidate.id) && closet.item(id: candidate.id) != nil {
                try? closet.delete(id: candidate.id)
            }
            throw error
        }
    }
}
