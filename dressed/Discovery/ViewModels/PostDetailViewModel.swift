//
//  PostDetailViewModel.swift
//  dressed
//
//  Created by vasanth aggala on 11/3/26.
//

import Combine
import Foundation
import UIKit

/// Everything the post-detail screen shows. It holds no storage paths and no
/// closet item IDs, so the view cannot reach anyone's private closet.
struct PostDetailContent {
    var postId: String
    var authorId: String
    var authorDisplayName: String
    var authorAvatar: UIImage?
    var createdAt: Date
    var caption: String
    var outfitName: String?
    var postImage: UIImage?
    var pieces: [PostDetailPiece]
}

/// One published piece. `index` is its position in the published snapshot and is
/// what a tap reports; the private `sourceItemId` is never passed to the view.
struct PostDetailPiece: Identifiable {
    var index: Int
    var name: String
    var category: ClothingCategory
    var image: UIImage?
    var productURL: URL?

    var id: Int { index }
}

extension PostDetailContent {
    /// Builds display content from a published post. Public media (#59, #87) and
    /// author profiles (#49) are not readable yet, so the parent passes whatever it
    /// has: missing images show placeholders and the author falls back to the ID.
    init(
        post: Post,
        authorDisplayName: String? = nil,
        authorAvatar: UIImage? = nil,
        postImage: UIImage? = nil,
        pieceImages: [Int: UIImage] = [:]
    ) {
        self.init(
            postId: post.id,
            authorId: post.authorId,
            authorDisplayName: authorDisplayName ?? "@\(post.authorId)",
            authorAvatar: authorAvatar,
            createdAt: post.createdAt,
            caption: post.caption,
            outfitName: post.outfitSnapshot.name,
            postImage: postImage,
            pieces: post.outfitSnapshot.items.enumerated().map { index, item in
                PostDetailPiece(
                    index: index,
                    name: item.name,
                    category: item.category,
                    image: pieceImages[index],
                    productURL: Self.publicProductURL(item.productURL)
                )
            }
        )
    }

    /// Only real HTTPS links reach the screen; placeholder `.example` hosts are dropped.
    static func publicProductURL(_ url: URL?) -> URL? {
        guard let url,
              url.scheme == "https",
              let host = url.host,
              !host.hasSuffix(".example") else { return nil }
        return url
    }
}

/// Supplies post-detail content, either from a post the feed already loaded or by
/// reading `posts/{postId}`.
@MainActor
final class PostDetailViewModel: ObservableObject {
    enum State {
        case loading
        case loaded(PostDetailContent)
        case removed
        case failed(String)
    }

    @Published private(set) var state: State
    private let postId: String
    private let service: any PostFunctions
    private var task: Task<Void, Never>?
    private var needsRefresh = false

    /// Opened from the feed. Shows the feed's copy right away, then re-checks
    /// Firestore so a post deleted since the feed loaded shows as removed.
    init(post: Post, service: any PostFunctions = DiscoveryPostSource.current) {
        postId = post.id
        self.service = service
        state = .loaded(PostDetailContent(post: post))
        needsRefresh = true
    }

    /// Opened by ID (for example, from Saved Posts). Reads the post on `load()`.
    init(postId: String, service: any PostFunctions = DiscoveryPostSource.current) {
        self.postId = postId
        self.service = service
        state = .loading
    }

    func loadIfNeeded() {
        if case .loading = state {
            load()
        } else if needsRefresh {
            needsRefresh = false
            refresh()
        }
    }

    /// Quietly re-reads the post without showing a spinner. If the read fails
    /// (for example, offline), the feed's copy stays on screen.
    private func refresh() {
        task?.cancel()
        task = Task {
            do {
                let post = try await service.fetchPost(id: postId)
                guard !Task.isCancelled else { return }
                if let post {
                    state = .loaded(PostDetailContent(post: post))
                } else {
                    state = .removed
                }
            } catch {
                return
            }
        }
    }
    func load() {
        task?.cancel()
        state = .loading
        task = Task {
            do {
                let post = try await service.fetchPost(id: postId)
                guard !Task.isCancelled else { return }
                if let post {
                    state = .loaded(PostDetailContent(post: post))
                } else {
                    state = .removed
                }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}

