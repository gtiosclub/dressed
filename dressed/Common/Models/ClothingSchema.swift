import Foundation

// First closet milestone: one manually described item and its private photo.
// The lead supplies the ID and owner ID. Firebase access rules remain separate work.
enum ClothingCategory: String, Codable, CaseIterable {
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
