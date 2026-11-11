import Combine
import Foundation
import UIKit

protocol ProductSearching {
    func search(image: Data, requestID: String) async throws -> ProductSearchResponse
}

enum ProductSearchError: LocalizedError {
    case invalidImage, unavailable, invalidResponse, requestLimit

    var errorDescription: String? {
        switch self {
        case .invalidImage: "This crop could not be prepared. Adjust its image region and try again."
        case .unavailable: "Product search is unavailable. Start the local product-search service on this Mac, then retry."
        case .invalidResponse: "The search response could not be read. Please retry."
        case .requestLimit: "The development search limit was reached. Check backend usage before retrying."
        }
    }
}

/// Development bridge only. A hosted, authenticated service is a separate integration.
struct LocalProductSearchService: ProductSearching {
    func search(image: Data, requestID: String) async throws -> ProductSearchResponse {
        #if DEBUG && targetEnvironment(simulator)
        let override = UserDefaults.standard.integer(forKey: "productSearchPort")
        let port = (1024...65535).contains(override) ? override : 8767
        let endpoint = URL(string: "http://127.0.0.1:\(port)/product-search")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.httpBody = image
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue(requestID, forHTTPHeaderField: "X-Request-ID")
        request.timeoutInterval = 65
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ProductSearchError.invalidResponse }
        if http.statusCode == 429 { throw ProductSearchError.requestLimit }
        guard http.statusCode == 200 else { throw ProductSearchError.unavailable }
        let result: ProductSearchResponse
        do {
            result = try JSONDecoder().decode(ProductSearchResponse.self, from: data)
        } catch {
            throw ProductSearchError.invalidResponse
        }
        guard result.requestId == requestID,
              Set(result.matches.map(\.id)).count == result.matches.count,
              result.matches.allSatisfy({ ProductLinkValidation.normalize($0.productURL.absoluteString) != nil }) else {
            throw ProductSearchError.invalidResponse
        }
        return result
        #else
        throw ProductSearchError.unavailable
        #endif
    }
}

@MainActor
final class ProductSearchViewModel: ObservableObject {
    enum State {
        case idle, loading
        case loaded(ProductSearchResponse)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    private let service: any ProductSearching
    private let requestID = UUID().uuidString

    init(service: (any ProductSearching)? = nil) {
        self.service = service ?? LocalProductSearchService()
    }

    func search(image: Data) async {
        state = .loading
        do {
            let prepared = try Self.prepare(image)
            let result = try await service.search(image: prepared, requestID: requestID)
            try Task.checkCancellation()
            state = .loaded(result)
        } catch {
            guard !Task.isCancelled else { return }
            state = .failed(error is URLError ? ProductSearchError.unavailable.localizedDescription : error.localizedDescription)
        }
    }

    /// Redrawing removes metadata, fixes orientation and composites transparent crops on white.
    private static func prepare(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data), image.size.width > 0, image.size.height > 0 else {
            throw ProductSearchError.invalidImage
        }
        let scale = min(1, 1024 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        for quality in [0.8, 0.6, 0.4, 0.2] {
            if let jpeg = rendered.jpegData(compressionQuality: CGFloat(quality)), jpeg.count <= 450_000 {
                return jpeg
            }
        }
        throw ProductSearchError.invalidImage
    }
}
