import Foundation
import FirebaseFirestore

// Shared contract for DATA-04 (#70) and DATA-05 (#71).
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership.
protocol ClothingFunctions {
    /// Save the supplied record at users/{ownerId}/items/{id}; throw on failure.
    func saveClothingItem(_ item: ClothingItem) async throws

    /// Read and decode users/{ownerId}/items; throw on read or decoding failure.
    func fetchClothingItems(ownerId: String) async throws -> [ClothingItem]
}

extension ClothingFunctions {
    /// Save at the supplied stable ID; the server sets createdAt on first write.
    func saveClothingItem(_ item: ClothingItem) async throws {
        var data = try Firestore.Encoder().encode(item)
        let document = Firestore.firestore()
            .collection("users")
            .document(item.ownerId)
            .collection("items")
            .document(item.id)
        let existing = try await document.getDocument(source: .server)

        if existing.exists {
            // Keep the original server timestamp when a save is retried or edited.
            data.removeValue(forKey: "createdAt")
            try await document.updateData(data)
        } else {
            data["createdAt"] = FieldValue.serverTimestamp()
            try await document.setData(data)
        }
    }

    /// Default Firestore implementation; conformers can override it for previews or tests.
    func fetchClothingItems(ownerId: String) async throws -> [ClothingItem] {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .document(ownerId)
            .collection("items")
            .getDocuments(source: .server)

        // map returns [] for an empty collection and propagates every decoding error.
        return try snapshot.documents.map { document in
            try document.data(as: ClothingItem.self)
        }
    }
    
    func updateClothingDetails(
        ownerId: String,
        itemId: String,
        name: String,
        category: ClothingCategory
    ) async throws {
        let db = Firestore.firestore()
        let document = db.collection("clothing").document(itemId)

        let snapshot = try await document.getDocument()

        guard snapshot.exists else {
            throw NSError(
                domain: "ClothingFunctions",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Clothing item not found."]
            )
        }

        guard let existingOwnerId = snapshot.data()?["ownerId"] as? String,
              existingOwnerId == ownerId else {
            throw NSError(
                domain: "ClothingFunctions",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Clothing item does not belong to this owner."]
            )
        }

        try await document.updateData([
            "name": name,
            "category": category.rawValue
        ])
    }
}
