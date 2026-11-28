// Matching vector for one piece cutout, for the iOS simulator. local_service.py compiles this with
// the app's CatalogEmbedding.swift. Runs on this Mac only.
// Usage: embed_piece <image>  ->  {"model": ..., "vector": [...]} on stdout
import Foundation
import Vision

@main
struct EmbedPiece {
    static func main() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
        guard let image = GarmentImage.upright(data),
              let canonical = CatalogEmbedding.canonicalImage(image) else { exit(1) }
        let request = CatalogEmbedding.request()
        try VNImageRequestHandler(cgImage: canonical).perform([request])
        guard let vector = request.results?.first.flatMap(CatalogEmbedding.vector(from:)) else { exit(1) }
        let result: [String: Any] = ["model": CatalogEmbedding.model, "vector": vector.map(Double.init)]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result))
    }
}
