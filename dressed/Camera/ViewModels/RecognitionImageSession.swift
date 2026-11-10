import ImageIO
import UIKit

nonisolated enum RecognitionMode: String, Codable, CaseIterable, Identifiable {
    case baseline, nativePixels, compact
    var id: String { rawValue }
    var title: String {
        switch self {
        case .baseline: "Original"
        case .nativePixels: "Native pixels"
        case .compact: "1024px trial"
        }
    }
}

// Confined to one pipeline run. The original remains untouched for review and saving.
nonisolated final class RecognitionImageSession {
    let original: Data
    let mode: RecognitionMode
    let metrics: RecognitionMetrics
    private var upright: CGImage?
    private var crops: [String: Data] = [:]
    let processingData: Data

    init(data: Data, mode: RecognitionMode, metrics: RecognitionMetrics) throws {
        original = data
        self.mode = mode
        self.metrics = metrics
        if mode == .compact {
            let pixels = try Self.decode(data, mode: mode, metrics: metrics)
            upright = pixels
            guard let jpeg = UIImage(cgImage: pixels).jpegData(compressionQuality: 0.85) else {
                throw PrototypeImportError.invalidImage
            }
            processingData = jpeg
        } else {
            // A whole-image fallback needs no extra native decode. Prepare only
            // after body pose actually produces regions that need cropping.
            processingData = data
            guard UIImage(data: data) != nil else { throw PrototypeImportError.invalidImage }
        }
    }

    private static func decode(_ data: Data, mode: RecognitionMode, metrics: RecognitionMetrics) throws -> CGImage {
        try metrics.measure("prepare") {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? Int,
                  let height = properties[kCGImagePropertyPixelHeight] as? Int else {
                throw PrototypeImportError.invalidImage
            }
            let limit = mode == .compact ? min(1024, max(width, height)) : max(width, height)
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: limit,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                throw PrototypeImportError.invalidImage
            }
            return image
        }
    }

    func crop(_ candidate: ImportCandidate) throws -> Data {
        try metrics.measure("crop preparation") {
            if mode == .baseline {
                return try SharedImportDraftStore.imageData(for: candidate, in: original, nativeScale: false)
            }
            if let cached = crops[candidate.id] { return cached }
            if mode == .nativePixels && candidate.region == nil {
                let jpeg = try SharedImportDraftStore.imageData(for: candidate, in: original)
                crops[candidate.id] = jpeg
                return jpeg
            }
            if upright == nil { upright = try Self.decode(original, mode: mode, metrics: metrics) }
            guard let upright else { throw PrototypeImportError.invalidImage }
            let pixels: CGImage
            if let region = candidate.region {
                guard region.isValid else { throw SharedImportDraftError.invalidCrop }
                let rect = CGRect(x: region.x * Double(upright.width), y: region.y * Double(upright.height),
                                  width: region.width * Double(upright.width),
                                  height: region.height * Double(upright.height)).integral
                    .intersection(CGRect(x: 0, y: 0, width: upright.width, height: upright.height))
                guard rect.width >= 2, rect.height >= 2, let cropped = upright.cropping(to: rect) else {
                    throw SharedImportDraftError.invalidCrop
                }
                pixels = cropped
            } else {
                pixels = upright
            }
            guard let jpeg = UIImage(cgImage: pixels).jpegData(compressionQuality: 0.85) else {
                throw PrototypeImportError.invalidImage
            }
            crops[candidate.id] = jpeg
            return jpeg
        }
    }
}
