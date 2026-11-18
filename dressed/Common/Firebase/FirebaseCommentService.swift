import FirebaseAuth
import FirebaseFirestore
import Foundation

/// Server reads prevent cached comments from appearing to confirm persistence.
@MainActor
struct FirebaseCommentService: CommentService {
    var currentUserId: String? { Auth.auth().currentUser?.uid }
    let isDemo = false
    private var firestore: Firestore { Firestore.firestore() }

    func fetch(postId: String) async throws -> [PostComment] {
        guard currentUserId != nil else { throw CommentError.signedOut }
        let post = firestore.collection("posts").document(postId)
        guard try await post.getDocument(source: .server).exists else { throw CommentError.postRemoved }
        let snapshot = try await post.collection("comments")
            .order(by: "createdAt", descending: true)
            .order(by: FieldPath.documentID(), descending: true)
            .limit(to: 50)
            .getDocuments(source: .server)
        return try snapshot.documents.map { try $0.data(as: PostComment.self) }
    }

    func submit(postId: String, id: String, text: String) async throws {
        guard let authorId = currentUserId else { throw CommentError.signedOut }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.count <= 1_000 else {
            throw CommentError.invalidText
        }
        let post = firestore.collection("posts").document(postId)
        let comment = post.collection("comments").document(id)
        // Retrying an acknowledged-but-interrupted request reads the same document
        // instead of creating a duplicate or changing its original timestamp.
        _ = try await firestore.runTransaction { transaction, errorPointer in
            do {
                let parent = try transaction.getDocument(post)
                let existing = try transaction.getDocument(comment)
                guard parent.exists else { throw CommentError.postRemoved }
                if existing.exists {
                    guard existing["authorId"] as? String == authorId,
                          existing["text"] as? String == text else { throw CommentError.conflictingRetry }
                } else {
                    transaction.setData([
                        "id": id, "authorId": authorId, "text": text,
                        "createdAt": FieldValue.serverTimestamp()
                    ], forDocument: comment)
                }
            } catch {
                errorPointer?.pointee = error as NSError
            }
            return nil
        }
    }
}

/// Explicitly isolated from Firebase, including when preview posts are composed.
@MainActor
final class DemoCommentService: CommentService {
    let currentUserId: String? = "preview_user"
    let isDemo = true
    private var records: [String: [PostComment]] = [:]

    func fetch(postId: String) async throws -> [PostComment] {
        try Task.checkCancellation()
        return records[postId, default: []]
    }

    func submit(postId: String, id: String, text: String) async throws {
        try Task.checkCancellation()
        guard records[postId, default: []].allSatisfy({ $0.id != id }) else { return }
        records[postId, default: []].insert(
            PostComment(id: id, authorId: "preview_user", text: text, createdAt: .now), at: 0
        )
    }
}
