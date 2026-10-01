import Foundation
import FirebaseFirestore

// Starter contract for DATA-03 (#57) and DATA-08 (#83).
// Students add an implementation here when their ticket is assigned.
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership.
protocol OutfitFunctions {
    /// Save the supplied record at users/{ownerId}/outfits/{id}; throw on failure.
    func saveOutfit(_ outfit: Outfit) async throws

    /// Read and decode users/{ownerId}/outfits; throw on read or decoding failure.
    func fetchOutfits(ownerId: String) async throws -> [Outfit]
}

enum OutfitFunctionsError: Error {
    case notImplemented
}

struct FirestoreOutfitFunctions: OutfitFunctions {
    private let db = Firestore.firestore()

    // DATA-03 (#57) owns this one.
    func saveOutfit(_ outfit: Outfit) async throws {
        throw OutfitFunctionsError.notImplemented
    }

    // DATA-08 (#83)
    func fetchOutfits(ownerId: String) async throws -> [Outfit] {
        let snapshot = try await db
            .collection("users")
            .document(ownerId)
            .collection("outfits")
            .getDocuments()

        return try snapshot.documents.map { document in
            try document.data(as: Outfit.self)
        }
    }
}
