import CryptoKit
import Foundation

/// Team image-generation key. The person using the app does not enter this.
enum TryOnAPIKey {
    static let openAI = ""

    static var isConfigured: Bool {
        !openAI.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum TryOnImageError: LocalizedError {
    case missingAPIKey
    case rejectedKey
    case provider(String)
    case emptyImage

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "The OpenAI API key in TryOnAPIKey is empty."
        case .rejectedKey:
            return "OpenAI rejected the API key."
        case .provider(let message):
            return message
        case .emptyImage:
            return "OpenAI did not return an image."
        }
    }
}

struct TryOnImageClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func edit(
        key: String,
        prompt: String,
        images: [Data],
        quality: String,
        ownerId: String
    ) async throws -> Data {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TryOnImageError.missingAPIKey }
        guard !images.isEmpty else { throw TryOnImageError.emptyImage }
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        let boundary = "TryOn\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        field("model", TryOnVersions.provider)
        field("prompt", prompt)
        field("size", "1024x1536")
        field("background", "transparent")
        field("output_format", "png")
        field("quality", quality)
        field("n", "1")
        field("safety_identifier", safetyIdentifier(for: ownerId))
        for (index, image) in images.enumerated() {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append(
                "Content-Disposition: form-data; name=\"image[]\"; filename=\"image-\(index).png\"\r\n"
                    .data(using: .utf8)!
            )
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(image)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 401 { throw TryOnImageError.rejectedKey }
        guard (200..<300).contains(status) else {
            throw TryOnImageError.provider(errorMessage(from: data, status: status))
        }
        guard let image = decodeImage(data) else { throw TryOnImageError.emptyImage }
        return image
    }

    private func safetyIdentifier(for ownerId: String) -> String {
        let digest = SHA256.hash(data: Data("dressed:\(ownerId)".utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func decodeImage(_ data: Data) -> Data? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = json["data"] as? [[String: Any]],
              let encoded = rows.first?["b64_json"] as? String else { return nil }
        return Data(base64Encoded: encoded)
    }

    private func errorMessage(from data: Data, status: Int) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String,
           !message.isEmpty {
            return message
        }
        return "Image generation failed (\(status))."
    }
}
