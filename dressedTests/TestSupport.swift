import Foundation
@testable import dressed

enum TestSupport {
    static func item(_ id: String, _ category: ClothingCategory, owner: String = "owner") -> ClothingItem {
        ClothingItem(
            id: id,
            ownerId: owner,
            name: "Item \(id)",
            category: category,
            imagePath: "\(id).png",
            createdAt: Date(timeIntervalSince1970: 0)
        )
    }
}
