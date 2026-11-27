import Combine
import Foundation
import UIKit

/// Catalog products the owner can try on from the avatar picker's Shop section. Products come from the
/// shared catalog service (Firebase `catalogProducts` when signed in) and are worn as `ClothingItem`s with a
/// `catalog-` id prefix, so they never collide with closet pieces or enter the closet. Photos download on
/// demand and stay in memory for this session.
final class AvatarCatalogStore: ObservableObject {
    enum State: Equatable {
        case idle, loading, loaded, failed
    }

    static let idPrefix = "catalog-"
    private static let maxImageBytes = 8_000_000

    @Published private(set) var state: State = .idle
    @Published private(set) var products: [CatalogProduct] = []
    @Published private(set) var images: [String: UIImage] = [:]

    private let ownerId: String
    private let service: any CatalogSearching
    private let session: URLSession
    private var downloading: Set<String> = []

    init(ownerId: String, service: any CatalogSearching = DiscoveryCatalogSource.current, session: URLSession = .shared) {
        self.ownerId = ownerId
        self.service = service
        self.session = session
    }

    /// Loads the catalog once. Products without a photo are left out, since they cannot be tried on.
    func load() async {
        guard state == .idle || state == .failed else { return }
        state = .loading
        do {
            let response = try await service.search(query: "", category: nil)
            let order = ClothingCategory.allCases
            products = response.products
                .filter { $0.displayImageURL?.scheme == "https" }
                .sorted {
                    let left = order.firstIndex(of: $0.category) ?? 0, right = order.firstIndex(of: $1.category) ?? 0
                    return left != right ? left < right : $0.title.localizedStandardCompare($1.title) == .orderedAscending
                }
            state = .loaded
        } catch is CancellationError {
            state = .idle
        } catch {
            state = .failed
        }
    }

    func item(for product: CatalogProduct) -> ClothingItem {
        ClothingItem(id: Self.idPrefix + product.id, ownerId: ownerId, name: product.title,
                     category: product.category, imagePath: "", createdAt: .distantPast)
    }

    /// The downloaded photo for a worn catalog item, by its `ClothingItem` id.
    func image(for itemId: String) -> UIImage? {
        images[itemId]
    }

    func loadImage(for product: CatalogProduct) async {
        let id = Self.idPrefix + product.id
        guard images[id] == nil, !downloading.contains(id), let url = product.displayImageURL,
              url.scheme == "https" else { return }
        downloading.insert(id)
        defer { downloading.remove(id) }
        guard let (data, response) = try? await session.data(from: url),
              let http = response as? HTTPURLResponse, http.statusCode == 200,
              data.count <= Self.maxImageBytes else { return }
        let image = await Task.detached(priority: .utility) { () -> UIImage? in
            guard let original = UIImage(data: data),
                  let png = AvatarMediaStore.downscaledPNG(original, maxSide: 768) else { return nil }
            return UIImage(data: png)
        }.value
        if let image { images[id] = image }
    }
}
