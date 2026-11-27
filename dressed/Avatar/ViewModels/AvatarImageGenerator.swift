import Foundation
import UIKit

/// One try-on request: the owner's reference photo and up to six labelled piece photos.
nonisolated struct AvatarGenerationRequest: Sendable {
    struct Piece: Sendable {
        let image: Data
        let label: String
    }

    let reference: Data
    let pieces: [Piece]
}

nonisolated enum AvatarGenerationError: LocalizedError, Equatable {
    case unavailable
    case contentPolicy
    case rateLimited
    case timedOut
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            #if DEBUG
            "The avatar service isn't running. Start backend/avatar/avatar_service.py on this Mac."
            #else
            "Avatar images aren't available in this build yet."
            #endif
        case .contentPolicy: "This look couldn't be generated. Try a different photo or outfit."
        case .rateLimited: "Too many looks right now. Try again in a minute."
        case .timedOut: "Generating took too long. Try again."
        case .failed(let message): message
        }
    }
}

/// Produces a generated image (JPEG or PNG data) for a try-on request. Implementations must not hold
/// private API keys on the device.
protocol AvatarImageGenerating: Sendable {
    func generate(_ request: AvatarGenerationRequest) async throws -> Data
}

enum AvatarImageGenerators {
    /// The generator for this build and launch arguments.
    static func current() -> any AvatarImageGenerating {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-mockAvatarGenerator") {
            return MockAvatarImageGenerator(delay: .seconds(2))
        }
        return LocalBridgeAvatarGenerator()
        #else
        return UnavailableAvatarGenerator()
        #endif
    }
}

#if DEBUG
/// Sends requests to `backend/avatar/avatar_service.py` on this Mac, which holds the OpenAI key.
/// The simulator reaches the Mac at 127.0.0.1; a device would need the Mac's LAN address.
nonisolated struct LocalBridgeAvatarGenerator: AvatarImageGenerating {
    var endpoint = URL(string: "http://127.0.0.1:8766/avatar")!
    var session: URLSession = .shared

    private struct Body: Encodable {
        struct Piece: Encodable { let image: String; let label: String }
        let reference: String
        let pieces: [Piece]
    }

    private struct Reply: Decodable {
        let image: String?
        let error: String?
        let message: String?
    }

    func generate(_ request: AvatarGenerationRequest) async throws -> Data {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // OpenAI can take up to two minutes for a detailed image.
        urlRequest.timeoutInterval = 200
        urlRequest.httpBody = try JSONEncoder().encode(Body(
            reference: request.reference.base64EncodedString(),
            pieces: request.pieces.map { .init(image: $0.image.base64EncodedString(), label: $0.label) }
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch let error as URLError where error.code == .timedOut {
            throw AvatarGenerationError.timedOut
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw AvatarGenerationError.unavailable
        }
        let reply = try? JSONDecoder().decode(Reply.self, from: data)
        if let http = response as? HTTPURLResponse, http.statusCode == 200,
           let encoded = reply?.image, let image = Data(base64Encoded: encoded) {
            return image
        }
        switch reply?.error {
        case "content_policy": throw AvatarGenerationError.contentPolicy
        case "rate_limited", "limit_reached": throw AvatarGenerationError.rateLimited
        case "unavailable": throw AvatarGenerationError.unavailable
        default: throw AvatarGenerationError.failed("The look couldn't be generated. Try again.")
        }
    }
}
#endif

/// Release builds have no generation backend yet (a Cloud Function holding the key is TBD).
nonisolated struct UnavailableAvatarGenerator: AvatarImageGenerating {
    func generate(_ request: AvatarGenerationRequest) async throws -> Data {
        throw AvatarGenerationError.unavailable
    }
}

/// For previews and UI tests: returns a plain rendered image after a delay, with no network.
nonisolated struct MockAvatarImageGenerator: AvatarImageGenerating {
    var delay: Duration = .milliseconds(300)
    var error: AvatarGenerationError?

    func generate(_ request: AvatarGenerationRequest) async throws -> Data {
        try await Task.sleep(for: delay)
        if let error { throw error }
        let size = CGSize(width: 512, height: 768)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor(white: 0.93, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor(white: 0.75, alpha: 1).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 206, y: 80, width: 100, height: 120))
            context.fill(CGRect(x: 166, y: 220, width: 180, height: 460))
        }
        return image.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
