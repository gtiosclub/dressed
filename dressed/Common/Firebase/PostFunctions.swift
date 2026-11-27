//
//  PostFunctions.swift
//  dressed
//
//  Created by Daniel  Roldan on 9/29/26.
//

import Foundation
import FirebaseFirestore

protocol PostFunctions {
    func fetchPost(id: String) async throws -> Post?
    func fetchRecentPosts() async throws -> [Post]
    func fetchPostPage(after cursor: PostPageCursor?) async throws -> PostPage
    /// The posts that can be shown for these IDs. A missing post is left out, not an error.
    func fetchPosts(ids: [String]) async throws -> [Post]
}

struct PostPageCursor: Equatable {
    let createdAt: Date
    let id: String
}

struct PostPage {
    let posts: [Post]
    let nextCursor: PostPageCursor?
}

extension PostFunctions {
    /// Compatibility for fixture services that expose a single bounded result set.
    func fetchPostPage(after cursor: PostPageCursor?) async throws -> PostPage {
        guard cursor == nil else { return PostPage(posts: [], nextCursor: nil) }
        return PostPage(posts: try await fetchRecentPosts(), nextCursor: nil)
    }
}

/// Firestore raises an exception that can't be caught for an empty ID or one containing "/".
func isValidFirestoreDocumentId(_ id: String) -> Bool {
    !id.isEmpty && !id.contains("/")
}

struct FirebasePostFunctions: PostFunctions {
    private let db = Firestore.firestore()
    private let pageSize = 20

    func fetchRecentPosts() async throws -> [Post] {
        let snapshot = try await db
            .collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
            .getDocuments()

        return try snapshot.documents.map { document in
            try document.data(as: Post.self)
        }
    }

    func fetchPostPage(after cursor: PostPageCursor?) async throws -> PostPage {
        var query: Query = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .order(by: FieldPath.documentID())
            .limit(to: pageSize)

        if let cursor {
            query = query.start(after: [cursor.createdAt, cursor.id])
        }

        let snapshot = try await query.getDocuments()
        let posts = snapshot.documents.compactMap { try? $0.data(as: Post.self) }
        let nextCursor = snapshot.documents.count == pageSize ? posts.last.map {
            PostPageCursor(createdAt: $0.createdAt, id: $0.id)
        } : nil
        return PostPage(posts: posts, nextCursor: nextCursor)
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
    // Reads posts/{id}. Signed-in users may read posts under the current rules;
    // a missing document means the post is gone, which is not an error.
    func fetchPost(id: String) async throws -> Post? {
        guard isValidFirestoreDocumentId(id) else { return nil }
        let document = try await db
            .collection("posts")
            .document(id)
            .getDocument()

        guard document.exists else { return nil }
        return try document.data(as: Post.self)
    }
}
