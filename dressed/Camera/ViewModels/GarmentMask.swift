import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

// A one-channel mask over a whole photo (255 = this garment), and the transparent cutout made from it.
// Shared by the app and the Mac tools in backend/recognition, so keep it free of app services.
nonisolated struct GarmentMask {
    let width: Int
    let height: Int
    var pixels: [UInt8]

    /// Bounds of the covered pixels in normalized, top-left coordinates.
    func region(padding: Double = 0) -> NormalizedImageRegion? {
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where pixels[y * width + x] != 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let left = max(0, Double(minX) / Double(width) - padding)
        let top = max(0, Double(minY) / Double(height) - padding)
        let right = min(1, Double(maxX + 1) / Double(width) + padding)
        let bottom = min(1, Double(maxY + 1) / Double(height) + padding)
        let result = NormalizedImageRegion(x: left, y: top, width: right - left, height: bottom - top)
        return result.isValid ? result : nil
    }

    var pngData: Data? {
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 8,
                                  bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent) else { return nil }
        return GarmentImage.png(image)
    }

    init(width: Int, height: Int, pixels: [UInt8]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    init?(pngData: Data) {
        guard let source = CGImageSourceCreateWithData(pngData as CFData, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width <= 2048, image.height <= 2048 else { return nil }
        var pixels = [UInt8](repeating: 0, count: image.width * image.height)
        let drew = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width,
                                          space: CGColorSpaceCreateDeviceGray(),
                                          bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        guard drew else { return nil }
        self.init(width: image.width, height: image.height, pixels: pixels)
    }
}

nonisolated enum GarmentImage {
    /// Decodes with the photo's orientation applied, no larger than `maximumSide`.
    static func upright(_ data: Data, maximumSide: Int = 2048) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumSide,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    static func png(_ image: CGImage) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }

    /// A transparent PNG of the masked garment, cropped to the piece, with a slightly soft edge.
    static func cutout(of image: CGImage, mask: GarmentMask, maximumSide: Int = 1024) -> Data? {
        guard let region = mask.region(padding: 0.005) else { return nil }
        let crop = CGRect(x: region.x * Double(image.width), y: region.y * Double(image.height),
                          width: region.width * Double(image.width),
                          height: region.height * Double(image.height)).integral
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard crop.width >= 2, crop.height >= 2, let cropped = image.cropping(to: crop) else { return nil }
        let scale = min(1, Double(maximumSide) / Double(max(cropped.width, cropped.height)))
        let width = max(2, Int(Double(cropped.width) * scale))
        let height = max(2, Int(Double(cropped.height) * scale))

        // Sample the mask smoothly at the cutout's resolution.
        var alpha = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            let sourceY = (Double(crop.minY) + (Double(y) + 0.5) / Double(height) * Double(crop.height))
                / Double(image.height) * Double(mask.height) - 0.5
            let y0 = min(mask.height - 1, max(0, Int(sourceY.rounded(.down))))
            let y1 = min(mask.height - 1, y0 + 1)
            let fy = min(1, max(0, sourceY - Double(y0)))
            for x in 0..<width {
                let sourceX = (Double(crop.minX) + (Double(x) + 0.5) / Double(width) * Double(crop.width))
                    / Double(image.width) * Double(mask.width) - 0.5
                let x0 = min(mask.width - 1, max(0, Int(sourceX.rounded(.down))))
                let x1 = min(mask.width - 1, x0 + 1)
                let fx = min(1, max(0, sourceX - Double(x0)))
                let upper = Double(mask.pixels[y0 * mask.width + x0]) * (1 - fx)
                    + Double(mask.pixels[y0 * mask.width + x1]) * fx
                let lower = Double(mask.pixels[y1 * mask.width + x0]) * (1 - fx)
                    + Double(mask.pixels[y1 * mask.width + x1]) * fx
                // Narrow the ramp to about 1-2 output pixels so the edge is soft, not hazy.
                let value = (upper * (1 - fy) + lower * fy) / 255
                let sharpness = max(1, Double(width) / (region.width * Double(mask.width)) / 1.5)
                alpha[y * width + x] = UInt8(min(1, max(0, (value - 0.5) * sharpness + 0.5)) * 255)
            }
        }

        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        let result = rgba.withUnsafeMutableBytes { bytes -> CGImage? in
            guard let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                          bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: space, bitmapInfo: info) else { return nil }
            context.interpolationQuality = .high
            context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
            let pixels = bytes.bindMemory(to: UInt8.self)
            for index in 0..<(width * height) {
                let a = Int(alpha[index])
                for channel in 0..<3 {
                    pixels[index * 4 + channel] = UInt8(Int(pixels[index * 4 + channel]) * a / 255)
                }
                pixels[index * 4 + 3] = UInt8(a)
            }
            return context.makeImage()
        }
        return result.flatMap(png)
    }
}
