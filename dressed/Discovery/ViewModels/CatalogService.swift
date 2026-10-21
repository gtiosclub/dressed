import Combine
import Foundation

protocol CatalogSearching {
    func search(query: String, category: ClothingCategory?) async throws -> CatalogSearchResponse
}

enum DiscoveryCatalogSource {
    static var current: any CatalogSearching {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if !arguments.contains("-liveCatalog") && !arguments.contains("-showCatalog") &&
            !arguments.contains("-catalogAPIURL") {
            return DemoCatalogService()
        }
        #endif
        return HTTPCatalogService(baseURL: CatalogConfiguration.baseURL)
    }

    static let demoStyles: [String: Set<String>] = [
        "idea_top_1": ["Y2K", "Comfortable"],
        "idea_pants_1": ["Minimal", "Trendy"],
        "idea_skirt_1": ["Colorful", "Trendy"],
        "idea_shoes_1": ["Streetwear", "Y2K"],
        "idea_accessory_1": ["Vintage", "Colorful"],
        "idea_outerwear_1": ["Comfortable", "Minimal"],
        "idea_top_2": ["Trendy", "Monotone"],
        "idea_pants_2": ["Minimal", "Monotone"]
    ]
}

/// Synthetic public item cards for the Debug prototype; they are not purchasable products.
struct DemoCatalogService: CatalogSearching {
    func search(query: String, category: ClothingCategory?) async throws -> CatalogSearchResponse {
        try Task.checkCancellation()
        let samples: [(String, String, ClothingCategory)] = [
            ("idea_top_1", "Everyday tee", .tops),
            ("idea_pants_1", "Straight-leg pants", .pants),
            ("idea_skirt_1", "Pleated skirt", .skirts),
            ("idea_shoes_1", "Low-top sneakers", .shoes),
            ("idea_accessory_1", "Pendant necklace", .accessories),
            ("idea_outerwear_1", "Light jacket", .outerwear),
            ("idea_top_2", "Relaxed shirt", .tops),
            ("idea_pants_2", "Dark trousers", .pants)
        ]
        let products = samples.compactMap { id, title, itemCategory -> CatalogProduct? in
            guard category == nil || category == itemCategory else { return nil }
            guard query.isEmpty || title.localizedCaseInsensitiveContains(query) ||
                    itemCategory.rawValue.localizedCaseInsensitiveContains(query) else { return nil }
            guard let productURL = URL(string: "https://dressed.example/\(id)") else { return nil }
            return CatalogProduct(
                id: id, sourceId: "prototype", sourceName: "Prototype", externalId: id,
                title: title, productURL: productURL,
                category: itemCategory, brand: nil, imageURL: nil, priceCents: nil,
                currency: nil, availability: "unknown", status: "demo", lastCheckedAt: ""
            )
        }
        return CatalogSearchResponse(products: products, total: products.count, nextOffset: nil)
    }
}

enum CatalogConfiguration {
    static var baseURL: URL? {
        #if DEBUG
        if let override = UserDefaults.standard.string(forKey: "catalogAPIURL"),
           let url = URL(string: override) {
            return url
        }
        #endif
        guard let value = Bundle.main.object(forInfoDictionaryKey: "CatalogAPIBaseURL") as? String,
              !value.isEmpty else { return nil }
        return URL(string: value)
    }
}

enum CatalogServiceError: LocalizedError {
    case notConfigured
    case invalidEndpoint
    case invalidResponse
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .notConfigured: "The catalog service is not configured yet."
        case .invalidEndpoint: "The catalog service address is invalid."
        case .invalidResponse: "The catalog returned an invalid response."
        case .server(let code): "The catalog is unavailable (HTTP \(code))."
        }
    }
}

struct HTTPCatalogService: CatalogSearching {
    let baseURL: URL?
    var session: URLSession = .shared

    func search(query: String, category: ClothingCategory?) async throws -> CatalogSearchResponse {
        guard let baseURL else { throw CatalogServiceError.notConfigured }
        guard baseURL.scheme == "https" ||
                (baseURL.scheme == "http" && baseURL.host == "127.0.0.1") else {
            throw CatalogServiceError.invalidEndpoint
        }
        let endpoint = baseURL.appending(path: "products")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw CatalogServiceError.invalidEndpoint
        }
        var items = [URLQueryItem(name: "limit", value: "100")]
        if !query.isEmpty { items.append(URLQueryItem(name: "q", value: query)) }
        if let category { items.append(URLQueryItem(name: "category", value: category.rawValue)) }
        components.queryItems = items
        guard let url = components.url else { throw CatalogServiceError.invalidEndpoint }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw CatalogServiceError.invalidResponse
        }
        guard (200..<300).contains(response.statusCode) else {
            throw CatalogServiceError.server(response.statusCode)
        }
        do {
            return try JSONDecoder().decode(CatalogSearchResponse.self, from: data)
        } catch {
            throw CatalogServiceError.invalidResponse
        }
    }
}

@MainActor
final class CatalogViewModel: ObservableObject {
    enum State {
        case idle
        case loading
        case loaded([CatalogProduct])
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    private let service: any CatalogSearching
    private var task: Task<Void, Never>?

    init(service: any CatalogSearching) {
        self.service = service
    }

    func search(query: String, category: ClothingCategory?) {
        task?.cancel()
        state = .loading
        task = Task {
            do {
                let result = try await service.search(query: query, category: category)
                guard !Task.isCancelled else { return }
                state = .loaded(result.products)
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
    }
}
