import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit
import Vision

/// Converts raw garment photos into avatar-style 3D-ready cutouts.
enum GarmentStylizer {
    struct StylizedResult {
        let image: UIImage
        let pngData: Data
        let dominantColor: UIColor
        let isAvatarStyle: Bool
    }

    /// Converts raw image data into an avatar-style piece with background removed.
    static func convert(_ imageData: Data) async -> StylizedResult {
        guard let sourceImage = UIImage(data: imageData) else {
            let fallback = UIImage(systemName: "tshirt") ?? UIImage()
            let data = fallback.pngData() ?? imageData
            return StylizedResult(
                image: fallback,
                pngData: data,
                dominantColor: UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1),
                isAvatarStyle: false
            )
        }

        // Try Vision subject lifting (background removal)
        var cutoutImage: UIImage?
        if let cgImage = sourceImage.cgImage {
            cutoutImage = await removeBackground(from: cgImage, orientation: sourceImage.imageOrientation)
        }

        let base = cutoutImage ?? sourceImage
        let stylized = applyAvatarStyle(to: base)
        let trimmed = cropToNonTransparentBounds(stylized) ?? stylized

        let dominantColor = GarmentColorExtractor.dominantColor(from: trimmed)
        let pngData = trimmed.pngData() ?? imageData

        return StylizedResult(
            image: trimmed,
            pngData: pngData,
            dominantColor: dominantColor,
            isAvatarStyle: cutoutImage != nil
        )
    }

    // MARK: - Vision foreground instance mask (Subject lifting)

    private static func removeBackground(from cgImage: CGImage, orientation: UIImage.Orientation) async -> UIImage? {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(orientation), options: [:])

                do {
                    try handler.perform([request])
                    guard let result = request.results?.first else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)

                    let ciOriginal = CIImage(cgImage: cgImage)
                    let ciMask = CIImage(cvPixelBuffer: maskPixelBuffer)

                    let filter = CIFilter(name: "CIBlendWithMask")
                    filter?.setValue(ciOriginal, forKey: kCIInputImageKey)
                    filter?.setValue(ciMask, forKey: kCIInputMaskImageKey)
                    filter?.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)

                    guard let output = filter?.outputImage else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let context = CIContext(options: [.useSoftwareRenderer: false])
                    guard let outputCG = context.createCGImage(output, from: output.extent) else {
                        continuation.resume(returning: nil)
                        return
                    }

                    let cutout = UIImage(cgImage: outputCG, scale: 1.0, orientation: .up)
                    continuation.resume(returning: cutout)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Avatar-style color & vibrancy enhancement

    private static func applyAvatarStyle(to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)

        // Boost saturation and contrast slightly for a crisp animated/avatar look
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(ciImage, forKey: kCIInputImageKey)
        controls?.setValue(1.18, forKey: kCIInputSaturationKey)
        controls?.setValue(1.06, forKey: kCIInputContrastKey)
        controls?.setValue(0.02, forKey: kCIInputBrightnessKey)

        guard let output = controls?.outputImage else { return image }
        let context = CIContext(options: nil)
        guard let outputCG = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    // MARK: - Trim transparent margins

    private static func cropToNonTransparentBounds(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height

        guard width > 0, height > 0 else { return image }

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
        ) else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var maxX = 0
        var minY = height
        var maxY = 0
        var hasPixels = false

        for y in 0..<height {
            for x in 0..<width {
                let alpha = rawData[(y * width + x) * 4 + 3]
                if alpha > 20 {
                    hasPixels = true
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard hasPixels, minX < maxX, minY < maxY else { return image }

        // Add 6% padding around the bounding box
        let padX = max(Int(Double(maxX - minX) * 0.06), 4)
        let padY = max(Int(Double(maxY - minY) * 0.06), 4)

        let cropMinX = max(minX - padX, 0)
        let cropMinY = max(minY - padY, 0)
        let cropMaxX = min(maxX + padX, width)
        let cropMaxY = min(maxY + padY, height)

        let cropRect = CGRect(
            x: cropMinX,
            y: cropMinY,
            width: cropMaxX - cropMinX,
            height: cropMaxY - cropMinY
        )

        guard let croppedCG = cgImage.cropping(to: cropRect) else { return image }
        return UIImage(cgImage: croppedCG, scale: image.scale, orientation: .up)
    }
}

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
