import FirebaseFirestore
import Foundation

struct PostLikeSnapshot: Equatable {
    let postId: String
    let isLiked: Bool
    let likeCount: Int
}

protocol PostLikeFunctions {
    func fetch(postId: String, ownerId: String, knownCount: Int) async throws -> PostLikeSnapshot
    func set(postId: String, ownerId: String, isLiked: Bool) async throws -> PostLikeSnapshot
}

enum PostLikeFunctionsError: LocalizedError {
    case invalidIdentifier
    case postRemoved
    case invalidPost

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier: "This post cannot be liked."
        case .postRemoved: "This post is no longer available."
        case .invalidPost: "The post's like count is invalid."
        }
    }
}

struct FirebasePostLikeFunctions: PostLikeFunctions {
    private let db = Firestore.firestore()

    func fetch(postId: String, ownerId: String, knownCount: Int) async throws -> PostLikeSnapshot {
        try validate(postId: postId, ownerId: ownerId)
        let like = try await likeReference(ownerId: ownerId, postId: postId).getDocument(source: .server)
        return PostLikeSnapshot(postId: postId, isLiked: like.exists, likeCount: max(knownCount, 0))
    }

    func set(postId: String, ownerId: String, isLiked desiredState: Bool) async throws -> PostLikeSnapshot {
        try validate(postId: postId, ownerId: ownerId)
        let post = db.collection("posts").document(postId)
        let like = likeReference(ownerId: ownerId, postId: postId)

        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            do {
                let postSnapshot = try transaction.getDocument(post)
                guard postSnapshot.exists else { throw PostLikeFunctionsError.postRemoved }
                let likeSnapshot = try transaction.getDocument(like)
                let currentState = likeSnapshot.exists
                let rawCount = postSnapshot.data()?["likeCount"] as? Int64
                    ?? (postSnapshot.data()?["likeCount"] as? Int).map(Int64.init)
                    ?? 0
                guard rawCount >= 0, rawCount <= Int64(Int.max) else {
                    throw PostLikeFunctionsError.invalidPost
                }
                let currentCount = Int(rawCount)

                guard currentState != desiredState else {
                    return ["isLiked": currentState, "likeCount": currentCount]
                }

                let nextCount = desiredState ? currentCount + 1 : max(0, currentCount - 1)
                if desiredState {
                    transaction.setData([
                        "id": postId,
                        "schemaVersion": 1,
                        "ownerId": ownerId,
                        "postId": postId,
                        "createdAt": FieldValue.serverTimestamp(),
                    ], forDocument: like)
                } else {
                    transaction.deleteDocument(like)
                }
                transaction.updateData(["likeCount": nextCount], forDocument: post)
                return ["isLiked": desiredState, "likeCount": nextCount]
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }

        guard let fields = result as? [String: Any],
              let isLiked = fields["isLiked"] as? Bool,
              let likeCount = fields["likeCount"] as? Int else {
            throw PostLikeFunctionsError.invalidPost
        }
        return PostLikeSnapshot(postId: postId, isLiked: isLiked, likeCount: likeCount)
    }

    private func likeReference(ownerId: String, postId: String) -> DocumentReference {
        db.collection("users").document(ownerId).collection("postLikes").document(postId)
    }

    private func validate(postId: String, ownerId: String) throws {
        guard isValidFirestoreDocumentId(postId), isValidFirestoreDocumentId(ownerId) else {
            throw PostLikeFunctionsError.invalidIdentifier
        }
    }
}
