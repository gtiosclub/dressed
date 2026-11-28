import Foundation

// DATA-18 (#163): Filter supplied clothing items by name

func filterClothingItems(_ items: [ClothingItem], byName query: String) -> [ClothingItem] {
    let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else { return items }
    return items.filter { $0.name.localizedCaseInsensitiveContains(trimmedQuery) }
}
