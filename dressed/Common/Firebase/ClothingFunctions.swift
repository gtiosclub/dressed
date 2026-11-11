import Foundation
import FirebaseFirestore

// Shared contract for DATA-04 (#70) and DATA-05 (#71).
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership.
protocol ClothingFunctions {
    /// Save the supplied record at users/{ownerId}/items/{id}; throw on failure.
    func saveClothingItem(_ item: ClothingItem) async throws

    /// Read and decode users/{ownerId}/items; throw on read or decoding failure.
    func fetchClothingItems(ownerId: String) async throws -> [ClothingItem]

    /// Read and decode users/{ownerId}/items/{itemId}; nil if absent; throw on read or decoding failure.
    func fetchClothingItem(ownerId: String, itemId: String) async throws -> ClothingItem?
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

    /// Default Firestore implementation; returns nil only when the document is absent.
    func fetchClothingItem(ownerId: String, itemId: String) async throws -> ClothingItem? {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .document(ownerId)
            .collection("items")
            .document(itemId)
            .getDocument(source: .server)

        // Absent document → nil. A present document that fails to decode throws.
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: ClothingItem.self)
    }
}
