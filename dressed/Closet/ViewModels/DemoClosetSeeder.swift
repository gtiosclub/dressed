#if DEBUG
import UIKit

/// Debug-only demo data: fills an empty closet with the Figma product cutouts from
/// `PreviewAssets` and saves a few outfits. Runs by default in Debug builds; pass `-skipDemoCloset` (UI tests do) to start empty.
@MainActor
enum DemoClosetSeeder {
    private struct Piece {
        let id: String, asset: String, name: String, category: ClothingCategory
    }

    private static let pieces: [Piece] = [
        .init(id: "00000000-0000-4000-8000-000000000001", asset: "PreviewSweaterBrown", name: "Brown Wool Sweater", category: .tops),
        .init(id: "00000000-0000-4000-8000-000000000002", asset: "PreviewJeans", name: "Wide-Leg Jeans", category: .pants),
        .init(id: "00000000-0000-4000-8000-000000000003", asset: "PreviewNecklace", name: "Silver Pendant Necklace", category: .accessories),
        .init(id: "00000000-0000-4000-8000-000000000004", asset: "PreviewTeeNavy", name: "Navy Tee", category: .tops),
        .init(id: "00000000-0000-4000-8000-000000000005", asset: "PreviewTeeBlack", name: "Black Tee", category: .tops),
        .init(id: "00000000-0000-4000-8000-000000000006", asset: "PreviewTeeGrey", name: "Grey Tee", category: .tops),
        .init(id: "00000000-0000-4000-8000-000000000007", asset: "PreviewTeeWhite", name: "White Tee", category: .tops),
        .init(id: "00000000-0000-4000-8000-000000000008", asset: "PreviewShirtGingham", name: "Gingham Shirt", category: .tops),
        .init(id: "00000000-0000-4000-8000-000000000009", asset: "PreviewSweatshirtBrown", name: "Brown Sweatshirt", category: .tops),
        .init(id: "00000000-0000-4000-8000-00000000000A", asset: "PreviewTeeBlueGraphic", name: "Blue Graphic Tee", category: .tops),
    ]

    private static let outfits: [(id: String, name: String, items: [String])] = [
        ("10000000-0000-4000-8000-000000000001", "Cozy Weekend",
         ["00000000-0000-4000-8000-000000000001", "00000000-0000-4000-8000-000000000002", "00000000-0000-4000-8000-000000000003"]),
        ("10000000-0000-4000-8000-000000000002", "Easy Denim",
         ["00000000-0000-4000-8000-000000000004", "00000000-0000-4000-8000-000000000002"]),
    ]

    static func seedIfNeeded(closet: PrototypeClosetStore, outfits store: PrototypeOutfitStore) {
        guard !ProcessInfo.processInfo.arguments.contains("-skipDemoCloset"), closet.items.isEmpty else { return }
        for piece in pieces.reversed() {
            guard let data = UIImage(named: piece.asset)?.pngData() else { continue }
            try? closet.save(imageData: data, draftId: piece.id, name: piece.name, category: piece.category)
        }
        for outfit in outfits.reversed() {
            let ids = outfit.items.filter { closet.item(id: $0) != nil }
            let placements = ids.enumerated().map {
                OutfitPlacement(itemId: $0.element, centerX: 0.5, centerY: 0.5, width: 0.4, rotationDegrees: 0, layer: $0.offset)
            }
            try? store.save(id: outfit.id, name: outfit.name, placements: placements, availableItems: closet.items)
        }
    }
}
#endif
