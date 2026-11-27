import CoreGraphics
import Foundation
import Vision

// How a cutout is turned into a matching vector. The catalog ingest tool (backend/catalog) and the
// app compile this same file, so both ends of a comparison are prepared the same way.
nonisolated enum CatalogEmbedding {
    static let model = "apple-featureprint-2"

    /// The cutout centered on a white square, so backgrounds and framing never take part in matching.
    static func canonicalImage(_ cutout: CGImage, side: Int = 360) -> CGImage? {
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: side, height: side))
        context.interpolationQuality = .high
        let room = Double(side) * 0.92
        let scale = min(room / Double(cutout.width), room / Double(cutout.height))
        let width = Double(cutout.width) * scale, height = Double(cutout.height) * scale
        context.draw(cutout, in: CGRect(x: (Double(side) - width) / 2, y: (Double(side) - height) / 2,
                                        width: width, height: height))
        return context.makeImage()
    }

    static func request() -> VNGenerateImageFeaturePrintRequest {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision2
        return request
    }

    /// Unit-length vector, so a dot product ranks by similarity.
    static func vector(from observation: VNFeaturePrintObservation) -> [Float]? {
        guard observation.elementType == .float, observation.elementCount > 0 else { return nil }
        let values = observation.data.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
        return normalized(values)
    }

    static func normalized(_ values: [Float]) -> [Float]? {
        let length = values.reduce(0) { $0 + $1 * $1 }.squareRoot()
        guard length > 0, length.isFinite else { return nil }
        return values.map { $0 / length }
    }
}
