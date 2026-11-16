#if DEBUG
import UIKit

/// Debug-only sample closet for simulator checks and UI tests. Launch with `-seedClosetFixture`.
/// Item ids are fixed, so seeding twice replaces the same four pieces instead of adding more.
enum ClosetFixture {
    private struct Piece {
        let id: String
        let name: String
        let category: ClothingCategory
        let color: UIColor
    }

    private static let pieces = [
        Piece(id: "6A3F0C11-0000-4000-8000-000000000001", name: "Blue Tee", category: .tops, color: .systemBlue),
        Piece(id: "6A3F0C11-0000-4000-8000-000000000002", name: "Red Shirt", category: .tops, color: .systemRed),
        Piece(id: "6A3F0C11-0000-4000-8000-000000000003", name: "Black Jeans", category: .pants, color: .darkGray),
        Piece(id: "6A3F0C11-0000-4000-8000-000000000004", name: "White Sneakers", category: .shoes, color: .systemTeal)
    ]

    @MainActor
    static func seed(into closet: PrototypeClosetStore) throws {
        for piece in pieces {
            let size = CGSize(width: 240, height: 240)
            let image = UIGraphicsImageRenderer(size: size).image { context in
                piece.color.setFill()
                context.fill(CGRect(origin: .zero, size: size))
            }
            guard let data = image.pngData() else { continue }
            try closet.save(imageData: data, draftId: piece.id, name: piece.name, category: piece.category)
        }
    }
}
#endif
