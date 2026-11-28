import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/// Frozen on the first Share attempt. Retrying always uses the same ID and bytes.
struct PostPublicationDraft {
    var id = UUID().uuidString.lowercased()
    var caption: String
    var photo: Data
    var outfitName: String?
    var items: [PostPublicationItem]
    var createdAt = Date()

    func post(authorId: String) -> Post {
        let root = "posts/\(authorId)/\(id)"
        return Post(
            id: id, schemaVersion: 1, authorId: authorId, caption: caption,
            outfitSnapshot: PublishedOutfitSnapshot(name: outfitName, items: items.map {
                PublishedClothingSnapshot(sourceItemId: $0.id, name: $0.name, category: $0.category,
                                          mediaPath: "\(root)/items/\($0.id).jpg", productURL: nil)
            }),
            mediaPath: "\(root)/composite.jpg", createdAt: createdAt, likeCount: 0
        )
    }
}

struct PostPublicationItem {
    let id: String
    let name: String
    let category: ClothingCategory
    let photo: Data
}

@MainActor
protocol PostPublishing {
    func publish(draft: PostPublicationDraft, authorId: String) async throws -> Post
}

@MainActor
protocol PostMediaStoring {
    func upload(_ data: Data, path: String) async throws
    func remove(path: String) async throws
}

@MainActor
protocol PostDocumentStoring {
    func fetch(id: String) async throws -> Post?
    func create(_ post: Post) async throws
}

/// Upload all independent public copies before committing the immutable post snapshot.
@MainActor
struct FirebasePostPublisher: PostPublishing {
    private let media: any PostMediaStoring
    private let documents: any PostDocumentStoring
    private let currentUserId: () -> String?

    init(media: (any PostMediaStoring)? = nil,
         documents: (any PostDocumentStoring)? = nil,
         currentUserId: @escaping () -> String? = { Auth.auth().currentUser?.uid }) {
        self.media = media ?? FirebasePostMediaStore()
        self.documents = documents ?? FirebasePostDocumentStore()
        self.currentUserId = currentUserId
    }

    func publish(draft: PostPublicationDraft, authorId: String) async throws -> Post {
        guard currentUserId() == authorId, isValidFirestoreDocumentId(authorId) else {
            throw PostPublishingError.invalidAuthor
        }
        guard UUID(uuidString: draft.id) != nil,
              draft.caption.count <= 500, (draft.outfitName?.count ?? 0) <= 80,
              (1...10).contains(draft.items.count),
              Set(draft.items.map(\.id)).count == draft.items.count,
              draft.items.allSatisfy({ item in
                  item.id.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil
                      && !item.name.isEmpty && item.name.count <= 80
              }) else { throw PostPublishingError.invalidDraft }
        let post = draft.post(authorId: authorId)
        // A server read resolves an interrupted acknowledgement before any media is overwritten.
        if let existing = try await documents.fetch(id: draft.id) {
            guard Self.matches(existing, post) else { throw PostPublishingError.conflictingRetry }
            return existing
        }
        let uploads = [(post.mediaPath, draft.photo)] + zip(post.outfitSnapshot.items, draft.items).map {
            ($0.0.mediaPath, $0.1.photo)
        }
        guard uploads.allSatisfy({ !$0.1.isEmpty && $0.1.count <= 10 * 1024 * 1024 }) else {
            throw PostPublishingError.invalidDraft
        }
        var attemptedPaths: [String] = []
        var attemptedCommit = false
        do {
            for (path, data) in uploads {
                try Task.checkCancellation()
                attemptedPaths.append(path)
                try await media.upload(data, path: path)
            }
            try Task.checkCancellation()
            attemptedCommit = true
            try await documents.create(post)
            // Do not turn an acknowledged publication into a cancellation/failure.
            return post
        } catch {
            let originalError = error
            if attemptedCommit {
                // If the network lost the acknowledgement, never delete a potentially published image.
                do {
                    if let existing = try await documents.fetch(id: post.id) {
                        guard Self.matches(existing, post) else { throw PostPublishingError.conflictingRetry }
                        return existing
                    }
                } catch {
                    throw PostPublishingError.uncertainCommit
                }
            }
            // Cleanup runs independently of the cancelled caller. Keep all failures visible.
            let cleanupFailed = await Task { @MainActor in
                var failed = false
                for path in attemptedPaths {
                    do { try await media.remove(path: path) } catch { failed = true }
                }
                return failed
            }.value
            if cleanupFailed { throw PostPublishingError.cleanupFailed }
            throw originalError
        }
    }

    static func matches(_ lhs: Post, _ rhs: Post) -> Bool {
        // Compare content, excluding the mutable aggregate like count.
        lhs.id == rhs.id && lhs.authorId == rhs.authorId && lhs.caption == rhs.caption
            && lhs.mediaPath == rhs.mediaPath && lhs.outfitSnapshot.name == rhs.outfitSnapshot.name
            && lhs.outfitSnapshot.items.count == rhs.outfitSnapshot.items.count
            && zip(lhs.outfitSnapshot.items, rhs.outfitSnapshot.items).allSatisfy {
                $0.sourceItemId == $1.sourceItemId && $0.name == $1.name
                    && $0.category == $1.category && $0.mediaPath == $1.mediaPath && $0.productURL == $1.productURL
            }
    }
}

@MainActor
struct FirebasePostMediaStore: PostMediaStoring {
    func upload(_ data: Data, path: String) async throws {
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await Storage.storage().reference(withPath: path).putDataAsync(data, metadata: metadata)
    }

    func remove(path: String) async throws {
        do {
            try await Storage.storage().reference(withPath: path).delete()
        } catch {
            guard (error as NSError).code == StorageErrorCode.objectNotFound.rawValue else { throw error }
        }
    }
}

@MainActor
struct FirebasePostDocumentStore: PostDocumentStoring {
    func fetch(id: String) async throws -> Post? {
        let document = try await Firestore.firestore().collection("posts").document(id).getDocument(source: .server)
        return document.exists ? try document.data(as: Post.self) : nil
    }

    func create(_ post: Post) async throws {
        let document = Firestore.firestore().collection("posts").document(post.id)
        let data = try Firestore.Encoder().encode(post)
        _ = try await Firestore.firestore().runTransaction { transaction, errorPointer in
            do {
                let existing = try transaction.getDocument(document)
                if existing.exists {
                    guard Self.matches(existing, data) else { throw PostPublishingError.conflictingRetry }
                } else {
                    transaction.setData(data, forDocument: document)
                }
            } catch { errorPointer?.pointee = error as NSError }
            return nil
        }
    }

    nonisolated private static func matches(_ snapshot: DocumentSnapshot, _ expected: [String: Any]) -> Bool {
        // The transaction may run outside the main actor. Encoded immutable fields must match.
        guard let actual = snapshot.data() else { return false }
        let keys = ["id", "schemaVersion", "authorId", "caption", "outfitSnapshot", "mediaPath"]
        return NSDictionary(dictionary: actual.filter { keys.contains($0.key) })
            .isEqual(to: expected.filter { keys.contains($0.key) })
    }
}

enum PostPublishingError: LocalizedError {
    case invalidAuthor, invalidDraft, conflictingRetry, uncertainCommit, cleanupFailed

    var errorDescription: String? {
        switch self {
        case .invalidAuthor: "Please sign in again before sharing."
        case .invalidDraft: "Choose a photo, tag 1–10 items, and keep the caption within 500 characters."
        case .conflictingRetry: "This post ID already exists with different content. Close this draft and start again."
        case .uncertainCommit: "The connection was interrupted. Retry Share to check whether your post was saved."
        case .cleanupFailed: "Sharing failed and some uploads could not be removed. Retry Share with this draft."
        }
    }
}
