import Combine
import Foundation

enum DiscoveryPostSource {
    static var isDemo: Bool {
        #if DEBUG
        return !ProcessInfo.processInfo.arguments.contains("-livePosts")
        #else
        return false
        #endif
    }

    static var current: any PostFunctions {
        if isDemo { return DemoPostFunctions() }
        return FirebasePostFunctions()
    }
}

@MainActor
final class DiscoveryFeedViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded([Post])
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    private let service: any PostFunctions
    private var task: Task<Void, Never>?

    init(service: any PostFunctions) {
        self.service = service
    }

    func load() {
        task?.cancel()
        state = .loading
        task = Task {
            do {
                let posts = try await service.fetchRecentPosts()
                guard !Task.isCancelled else { return }
                state = .loaded(posts)
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

/// Synthetic published snapshots for the signed-in simulator walkthrough.
struct DemoPostFunctions: PostFunctions {
    private struct Example {
        let author: String
        let caption: String
        let name: String
        let pieces: [(String, ClothingCategory)]

        init(_ author: String, _ caption: String, _ name: String, _ pieces: [(String, ClothingCategory)]) {
            self.author = author
            self.caption = caption
            self.name = name
            self.pieces = pieces
        }
    }

    func fetchRecentPosts() async throws -> [Post] {
        try Task.checkCancellation()
        let examples: [Example] = [
            Example("user38483", "caption (optional)", "Fit check", [
                ("Vintage leather jacket", .outerwear),
                ("Pleated wool trousers", .pants),
                ("Leather belt", .accessories),
                ("Chunky loafers", .shoes)
            ]),
            Example("alex", "Keeping it simple today", "Everyday", [("White shirt", .tops), ("Sneakers", .shoes)]),
            Example("jordan", "A little color for Friday", "Friday", [
                ("Blue dress", .dresses), ("Silver necklace", .accessories)
            ]),
            Example("sam", "Coffee run fit", "Coffee run", [("Denim jacket", .outerwear), ("Black pants", .pants)]),
            Example("lee", "Sunny afternoon", "Sunny day", [("Pleated skirt", .skirts), ("Canvas shoes", .shoes)]),
            Example("riley", "My favorite layers", "Layers", [("Striped top", .tops), ("Light jacket", .outerwear)]),
            Example("casey", "Dinner with friends", "Dinner", [
                ("Black dress", .dresses), ("Pendant necklace", .accessories)
            ]),
            Example("taylor", "Back to basics", "Basics", [("Gray tee", .tops), ("Straight-leg pants", .pants)])
        ]

        return examples.enumerated().map { index, example in
            let postId = "demo_post_\(index + 1)"
            let items = example.pieces.enumerated().map { itemIndex, piece in
                PublishedClothingSnapshot(
                    sourceItemId: "demo_item_\(index + 1)_\(itemIndex + 1)",
                    name: piece.0,
                    category: piece.1,
                    mediaPath: "posts/\(example.author)/\(postId)/item_\(itemIndex + 1).png",
                    productURL: nil
                )
            }
            return Post(
                id: postId,
                schemaVersion: 1,
                authorId: example.author,
                caption: example.caption,
                outfitSnapshot: PublishedOutfitSnapshot(name: example.name, items: items),
                mediaPath: "posts/\(example.author)/\(postId)/composite.jpg",
                createdAt: Date(timeIntervalSince1970: 1_792_000_000 - Double(index * 3_600))
            )
        }
    }
}
