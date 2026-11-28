import Foundation

/// Builds a starter outfit from the closet so the avatar is not bare on first open.
enum OutfitDefaults {
    #if DEBUG
    private static let preferredItemIDs: [ClothingCategory: String] = [
      .tops: "6A3F0C11-0000-4000-8000-000000000001",
      .pants: "6A3F0C11-0000-4000-8000-000000000003",
      .shoes: "6A3F0C11-0000-4000-8000-000000000004"
    ]
    #else
    private static let preferredItemIDs: [ClothingCategory: String] = [:]
    #endif

    static func defaultWorn(from items: [ClothingItem]) -> [ClothingCategory: ClothingItem] {
        guard !items.isEmpty else { return [:] }
        var worn: [ClothingCategory: ClothingItem] = [:]

        func pick(_ category: ClothingCategory) -> ClothingItem? {
            if let id = preferredItemIDs[category], let match = items.first(where: { $0.id == id }) {
                return match
            }
            return items.first { $0.category == category }
        }

        if let top = pick(.tops) ?? items.first(where: { $0.category == .outerwear }) {
            worn[top.category] = top
        }
        if worn[.pants] == nil, worn[.skirts] == nil, worn[.dresses] == nil,
           let bottom = pick(.pants) ?? items.first(where: { [.skirts, .dresses].contains($0.category) }) {
            worn[bottom.category] = bottom
        }
        if let shoes = pick(.shoes) {
            worn[.shoes] = shoes
        }
        return worn
    }
}