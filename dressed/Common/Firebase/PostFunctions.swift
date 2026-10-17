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
}
