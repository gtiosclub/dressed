import Combine
import Foundation

/// Loads the signed-in user's published posts for their own profile.
@MainActor
final class MyProfileModel: ObservableObject {
    enum PostsState: Equatable {
        case loading
        case loaded([Post])
        case failed(String)

        static func == (lhs: Self, rhs: Self) -> Bool {
            switch (lhs, rhs) {
            case (.loading, .loading): true
            case let (.loaded(a), .loaded(b)): a.map(\.id) == b.map(\.id)
            case let (.failed(a), .failed(b)): a == b
            default: false
            }
        }
    }

    @Published private(set) var posts: PostsState = .loading

    private let ownerId: String
    private let service: any PostFunctions

    init(ownerId: String, service: any PostFunctions) {
        self.ownerId = ownerId
        self.service = service
    }

    var postCount: Int? {
        if case .loaded(let posts) = posts { return posts.count }
        return nil
    }

    func load() async {
        posts = .loading
        do {
            let fetched = try await service.fetchPosts(authorId: ownerId)
            try Task.checkCancellation()
            posts = .loaded(fetched)
        } catch is CancellationError {
            return
        } catch {
            posts = .failed("Your posts couldn't load. Check your connection and try again.")
        }
    }

    func removePost(id: String) {
        if case .loaded(let existing) = posts {
            posts = .loaded(existing.filter { $0.id != id })
        }
    }
}
