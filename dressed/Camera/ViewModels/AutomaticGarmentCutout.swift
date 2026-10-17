import CoreImage
import Foundation
import UIKit
import Vision

// Vision separates prominent foreground subjects. It can miss a garment or
// include part of a person, so review always shows the result before saving.
enum AutomaticGarmentCutout {
    static func png(from croppedImage: Data) async -> Data? {
        await Task.detached(priority: .userInitiated) {
            guard let image = UIImage(data: croppedImage) else { return nil }
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let upright = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
            guard let cgImage = upright.cgImage else { return nil }
            if let masked = visionMask(cgImage) { return masked }
            return simpleBackgroundMask(cgImage)
        }.value
    }

    nonisolated private static func visionMask(_ cgImage: CGImage) -> Data? {
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
            guard let output = CIContext().createCGImage(ciImage, from: ciImage.extent) else { return nil }
            return UIImage(cgImage: output).pngData()
        } catch {
            return nil
        }
    }

    // A conservative local fallback for catalog-style photos with a nearly
    // uniform backdrop. Flood fill from the edges so light details inside the
    // garment stay opaque. Complex backgrounds return nil.
    nonisolated private static func simpleBackgroundMask(_ image: CGImage) -> Data? {
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
}
