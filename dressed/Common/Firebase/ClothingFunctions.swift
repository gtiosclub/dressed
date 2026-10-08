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
}
