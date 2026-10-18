import UIKit

enum GarmentColorExtractor {
    /// Extracts the dominant color from non-transparent pixels of a clothing cutout.
    static func dominantColor(from image: UIImage?) -> UIColor {
        guard let image, let cgImage = image.cgImage else {
            return UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1)
        }

        let width = 24
        let height = 24
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var rawData = [UInt8](repeating: 0, count: width * height * 4)

        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1)
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var totalR: Double = 0
        var totalG: Double = 0
        var totalB: Double = 0
        var count: Double = 0

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let alpha = Double(rawData[index + 3]) / 255.0
                if alpha > 0.35 {
                    let r = Double(rawData[index]) / 255.0
                    let g = Double(rawData[index + 1]) / 255.0
                    let b = Double(rawData[index + 2]) / 255.0

                    // Weight saturated pixels slightly higher so vivid colors show accurately
                    let maxC = max(r, max(g, b))
                    let minC = min(r, min(g, b))
                    let satWeight = 1.0 + (maxC - minC)

                    let weight = alpha * satWeight
                    totalR += r * weight
                    totalG += g * weight
                    totalB += b * weight
                    count += weight
                }
            }
        }

        guard count > 0 else {
            return UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1)
        }

        return UIColor(
            red: CGFloat(min(max(totalR / count, 0), 1)),
            green: CGFloat(min(max(totalG / count, 0), 1)),
            blue: CGFloat(min(max(totalB / count, 0), 1)),
            alpha: 1.0
        )
    }
}
