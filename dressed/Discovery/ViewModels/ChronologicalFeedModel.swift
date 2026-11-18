//
//  ChronologicalFeedView.swift
//  dressed
//
//  Created by Tiana Prem  on 11/3/26.
//

import Combine
import Foundation

struct FeedPage {
    let posts: [Post]
    let nextCursor: String?
    let removedPostIDs: Set<String>
}

@MainActor
final class ChronologicalFeedModel: ObservableObject {
    enum Operation: Equatable {
           case initial
           case nextPage
           case refresh
       }

    typealias PageLoader = (String?) async throws -> FeedPage
    @Published private(set) var posts: [Post] = []
    @Published private(set) var operation: Operation?
    @Published private(set) var errorMessage: String?
    @Published private(set) var nextCursor: String?
    @Published private(set) var hasLoaded = false

    private let loadPage: PageLoader
        private var failedOperation: Operation?
        private var removedIDs: Set<String> = []

        init(loadPage: @escaping PageLoader) {
            self.loadPage = loadPage
        }

        var isLoading: Bool {
            operation != nil
        }

        var isRefreshing: Bool {
            operation == .refresh
        }

    var hasMore: Bool {
        nextCursor != nil
    }
    func loadInitial() async {
        guard !hasLoaded, !isLoading, errorMessage == nil else { return }
        await request(.initial)
    }

    func loadMore() async {
        guard hasLoaded, hasMore, !isLoading,
              errorMessage == nil else { return }
        await request(.nextPage)
    }

    func refresh() async {
        guard !isLoading else { return }

        await request(hasLoaded ? .refresh : .initial)
    }

    func retry() async {
        guard !isLoading, let failedOperation else { return }
        await request(failedOperation)
    }

    private func request(_ requested: Operation) async {
        let previousError = errorMessage
        let previousFailedOperation = failedOperation
        operation = requested
        errorMessage = nil
        failedOperation = nil

        defer { operation = nil }

        do {
            let cursor = requested == .nextPage ? nextCursor : nil
            let page = try await loadPage(cursor)
            try Task.checkCancellation()

            var updatedRemovedIDs = requested == .nextPage
                ? removedIDs
                : Set<String>()
            updatedRemovedIDs.formUnion(page.removedPostIDs)

            let existingPosts = requested == .nextPage ? posts : []
            var postsByID: [String: Post] = [:]

            for post in existingPosts + page.posts {
                guard !updatedRemovedIDs.contains(post.id) else { continue }
                postsByID[post.id] = post
            }

            posts = postsByID.values.sorted {
                if $0.createdAt == $1.createdAt {
                    return $0.id < $1.id
                }
                return $0.createdAt > $1.createdAt
            }

            removedIDs = updatedRemovedIDs
            nextCursor = page.nextCursor
            hasLoaded = true
        } catch {
            if error is CancellationError || Task.isCancelled {
                errorMessage = previousError
                failedOperation = previousFailedOperation
            } else {
                errorMessage = error.localizedDescription
                failedOperation = requested
            }
        }
    }
}
