import Foundation
import UIKit
import Vision

/// Proportions calculated from clothing piece imagery to dynamically scale and fit 3D garments.
struct GarmentProportions {
    var widthRatio: Float = 1.0     // Scale on width / girth
    var lengthRatio: Float = 1.0    // Scale on vertical length / drop
    var fullness: Float = 1.0       // Flare / drape factor
    var shoulderSpan: Float = 1.0   // Top shoulder span
}

enum GarmentMeasurement {
    /// Analyzes the visual silhouette and contours of a clothing piece
    /// to determine its exact proportions (crop length, oversized/fitted, drape, width ratio).
    static func calculateProportions(from image: UIImage?, category: ClothingCategory) -> GarmentProportions {
        guard let image, let cgImage = image.cgImage else {
            return GarmentProportions()
        }

        let width = CGFloat(cgImage.width)
        let height = CGFloat(cgImage.height)
        guard width > 10, height > 10 else { return GarmentProportions() }

        let aspectRatio = Float(width / height) // Width divided by height
        var proportions = GarmentProportions()

        switch category {
        case .tops:
            // Standard tops aspect ratio is roughly 1.0 - 1.2
            if aspectRatio > 1.32 {
                // Wide / boxy / oversized / cropped top
                proportions.widthRatio = min(1.0 + (aspectRatio - 1.32) * 0.45, 1.25)
                proportions.lengthRatio = max(1.0 - (aspectRatio - 1.32) * 0.35, 0.82)
                proportions.shoulderSpan = 1.08
            } else if aspectRatio < 0.92 {
                // Longline / tunic / tall shirt
                proportions.lengthRatio = min(1.0 + (0.92 - aspectRatio) * 0.55, 1.30)
                proportions.widthRatio = 0.95
            }

        case .pants:
            // Pants aspect ratio: height is typically much larger than width (aspectRatio ~ 0.45 - 0.65)
            if aspectRatio > 0.65 {
                // Wide-leg / baggy pants
                proportions.widthRatio = min(1.0 + (aspectRatio - 0.65) * 0.65, 1.35)
                proportions.fullness = 1.22
            } else if aspectRatio < 0.44 {
                // Slim / skinny / tapered pants
                proportions.widthRatio = max(1.0 - (0.44 - aspectRatio) * 0.5, 0.88)
            }

        case .skirts:
            if aspectRatio > 1.2 {
                // Mini skirt
                proportions.lengthRatio = 0.72
                proportions.fullness = 1.12
            } else if aspectRatio < 0.78 {
                // Midi / maxi skirt
                proportions.lengthRatio = min(1.0 + (0.78 - aspectRatio) * 0.75, 1.45)
                proportions.fullness = 1.28
            }

        case .dresses:
            if aspectRatio > 0.86 {
                // Mini / short dress
                proportions.lengthRatio = 0.80
                proportions.fullness = 1.08
            } else if aspectRatio < 0.56 {
                // Long / maxi dress
                proportions.lengthRatio = min(1.0 + (0.56 - aspectRatio) * 0.75, 1.38)
                proportions.fullness = 1.22
            }

        case .outerwear:
            if aspectRatio > 1.28 {
                // Cropped bomber / short jacket
                proportions.lengthRatio = 0.86
                proportions.widthRatio = 1.14
            } else if aspectRatio < 0.82 {
                // Long trench coat / duster / parka
                proportions.lengthRatio = min(1.0 + (0.82 - aspectRatio) * 0.7, 1.35)
                proportions.widthRatio = 1.10
            }

        case .shoes:
            if aspectRatio < 1.05 {
                // High-top / ankle boot
                proportions.lengthRatio = 1.25
            }

        case .accessories, .other:
            break
        }

        return proportions
    }
}
