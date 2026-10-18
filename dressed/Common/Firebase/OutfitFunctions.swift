import Foundation
import FirebaseFirestore

// Shared contract for DATA-03 (#57) and DATA-08 (#83).
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership.
protocol OutfitFunctions {
    /// Save the supplied record at users/{ownerId}/outfits/{id}; throw on failure.
    func saveOutfit(_ outfit: Outfit) async throws

    /// Read and decode users/{ownerId}/outfits; throw on read or decoding failure.
    func fetchOutfits(ownerId: String) async throws -> [Outfit]

    /// Read and decode users/{ownerId}/outfits/{outfitId}; nil if absent; throw on read or decoding failure.
    func fetchOutfit(ownerId: String, outfitId: String) async throws -> Outfit?
}

extension OutfitFunctions {
    /// Save at the supplied stable ID; the server owns both timestamps.
    func saveOutfit(_ outfit: Outfit) async throws {
        var data = try Firestore.Encoder().encode(outfit)
        let document = Firestore.firestore()
            .collection("users")
            .document(outfit.ownerId)
            .collection("outfits")
            .document(outfit.id)
        let existing = try await document.getDocument(source: .server)

        data["updatedAt"] = FieldValue.serverTimestamp()
        if existing.exists {
            // Preserve the original creation time across edits and retries.
            data.removeValue(forKey: "createdAt")
            try await document.updateData(data)
        } else {
            data["createdAt"] = FieldValue.serverTimestamp()
            try await document.setData(data)
        }
    }

    /// Fetch owner-scoped records and propagate read or decoding errors.
    func fetchOutfits(ownerId: String) async throws -> [Outfit] {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .document(ownerId)
            .collection("outfits")
            .getDocuments(source: .server)

        return try snapshot.documents.map { document in
            try document.data(as: Outfit.self)
        }
    }

    /// Default Firestore implementation; returns nil only when the document is absent.
    func fetchOutfit(ownerId: String, outfitId: String) async throws -> Outfit? {
        let snapshot = try await Firestore.firestore()
            .collection("users")
            .document(ownerId)
            .collection("outfits")
            .document(outfitId)
            .getDocument(source: .server)

        // Absent document → nil. A present document that fails to decode throws.
        guard snapshot.exists else { return nil }
        return try snapshot.data(as: Outfit.self)
    }
}
