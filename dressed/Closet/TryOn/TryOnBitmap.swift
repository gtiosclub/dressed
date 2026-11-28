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

    /// Stacks transparent body-part layers over a base avatar image.
    static func compositeLayers(base: CGImage, overlays: [CGImage], canvas: TryOnCanvas = .canonical) -> CGImage? {
        guard overlays.isEmpty == false else { return placed(base, canvas: canvas) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: canvas.width, height: canvas.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            if let baseImage = placed(base, canvas: canvas) {
                UIImage(cgImage: baseImage).draw(in: CGRect(origin: .zero, size: size))
            }
            for overlay in overlays {
                guard let fitted = placed(overlay, canvas: canvas) else { continue }
                UIImage(cgImage: fitted).draw(in: CGRect(origin: .zero, size: size))
            }
        }.cgImage
    }

    struct BodyPartLayer: Equatable {
        var slot: TryOnBodySlot
        var image: CGImage
    }

    /// Maps one body-part PNG into the shared figure frame and returns a full-canvas transparent layer.
    static func bodyPartLayerOnCanvas(
        _ image: CGImage,
        slot: TryOnBodySlot,
        landmarks: TryOnLandmarks,
        canvas: TryOnCanvas = .canonical
    ) -> CGImage? {
        guard let stats = stats(of: image), stats.opaqueCount > 0 else { return nil }
        let frame = slot.figureFrame(landmarks: landmarks)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let canvasSize = CGSize(width: canvas.width, height: canvas.height)
        let slotRect = CGRect(
            x: frame.x * canvasSize.width,
            y: frame.y * canvasSize.height,
            width: frame.width * canvasSize.width,
            height: frame.height * canvasSize.height
        )
        let opaque = stats.bounds
        let shoulderLeft = landmarks.leftShoulderJoint?.x ?? landmarks.leftShoulderEdge?.x ?? 0.22
        let shoulderRight = landmarks.rightShoulderJoint?.x ?? landmarks.rightShoulderEdge?.x ?? 0.78
        let shoulderSpan = max(abs(shoulderRight - shoulderLeft), 0.22)
        let shoulderWidthPx = shoulderSpan * canvasSize.width
        let hipLeft = landmarks.leftHip?.x ?? shoulderLeft + 0.04
        let hipRight = landmarks.rightHip?.x ?? shoulderRight - 0.04
        let hipWidthPx = max(abs(hipRight - hipLeft), shoulderSpan * 0.72) * canvasSize.width
        let ankleLeft = landmarks.leftAnkle?.x ?? frame.center.x - shoulderSpan * 0.12
        let ankleRight = landmarks.rightAnkle?.x ?? frame.center.x + shoulderSpan * 0.12
        let footSpanPx = max(abs(ankleRight - ankleLeft), shoulderSpan * 0.38) * canvasSize.width

        // Aspect-fill into the slot, but never smaller than ~90% of the slot or the figure width at that region.
        let scaleW = slotRect.width / max(opaque.width, 1)
        let scaleH = slotRect.height / max(opaque.height, 1)
        let minScaleW = (slotRect.width * 0.90) / max(opaque.width, 1)
        let minScaleH = (slotRect.height * 0.90) / max(opaque.height, 1)
        let targetWidth: CGFloat
        switch slot {
        case .top:
            targetWidth = max(slotRect.width * 0.92, shoulderWidthPx * 1.04)
        case .bottom:
            targetWidth = max(slotRect.width * 0.92, hipWidthPx * 1.02)
        case .shoes:
            targetWidth = max(slotRect.width * 0.90, footSpanPx * 1.05)
        case .headwear:
            targetWidth = max(slotRect.width * 0.88, shoulderWidthPx * 0.55)
        }
        let scaleShoulder = targetWidth / max(opaque.width, 1)
        let scale = max(max(scaleW, scaleH), scaleShoulder, minScaleW, minScaleH)
        let scaledImageSize = CGSize(
            width: CGFloat(image.width) * scale,
            height: CGFloat(image.height) * scale
        )
        let midlineX = (landmarks.neckCenter?.x ?? frame.center.x) * canvasSize.width
        let drawX = midlineX - opaque.midX * scale
        let drawY: CGFloat
        switch slot {
        case .shoes:
            let feetY = max(landmarks.leftAnkle?.y ?? 0.94, landmarks.rightAnkle?.y ?? 0.94) * canvasSize.height
            drawY = feetY - opaque.maxY * scale
        case .top:
            let neckY = (landmarks.neckCenter?.y ?? frame.y) * canvasSize.height
            drawY = neckY - opaque.minY * scale
        case .bottom:
            let waistY = (landmarks.waistCenter?.y
                ?? landmarks.leftHip?.y
                ?? landmarks.rightHip?.y
                ?? frame.y) * canvasSize.height
            drawY = waistY - opaque.minY * scale
        case .headwear:
            let browY = max((landmarks.neckCenter?.y ?? 0.18) - 0.08, 0.05) * canvasSize.height
            drawY = browY - opaque.minY * scale
        }
        let drawRect = CGRect(
            x: drawX,
            y: drawY,
            width: scaledImageSize.width,
            height: scaledImageSize.height
        )
        return UIGraphicsImageRenderer(size: canvasSize, format: format).image { context in
            context.cgContext.clip(to: slotRect)
            UIImage(cgImage: image).draw(in: drawRect)
        }.cgImage
    }

    /// Transparent skin plate for body-part baking: avatar body with all garment slots cleared.
    /// Arms and hair are drawn separately in the render graph; never bake legacy garment PNGs here.
    static func skinOnlyBodyPartBase(
        avatarBody: CGImage,
        landmarks: TryOnLandmarks,
        canvas: TryOnCanvas = .canonical
    ) -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: canvas.width, height: canvas.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            if let baseImage = placed(avatarBody, canvas: canvas) {
                UIImage(cgImage: baseImage).draw(in: CGRect(origin: .zero, size: size))
            }
            let cg = context.cgContext
            for slot in TryOnBodySlot.allCases {
                let frame = slot.figureFrame(landmarks: landmarks)
                let slotRect = CGRect(
                    x: frame.x * size.width,
                    y: frame.y * size.height,
                    width: frame.width * size.width,
                    height: frame.height * size.height
                )
                cg.saveGState()
                cg.setBlendMode(.clear)
                cg.fill(slotRect)
                cg.restoreGState()
            }
        }.cgImage
    }

    /// Composites body-part PNGs onto a skin-only base; does not draw garment overlay assets.
    static func compositeBodyPartLayers(
        base: CGImage,
        landmarks: TryOnLandmarks,
        layers: [BodyPartLayer],
        canvas: TryOnCanvas = .canonical,
        clearSlotsBeforePaint: Bool = true
    ) -> CGImage? {
        guard !layers.isEmpty else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: canvas.width, height: canvas.height)
        let ordered = layers.sorted {
            TryOnStack.rank(for: category(for: $0.slot)) < TryOnStack.rank(for: category(for: $1.slot))
        }
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            if let baseImage = placed(base, canvas: canvas) {
                UIImage(cgImage: baseImage).draw(in: CGRect(origin: .zero, size: size))
            }
            let cg = context.cgContext
            if clearSlotsBeforePaint {
                for layer in ordered {
                    let frame = layer.slot.figureFrame(landmarks: landmarks)
                    let slotRect = CGRect(
                        x: frame.x * size.width,
                        y: frame.y * size.height,
                        width: frame.width * size.width,
                        height: frame.height * size.height
                    )
                    cg.saveGState()
                    cg.setBlendMode(.clear)
                    cg.fill(slotRect)
                    cg.restoreGState()
                }
            }
            for layer in ordered {
                guard let normalized = bodyPartLayerOnCanvas(
                    layer.image,
                    slot: layer.slot,
                    landmarks: landmarks,
                    canvas: canvas
                ) else { continue }
                UIImage(cgImage: normalized).draw(in: CGRect(origin: .zero, size: size))
            }
        }.cgImage
    }

    private static func category(for slot: TryOnBodySlot) -> ClothingCategory {
        switch slot {
        case .top: return .tops
        case .bottom: return .pants
        case .shoes: return .shoes
        case .headwear: return .accessories
        }
    }

    /// Uniform horizontal scale about a canvas pixel anchor, canvas size unchanged.
    static func scaledX(
        _ image: CGImage,
        scale: CGFloat,
        anchorX: CGFloat,
        canvas: TryOnCanvas
    ) -> CGImage? {
        guard scale > 0.001, abs(scale - 1) > 0.001 else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let size = CGSize(width: canvas.width, height: canvas.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: anchorX, y: 0)
            cg.scaleBy(x: scale, y: 1)
            cg.translateBy(x: -anchorX, y: 0)
            UIImage(cgImage: image).draw(
                in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height))
            )
        }.cgImage
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

    /// Punches neck, cuff, head, and hand openings so the avatar shows through as worn clothing, not a flat poster.
    static func applyWearHoles(
        _ image: CGImage,
        landmarks: TryOnLandmarks,
        template: TryOnTemplateID,
        canvas: TryOnCanvas = .canonical,
        silhouette: CGImage? = nil
    ) -> CGImage? {
        guard var source = rgba(from: image) else { return image }
        let width = source.width
        let height = source.height
        func px(_ nx: Double) -> Int { min(max(Int((nx * Double(width - 1)).rounded()), 0), width - 1) }
        func py(_ ny: Double) -> Int { min(max(Int((ny * Double(height - 1)).rounded()), 0), height - 1) }
        func clear(_ x: Int, _ y: Int) {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            let index = (y * width + x) * 4
            source.bytes[index] = 0
            source.bytes[index + 1] = 0
            source.bytes[index + 2] = 0
            source.bytes[index + 3] = 0
        }
        func clearEllipse(cx: Double, cy: Double, rx: Double, ry: Double) {
            let x0 = px(cx - rx)
            let x1 = px(cx + rx)
            let y0 = py(cy - ry)
            let y1 = py(cy + ry)
            let centerX = px(cx)
            let centerY = py(cy)
            let radiusX = max(px(cx + rx) - centerX, 1)
            let radiusY = max(py(cy + ry) - centerY, 1)
            for y in y0...y1 {
                for x in x0...x1 {
                    let dx = Double(x - centerX) / Double(radiusX)
                    let dy = Double(y - centerY) / Double(radiusY)
                    if dx * dx + dy * dy <= 1.02 { clear(x, y) }
                }
            }
        }
        func clearAbove(_ yCut: Double) {
            let limit = py(yCut)
            for y in 0...limit {
                for x in 0..<width {
                    let index = (y * width + x) * 4
                    guard source.bytes[index + 3] > 16 else { continue }
                    clear(x, y)
                }
            }
        }
        let leftShoulder = landmarks.leftShoulderJoint ?? landmarks.leftShoulderEdge
        let rightShoulder = landmarks.rightShoulderJoint ?? landmarks.rightShoulderEdge
        let shoulderY: Double = {
            let ys = [leftShoulder?.y, rightShoulder?.y, landmarks.neckCenter?.y].compactMap { $0 }
            guard let minY = ys.min() else { return 0.22 }
            return minY
        }()
        let shoulderSpan = abs((rightShoulder?.x ?? 0.62) - (leftShoulder?.x ?? 0.38))
        let torsoLeft = (leftShoulder?.x ?? 0.38) - shoulderSpan * 0.06
        let torsoRight = (rightShoulder?.x ?? 0.62) + shoulderSpan * 0.06

        clearAbove(shoulderY - 0.012)

        if let neck = landmarks.neckCenter {
            let rx = max(shoulderSpan * 0.14, 0.035)
            let ry = max(shoulderSpan * 0.22, 0.045)
            clearEllipse(cx: neck.x, cy: neck.y + ry * 0.15, rx: rx, ry: ry)
            let headTop = max(0.04, neck.y - 0.14)
            clearEllipse(cx: neck.x, cy: (headTop + neck.y) / 2, rx: rx * 1.35, ry: (neck.y - headTop) * 0.55 + 0.02)
        }

        func punchCuff(wrist: TryOnPoint?, elbow: TryOnPoint?, side: Double) {
            guard let wrist else { return }
            let cuffY = min(wrist.y + 0.02, 0.98)
            let rx = max(shoulderSpan * 0.12, 0.03)
            let ry = max(shoulderSpan * 0.08, 0.025)
            clearEllipse(cx: wrist.x, cy: cuffY, rx: rx, ry: ry)
            if let elbow {
                let steps = 6
                for step in 1...steps {
                    let t = Double(step) / Double(steps)
                    let y = lerp(elbow.y, cuffY + ry, t)
                    let x = lerp(elbow.x, wrist.x, t)
                    if x < torsoLeft || x > torsoRight { clearEllipse(cx: x, cy: y, rx: rx * 0.55, ry: ry * 0.45) }
                }
            }
            let handY = min(wrist.y + 0.035, 0.99)
            clearEllipse(cx: wrist.x + side * 0.01, cy: handY, rx: rx * 1.1, ry: ry * 1.25)
        }
        punchCuff(wrist: landmarks.leftWrist, elbow: landmarks.leftElbow, side: -1)
        punchCuff(wrist: landmarks.rightWrist, elbow: landmarks.rightElbow, side: 1)

        if template == .tShirt || template == .openJacket {
            let stats = stats(of: image)
            let openCenter = (stats?.centerBandAlpha ?? 1) < 0.32 || template == .openJacket
            if openCenter, let neck = landmarks.neckCenter, let waist = landmarks.waistCenter ?? landmarks.chestCenter {
                let bandHalf = max(shoulderSpan * 0.06, 0.018)
                let y0 = py(neck.y + 0.04)
                let y1 = py(min(waist.y, neck.y + 0.38))
                let x0 = px(neck.x - bandHalf)
                let x1 = px(neck.x + bandHalf)
                for y in y0...y1 {
                    for x in x0...x1 { clear(x, y) }
                }
            }
        }

        if let silhouette, let mask = rgba(from: silhouette),
           mask.width == width, mask.height == height {
            for y in 0..<height {
                for x in 0..<width {
                    let ny = Double(y) / Double(max(height - 1, 1))
                    let index = (y * width + x) * 4
                    guard source.bytes[index + 3] > 16 else { continue }
                    if mask.bytes[index + 3] < 64, ny < shoulderY + 0.015 {
                        clear(x, y)
                    }
                }
            }
            for wrist in [landmarks.leftWrist, landmarks.rightWrist].compactMap({ $0 }) {
                let rx = max(Int((shoulderSpan * 0.16 * Double(width)).rounded()), 10)
                let wx = px(wrist.x)
                let wy0 = py(wrist.y - 0.01)
                let wy1 = py(min(wrist.y + 0.06, 0.99))
                let x0 = max(0, wx - rx)
                let x1 = min(width - 1, wx + rx)
                for y in wy0...wy1 {
                    for x in x0...x1 {
                        let nx = Double(x) / Double(max(width - 1, 1))
                        if nx >= torsoLeft && nx <= torsoRight,
                           mask.bytes[(y * width + x) * 4 + 3] > 128 {
                            clear(x, y)
                        }
                    }
                }
            }
        }

        return cgImage(width: width, height: height, bytes: source.bytes) ?? image
    }

    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + (b - a) * t
    }

    private static func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    private static func hypot3(_ a: Double, _ b: Double, _ c: Double) -> Double {
        (a * a + b * b + c * c).squareRoot()
    }
}
