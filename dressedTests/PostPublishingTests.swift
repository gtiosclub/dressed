import XCTest
import UIKit
@testable import dressed

@MainActor
final class PostPublishingTests: XCTestCase {
    private enum Failure: Error { case network }

    private final class Media: PostMediaStoring {
        var uploaded: [String] = []
        var removed: [String] = []
        var failUpload = false
        var failCleanup = false
        func upload(_ data: Data, path: String) async throws {
            uploaded.append(path)
            if failUpload, uploaded.count == 2 { throw Failure.network }
        }
        func remove(path: String) async throws {
            removed.append(path)
            if failCleanup { throw Failure.network }
        }
    }

    private final class Documents: PostDocumentStoring {
        var post: Post?
        var commits = 0
        var failCommit = false
        var commitThenFail = false
        var failResolution = false
        func fetch(id: String) async throws -> Post? {
            if failResolution, commits > 0 { throw Failure.network }
            return post
        }
        func create(_ post: Post) async throws {
            commits += 1
            if commitThenFail { self.post = post; throw Failure.network }
            if failCommit { throw Failure.network }
            self.post = post
        }
    }

    private func draft() -> PostPublicationDraft {
        PostPublicationDraft(caption: "Layers", photo: Data([1]), outfitName: "Monday", items: [
            PostPublicationItem(id: "piece_1", name: "Blue shirt", category: .tops, photo: Data([2]))
        ])
    }

    func testPublicationCopiesMediaAndRetryDoesNotDuplicateOrOverwrite() async throws {
        let media = Media(), documents = Documents()
        let publisher = FirebasePostPublisher(media: media, documents: documents, currentUserId: { "owner" })
        let draft = draft()
        let post = try await publisher.publish(draft: draft, authorId: "owner")
        XCTAssertEqual(post.mediaPath, "posts/owner/\(draft.id)/composite.jpg")
        XCTAssertEqual(post.outfitSnapshot.name, "Monday")
        XCTAssertEqual(post.outfitSnapshot.items.first?.name, "Blue shirt")
        XCTAssertEqual(post.outfitSnapshot.items.first?.category, .tops)
        XCTAssertEqual(media.uploaded.count, 2)
        XCTAssertFalse(media.uploaded.contains { $0.hasPrefix("users/") })
        let retry = try await publisher.publish(draft: draft, authorId: "owner")
        XCTAssertEqual(retry.id, post.id)
        XCTAssertEqual(documents.commits, 1)
        XCTAssertEqual(media.uploaded.count, 2)
        XCTAssertTrue(media.removed.isEmpty)
    }

    func testUploadFailureCleansAllAttemptedPathsAndDoesNotCreatePost() async {
        let media = Media(), documents = Documents()
        media.failUpload = true
        let publisher = FirebasePostPublisher(media: media, documents: documents, currentUserId: { "owner" })
        do { _ = try await publisher.publish(draft: draft(), authorId: "owner"); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(media.removed, media.uploaded)
        XCTAssertEqual(documents.commits, 0)
    }

    func testRejectedPostCleansMedia() async {
        let media = Media(), documents = Documents()
        documents.failCommit = true
        let publisher = FirebasePostPublisher(media: media, documents: documents, currentUserId: { "owner" })
        do { _ = try await publisher.publish(draft: draft(), authorId: "owner"); XCTFail("Expected failure") } catch {}
        XCTAssertEqual(media.removed.count, 2)
        XCTAssertNil(documents.post)
    }

    func testLostAcknowledgementReturnsPublishedPostWithoutDeletingMedia() async throws {
        let media = Media(), documents = Documents()
        documents.commitThenFail = true
        let publisher = FirebasePostPublisher(media: media, documents: documents, currentUserId: { "owner" })
        let post = try await publisher.publish(draft: draft(), authorId: "owner")
        XCTAssertEqual(post.id, documents.post?.id)
        XCTAssertTrue(media.removed.isEmpty)
    }

    func testUncertainCommitPreservesMediaForSameIdRetry() async throws {
        let media = Media(), documents = Documents()
        documents.commitThenFail = true
        documents.failResolution = true
        let publisher = FirebasePostPublisher(media: media, documents: documents, currentUserId: { "owner" })
        let draft = draft()
        do { _ = try await publisher.publish(draft: draft, authorId: "owner"); XCTFail("Expected uncertainty") } catch {}
        XCTAssertTrue(media.removed.isEmpty)
        documents.failResolution = false
        let post = try await publisher.publish(draft: draft, authorId: "owner")
        XCTAssertEqual(post.id, draft.id)
        XCTAssertEqual(documents.commits, 1)
    }

    func testImpersonationAndEmptyItemsAreRejectedBeforeIO() async {
        let media = Media(), documents = Documents()
        let publisher = FirebasePostPublisher(media: media, documents: documents, currentUserId: { "owner" })
        do { _ = try await publisher.publish(draft: draft(), authorId: "someone_else"); XCTFail("Expected rejection") } catch {}
        var empty = draft()
        empty.items = []
        do { _ = try await publisher.publish(draft: empty, authorId: "owner"); XCTFail("Expected rejection") } catch {}
        XCTAssertTrue(media.uploaded.isEmpty)
        XCTAssertEqual(documents.commits, 0)
    }

    func testCancelledPublicationDoesNotCommit() async {
        let media = Media(), documents = Documents()
        let publisher = FirebasePostPublisher(media: media, documents: documents, currentUserId: { "owner" })
        let draft = draft()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try await publisher.publish(draft: draft, authorId: "owner"); XCTFail("Expected cancellation") } catch {}
        }
        await task.value
        XCTAssertEqual(documents.commits, 0)
        XCTAssertTrue(media.uploaded.isEmpty)
    }

    func testPhotoEncodingBoundsDimensionsAndPreservesDecodablePixels() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3_200, height: 2_400)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 3_200, height: 2_400))
        }
        let encoded = try PostPhotoEncoding.jpeg(image)
        let decoded = try XCTUnwrap(UIImage(data: encoded))
        XCTAssertEqual(decoded.size.width, 1_600)
        XCTAssertEqual(decoded.size.height, 1_200)
        XCTAssertLessThan(encoded.count, 10 * 1024 * 1024)
    }
}
