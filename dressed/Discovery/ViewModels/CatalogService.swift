import Combine
import Foundation

protocol CatalogSearching {
    func search(query: String, category: ClothingCategory?) async throws -> CatalogSearchResponse
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
