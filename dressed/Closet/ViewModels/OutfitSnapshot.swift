import Foundation

/// What the avatar is wearing at one moment: one closet item per clothing category.
/// Two snapshots are equal when every category holds the same item id.
/// `ClothingItem` is a shared schema type and isn't `Equatable`, so equality is by id.
struct OutfitSnapshot: Equatable {
    var items: [ClothingCategory: ClothingItem]

    init(_ items: [ClothingCategory: ClothingItem] = [:]) {
        self.items = items
    }

    static func == (lhs: OutfitSnapshot, rhs: OutfitSnapshot) -> Bool {
        lhs.items.mapValues(\.id) == rhs.items.mapValues(\.id)
    }

    /// The same outfit without any piece whose id isn't in `available` (for example, one deleted from the closet).
    func keeping(only available: Set<String>) -> OutfitSnapshot {
        OutfitSnapshot(items.filter { available.contains($0.value.id) })
    }
}
