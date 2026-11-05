import Foundation
import CoreML
import Vision

// A whole-image hint for one garment photo. This does not locate separate pieces
// or identify a specific product; a user must approve the details before saving.
nonisolated enum PrototypeGarmentRecognition {
    struct Suggestion {
        let name: String
        let category: ClothingCategory
    }

    static func analyze(_ imageData: Data, metrics: RecognitionMetrics? = nil) async throws -> Suggestion? {
        try await RecognitionExecution.offMain {
            try Task.checkCancellation()
            let request = VNClassifyImageRequest()
            do {
                let start = ProcessInfo.processInfo.systemUptime
                defer { metrics?.record("classification", since: start) }
                try configureCompute(request)
                try VNImageRequestHandler(data: imageData).perform([request])
            } catch {
                metrics?.warning("Vision classification failed; category quality was not evaluated for this call.", error: error)
                throw error
            }
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
        }
    }

    static func configureCompute(_ request: VNClassifyImageRequest) throws {
        #if targetEnvironment(simulator)
        // This runtime's automatic GPU selection fails with an Espresso error.
        // Use a CPU that Vision explicitly reports as supported. Device builds
        // retain Apple's automatic compute selection.
        for (stage, devices) in try request.supportedComputeStageDevices {
            if let cpu = devices.first(where: { if case .cpu = $0 { return true }; return false }) {
                request.setComputeDevice(cpu, for: stage)
            }
        }
        #endif
    }
}
