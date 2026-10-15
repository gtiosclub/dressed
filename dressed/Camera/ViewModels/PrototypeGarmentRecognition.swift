import Foundation
import Vision

// A whole-image hint for one garment photo. This does not locate separate pieces
// or identify a specific product; a user must approve the details before saving.
enum PrototypeGarmentRecognition {
    struct Suggestion {
        let name: String
        let category: ClothingCategory
    }

    static func analyze(_ imageData: Data) async throws -> Suggestion? {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let request = VNClassifyImageRequest()
            try VNImageRequestHandler(data: imageData).perform([request])
            try Task.checkCancellation()

            // Vision's general classifier is often uncertain about clothing.
            // Prefer a manual draft over presenting a weak guess as a detection.
            let mappings: [(name: String, category: ClothingCategory, keywords: [String])] = [
                ("Shirt", .tops, ["shirt", "jersey", "blouse", "t-shirt"]),
                ("Sweater", .tops, ["sweater", "pullover"]),
                ("Pants", .pants, ["jean", "trouser", "pant", "legging"]),
                ("Skirt", .skirts, ["skirt"]),
                ("Dress", .dresses, ["dress", "gown"]),
                ("Shoes", .shoes, ["shoe", "sneaker", "boot", "sandal", "loafer"]),
                ("Jacket", .outerwear, ["coat", "jacket", "parka", "blazer"]),
                ("Accessory", .accessories, ["hat", "cap", "bag", "belt", "scarf", "glove"])
            ]
            let observations = (request.results ?? [])
                .filter { $0.confidence >= 0.15 }
                .prefix(10)
            for observation in observations {
                let label = observation.identifier.lowercased()
                if let match = mappings.first(where: { $0.keywords.contains(where: label.contains) }) {
                    return Suggestion(name: match.name, category: match.category)
                }
            }
            return nil
        }.value
    }
}
