import Foundation

// Starter contract for DATA-03 (#57) and DATA-08 (#83).
// Students add an implementation here when their ticket is assigned.
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership.
protocol OutfitFunctions {
    /// Save the supplied record at users/{ownerId}/outfits/{id}; throw on failure.
    func saveOutfit(_ outfit: Outfit) async throws

    /// Read and decode users/{ownerId}/outfits; throw on read or decoding failure.
    func fetchOutfits(ownerId: String) async throws -> [Outfit]
}
