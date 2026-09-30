import FirebaseFirestore

/// Saves the prepared outfit, replacing any existing document with the same ID.
func saveOutfit(_ outfit: Outfit) async throws {
    let data = try Firestore.Encoder().encode(outfit)

    try await Firestore.firestore()
        .collection("users")
        .document(outfit.ownerId)
        .collection("outfits")
        .document(outfit.id)
        .setData(data)
}
