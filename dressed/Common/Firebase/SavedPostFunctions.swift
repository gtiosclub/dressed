import FirebaseFirestore

// SOCIAL-08 (#122): list the post IDs a user bookmarked at users/{ownerId}/savedPosts.
// Returns IDs only; loading the public post bodies is separate work.
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership (#94).
func fetchSavedPostIds(ownerId: String) async throws -> [String] {
    // .server throws while offline instead of returning a partial cached list.
    let snapshot = try await Firestore.firestore()
        .collection("users")
        .document(ownerId)
        .collection("savedPosts")
        .getDocuments(source: .server)

    // A malformed document throws rather than being skipped; repeated post IDs appear once.
    var seen = Set<String>()
    return try snapshot.documents
        .map { document in try document.data(as: SavedPost.self).postId }
        .filter { seen.insert($0).inserted }
}
