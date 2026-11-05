import Foundation

// Development-only bridge. Store pages are fetched and read by the loopback
// service (backend/links), never by the app. No keys live in the app. If the
// service is unavailable the review screen stays a manual form.
protocol ProductLinkImportService {
    func draft(for url: URL, requestID: String) async throws -> ProductImportDraft
}

enum ProductLinkImportError: LocalizedError {
    case unavailable
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable: "Automatic details are unavailable. Enter them yourself."
        case .invalidResponse: "The page details could not be read. Enter them yourself."
        }
    }
}

struct LocalProductLinkImport: ProductLinkImportService {
    private struct Request: Encodable {
        let url: String
        let clientRequestId: String
    }

    func draft(for url: URL, requestID: String) async throws -> ProductImportDraft {
        #if DEBUG
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8767/product-imports")!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONEncoder().encode(Request(url: url.absoluteString, clientRequestId: requestID))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 20
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw ProductLinkImportError.unavailable
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let draft = try? JSONDecoder().decode(ProductImportDraft.self, from: data) else {
            throw ProductLinkImportError.invalidResponse
        }
        return draft
        #else
        throw ProductLinkImportError.unavailable
        #endif
    }
}
