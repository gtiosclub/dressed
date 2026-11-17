//
//  PostFunctions.swift
//  dressed
//
//  Created by Daniel  Roldan on 9/29/26.
//

import Foundation
import FirebaseFirestore

protocol PostFunctions {
    func fetchRecentPosts() async throws -> [Post]
    /// Reads one published post. Returns nil when no post exists at that ID
    /// (for example, the author deleted it).
    func fetchPost(id: String) async throws -> Post?
}

struct FirebasePostFunctions: PostFunctions {
    private let db = Firestore.firestore()

    func fetchRecentPosts() async throws -> [Post] {
        let snapshot = try await db
            .collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: 20)
            .getDocuments()

        return try snapshot.documents.map { document in
            try document.data(as: Post.self)
        }
    }

    // Reads posts/{id}. Signed-in users may read posts under the current rules;
    // a missing document means the post is gone, which is not an error.
    func fetchPost(id: String) async throws -> Post? {
        let document = try await db
            .collection("posts")
            .document(id)
            .getDocument()

        guard document.exists else { return nil }
        return try document.data(as: Post.self)
    }
}
