import CoreGraphics
import CoreML
import CoreVideo
import Foundation

// Finds garments pixel by pixel with a clothes-parsing model, so each piece gets its real shape.
// Shared by the app and the Mac tools in backend/recognition, so keep it free of app services.
//
// The model is NOT bundled: the available weights allow research and evaluation only.
// See "Clothes parsing" in backend/recognition/README.md.
nonisolated struct ParsedPiece {
    /// Stable per photo, such as "top" or "shoes".
    let part: String
    let name: String
    let category: ClothingCategory
    let region: NormalizedImageRegion
    /// This piece's pixels over the whole photo.
    let mask: GarmentMask
}

nonisolated enum ClothesParserError: Error {
    case unreadableImage
    case unexpectedOutput
}

nonisolated enum ClothesParser {
    static let side = 512

    // Order matches the model's labels (backend/recognition/convert_clothes_parser.py).
    enum Label: UInt8, CaseIterable {
        case background, hat, hair, sunglasses, upperClothes, skirt, pants, dress, belt,
             leftShoe, rightShoe, face, leftLeg, rightLeg, leftArm, rightArm, bag, scarf
    }

    private struct Kind {
        let part: String
        let name: String
        let category: ClothingCategory
        let labels: [Label]
        /// Smallest share of the photo that counts as a piece.
        let minimumShare: Double
    }

    // Garments need 1.5% of the photo. Shoes and accessories are naturally small, so they need less.
    // Skin, hair, face and background are never listed, so they can never become a piece.
    private static let garmentShare = 0.015
    private static let accessoryShare = 0.002
    private static let kinds = [
        Kind(part: "top", name: "Top", category: .tops, labels: [.upperClothes], minimumShare: garmentShare),
        Kind(part: "dress", name: "Dress", category: .dresses, labels: [.dress], minimumShare: garmentShare),
        Kind(part: "pants", name: "Pants", category: .pants, labels: [.pants], minimumShare: garmentShare),
        Kind(part: "skirt", name: "Skirt", category: .skirts, labels: [.skirt], minimumShare: garmentShare),
        Kind(part: "shoes", name: "Shoes", category: .shoes, labels: [.leftShoe, .rightShoe],
             minimumShare: accessoryShare),
        Kind(part: "hat", name: "Hat", category: .accessories, labels: [.hat], minimumShare: accessoryShare),
        Kind(part: "scarf", name: "Scarf", category: .accessories, labels: [.scarf], minimumShare: accessoryShare),
        Kind(part: "bag", name: "Bag", category: .accessories, labels: [.bag], minimumShare: accessoryShare),
        Kind(part: "sunglasses", name: "Sunglasses", category: .accessories, labels: [.sunglasses],
             minimumShare: accessoryShare),
        Kind(part: "belt", name: "Belt", category: .accessories, labels: [.belt], minimumShare: accessoryShare),
    ]

    /// Turns a label per pixel into reviewable pieces.
    static func pieces(labels: [UInt8], width: Int, height: Int) -> [ParsedPiece] {
        guard width > 0, height > 0, labels.count == width * height else { return [] }
        var map = labels
        var counts = [Int](repeating: 0, count: Label.allCases.count)
        for value in map where Int(value) < counts.count { counts[Int(value)] += 1 }

        // A dress and a top are rarely both right on one body: the larger one takes the other's pixels.
        func merge(_ from: Label, into target: Label) {
            for index in map.indices where map[index] == from.rawValue { map[index] = target.rawValue }
        }
        let dress = counts[Int(Label.dress.rawValue)]
        if dress > 0 {
            if dress > counts[Int(Label.upperClothes.rawValue)] {
                merge(.upperClothes, into: .dress)
                if dress > counts[Int(Label.skirt.rawValue)] { merge(.skirt, into: .dress) }
            } else {
                merge(.dress, into: .upperClothes)
            }
        }

        return kinds.compactMap { kind in
            let wanted = Set(kind.labels.map(\.rawValue))
            var pixels = map.map { wanted.contains($0) ? UInt8(255) : 0 }
            guard let area = removeSpecks(&pixels, width: width, height: height),
                  Double(area) >= kind.minimumShare * Double(width * height) else { return nil }
            let mask = GarmentMask(width: width, height: height, pixels: pixels)
            guard let region = mask.region(padding: 0.01) else { return nil }
            return ParsedPiece(part: kind.part, name: kind.name, category: kind.category,
                               region: region, mask: mask)
        }
    }

    /// Clears connected areas under a tenth of the largest one (stray pixels, a passer-by).
    /// Returns the remaining area, or nil when nothing is left.
    private static func removeSpecks(_ pixels: inout [UInt8], width: Int, height: Int) -> Int? {
        var seen = [Bool](repeating: false, count: pixels.count)
        var areas: [[Int]] = []
        for start in pixels.indices where pixels[start] != 0 && !seen[start] {
            var area = [start]
            seen[start] = true
            var head = 0
            while head < area.count {
                let pixel = area[head]
                head += 1
                let x = pixel % width, y = pixel / width
                for (nx, ny) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
                    where nx >= 0 && nx < width && ny >= 0 && ny < height {
                    let next = ny * width + nx
                    if pixels[next] != 0 && !seen[next] {
                        seen[next] = true
                        area.append(next)
                    }
                }
            }
            areas.append(area)
        }
        guard let largest = areas.map(\.count).max() else { return nil }
        var kept = 0
        for area in areas {
            if area.count * 10 >= largest {
                kept += area.count
            } else {
                for pixel in area { pixels[pixel] = 0 }
            }
        }
        return kept
    }

    static func load(modelAt url: URL) async throws -> MLModel {
        let compiled = url.pathExtension == "mlmodelc" ? url : try await MLModel.compileModel(at: url)
        let configuration = MLModelConfiguration()
        #if targetEnvironment(simulator)
        configuration.computeUnits = .cpuOnly
        #else
        configuration.computeUnits = .all
        #endif
        return try MLModel(contentsOf: compiled, configuration: configuration)
    }

    /// One label per pixel of a `side` x `side` copy of the upright photo.
    static func labels(for image: CGImage, model: MLModel) throws -> [UInt8] {
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(nil, side, side, kCVPixelFormatType_32BGRA,
                            [kCVPixelBufferCGImageCompatibilityKey: true] as CFDictionary, &buffer)
        guard let buffer else { throw ClothesParserError.unreadableImage }
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer), width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        context?.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context?.interpolationQuality = .high
        // The model was trained on stretched squares, so the photo is not letterboxed.
        context?.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        CVPixelBufferUnlockBaseAddress(buffer, [])
        guard context != nil else { throw ClothesParserError.unreadableImage }

        let input = try MLDictionaryFeatureProvider(dictionary: ["image": MLFeatureValue(pixelBuffer: buffer)])
        let output = try model.prediction(from: input)
        guard let array = output.featureValue(for: "labels")?.multiArrayValue,
              array.shape.map(\.intValue) == [1, side, side] else {
            throw ClothesParserError.unexpectedOutput
        }
        var result = [UInt8](repeating: 0, count: side * side)
        for y in 0..<side {
            for x in 0..<side {
                result[y * side + x] = UInt8(clamping: array[[0, y, x] as [NSNumber]].intValue)
            }
        }
        return result
    }

    static func parse(_ image: CGImage, model: MLModel) throws -> [ParsedPiece] {
        pieces(labels: try labels(for: image, model: model), width: side, height: side)
    }
}
