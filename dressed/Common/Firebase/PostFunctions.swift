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
    /// The posts that can be shown for these IDs. A missing post is left out, not an error.
    func fetchPosts(ids: [String]) async throws -> [Post]
}

/// Firestore raises an exception that can't be caught for an empty ID or one containing "/".
func isValidFirestoreDocumentId(_ id: String) -> Bool {
    !id.isEmpty && !id.contains("/")
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

    func fetchPosts(ids: [String]) async throws -> [Post] {
        let validIds = Array(Set(ids.filter(isValidFirestoreDocumentId))).sorted()
        let batchSize = 30 // The most values Firestore accepts in an "in" filter.
        var posts: [Post] = []
        for start in stride(from: 0, to: validIds.count, by: batchSize) {
            let batch = Array(validIds[start..<min(start + batchSize, validIds.count)])
            // .server throws while offline, so a post only counts as missing after a real lookup.
            let snapshot = try await db
                .collection("posts")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments(source: .server)
            // A post that can't be decoded is left out, so one bad public post can't block the
            // whole Saved screen. Its saved ID stays listed as unavailable and can be unsaved.
            posts += snapshot.documents.compactMap { document in
                try? document.data(as: Post.self)
            }
        }
        return posts
    }
}
