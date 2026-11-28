// Mac ingest helper for build_catalog_pack.py: picks each product's packshot, cuts it out and
// embeds it with the app's own parsing, cutout and embedding code. Runs on this Mac only.
// Usage: catalog_pack_tool <ClothesParser.mlpackage>  (one JSON request per stdin line, one reply per line)
import CoreML
import Foundation
import Vision

struct Request: Decodable {
    /// "catalog" chooses among a product's images; "query" treats one photo like a person's piece.
    let op: String
    let id: String
    let category: String
    let images: [String]
    let cutout: String
    let canonical: String?
}

struct Photo {
    let image: CGImage
    let pieces: [ParsedPiece]
    let hasPerson: Bool
}

@main
struct CatalogPackTool {
    static func main() async throws {
        let model = try await ClothesParser.load(modelAt: URL(fileURLWithPath: CommandLine.arguments[1]))
        while let line = readLine() {
            var reply: [String: Any] = [:]
            do {
                let request = try JSONDecoder().decode(Request.self, from: Data(line.utf8))
                reply["id"] = request.id
                try autoreleasepool { try handle(request, model: model, into: &reply) }
            } catch {
                reply["error"] = "\(error)"
            }
            var output = try JSONSerialization.data(withJSONObject: reply)
            output.append(0x0A)
            FileHandle.standardOutput.write(output)
        }
    }

    static func read(_ path: String, model: MLModel) throws -> Photo {
        guard let image = GarmentImage.upright(try Data(contentsOf: URL(fileURLWithPath: path)), maximumSide: 1200) else {
            throw ClothesParserError.unreadableImage
        }
        let labels = try ClothesParser.labels(for: image, model: model)
        let body: Set<UInt8> = Set([ClothesParser.Label.hair, .face, .leftArm, .rightArm, .leftLeg, .rightLeg]
            .map(\.rawValue))
        let skin = labels.filter { body.contains($0) }.count
        return Photo(image: image,
                     pieces: ClothesParser.pieces(labels: labels, width: ClothesParser.side, height: ClothesParser.side),
                     hasPerson: Double(skin) > 0.01 * Double(labels.count))
    }

    /// Parsed parts that can stand for a catalog category.
    static func parts(for category: String) -> [String] {
        switch category {
        case "tops", "outerwear": ["top", "dress"]
        case "pants": ["pants", "skirt"]
        case "skirts": ["skirt", "dress"]
        case "dresses": ["dress", "top", "skirt"]
        case "shoes": ["shoes"]
        case "accessories": ["bag", "hat", "scarf", "belt", "sunglasses"]
        default: []
        }
    }

    static func parsedPiece(_ photo: Photo, category: String) -> ParsedPiece? {
        // The first matching part wins, except accessories where the largest one is the subject.
        let wanted = parts(for: category)
        let found = wanted.compactMap { part in photo.pieces.first { $0.part == part } }
        return category == "accessories" ? found.max { area($0) < area($1) } : found.first
    }

    static func parsedCutout(_ photo: Photo, category: String) -> Data? {
        parsedPiece(photo, category: category).flatMap {
            GarmentImage.cutout(of: photo.image, mask: $0.mask, maximumSide: 480)
        }
    }

    /// Share of the piece's box that it covers. Low values are scattered fragments, not a product image.
    static func fill(_ piece: ParsedPiece) -> Double {
        let box = piece.region.width * piece.region.height * Double(piece.mask.width * piece.mask.height)
        return box > 0 ? Double(area(piece)) / box : 0
    }

    static func area(_ piece: ParsedPiece) -> Int { piece.mask.pixels.reduce(0) { $0 + ($1 > 0 ? 1 : 0) } }

    /// Apple's foreground mask, for product photos with no person in them.
    static func foregroundCutout(_ image: CGImage) -> Data? {
        let handler = VNImageRequestHandler(cgImage: image)
        let request = VNGenerateForegroundInstanceMaskRequest()
        guard (try? handler.perform([request])) != nil, let observation = request.results?.first,
              !observation.allInstances.isEmpty,
              let buffer = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        else { return nil }
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer),
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_OneComponent32Float else { return nil }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        var pixels = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            let row = base.advanced(by: y * CVPixelBufferGetBytesPerRow(buffer)).assumingMemoryBound(to: Float.self)
            for x in 0..<width where row[x] > 0.5 { pixels[y * width + x] = 255 }
        }
        let mask = GarmentMask(width: width, height: height, pixels: pixels)
        // A subject filling the whole frame is a fabric close-up, not a view of the product.
        guard let region = mask.region(), region.width < 0.98 || region.height < 0.98 else { return nil }
        return GarmentImage.cutout(of: image, mask: mask, maximumSide: 480)
    }

    static func handle(_ request: Request, model: MLModel, into reply: inout [String: Any]) throws {
        var chosen: (index: Int, method: String, png: Data)?
        if request.op == "catalog" {
            // Prefer the first gallery photo with no person in it.
            var photos: [Photo] = []
            for (index, path) in request.images.enumerated() {
                guard let photo = try? read(path, model: model) else { photos.append(Photo(image: blank, pieces: [], hasPerson: true)); continue }
                photos.append(photo)
                if !photo.hasPerson, let png = foregroundCutout(photo.image) {
                    chosen = (index, "packshot", png)
                    break
                }
            }
            // Otherwise cut the garment off a model photo.
            if chosen == nil {
                // The photo that shows the most of the piece, ignoring fragmented outlines.
                let best = photos.enumerated().compactMap { index, photo in
                    parsedPiece(photo, category: request.category)
                        .flatMap { fill($0) >= 0.35 ? (index, photo, $0) : nil }
                }.max { area($0.2) < area($1.2) }
                if let (index, photo, piece) = best,
                   let png = GarmentImage.cutout(of: photo.image, mask: piece.mask, maximumSide: 480) {
                    chosen = (index, "from-model", png)
                }
            }
        } else if let path = request.images.first {
            let photo = try read(path, model: model)
            if let png = parsedCutout(photo, category: request.category) {
                chosen = (0, "parsed", png)
            } else if let png = foregroundCutout(photo.image) {
                chosen = (0, "foreground", png)
            } else if let png = GarmentImage.png(photo.image) {
                chosen = (0, "whole", png)
            }
        }
        guard let chosen else { return }
        guard let cutout = GarmentImage.upright(chosen.png),
              let canonical = CatalogEmbedding.canonicalImage(cutout) else { throw ClothesParserError.unreadableImage }
        try chosen.png.write(to: URL(fileURLWithPath: request.cutout))
        if let path = request.canonical {
            try GarmentImage.png(canonical)?.write(to: URL(fileURLWithPath: path))
        }
        let print = CatalogEmbedding.request()
        try VNImageRequestHandler(cgImage: canonical).perform([print])
        guard let vector = print.results?.first.flatMap(CatalogEmbedding.vector(from:)) else {
            throw ClothesParserError.unexpectedOutput
        }
        reply["chosen"] = chosen.index
        reply["method"] = chosen.method
        reply["vector"] = vector.map(Double.init)
    }

    static let blank: CGImage = {
        let context = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        return context!.makeImage()!
    }()
}
