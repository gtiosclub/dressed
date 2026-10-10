import Foundation
import FirebaseFirestore

// Shared contract for DATA-03 (#57) and DATA-08 (#83).
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership.
protocol OutfitFunctions {
    /// Save the supplied record at users/{ownerId}/outfits/{id}; throw on failure.
    func saveOutfit(_ outfit: Outfit) async throws

    /// Read and decode users/{ownerId}/outfits; throw on read or decoding failure.
    func fetchOutfits(ownerId: String) async throws -> [Outfit]
}

extension OutfitFunctions {
    /// Replace the document with the same ID; propagate encoding and write errors.
    func saveOutfit(_ outfit: Outfit) async throws {
        let data = try Firestore.Encoder().encode(outfit)
        try await Firestore.firestore()
            .collection("users")
            .document(outfit.ownerId)
            .collection("outfits")
            .document(outfit.id)
            .setData(data)
    }
}
