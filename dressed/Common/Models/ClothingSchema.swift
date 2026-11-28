import Foundation

// First closet milestone: one manually described item and its private photo.
// The lead supplies the ID and owner ID. Firebase access rules remain separate work.
nonisolated enum ClothingCategory: String, Codable, CaseIterable {
    case tops, pants, skirts, dresses, shoes, outerwear, accessories, other
}

struct ClothingItem: Codable, Identifiable {
    var id: String
    var ownerId: String
    var name: String
    var category: ClothingCategory
    var imagePath: String
    var createdAt: Date
}

extension ClothingItem {
    /// Scarves wear on the top body slot but stay categorized as accessories in the closet.
    var isScarfLike: Bool { TryOnBodySlot.scarfLikeName(name) }
}
