import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import UIKit
import Vision

/// Converts raw garment photos into avatar-style 3D-ready cutouts,
/// isolating specific garments (tops, pants, skirts, etc.) and extracting colors & designs.
enum GarmentStylizer {
    struct StylizedResult {
        let image: UIImage
        let photoCutout: UIImage?
        let pngData: Data
        let dominantColor: UIColor
        let accentColor: UIColor?
        let graphicEmblem: UIImage?
        let detectedPreset: GarmentPreset
        let isAvatarStyle: Bool
    }

    /// Converts raw image data into an isolated avatar-style piece for a specific category or preset.
    static func convert(_ imageData: Data, preferredCategory: ClothingCategory? = nil, presetHint: GarmentPreset? = nil) async -> StylizedResult {
        guard let sourceImage = UIImage(data: imageData) else {
            let fallback = UIImage(systemName: "tshirt") ?? UIImage()
            let data = fallback.pngData() ?? imageData
            return StylizedResult(
                image: fallback,
                photoCutout: nil,
                pngData: data,
                dominantColor: UIColor(red: 0.35, green: 0.55, blue: 0.85, alpha: 1),
                accentColor: nil,
                graphicEmblem: nil,
                detectedPreset: .tShirt,
                isAvatarStyle: false
            )
        }

        // 1. Identify preset & category
        let category = preferredCategory ?? presetHint?.category ?? .tops
        let preset = presetHint ?? GarmentPreset.detect(name: "", category: category)

        // 2. Isolate the specific garment region from the photo
        let isolatedImage = await isolateGarment(from: sourceImage, category: category)

        // 3. Remove background via Vision instance mask or background keying
        let cutout = await removeBackground(from: isolatedImage) ?? isolatedImage

        // 4. Avatar stylization (clean crop, vibrancy boost)
        let trimmed = cropToNonTransparentBounds(cutout) ?? cutout
        let stylized = applyAvatarVibrancy(to: trimmed)

        // 5. Extract colors & central graphic design
        let dominantColor = GarmentColorExtractor.dominantColor(from: stylized)
        let (accentColor, graphic) = extractGraphicAndAccent(from: stylized, dominantColor: dominantColor)

        // 6. Fill the preset with the extracted colors and design!
        let filledPresetImage = PresetGarmentRenderer.render(
            preset: preset,
            dominantColor: dominantColor,
            accentColor: accentColor,
            graphicEmblem: graphic
        )
        let pngData = filledPresetImage.pngData() ?? (stylized.pngData() ?? imageData)

        return StylizedResult(
            image: filledPresetImage,
            photoCutout: stylized,
            pngData: pngData,
            dominantColor: dominantColor,
            accentColor: accentColor,
            graphicEmblem: graphic,
            detectedPreset: preset,
            isAvatarStyle: true
        )
    }

    // MARK: - Garment Isolation by Category (Body Pose / Region Cropping)

    private static func isolateGarment(from source: UIImage, category: ClothingCategory) async -> UIImage {
        guard let cgImage = source.cgImage else { return source }

        // Attempt human body pose detection to isolate the exact body section
        if let poseCrop = await cropByBodyPose(cgImage: cgImage, category: category, orientation: source.imageOrientation) {
            return poseCrop
        }

        // If no human pose found (flat-lay on bed/table or hanger), crop by saliency & category heuristic
        return cropBySaliencyOrCenter(source: source, category: category)
    }

    private static func cropByBodyPose(cgImage: CGImage, category: ClothingCategory, orientation: UIImage.Orientation) async -> UIImage? {
        await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: cropByBodyPoseSync(cgImage: cgImage, category: category,
                                                                   orientation: orientation))
            }
        }
    }

    private static func cropByBodyPoseSync(cgImage: CGImage, category: ClothingCategory,
                                           orientation: UIImage.Orientation) -> UIImage? {
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(orientation), options: [:])

        do {
            try handler.perform([request])
            guard let observation = request.results?.first else {
                return nil
            }

            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)

            // Helper to get normalized point in image coordinates (Vision coordinates have (0,0) at bottom-left)
            func point(for joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let p = try? observation.recognizedPoint(joint), p.confidence > 0.15 else { return nil }
                return CGPoint(x: p.location.x * imageWidth, y: (1.0 - p.location.y) * imageHeight)
            }

            var cropRect: CGRect?

            switch category {
            case .tops, .outerwear:
                // Torso: from collar/neck down to hips
                let neck = point(for: .neck) ?? point(for: .nose)
                let leftShoulder = point(for: .leftShoulder)
                let rightShoulder = point(for: .rightShoulder)
                let leftHip = point(for: .leftHip)
                let rightHip = point(for: .rightHip)
                let leftWrist = point(for: .leftWrist)
                let rightWrist = point(for: .rightWrist)

                let allPoints = [neck, leftShoulder, rightShoulder, leftHip, rightHip, leftWrist, rightWrist].compactMap { $0 }
                if allPoints.count >= 2 {
                    let minX = max((allPoints.map(\.x).min() ?? 0) - imageWidth * 0.05, 0)
                    let maxX = min((allPoints.map(\.x).max() ?? imageWidth) + imageWidth * 0.05, imageWidth)
                    let pointYs = allPoints.map(\.y)
                    let shoulderY: CGFloat = leftShoulder?.y ?? neck?.y ?? pointYs.min() ?? 0
                    let hipY: CGFloat = leftHip?.y ?? rightHip?.y ?? pointYs.max() ?? imageHeight
                    let topY = max(shoulderY - imageHeight * 0.04, 0)
                    let bottomY = min(hipY + imageHeight * 0.06, imageHeight)

                    cropRect = CGRect(x: minX, y: topY, width: maxX - minX, height: bottomY - topY)
                }

            case .pants:
                // Lower body: from waist/hips down to ankles
                let leftHip = point(for: .leftHip)
                let rightHip = point(for: .rightHip)
                let leftKnee = point(for: .leftKnee)
                let rightKnee = point(for: .rightKnee)
                let leftAnkle = point(for: .leftAnkle)
                let rightAnkle = point(for: .rightAnkle)

                let allPoints = [leftHip, rightHip, leftKnee, rightKnee, leftAnkle, rightAnkle].compactMap { $0 }
                if allPoints.count >= 2 {
                    let minX = max((allPoints.map(\.x).min() ?? 0) - imageWidth * 0.06, 0)
                    let maxX = min((allPoints.map(\.x).max() ?? imageWidth) + imageWidth * 0.06, imageWidth)
                    let pointYs = allPoints.map(\.y)
                    let hipY: CGFloat = leftHip?.y ?? rightHip?.y ?? pointYs.min() ?? 0
                    let ankleY: CGFloat = leftAnkle?.y ?? rightAnkle?.y ?? pointYs.max() ?? imageHeight
                    let topY = max(hipY - imageHeight * 0.03, 0)
                    let bottomY = min(ankleY + imageHeight * 0.04, imageHeight)

                    cropRect = CGRect(x: minX, y: topY, width: maxX - minX, height: bottomY - topY)
                }

            case .skirts:
                let leftHip = point(for: .leftHip)
                let rightHip = point(for: .rightHip)
                let leftKnee = point(for: .leftKnee)
                let rightKnee = point(for: .rightKnee)

                let allPoints = [leftHip, rightHip, leftKnee, rightKnee].compactMap { $0 }
                if allPoints.count >= 2 {
                    let minX = max((allPoints.map(\.x).min() ?? 0) - imageWidth * 0.08, 0)
                    let maxX = min((allPoints.map(\.x).max() ?? imageWidth) + imageWidth * 0.08, imageWidth)
                    let topY = max((leftHip?.y ?? rightHip?.y ?? 0) - imageHeight * 0.03, 0)
                    let bottomY = min((leftKnee?.y ?? rightKnee?.y ?? imageHeight) + imageHeight * 0.06, imageHeight)

                    cropRect = CGRect(x: minX, y: topY, width: maxX - minX, height: bottomY - topY)
                }

            case .shoes:
                let leftAnkle = point(for: .leftAnkle)
                let rightAnkle = point(for: .rightAnkle)
                let ankles = [leftAnkle, rightAnkle].compactMap { $0 }
                if !ankles.isEmpty {
                    let minX = max((ankles.map(\.x).min() ?? 0) - imageWidth * 0.12, 0)
                    let maxX = min((ankles.map(\.x).max() ?? imageWidth) + imageWidth * 0.12, imageWidth)
                    let topY = max((ankles.map(\.y).min() ?? 0) - imageHeight * 0.02, 0)
                    cropRect = CGRect(x: minX, y: topY, width: maxX - minX, height: imageHeight - topY)
                }

            case .dresses:
                let leftShoulder = point(for: .leftShoulder)
                let rightShoulder = point(for: .rightShoulder)
                let leftKnee = point(for: .leftKnee)
                let rightKnee = point(for: .rightKnee)
                let points = [leftShoulder, rightShoulder, leftKnee, rightKnee].compactMap { $0 }
                if points.count >= 2 {
                    let minX = max((points.map(\.x).min() ?? 0) - imageWidth * 0.06, 0)
                    let maxX = min((points.map(\.x).max() ?? imageWidth) + imageWidth * 0.06, imageWidth)
                    let topY = max((points.map(\.y).min() ?? 0) - imageHeight * 0.03, 0)
                    let bottomY = min((points.map(\.y).max() ?? imageHeight) + imageHeight * 0.06, imageHeight)
                    cropRect = CGRect(x: minX, y: topY, width: maxX - minX, height: bottomY - topY)
                }

            case .accessories, .other:
                break
            }

            guard let rect = cropRect, rect.width > 20, rect.height > 20,
                  let croppedCG = cgImage.cropping(to: rect) else {
                return nil
            }

            return UIImage(cgImage: croppedCG, scale: 1.0, orientation: .up)
        } catch {
            return nil
        }
    }

    private static func cropBySaliencyOrCenter(source: UIImage, category: ClothingCategory) -> UIImage {
        // If it's a flat shot of multiple items (e.g. top + pants lay), crop to the relevant half
        guard let cgImage = source.cgImage else { return source }
        let w = CGFloat(cgImage.width)
        let h = CGFloat(cgImage.height)

        let rect: CGRect
        switch category {
        case .tops, .outerwear:
            rect = CGRect(x: 0, y: 0, width: w, height: h * 0.65)
        case .pants, .skirts:
            rect = CGRect(x: 0, y: h * 0.35, width: w, height: h * 0.65)
        case .shoes:
            rect = CGRect(x: 0, y: h * 0.60, width: w, height: h * 0.40)
        default:
            return source
        }

        if let cropped = cgImage.cropping(to: rect) {
            return UIImage(cgImage: cropped, scale: source.scale, orientation: .up)
        }
        return source
    }

    // MARK: - Background Removal (Vision Instance Mask & Thresholding)

    private static func removeBackground(from source: UIImage) async -> UIImage? {
        guard let cgImage = source.cgImage else { return source }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNGenerateForegroundInstanceMaskRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                do {
                    try handler.perform([request])
                    guard let result = request.results?.first else {
                        // Fallback: color-key the background corners
                        let keyed = removeBackgroundColor(from: source)
                        continuation.resume(returning: keyed)
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
                        continuation.resume(returning: removeBackgroundColor(from: source))
                        return
                    }

                    let context = CIContext(options: [.useSoftwareRenderer: false])
                    guard let outputCG = context.createCGImage(output, from: output.extent) else {
                        continuation.resume(returning: removeBackgroundColor(from: source))
                        return
                    }

                    continuation.resume(returning: UIImage(cgImage: outputCG, scale: 1.0, orientation: .up))
                } catch {
                    continuation.resume(returning: removeBackgroundColor(from: source))
                }
            }
        }
    }

    /// Color-keys out uniform backgrounds (bedsheets, floors, tables) based on edge pixels
    private static func removeBackgroundColor(from image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        guard width > 4, height > 4 else { return image }

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

        // Sample corner pixels to estimate background color
        let corners = [0, (width - 1) * 4, (height - 1) * width * 4, ((height - 1) * width + width - 1) * 4]
        var bgR: Double = 0
        var bgG: Double = 0
        var bgB: Double = 0
        for corner in corners {
            bgR += Double(rawData[corner])
            bgG += Double(rawData[corner + 1])
            bgB += Double(rawData[corner + 2])
        }
        bgR /= 4.0; bgG /= 4.0; bgB /= 4.0

        let threshold: Double = 35.0

        // Zero out pixels within threshold of background color
        for i in stride(from: 0, to: rawData.count, by: 4) {
            let r = Double(rawData[i])
            let g = Double(rawData[i + 1])
            let b = Double(rawData[i + 2])
            let diff = abs(r - bgR) + abs(g - bgG) + abs(b - bgB)
            if diff < threshold * 3.0 {
                rawData[i + 3] = 0 // Transparent
            }
        }

        guard let outputCG = context.makeImage() else { return image }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    // MARK: - Extract Central Graphic & Accent Color

    private static func extractGraphicAndAccent(from image: UIImage, dominantColor: UIColor) -> (UIColor?, UIImage?) {
        guard let cgImage = image.cgImage else { return (nil, nil) }
        let w = cgImage.width
        let h = cgImage.height
        guard w > 20, h > 20 else { return (nil, nil) }

        // Center 45% x 35% bounding box where chest graphics / logos sit
        let graphicRect = CGRect(
            x: CGFloat(w) * 0.28,
            y: CGFloat(h) * 0.25,
            width: CGFloat(w) * 0.44,
            height: CGFloat(h) * 0.35
        )

        guard let cropped = cgImage.cropping(to: graphicRect) else { return (nil, nil) }
        let graphicImage = UIImage(cgImage: cropped, scale: 1.0, orientation: .up)

        // Find accent color inside the graphic patch that contrasts with the dominant fabric color
        let accent = findContrastingAccentColor(in: graphicImage, against: dominantColor)
        return (accent, graphicImage)
    }

    private static func findContrastingAccentColor(in image: UIImage, against dominant: UIColor) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }
        let w = 16
        let h = 16
        var rawData = [UInt8](repeating: 0, count: w * h * 4)

        guard let context = CGContext(
            data: &rawData,
            width: w,
            height: h,
            bitsPerComponent: 8,
            bytesPerRow: w * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))

        var domR: CGFloat = 0, domG: CGFloat = 0, domB: CGFloat = 0, domA: CGFloat = 0
        dominant.getRed(&domR, green: &domG, blue: &domB, alpha: &domA)

        var bestDiff: Double = 0
        var bestColor: UIColor?

        for i in stride(from: 0, to: rawData.count, by: 4) {
            let a = Double(rawData[i + 3]) / 255.0
            guard a > 0.5 else { continue }
            let r = Double(rawData[i]) / 255.0
            let g = Double(rawData[i + 1]) / 255.0
            let b = Double(rawData[i + 2]) / 255.0

            let diff = abs(r - Double(domR)) + abs(g - Double(domG)) + abs(b - Double(domB))
            if diff > bestDiff && diff > 0.45 {
                bestDiff = diff
                bestColor = UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: 1.0)
            }
        }

        return bestColor
    }

    // MARK: - Avatar Vibrancy & Edge Enhancement

    private static func applyAvatarVibrancy(to image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cgImage)

        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(ciImage, forKey: kCIInputImageKey)
        controls?.setValue(1.18, forKey: kCIInputSaturationKey)
        controls?.setValue(1.06, forKey: kCIInputContrastKey)

        guard let output = controls?.outputImage else { return image }
        let context = CIContext(options: nil)
        guard let outputCG = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: outputCG, scale: image.scale, orientation: .up)
    }

    // MARK: - Trim Transparent Bounds

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
                if alpha > 25 {
                    hasPixels = true
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        guard hasPixels, minX < maxX, minY < maxY else { return image }

        let padX = max(Int(Double(maxX - minX) * 0.05), 4)
        let padY = max(Int(Double(maxY - minY) * 0.05), 4)

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
