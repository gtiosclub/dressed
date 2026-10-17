import Foundation

// Development-only bridge. Google credentials stay in the loopback service,
// never in the app. In Debug, import review tries this bridge automatically
// and falls back to on-device suggestions when it is unavailable.
protocol GarmentRecognitionService {
    func detect(imageData: Data, importID: String) async throws -> [ImportCandidate]
}

enum LocalRecognitionError: LocalizedError {
    case unavailable
    case invalidResponse
    case imageTooLarge

    var errorDescription: String? {
        switch self {
        case .unavailable: "Recognition test service is unavailable. Start it on this Mac or enter details manually."
        case .invalidResponse: "The recognition response could not be read. Enter details manually or retry."
        case .imageTooLarge: "This photo exceeds the 5 MB test limit. Choose a smaller image."
        }
    }
}

struct LocalGarmentRecognition: GarmentRecognitionService {
    private struct Result: Decodable {
        let importId: String
        let candidates: [Candidate]
    }

    private struct Candidate: Decodable {
        let id: String
        let boundingBox: NormalizedImageRegion
        let suggestedName: String
        let suggestedCategory: String
    }

    func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        guard !imageData.isEmpty, imageData.count <= 5_000_000 else {
            throw LocalRecognitionError.imageTooLarge
        }
        #if DEBUG
        var request = URLRequest(url: URL(string: "http://127.0.0.1:8765/recognize")!)
        request.httpMethod = "POST"
        request.httpBody = imageData
        request.setValue(importID, forHTTPHeaderField: "X-Import-ID")
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 35
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw LocalRecognitionError.unavailable
        }
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              let result = try? JSONDecoder().decode(Result.self, from: data),
              result.importId == importID else {
            throw LocalRecognitionError.invalidResponse
        }
        return result.candidates.compactMap { value in
            guard value.boundingBox.isValid,
                  let category = ClothingCategory(rawValue: value.suggestedCategory) else { return nil }
            return ImportCandidate(
                id: SharedImportDraftStore.stableID(importID: importID, part: "google-\(value.id)"),
                name: value.suggestedName, category: category, destination: .closet,
                temporaryCutoutPath: nil, region: value.boundingBox,
                suggestionSource: "Automatic suggestion", selected: false,
                tags: [], suggestedTags: []
            )
        }
        #else
        throw LocalRecognitionError.unavailable
        #endif
    }
}
