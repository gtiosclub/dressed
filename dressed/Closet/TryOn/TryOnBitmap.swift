import CoreGraphics
import UIKit
import UniformTypeIdentifiers

struct TryOnAlphaStats: Equatable {
    var bounds: CGRect
    var opaqueCount: Int
    var topBorderOpaque: Int
    var leftBorderOpaque: Int
    var rightBorderOpaque: Int
    var centerBandAlpha: Double
    var opaqueFraction: Double
    var holeFractionInsideBounds: Double
}

enum TryOnBitmap {
    /// A front-facing stand-in used only as the source photo for the first avatar request.
    static func neutralFigure(canvas: TryOnCanvas = .canonical) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: canvas.width, height: canvas.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let ink = UIColor(white: 0.75, alpha: 1)
            ink.setFill()
            let width = size.width
            let height = size.height
            let head = CGRect(x: width * 0.40, y: height * 0.08, width: width * 0.20, height: height * 0.10)
            context.cgContext.fillEllipse(in: head)
            context.fill(CGRect(x: width * 0.38, y: height * 0.18, width: width * 0.24, height: height * 0.28))
            context.fill(CGRect(x: width * 0.22, y: height * 0.20, width: width * 0.14, height: height * 0.22))
            context.fill(CGRect(x: width * 0.64, y: height * 0.20, width: width * 0.14, height: height * 0.22))
            context.fill(CGRect(x: width * 0.38, y: height * 0.46, width: width * 0.10, height: height * 0.40))
            context.fill(CGRect(x: width * 0.52, y: height * 0.46, width: width * 0.10, height: height * 0.40))
        }
    }

    static func aspectFit(_ image: UIImage, canvas: TryOnCanvas) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: canvas.width, height: canvas.height)
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            let source = image.size
            guard source.width > 0, source.height > 0 else { return }
            let scale = min(size.width / source.width, size.height / source.height)
            let fitted = CGSize(width: source.width * scale, height: source.height * scale)
            let rect = CGRect(
                x: (size.width - fitted.width) / 2,
                y: (size.height - fitted.height) / 2,
                width: fitted.width,
                height: fitted.height
            )
            image.draw(in: rect)
        }
        return rendered.cgImage
    }

    static func placed(_ image: CGImage, canvas: TryOnCanvas) -> CGImage? {
        if image.width == canvas.width && image.height == canvas.height {
            return image
        }
        return aspectFit(UIImage(cgImage: image), canvas: canvas)
    }

    static func translated(_ image: CGImage, dx: CGFloat, dy: CGFloat, canvas: TryOnCanvas) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: canvas.width, height: canvas.height)
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: image).draw(
                in: CGRect(x: dx, y: dy, width: CGFloat(image.width), height: CGFloat(image.height))
            )
        }
        return rendered.cgImage
    }

    static func pngData(from image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    static func stats(of image: CGImage) -> TryOnAlphaStats? {
        guard let bytes = rgba(from: image) else { return nil }
        let width = bytes.width
        let height = bytes.height
        let pixels = bytes.bytes
        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1
        var opaque = 0
        var top = 0
        var left = 0
        var right = 0
        let frame = 2
        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[(y * width + x) * 4 + 3]
                guard alpha > 16 else { continue }
                opaque += 1
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
                if y < frame { top += 1 }
                if x < frame { left += 1 }
                if x >= width - frame { right += 1 }
            }
        }
        let area = max(width * height, 1)
        let bounds: CGRect
        let holeFraction: Double
        let centerAlpha: Double
        if opaque == 0 {
            bounds = .zero
            holeFraction = 1
            centerAlpha = 0
        } else {
            bounds = CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
            var transparentInside = 0
            let bandMin = bounds.midX - bounds.width * 0.04
            let bandMax = bounds.midX + bounds.width * 0.04
            var bandTotal = 0.0
            var bandCount = 0
            for y in Int(bounds.minY)..<Int(bounds.maxY) {
                for x in Int(bounds.minX)..<Int(bounds.maxX) {
                    let alpha = Double(pixels[(y * width + x) * 4 + 3]) / 255
                    if alpha <= 16.0 / 255 { transparentInside += 1 }
                    if Double(x) >= bandMin && Double(x) <= bandMax {
                        bandTotal += alpha
                        bandCount += 1
                    }
                }
            }
            let boundsArea = max(Int(bounds.width * bounds.height), 1)
            holeFraction = Double(transparentInside) / Double(boundsArea)
            centerAlpha = bandCount == 0 ? 0 : bandTotal / Double(bandCount)
        }
        return TryOnAlphaStats(
            bounds: bounds,
            opaqueCount: opaque,
            topBorderOpaque: top,
            leftBorderOpaque: left,
            rightBorderOpaque: right,
            centerBandAlpha: centerAlpha,
            opaqueFraction: Double(opaque) / Double(area),
            holeFractionInsideBounds: holeFraction
        )
    }

    /// Removes a flat corner color when the model did not return transparency.
    /// A real transparent image is left alone. The key is the corner color, not a fixed green.
    static func keyedIfNeeded(_ image: CGImage) -> (image: CGImage, usedKey: Bool) {
        guard let source = rgba(from: image) else { return (image, false) }
        let width = source.width
        let height = source.height
        let pixels = source.bytes
        let sample = min(8, width, height)
        guard sample > 0 else { return (image, false) }
        var reds: [Double] = []
        var greens: [Double] = []
        var blues: [Double] = []
        var alphaTotal = 0.0
        var cornerCount = 0
        let origins = [(0, 0), (width - sample, 0), (0, height - sample), (width - sample, height - sample)]
        for origin in origins {
            for row in origin.1..<(origin.1 + sample) {
                for column in origin.0..<(origin.0 + sample) {
                    let index = (row * width + column) * 4
                    let alpha = Double(pixels[index + 3]) / 255
                    alphaTotal += alpha
                    cornerCount += 1
                    guard alpha > 0.9 else { continue }
                    reds.append(Double(pixels[index]) / alpha)
                    greens.append(Double(pixels[index + 1]) / alpha)
                    blues.append(Double(pixels[index + 2]) / alpha)
                }
            }
        }
        guard cornerCount > 0, reds.count > 20 else { return (image, false) }
        let meanAlpha = alphaTotal / Double(cornerCount)
        let key = (average(reds), average(greens), average(blues))
        var spread = 0.0
        for index in reds.indices {
            spread = max(spread, hypot3(reds[index] - key.0, greens[index] - key.1, blues[index] - key.2))
        }
        guard meanAlpha > 0.85, spread < 40 else { return (image, false) }
        var output = pixels
        for index in stride(from: 0, to: output.count, by: 4) {
            let alpha = Double(output[index + 3])
            guard alpha > 0 else { continue }
            let red = Double(output[index]) / alpha * 255
            let green = Double(output[index + 1]) / alpha * 255
            let blue = Double(output[index + 2]) / alpha * 255
            let distance = hypot3(red - key.0, green - key.1, blue - key.2)
            let coverage: Double
            if distance < 40 {
                coverage = 0
            } else if distance > 90 {
                coverage = alpha / 255
            } else {
                coverage = (distance - 40) / 50 * (alpha / 255)
            }
            output[index] = UInt8(min(max(red * coverage, 0), 255))
            output[index + 1] = UInt8(min(max(green * coverage, 0), 255))
            output[index + 2] = UInt8(min(max(blue * coverage, 0), 255))
            output[index + 3] = UInt8(min(max(coverage * 255, 0), 255))
        }
        guard let keyed = cgImage(width: width, height: height, bytes: output) else { return (image, false) }
        return (keyed, true)
    }

    static func rgba(from image: CGImage) -> (width: Int, height: Int, bytes: [UInt8])? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drew = bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        return drew ? (width, height, bytes) : nil
    }

    static func cgImage(width: Int, height: Int, bytes: [UInt8]) -> CGImage? {
        let data = Data(bytes)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        )
    }

    static func mask(from image: CGImage) -> CGImage? {
        guard let source = rgba(from: image) else { return nil }
        var bytes = source.bytes
        for index in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = bytes[index + 3]
            bytes[index] = alpha
            bytes[index + 1] = alpha
            bytes[index + 2] = alpha
            bytes[index + 3] = 255
        }
        return cgImage(width: source.width, height: source.height, bytes: bytes)
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func hypot3(_ a: Double, _ b: Double, _ c: Double) -> Double {
        (a * a + b * b + c * c).squareRoot()
    }
}
