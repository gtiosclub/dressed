//
//  SavedPostFunctions.swift
//  dressed
//
//  Created by vasanth aggala on 10/6/26.
//

import FirebaseFirestore

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
