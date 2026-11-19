import Foundation
import FirebaseFirestore

protocol PostPublishing {
    func publish(caption: String, authorId: String) async throws -> Post
}

struct FirebasePostPublisher: PostPublishing {
    private let db = Firestore.firestore()

    func publish(caption: String, authorId: String) async throws -> Post {
        guard isValidFirestoreDocumentId(authorId) else {
            throw PostPublishingError.invalidAuthor
        }

        let postId = UUID().uuidString.lowercased()
        let post = Post(
            id: postId,
            schemaVersion: 1,
            authorId: authorId,
            caption: caption,
            outfitSnapshot: PublishedOutfitSnapshot(name: nil, items: []),
            mediaPath: "",
            createdAt: .now,
            likeCount: 0
        )
        let data = try Firestore.Encoder().encode(post)
        try await db.collection("posts").document(postId).setData(data)
        return post
    }
}

enum PostPublishingError: LocalizedError {
    case invalidAuthor

    var errorDescription: String? {
        "Your account could not be used to publish this post. Please sign in again."
    }
}
