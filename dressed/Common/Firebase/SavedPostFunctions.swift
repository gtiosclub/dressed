//
//  SavedPostFunctions.swift
//  dressed
//
//  Created by vasanth aggala on 10/6/26.
//

import FirebaseFirestore
import Foundation

// What the saved-post screens need from the backend, so previews and tests can use the demo version.
// The caller supplies the signed-in user's ID; Firestore rules enforce ownership (#94).
protocol SavedPostFunctions {
    func save(postId: String, ownerId: String) async throws
    func remove(postId: String, ownerId: String) async throws
    func fetchSavedIds(ownerId: String) async throws -> [String]
}

struct FirebaseSavedPostFunctions: SavedPostFunctions {
    func save(postId: String, ownerId: String) async throws {
        guard isValidFirestoreDocumentId(postId) else { throw SavedPostFunctionsError.invalidPostId }
        // The document ID, id and postId stay equal, so each post has exactly one saved document.
        try await savePost(SavedPost(id: postId, schemaVersion: 1, ownerId: ownerId, postId: postId,
                                     createdAt: Date()))
    }

    func remove(postId: String, ownerId: String) async throws {
        guard isValidFirestoreDocumentId(postId) else { throw SavedPostFunctionsError.invalidPostId }
        try await removeSavedPost(ownerId: ownerId, postId: postId)
    }

    func fetchSavedIds(ownerId: String) async throws -> [String] {
        try await fetchSavedPostIds(ownerId: ownerId)
    }
}

enum SavedPostFunctionsError: Error {
    case invalidPostId
}

// bookmarks an existing post for one user.
// writes users/{ownerId}/savedPosts/{postId}
// saving the same post again overwrites the previous entry
func savePost(_ savedPost: SavedPost) async throws {
    let docRef = Firestore.firestore()
        .collection("users")
        .document(savedPost.ownerId)
        .collection("savedPosts")
        .document(savedPost.id)

    let data = try Firestore.Encoder().encode(savedPost)
    try await docRef.setData(data)
}

func removeSavedPost(ownerId: String, postId: String) async throws {
    let docRef = Firestore.firestore()
        .collection("users")
        .document(ownerId)
        .collection("savedPosts")
        .document(postId)
    try await docRef.delete()
}

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
