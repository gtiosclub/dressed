//
//  OutfitFilters.swift
//  dressed
//
//  Created by Tvisha Talwar on 10/13/26.
//

func outfitsContainingItem(
    _ outfits: [Outfit],
    itemId: String
) -> [Outfit] {
    return outfits.filter { outfit in
        outfit.placements.contains { placement in
            placement.itemId == itemId
        }
    }
}
