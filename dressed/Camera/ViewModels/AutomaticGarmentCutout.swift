import CoreImage
import Foundation
import UIKit
import Vision

// Vision separates prominent foreground subjects. It can miss a garment or
// include part of a person, so review always shows the result before saving.
nonisolated enum AutomaticGarmentCutout {
    private static let sharedContext = CIContext()

    static func png(from croppedImage: Data, reuseContext: Bool = true,
                    metrics: RecognitionMetrics? = nil) async throws -> Data? {
        try await RecognitionExecution.offMain { () throws -> Data? in
            try Task.checkCancellation()
            let start = ProcessInfo.processInfo.systemUptime
            defer { metrics?.record("cutout total", since: start) }
            guard let image = UIImage(data: croppedImage) else { return nil }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
            guard let cgImage = upright.cgImage else { return nil }
            if let masked = visionMask(cgImage, reuseContext: reuseContext, metrics: metrics) {
                try Task.checkCancellation()
                return masked
            }
            try Task.checkCancellation()
            if let metrics {
                return metrics.measure("background fallback") { simpleBackgroundMask(cgImage, optimized: reuseContext) }
            }
            return simpleBackgroundMask(cgImage, optimized: reuseContext)
        }
    }

    nonisolated private static func visionMask(_ cgImage: CGImage, reuseContext: Bool,
                                               metrics: RecognitionMetrics?) -> Data? {
        let start = ProcessInfo.processInfo.systemUptime
        defer { metrics?.record("foreground mask", since: start) }
        let handler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNGenerateForegroundInstanceMaskRequest()
        do {
            try handler.perform([request])
            guard let observation = request.results?.first,
                  !observation.allInstances.isEmpty else { return nil }
            let buffer = try observation.generateMaskedImage(
                ofInstances: observation.allInstances,
                from: handler,
                croppedToInstancesExtent: true
            )
            let ciImage = CIImage(cvPixelBuffer: buffer)
            guard let output = (reuseContext ? sharedContext : CIContext()).createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: output).pngData()
        } catch {
            metrics?.warning("Vision foreground mask failed; using plain-background fallback.", error: error)
            return nil
        }
    }

    // A conservative local fallback for catalog-style photos with a nearly
    // uniform backdrop. Flood fill from the edges so light details inside the
    // garment stay opaque. Complex backgrounds return nil.
    nonisolated static func simpleBackgroundMask(_ image: CGImage, optimized: Bool) -> Data? {
        let width = image.width
        let height = image.height
        let count = width * height
        guard width >= 16, height >= 16, count <= 6_000_000 else { return nil }
        var pixels = [UInt8](repeating: 0, count: count * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let drew = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: colorSpace, bitmapInfo: bitmapInfo) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drew else { return nil }

        let corners = [0, width - 1, count - width, count - 1]
        let background = (0..<3).map { channel in
            corners.reduce(0.0) { $0 + Double(pixels[$1 * 4 + channel]) } / 4
        }
        // Reject backdrops whose corners differ substantially (outdoor scenes).
        guard corners.allSatisfy({ pixel in
            (0..<3).allSatisfy { abs(Double(pixels[pixel * 4 + $0]) - background[$0]) < 32 }
        }) else { return nil }

        if optimized {
            return scanlineMask(pixels: &pixels, width: width, height: height, background: background)
        }

        var visited = [Bool](repeating: false, count: count)
        var queue: [Int] = []
        queue.reserveCapacity(count / 2)
        func enqueue(_ pixel: Int) {
            guard !visited[pixel] else { return }
            visited[pixel] = true
            let offset = pixel * 4
            let difference = (0..<3).reduce(0.0) {
                $0 + abs(Double(pixels[offset + $1]) - background[$1])
            } / 3
            if difference < 35 { queue.append(pixel) }
        }
        for x in 0..<width {
            enqueue(x)
            enqueue((height - 1) * width + x)
        }
        for y in 0..<height {
            enqueue(y * width)
            enqueue(y * width + width - 1)
        }
        var head = 0
        var left = width
        var top = height
        var right = 0
        var bottom = 0
        while head < queue.count {
            if head % 4096 == 0 && Task.isCancelled { return nil }
            let pixel = queue[head]
            head += 1
            let x = pixel % width
            let y = pixel / width
            pixels[pixel * 4] = 0
            pixels[pixel * 4 + 1] = 0
            pixels[pixel * 4 + 2] = 0
            pixels[pixel * 4 + 3] = 0
            if x > 0 { enqueue(pixel - 1) }
            if x + 1 < width { enqueue(pixel + 1) }
            if y > 0 { enqueue(pixel - width) }
            if y + 1 < height { enqueue(pixel + width) }
        }
        guard queue.count > count / 10, queue.count < count * 9 / 10 else { return nil }
        for pixel in 0..<count where pixels[pixel * 4 + 3] > 0 {
            let x = pixel % width
            let y = pixel / width
            left = min(left, x)
            top = min(top, y)
            right = max(right, x)
            bottom = max(bottom, y)
        }
        guard right > left + 8, bottom > top + 8 else { return nil }
        let result = pixels.withUnsafeMutableBytes { bytes -> CGImage? in
            let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                    bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: colorSpace, bitmapInfo: bitmapInfo)
            return context?.makeImage()?.cropping(to: CGRect(x: left, y: top,
                                                               width: right - left + 1,
                                                               height: bottom - top + 1))
        }
        return result.flatMap { UIImage(cgImage: $0).pngData() }
    }

    private struct RowSpan {
        let left: Int
        let right: Int
        let row: Int
    }

    // Same four-connected flood fill and threshold as the original. Queue
    // horizontal runs instead of individual pixels; interior holes stay opaque.
    private static func scanlineMask(pixels: inout [UInt8], width: Int, height: Int,
                                     background: [Double]) -> Data? {
        var visited = [Bool](repeating: false, count: width * height)
        // Pin storage once for the synchronous fill. All indices are bounded by
        // width/height; PNG encoding finishes before either pointer leaves scope.
        return pixels.withUnsafeMutableBufferPointer { rgba in
            visited.withUnsafeMutableBufferPointer { seen in
                scanlineMask(pixels: rgba.baseAddress!, visited: seen.baseAddress!,
                             width: width, height: height, background: background)
            }
        }
    }

    private static func scanlineMask(pixels: UnsafeMutablePointer<UInt8>,
                                     visited: UnsafeMutablePointer<Bool>,
                                     width: Int, height: Int, background: [Double]) -> Data? {
        var spans: [RowSpan] = []
        spans.reserveCapacity(height * 2)
        var removed = 0
        let redBackground = background[0]
        let greenBackground = background[1]
        let blueBackground = background[2]

        func matches(_ pixel: Int) -> Bool {
            guard !visited[pixel] else { return false }
            let offset = pixel * 4
            let distance = (abs(Double(pixels[offset]) - redBackground)
                            + abs(Double(pixels[offset + 1]) - greenBackground)
                            + abs(Double(pixels[offset + 2]) - blueBackground)) / 3
            if distance < 35 { return true }
            visited[pixel] = true
            return false
        }

        @discardableResult
        func fill(_ x: Int, _ row: Int) -> Int? {
            let base = row * width
            guard matches(base + x) else { return nil }
            var left = x
            var right = x
            while left > 0 && matches(base + left - 1) { left -= 1 }
            while right + 1 < width && matches(base + right + 1) { right += 1 }
            for column in left...right {
                let pixel = base + column
                visited[pixel] = true
                let offset = pixel * 4
                pixels[offset] = 0
                pixels[offset + 1] = 0
                pixels[offset + 2] = 0
                pixels[offset + 3] = 0
            }
            removed += right - left + 1
            spans.append(RowSpan(left: left, right: right, row: row))
            return right
        }

        for x in 0..<width { fill(x, 0); fill(x, height - 1) }
        for y in 0..<height { fill(0, y); fill(width - 1, y) }
        var processed = 0
        // Release processed spans instead of retaining a history of the fill.
        while let span = spans.popLast() {
            if processed % 64 == 0 && Task.isCancelled { return nil }
            processed += 1
            for row in [span.row - 1, span.row + 1] where row >= 0 && row < height {
                var x = span.left
                while x <= span.right {
                    if let end = fill(x, row) { x = end + 1 }
                    else { x += 1 }
                }
            }
        }
        let count = width * height
        guard removed > count / 10, removed < count * 9 / 10 else { return nil }

        var left = width
        var right = 0
        var top = height
        var bottom = 0
        for row in 0..<height {
            let base = row * width
            var first = 0
            while first < width && pixels[(base + first) * 4 + 3] == 0 { first += 1 }
            guard first < width else { continue }
            var last = width - 1
            while last > first && pixels[(base + last) * 4 + 3] == 0 { last -= 1 }
            left = min(left, first)
            right = max(right, last)
            top = min(top, row)
            bottom = row
        }
        guard right > left + 8, bottom > top + 8 else { return nil }
        let context = CGContext(data: pixels, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                                    | CGBitmapInfo.byteOrder32Big.rawValue)
        let result = context?.makeImage()?.cropping(to: CGRect(x: left, y: top,
            width: right - left + 1, height: bottom - top + 1))
        return result.flatMap { UIImage(cgImage: $0).pngData() }
    }
}
