import Combine
import UIKit
import FirebaseStorage

@MainActor
protocol PublishedPostImageLoading {
    func image(for post: Post) async throws -> UIImage?
}

@MainActor
struct FirebasePublishedPostImageLoader: PublishedPostImageLoading {
    private static let cache = NSCache<NSString, UIImage>()
    private static let sampleAssets = [
        "demo_front_jacket_trousers": "DemoFrontJacketTrousers",
        "demo_front_overshirt_chinos": "DemoFrontOvershirtChinos",
        "demo_front_tee_jeans": "DemoFrontTeeJeans"
    ]

    func image(for post: Post) async throws -> UIImage? {
        if post.authorId == "dressed_demo", let asset = Self.sampleAssets[post.id] {
            return UIImage(named: asset)
        }
        // Never resolve an arbitrary record's private closet path or external URL.
        guard !post.authorId.contains("/"), !post.id.contains("/"),
              post.mediaPath == "posts/\(post.authorId)/\(post.id)/composite.jpg" else { return nil }
        return try await image(path: post.mediaPath)
    }

    func image(for item: PublishedClothingSnapshot, in post: Post) async throws -> UIImage? {
        guard !post.authorId.contains("/"), !post.id.contains("/"), !item.sourceItemId.contains("/"),
              item.mediaPath == "posts/\(post.authorId)/\(post.id)/items/\(item.sourceItemId).jpg" else { return nil }
        return try await image(path: item.mediaPath)
    }

    static func cache(draft: PostPublicationDraft, post: Post) {
        cache.totalCostLimit = 32 * 1024 * 1024
        for (path, data) in [(post.mediaPath, draft.photo)] + zip(post.outfitSnapshot.items, draft.items).map({
            ($0.0.mediaPath, $0.1.photo)
        }) {
            if let image = UIImage(data: data) { cache.setObject(image, forKey: path as NSString, cost: data.count) }
        }
    }

    private func image(path: String) async throws -> UIImage? {
        if let image = Self.cache.object(forKey: path as NSString) { return image }
        try Task.checkCancellation()
        let data = try await Storage.storage().reference(withPath: path).data(maxSize: 10 * 1024 * 1024)
        try Task.checkCancellation()
        guard let image = UIImage(data: data) else { return nil }
        Self.cache.totalCostLimit = 32 * 1024 * 1024
        Self.cache.setObject(image, forKey: path as NSString, cost: data.count)
        return image
    }
}

@MainActor
final class PublishedPostImageModel: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false
    @Published private(set) var pieceImages: [String: UIImage] = [:]
    private var requestID = UUID()
    private let loader: any PublishedPostImageLoading

    init(loader: (any PublishedPostImageLoading)? = nil) {
        self.loader = loader ?? FirebasePublishedPostImageLoader()
    }

    func loadItems(_ post: Post) async {
        pieceImages = [:]
        let itemLoader = FirebasePublishedPostImageLoader()
        for item in post.outfitSnapshot.items {
            guard !Task.isCancelled else { return }
            if let image = try? await itemLoader.image(for: item, in: post) {
                pieceImages[item.mediaPath] = image
            }
        }
    }

    func load(_ post: Post) async {
        let currentRequest = UUID()
        requestID = currentRequest
        image = nil
        isLoading = true
        defer { if requestID == currentRequest { isLoading = false } }
        do {
            let loaded = try await loader.image(for: post)
            try Task.checkCancellation()
            guard requestID == currentRequest else { return }
            image = loaded
        } catch { if requestID == currentRequest { image = nil } }
    }
}
