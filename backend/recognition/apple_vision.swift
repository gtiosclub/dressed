// Pieces for the iOS simulator and for evaluation, computed on this Mac with the app's own code.
// With a parsing model it returns garment masks; otherwise Apple Vision body regions.
// local_service.py compiles this. Runs on this Mac only.
// Usage: apple_vision <image> <import-id> [<ClothesParser.mlpackage>]  ->  recognition bridge JSON on stdout
import Foundation
import Vision

@main
struct AppleVisionRegions {
    static func main() async throws {
        let arguments = CommandLine.arguments
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
        var candidates: [[String: Any]] = []
        if arguments.count > 3 {
            let model = try await ClothesParser.load(modelAt: URL(fileURLWithPath: arguments[3]))
            guard let image = GarmentImage.upright(data) else { throw ClothesParserError.unreadableImage }
            candidates = try ClothesParser.parse(image, model: model).map { piece in
                var value = candidate(piece.part, piece.name, piece.category.rawValue, piece.region)
                value["mask"] = piece.mask.pngData?.base64EncodedString()
                return value
            }
        }
        if candidates.isEmpty {
            candidates = try bodyRegions(data)
        }
        let result: [String: Any] = ["importId": arguments[2], "candidates": candidates]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result))
    }

    private static func candidate(_ id: String, _ name: String, _ category: String,
                                  _ region: NormalizedImageRegion) -> [String: Any] {
        ["id": id, "suggestedName": name, "suggestedCategory": category,
         "boundingBox": ["x": region.x, "y": region.y, "width": region.width, "height": region.height]]
    }

    private static func bodyRegions(_ data: Data) throws -> [[String: Any]] {
        let request = VNDetectHumanBodyPoseRequest()
        try VNImageRequestHandler(data: data).perform([request])
        return try GarmentPoseRegions.regions(in: request.results?.first).compactMap { part, region in
            if part == "head" {
                guard try seesHeadwear(data, in: region) else { return nil }
                return candidate(part, "Headwear", "accessories", region)
            }
            let (name, category) = switch part {
            case "upper": ("Top", "tops")
            case "shoes": ("Shoes", "shoes")
            default: ("Bottom", "pants")
            }
            return candidate(part, name, category, region)
        }
    }

    private static func seesHeadwear(_ data: Data, in region: NormalizedImageRegion) throws -> Bool {
        let request = VNClassifyImageRequest()
        request.regionOfInterest = CGRect(x: region.x, y: 1 - region.y - region.height,
                                          width: region.width, height: region.height)
        try VNImageRequestHandler(data: data).perform([request])
        return (request.results ?? []).filter { $0.confidence >= 0.15 }.prefix(10).contains { result in
            let words = result.identifier.lowercased().split(separator: "_")
            return words.contains { ["hat", "cap", "scarf", "headgear", "headwear", "beanie"].contains($0) }
        }
    }
}
