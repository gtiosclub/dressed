import CoreGraphics
import Foundation
import UIKit

/// Generates replicable, animated avatar-style 2D clothing pieces from a preset,
/// filled with the colors, trims, and graphic designs extracted from a user's photo.
enum PresetGarmentRenderer {

    /// Renders a crisp 512x512 transparent PNG avatar-style garment for the given preset.
    static func render(
        preset: GarmentPreset,
        dominantColor: UIColor,
        accentColor: UIColor? = nil,
        graphicEmblem: UIImage? = nil,
        size: CGSize = CGSize(width: 512, height: 512)
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let cg = ctx.cgContext
            cg.setAllowsAntialiasing(true)
            cg.setShouldAntialias(true)

            let w = size.width
            let h = size.height

            // Calculate contrasting accent color if not provided
            let resolvedAccent = accentColor ?? contrastingAccent(for: dominantColor)

            // Draw shadow under garment
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 10), blur: 16, color: UIColor.black.withAlphaComponent(0.18).cgColor)

            // Draw preset base shape
            drawPresetBase(preset: preset, dominantColor: dominantColor, accentColor: resolvedAccent, in: cg, width: w, height: h)
            cg.restoreGState()

            // Draw preset details, seams, cuffs, and trim
            drawPresetDetails(preset: preset, dominantColor: dominantColor, accentColor: resolvedAccent, in: cg, width: w, height: h)

            // Overlay the extracted graphic emblem/print if available
            if let graphic = graphicEmblem {
                drawGraphicEmblem(graphic, preset: preset, in: cg, width: w, height: h)
            }
        }
    }

    // MARK: - Preset Base Shapes

    private static func drawPresetBase(
        preset: GarmentPreset,
        dominantColor: UIColor,
        accentColor: UIColor,
        in cg: CGContext,
        width w: CGFloat,
        height h: CGFloat
    ) {
        let path = UIBezierPath()

        switch preset {
        case .tShirt:
            // Crewneck short sleeve t-shirt
            path.move(to: CGPoint(x: w * 0.34, y: h * 0.16))
            path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.16), controlPoint: CGPoint(x: w * 0.50, y: h * 0.23))
            path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.22)) // right shoulder
            path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.40)) // right sleeve outer
            path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.46)) // right sleeve cuff
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.38)) // right armpit
            path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.86)) // right waist to hem
            path.addQuadCurve(to: CGPoint(x: w * 0.27, y: h * 0.86), controlPoint: CGPoint(x: w * 0.50, y: h * 0.89)) // bottom hem
            path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.38)) // left waist to armpit
            path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.46)) // left sleeve cuff
            path.addLine(to: CGPoint(x: w * 0.06, y: h * 0.40)) // left sleeve outer
            path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.22)) // left shoulder
            path.close()

        case .hoodie:
            // Relaxed fit hoodie with long sleeves
            path.move(to: CGPoint(x: w * 0.32, y: h * 0.17))
            path.addQuadCurve(to: CGPoint(x: w * 0.68, y: h * 0.17), controlPoint: CGPoint(x: w * 0.50, y: h * 0.25))
            path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.24))
            path.addLine(to: CGPoint(x: w * 0.96, y: h * 0.70)) // long sleeve right
            path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.73))
            path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.42))
            path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.88))
            path.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.88), controlPoint: CGPoint(x: w * 0.50, y: h * 0.90))
            path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.42))
            path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.73))
            path.addLine(to: CGPoint(x: w * 0.04, y: h * 0.70)) // long sleeve left
            path.addLine(to: CGPoint(x: w * 0.14, y: h * 0.24))
            path.close()

        case .sweater, .sweatshirt:
            // Knitted sweater / crewneck sweatshirt with long sleeves
            path.move(to: CGPoint(x: w * 0.33, y: h * 0.16))
            path.addQuadCurve(to: CGPoint(x: w * 0.67, y: h * 0.16), controlPoint: CGPoint(x: w * 0.50, y: h * 0.23))
            path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.23))
            path.addLine(to: CGPoint(x: w * 0.95, y: h * 0.68))
            path.addLine(to: CGPoint(x: w * 0.83, y: h * 0.71))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.40))
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.86))
            path.addQuadCurve(to: CGPoint(x: w * 0.26, y: h * 0.86), controlPoint: CGPoint(x: w * 0.50, y: h * 0.88))
            path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.40))
            path.addLine(to: CGPoint(x: w * 0.17, y: h * 0.71))
            path.addLine(to: CGPoint(x: w * 0.05, y: h * 0.68))
            path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.23))
            path.close()

        case .jersey:
            // Athletic jersey with wide arm openings and V-neck
            path.move(to: CGPoint(x: w * 0.35, y: h * 0.14))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.26)) // V-neck
            path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.14))
            path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.20))
            path.addLine(to: CGPoint(x: w * 0.90, y: h * 0.36))
            path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.40))
            path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.34))
            path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.88))
            path.addLine(to: CGPoint(x: w * 0.27, y: h * 0.88))
            path.addLine(to: CGPoint(x: w * 0.27, y: h * 0.34))
            path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.40))
            path.addLine(to: CGPoint(x: w * 0.10, y: h * 0.36))
            path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.20))
            path.close()

        case .tankTop:
            // Sleeveless tank top with bare shoulders and scoop neck
            path.move(to: CGPoint(x: w * 0.36, y: h * 0.15))
            path.addQuadCurve(to: CGPoint(x: w * 0.64, y: h * 0.15), controlPoint: CGPoint(x: w * 0.50, y: h * 0.29)) // deep scoop
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.16)) // right strap
            path.addQuadCurve(to: CGPoint(x: w * 0.72, y: h * 0.44), controlPoint: CGPoint(x: w * 0.67, y: h * 0.28)) // armhole curve
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.86))
            path.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.86), controlPoint: CGPoint(x: w * 0.50, y: h * 0.88))
            path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.44))
            path.addQuadCurve(to: CGPoint(x: w * 0.28, y: h * 0.16), controlPoint: CGPoint(x: w * 0.33, y: h * 0.28))
            path.close()

        case .blouse:
            // Flowy elegant blouse with gathered waist
            path.move(to: CGPoint(x: w * 0.33, y: h * 0.15))
            path.addQuadCurve(to: CGPoint(x: w * 0.67, y: h * 0.15), controlPoint: CGPoint(x: w * 0.50, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.94, y: h * 0.55))
            path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.57))
            path.addLine(to: CGPoint(x: w * 0.76, y: h * 0.40))
            path.addQuadCurve(to: CGPoint(x: w * 0.75, y: h * 0.86), controlPoint: CGPoint(x: w * 0.79, y: h * 0.65))
            path.addQuadCurve(to: CGPoint(x: w * 0.25, y: h * 0.86), controlPoint: CGPoint(x: w * 0.50, y: h * 0.89))
            path.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.40), controlPoint: CGPoint(x: w * 0.21, y: h * 0.65))
            path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.57))
            path.addLine(to: CGPoint(x: w * 0.06, y: h * 0.55))
            path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.22))
            path.close()

        case .cropTop:
            // Short torso crop top
            path.move(to: CGPoint(x: w * 0.34, y: h * 0.20))
            path.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.20), controlPoint: CGPoint(x: w * 0.50, y: h * 0.27))
            path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.25))
            path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.42))
            path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.46))
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.40))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.64)) // ends at midriff
            path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.64))
            path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.40))
            path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.46))
            path.addLine(to: CGPoint(x: w * 0.08, y: h * 0.42))
            path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.25))
            path.close()

        case .bikini:
            // Two triangle halter cups connected by band
            // Left cup
            path.move(to: CGPoint(x: w * 0.30, y: h * 0.28))
            path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.54))
            path.addLine(to: CGPoint(x: w * 0.20, y: h * 0.54))
            path.close()
            // Right cup
            path.move(to: CGPoint(x: w * 0.70, y: h * 0.28))
            path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.54))
            path.addLine(to: CGPoint(x: w * 0.54, y: h * 0.54))
            path.close()
            // Underband
            let band = UIBezierPath(roundedRect: CGRect(x: w * 0.16, y: h * 0.54, width: w * 0.68, height: h * 0.06), cornerRadius: 4)
            path.append(band)

        case .jeans, .pants:
            // Full length denim / tailored trousers
            path.move(to: CGPoint(x: w * 0.26, y: h * 0.12)) // waistband
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.77, y: h * 0.34))
            path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.90)) // right ankle
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.90))
            path.addLine(to: CGPoint(x: w * 0.51, y: h * 0.42)) // crotch
            path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.90))
            path.addLine(to: CGPoint(x: w * 0.27, y: h * 0.90)) // left ankle
            path.addLine(to: CGPoint(x: w * 0.23, y: h * 0.34))
            path.close()

        case .shorts:
            // Above-the-knee shorts
            path.move(to: CGPoint(x: w * 0.26, y: h * 0.16))
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.16))
            path.addLine(to: CGPoint(x: w * 0.77, y: h * 0.40))
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.62)) // right leg hem
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.62))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.44)) // crotch
            path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.62))
            path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.62)) // left leg hem
            path.addLine(to: CGPoint(x: w * 0.23, y: h * 0.40))
            path.close()

        case .capris:
            // Mid-calf capri pants
            path.move(to: CGPoint(x: w * 0.26, y: h * 0.14))
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.14))
            path.addLine(to: CGPoint(x: w * 0.77, y: h * 0.36))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.76)) // mid-calf
            path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.76))
            path.addLine(to: CGPoint(x: w * 0.51, y: h * 0.42))
            path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.76))
            path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.76))
            path.addLine(to: CGPoint(x: w * 0.23, y: h * 0.36))
            path.close()

        case .leggings:
            // Skin-tight form fitting leggings
            path.move(to: CGPoint(x: w * 0.28, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.72, y: h * 0.12))
            path.addLine(to: CGPoint(x: w * 0.75, y: h * 0.36))
            path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.55, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.50, y: h * 0.42))
            path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.32, y: h * 0.92))
            path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.36))
            path.close()

        case .skirt:
            // Flared A-line skirt
            path.move(to: CGPoint(x: w * 0.32, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.22))
            path.addQuadCurve(to: CGPoint(x: w * 0.84, y: h * 0.78), controlPoint: CGPoint(x: w * 0.78, y: h * 0.50))
            path.addQuadCurve(to: CGPoint(x: w * 0.16, y: h * 0.78), controlPoint: CGPoint(x: w * 0.50, y: h * 0.83))
            path.addQuadCurve(to: CGPoint(x: w * 0.32, y: h * 0.22), controlPoint: CGPoint(x: w * 0.22, y: h * 0.50))
            path.close()

        case .dress:
            // Knee-length dress with fitted bodice and flared skirt
            path.move(to: CGPoint(x: w * 0.35, y: h * 0.12))
            path.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.12), controlPoint: CGPoint(x: w * 0.50, y: h * 0.18))
            path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.17))
            path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.28))
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.30))
            path.addLine(to: CGPoint(x: w * 0.69, y: h * 0.44)) // waist
            path.addQuadCurve(to: CGPoint(x: w * 0.82, y: h * 0.88), controlPoint: CGPoint(x: w * 0.78, y: h * 0.66))
            path.addQuadCurve(to: CGPoint(x: w * 0.18, y: h * 0.88), controlPoint: CGPoint(x: w * 0.50, y: h * 0.91))
            path.addQuadCurve(to: CGPoint(x: w * 0.31, y: h * 0.44), controlPoint: CGPoint(x: w * 0.22, y: h * 0.66))
            path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.30))
            path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.28))
            path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.17))
            path.close()

        case .longDress:
            // Floor-length maxi dress
            path.move(to: CGPoint(x: w * 0.35, y: h * 0.10))
            path.addQuadCurve(to: CGPoint(x: w * 0.65, y: h * 0.10), controlPoint: CGPoint(x: w * 0.50, y: h * 0.16))
            path.addLine(to: CGPoint(x: w * 0.78, y: h * 0.15))
            path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.26))
            path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.28))
            path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.40))
            path.addQuadCurve(to: CGPoint(x: w * 0.86, y: h * 0.94), controlPoint: CGPoint(x: w * 0.78, y: h * 0.68))
            path.addQuadCurve(to: CGPoint(x: w * 0.14, y: h * 0.94), controlPoint: CGPoint(x: w * 0.50, y: h * 0.97))
            path.addQuadCurve(to: CGPoint(x: w * 0.32, y: h * 0.40), controlPoint: CGPoint(x: w * 0.22, y: h * 0.68))
            path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.28))
            path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.26))
            path.addLine(to: CGPoint(x: w * 0.22, y: h * 0.15))
            path.close()

        case .beanie:
            // Ribbed knit beanie cap
            path.move(to: CGPoint(x: w * 0.20, y: h * 0.75))
            path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.75))
            path.addLine(to: CGPoint(x: w * 0.80, y: h * 0.55))
            path.addQuadCurve(to: CGPoint(x: w * 0.50, y: h * 0.22), controlPoint: CGPoint(x: w * 0.78, y: h * 0.28))
            path.addQuadCurve(to: CGPoint(x: w * 0.20, y: h * 0.55), controlPoint: CGPoint(x: w * 0.22, y: h * 0.28))
            path.close()

        case .sneakers:
            // Athletic low sneaker
            path.move(to: CGPoint(x: w * 0.12, y: h * 0.68))
            path.addLine(to: CGPoint(x: w * 0.88, y: h * 0.68))
            path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.54))
            path.addQuadCurve(to: CGPoint(x: w * 0.56, y: h * 0.36), controlPoint: CGPoint(x: w * 0.74, y: h * 0.48))
            path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.36))
            path.addQuadCurve(to: CGPoint(x: w * 0.14, y: h * 0.54), controlPoint: CGPoint(x: w * 0.20, y: h * 0.44))
            path.close()

        case .boots:
            // High ankle boot
            path.move(to: CGPoint(x: w * 0.24, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.22))
            path.addLine(to: CGPoint(x: w * 0.60, y: h * 0.56))
            path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.66))
            path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.78))
            path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.78))
            path.addLine(to: CGPoint(x: w * 0.18, y: h * 0.60))
            path.addLine(to: CGPoint(x: w * 0.24, y: h * 0.52))
            path.close()
        }

        // Fill with dominant color and subtle soft vertical gradient for avatar dimension
        cg.saveGState()
        path.addClip()

        let baseComponents = dominantColor.cgColor.components ?? [0.5, 0.5, 0.5, 1.0]
        let r = baseComponents[0]
        let g = baseComponents.count > 1 ? baseComponents[1] : r
        let b = baseComponents.count > 2 ? baseComponents[2] : r
        let a = baseComponents.count > 3 ? baseComponents[3] : 1.0

        let topColor = UIColor(red: min(r * 1.14, 1.0), green: min(g * 1.14, 1.0), blue: min(b * 1.14, 1.0), alpha: a).cgColor
        let bottomColor = UIColor(red: max(r * 0.86, 0.0), green: max(g * 0.86, 0.0), blue: max(b * 0.86, 0.0), alpha: a).cgColor

        let colors = [topColor, bottomColor] as CFArray
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 1.0]) {
            cg.drawLinearGradient(gradient, start: CGPoint(x: w * 0.5, y: 0), end: CGPoint(x: w * 0.5, y: h), options: [])
        }
        cg.restoreGState()

        // Clean avatar outline
        let outlineColor = UIColor(red: max(r * 0.55, 0.0), green: max(g * 0.55, 0.0), blue: max(b * 0.55, 0.0), alpha: 0.85)
        outlineColor.setStroke()
        path.lineWidth = 3.5
        path.lineJoinStyle = .round
        path.stroke()
    }

    // MARK: - Preset Details & Trims (Collar, Cuffs, Pockets, Waistband)

    private static func drawPresetDetails(
        preset: GarmentPreset,
        dominantColor: UIColor,
        accentColor: UIColor,
        in cg: CGContext,
        width w: CGFloat,
        height h: CGFloat
    ) {
        accentColor.setStroke()
        cg.setLineWidth(3.0)
        cg.setLineCap(.round)

        switch preset {
        case .tShirt:
            // Ribbed collar ring
            let collar = UIBezierPath()
            collar.move(to: CGPoint(x: w * 0.34, y: h * 0.16))
            collar.addQuadCurve(to: CGPoint(x: w * 0.66, y: h * 0.16), controlPoint: CGPoint(x: w * 0.50, y: h * 0.23))
            collar.stroke()

            // Sleeve hem seams
            let leftSleeve = UIBezierPath()
            leftSleeve.move(to: CGPoint(x: w * 0.08, y: h * 0.39))
            leftSleeve.addLine(to: CGPoint(x: w * 0.20, y: h * 0.44))
            leftSleeve.stroke()

            let rightSleeve = UIBezierPath()
            rightSleeve.move(to: CGPoint(x: w * 0.92, y: h * 0.39))
            rightSleeve.addLine(to: CGPoint(x: w * 0.80, y: h * 0.44))
            rightSleeve.stroke()

        case .hoodie:
            // Kangaroo pocket
            let pocket = UIBezierPath()
            pocket.move(to: CGPoint(x: w * 0.34, y: h * 0.65))
            pocket.addLine(to: CGPoint(x: w * 0.66, y: h * 0.65))
            pocket.addLine(to: CGPoint(x: w * 0.72, y: h * 0.80))
            pocket.addLine(to: CGPoint(x: w * 0.28, y: h * 0.80))
            pocket.close()
            pocket.stroke()

            // Drawstrings hanging from hood
            let stringLeft = UIBezierPath()
            stringLeft.move(to: CGPoint(x: w * 0.44, y: h * 0.24))
            stringLeft.addQuadCurve(to: CGPoint(x: w * 0.43, y: h * 0.42), controlPoint: CGPoint(x: w * 0.41, y: h * 0.33))
            stringLeft.stroke()

            let stringRight = UIBezierPath()
            stringRight.move(to: CGPoint(x: w * 0.56, y: h * 0.24))
            stringRight.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.42), controlPoint: CGPoint(x: w * 0.59, y: h * 0.33))
            stringRight.stroke()

        case .jersey:
            // Athletic shoulder stripes in accent color
            let leftStripe = UIBezierPath()
            leftStripe.move(to: CGPoint(x: w * 0.20, y: h * 0.22))
            leftStripe.addLine(to: CGPoint(x: w * 0.12, y: h * 0.35))
            leftStripe.stroke()

            let rightStripe = UIBezierPath()
            rightStripe.move(to: CGPoint(x: w * 0.80, y: h * 0.22))
            rightStripe.addLine(to: CGPoint(x: w * 0.88, y: h * 0.35))
            rightStripe.stroke()

            // Neckline V-trim
            let vTrim = UIBezierPath()
            vTrim.move(to: CGPoint(x: w * 0.35, y: h * 0.14))
            vTrim.addLine(to: CGPoint(x: w * 0.50, y: h * 0.26))
            vTrim.addLine(to: CGPoint(x: w * 0.65, y: h * 0.14))
            vTrim.lineWidth = 4.0
            vTrim.stroke()

        case .jeans:
            // Waistband stitch line & fly
            let waistband = UIBezierPath()
            waistband.move(to: CGPoint(x: w * 0.25, y: h * 0.18))
            waistband.addLine(to: CGPoint(x: w * 0.75, y: h * 0.18))
            waistband.stroke()

            let fly = UIBezierPath()
            fly.move(to: CGPoint(x: w * 0.50, y: h * 0.18))
            fly.addLine(to: CGPoint(x: w * 0.50, y: h * 0.36))
            fly.addQuadCurve(to: CGPoint(x: w * 0.54, y: h * 0.38), controlPoint: CGPoint(x: w * 0.52, y: h * 0.38))
            fly.stroke()

            // Front curved jean pockets
            let leftPocket = UIBezierPath()
            leftPocket.move(to: CGPoint(x: w * 0.28, y: h * 0.18))
            leftPocket.addQuadCurve(to: CGPoint(x: w * 0.24, y: h * 0.29), controlPoint: CGPoint(x: w * 0.34, y: h * 0.22))
            leftPocket.stroke()

            let rightPocket = UIBezierPath()
            rightPocket.move(to: CGPoint(x: w * 0.72, y: h * 0.18))
            rightPocket.addQuadCurve(to: CGPoint(x: w * 0.76, y: h * 0.29), controlPoint: CGPoint(x: w * 0.66, y: h * 0.22))
            rightPocket.stroke()

        case .beanie:
            // Folded brim band
            let brim = UIBezierPath()
            brim.move(to: CGPoint(x: w * 0.20, y: h * 0.62))
            brim.addLine(to: CGPoint(x: w * 0.80, y: h * 0.62))
            brim.stroke()

        default:
            break
        }
    }

    // MARK: - Graphic Emblem / Pattern Compositing

    private static func drawGraphicEmblem(
        _ graphic: UIImage,
        preset: GarmentPreset,
        in cg: CGContext,
        width w: CGFloat,
        height h: CGFloat
    ) {
        cg.saveGState()

        let emblemRect: CGRect
        switch preset {
        case .tShirt, .sweatshirt, .hoodie, .jersey, .sweater:
            // Centered on upper chest
            let emblemSize = min(w * 0.36, h * 0.28)
            emblemRect = CGRect(
                x: (w - emblemSize) / 2,
                y: h * 0.32,
                width: emblemSize,
                height: emblemSize
            )

        case .cropTop, .blouse:
            let emblemSize = min(w * 0.30, h * 0.20)
            emblemRect = CGRect(
                x: (w - emblemSize) / 2,
                y: h * 0.32,
                width: emblemSize,
                height: emblemSize
            )

        case .tankTop:
            let emblemSize = min(w * 0.28, h * 0.22)
            emblemRect = CGRect(
                x: (w - emblemSize) / 2,
                y: h * 0.36,
                width: emblemSize,
                height: emblemSize
            )

        case .dress, .longDress:
            let emblemSize = min(w * 0.28, h * 0.22)
            emblemRect = CGRect(
                x: (w - emblemSize) / 2,
                y: h * 0.25,
                width: emblemSize,
                height: emblemSize
            )

        case .jeans, .pants, .shorts, .capris, .skirt, .leggings:
            // Front left pocket/hip graphic
            let emblemSize = min(w * 0.18, h * 0.14)
            emblemRect = CGRect(
                x: w * 0.30,
                y: h * 0.28,
                width: emblemSize,
                height: emblemSize
            )

        case .beanie:
            // Center of folded brim
            let emblemSize = min(w * 0.22, h * 0.14)
            emblemRect = CGRect(
                x: (w - emblemSize) / 2,
                y: h * 0.63,
                width: emblemSize,
                height: emblemSize
            )

        case .bikini, .sneakers, .boots:
            let emblemSize = min(w * 0.20, h * 0.15)
            emblemRect = CGRect(
                x: (w - emblemSize) / 2,
                y: h * 0.40,
                width: emblemSize,
                height: emblemSize
            )
        }

        // Clip to rounded emblem bounds and draw with subtle blend
        cg.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.withAlphaComponent(0.20).cgColor)
        graphic.draw(in: emblemRect)

        cg.restoreGState()
    }

    private static func contrastingAccent(for color: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        if luminance > 0.65 {
            // Dark accent for light garments
            return UIColor(red: max(r * 0.45, 0.1), green: max(g * 0.45, 0.1), blue: max(b * 0.45, 0.1), alpha: 0.9)
        } else {
            // Light crisp accent for dark garments
            return UIColor(red: min(r * 1.5 + 0.25, 1.0), green: min(g * 1.5 + 0.25, 1.0), blue: min(b * 1.5 + 0.25, 1.0), alpha: 0.9)
        }
    }
}
