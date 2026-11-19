import CoreGraphics
import Foundation

struct TryOnComponentImage {
    var id: String
    var kind: TryOnComponentKind
    var depthGroup: TryOnDepthGroup
    var renderOrder: Int
    var image: CGImage
    var bounds: TryOnRect
}

struct TryOnFitProduct {
    var image: CGImage
    var anchors: [String: TryOnPoint]
    var bounds: TryOnRect
    var mesh: TryOnMesh
    var components: [TryOnComponentImage]
    var bypassedUpperTemplate: Bool
    var alignmentNote: String?
}

enum TryOnFit {
    static func anchors(for template: TryOnTemplateID, stats: TryOnAlphaStats, canvas: TryOnCanvas) -> [String: TryOnPoint] {
        let bounds = stats.bounds
        guard bounds.width > 1, bounds.height > 1 else { return [:] }
        func point(_ x: CGFloat, _ y: CGFloat) -> TryOnPoint {
            TryOnPoint(
                x: Double(x) / Double(canvas.width),
                y: Double(y) / Double(canvas.height)
            )
        }
        let minX = bounds.minX
        let maxX = bounds.maxX
        let minY = bounds.minY
        let maxY = bounds.maxY
        let midX = bounds.midX
        let width = bounds.width
        let height = bounds.height
        switch template {
        case .tShirt, .oversizedHoodie, .openJacket:
            return [
                "necklineCenter": point(midX, minY + height * 0.08),
                "leftShoulderSeam": point(minX + width * 0.14, minY + height * 0.14),
                "rightShoulderSeam": point(maxX - width * 0.14, minY + height * 0.14),
                "leftCuff": point(minX + width * 0.04, minY + height * 0.48),
                "rightCuff": point(maxX - width * 0.04, minY + height * 0.48),
                "hemCenter": point(midX, maxY - height * 0.03),
                "leftHem": point(minX + width * 0.18, maxY - height * 0.03),
                "rightHem": point(maxX - width * 0.18, maxY - height * 0.03)
            ]
        case .trousers:
            return [
                "waistCenter": point(midX, minY + height * 0.06),
                "leftHip": point(minX + width * 0.22, minY + height * 0.12),
                "rightHip": point(maxX - width * 0.22, minY + height * 0.12),
                "crotchCenter": point(midX, minY + height * 0.28),
                "leftKnee": point(minX + width * 0.28, minY + height * 0.62),
                "rightKnee": point(maxX - width * 0.28, minY + height * 0.62),
                "leftAnkle": point(minX + width * 0.30, maxY - height * 0.04),
                "rightAnkle": point(maxX - width * 0.30, maxY - height * 0.04)
            ]
        }
    }

    /// Translates the garment toward detected avatar landmarks. Hem anchors are not used,
    /// so garment length stays with the source. A large offset is rejected.
    static func alignmentShift(
        template: TryOnTemplateID,
        garmentAnchors: [String: TryOnPoint],
        landmarks: TryOnLandmarks
    ) -> (shift: TryOnPoint, note: String?) {
        var pairs: [TryOnPoint] = []
        for link in template.alignmentLinks {
            guard let garment = garmentAnchors[link.garment] else { continue }
            guard let avatar = link.avatar.compactMap({ landmarks.point(named: $0) }).first else { continue }
            pairs.append(TryOnPoint(x: avatar.x - garment.x, y: avatar.y - garment.y))
        }
        guard pairs.count >= 2 else {
            return (.zero, "Not enough detected avatar landmarks to adjust placement.")
        }
        let middle = median(pairs)
        let kept = pairs.filter { abs($0.x - middle.x) <= 0.08 && abs($0.y - middle.y) <= 0.08 }
        let used = kept.count >= 2 ? kept : pairs
        let shift = median(used)
        if abs(shift.x) > 0.2 || abs(shift.y) > 0.2 {
            return (.zero, "The garment and avatar landmarks were too far apart to auto-align.")
        }
        return (shift, nil)
    }

    static func clamp(_ shift: TryOnPoint, stats: TryOnAlphaStats, canvas: TryOnCanvas) -> TryOnPoint {
        let bounds = stats.bounds
        guard bounds.width > 1 else { return .zero }
        var dx = shift.x * Double(canvas.width)
        var dy = shift.y * Double(canvas.height)
        dx = min(max(dx, -bounds.minX), Double(canvas.width) - bounds.maxX)
        dy = min(max(dy, -bounds.minY), Double(canvas.height) - bounds.maxY)
        return TryOnPoint(x: dx / Double(canvas.width), y: dy / Double(canvas.height))
    }

    static func mesh(
        template: TryOnTemplateID,
        bounds: TryOnRect,
        anchors: [String: TryOnPoint],
        landmarks: TryOnLandmarks,
        appliedShift: TryOnPoint
    ) -> TryOnMesh {
        let columns = 5
        let rows = 6
        var vertices: [TryOnMeshVertex] = []
        var shoulderIndices: [Int] = []
        let chest = protectedChest(anchors: anchors, template: template)
        for row in 0..<rows {
            for column in 0..<columns {
                let u = bounds.x + bounds.width * Double(column) / Double(columns - 1)
                let v = bounds.y + bounds.height * Double(row) / Double(rows - 1)
                let onEdge = row == 0 || row == rows - 1 || column == 0 || column == columns - 1
                let protected = chest?.contains(TryOnPoint(x: u, y: v)) == true
                var constraint: TryOnVertexConstraint = protected ? .protected : (onEdge ? .edge : .flexible)
                var position = TryOnPoint(x: u, y: v)
                if !protected {
                    let moved = displaced(
                        position,
                        template: template,
                        anchors: anchors,
                        landmarks: landmarks,
                        appliedShift: appliedShift
                    )
                    position = moved.point
                    if moved.pulled {
                        shoulderIndices.append(vertices.count)
                        if constraint == .flexible { constraint = .seam }
                    }
                }
                vertices.append(TryOnMeshVertex(
                    x: Float(position.x),
                    y: Float(position.y),
                    u: Float(u),
                    v: Float(v),
                    constraint: constraint
                ))
            }
        }
        var indices: [UInt32] = []
        for row in 0..<(rows - 1) {
            for column in 0..<(columns - 1) {
                let start = UInt32(row * columns + column)
                let stride = UInt32(columns)
                indices.append(contentsOf: [start, start + 1, start + stride + 1, start, start + stride + 1, start + stride])
            }
        }
        let region = TryOnDeformationRegion(
            id: "shoulder-seam",
            regionType: "shoulder",
            vertexIndices: shoulderIndices,
            maxDisplacement: TryOnVersions.maxLocalDisplacement
        )
        return TryOnMesh(vertices: vertices, indices: indices, regions: [region])
    }

    static func split(
        template: TryOnTemplateID,
        image: CGImage,
        anchors: [String: TryOnPoint],
        canvas: TryOnCanvas
    ) -> (components: [TryOnComponentImage], bypassedHoodTemplate: Bool) {
        switch template.split {
        case .single:
            return ([whole(image, order: 30)], false)
        case .hoodie:
            return splitHoodie(image, anchors: anchors, canvas: canvas)
        case .openJacket:
            return (splitJacket(image, canvas: canvas), false)
        case .trousers:
            return (splitTrousers(image, anchors: anchors, canvas: canvas), false)
        }
    }

    private static func whole(_ image: CGImage, order: Int) -> TryOnComponentImage {
        TryOnComponentImage(
            id: "main",
            kind: .mainBody,
            depthGroup: .clothing,
            renderOrder: order,
            image: image,
            bounds: normalizedBounds(of: image) ?? TryOnRect(x: 0, y: 0, width: 1, height: 1)
        )
    }

    private static func splitHoodie(
        _ image: CGImage,
        anchors: [String: TryOnPoint],
        canvas: TryOnCanvas
    ) -> (components: [TryOnComponentImage], bypassedHoodTemplate: Bool) {
        guard let neck = anchors["necklineCenter"],
              let left = anchors["leftShoulderSeam"],
              let right = anchors["rightShoulderSeam"],
              let bytes = TryOnBitmap.rgba(from: image) else {
            return ([whole(image, order: 30)], true)
        }
        let hoodWindow = TryOnRect(x: 0.30, y: 0.10, width: 0.40, height: 0.22)
        var hoodPixels = 0
        var hood = [UInt8](repeating: 0, count: bytes.bytes.count)
        var torso = [UInt8](repeating: 0, count: bytes.bytes.count)
        var leftSleeve = [UInt8](repeating: 0, count: bytes.bytes.count)
        var rightSleeve = [UInt8](repeating: 0, count: bytes.bytes.count)
        for y in 0..<bytes.height {
            for x in 0..<bytes.width {
                let index = (y * bytes.width + x) * 4
                guard bytes.bytes[index + 3] > 16 else { continue }
                let point = TryOnPoint(x: Double(x) / Double(canvas.width), y: Double(y) / Double(canvas.height))
                if hoodWindow.contains(point) { hoodPixels += 1 }
                if point.y < neck.y {
                    copy(bytes.bytes, index, into: &hood)
                } else if point.x < left.x {
                    copy(bytes.bytes, index, into: &leftSleeve)
                } else if point.x > right.x {
                    copy(bytes.bytes, index, into: &rightSleeve)
                } else {
                    copy(bytes.bytes, index, into: &torso)
                }
            }
        }
        guard hoodPixels > 80,
              let hoodImage = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: hood),
              let torsoImage = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: torso) else {
            return ([whole(image, order: 30)], true)
        }
        var components = [
            component("hood", .hood, .behindAvatar, 10, hoodImage),
            component("torso", .mainBody, .clothing, 30, torsoImage)
        ]
        if let sleeve = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: leftSleeve),
           (TryOnBitmap.stats(of: sleeve)?.opaqueCount ?? 0) > 80 {
            components.append(component("left-sleeve", .leftSleeve, .clothing, 40, sleeve))
        }
        if let sleeve = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: rightSleeve),
           (TryOnBitmap.stats(of: sleeve)?.opaqueCount ?? 0) > 80 {
            components.append(component("right-sleeve", .rightSleeve, .clothing, 41, sleeve))
        }
        return (components, false)
    }

    private static func splitJacket(_ image: CGImage, canvas: TryOnCanvas) -> [TryOnComponentImage] {
        guard let bytes = TryOnBitmap.rgba(from: image), let stats = TryOnBitmap.stats(of: image) else {
            return [whole(image, order: 30)]
        }
        guard stats.centerBandAlpha < 0.2 else { return [whole(image, order: 30)] }
        var left = [UInt8](repeating: 0, count: bytes.bytes.count)
        var right = [UInt8](repeating: 0, count: bytes.bytes.count)
        let mid = Double(canvas.width) / 2
        for y in 0..<bytes.height {
            for x in 0..<bytes.width {
                let index = (y * bytes.width + x) * 4
                guard bytes.bytes[index + 3] > 16 else { continue }
                if Double(x) < mid {
                    copy(bytes.bytes, index, into: &left)
                } else {
                    copy(bytes.bytes, index, into: &right)
                }
            }
        }
        guard let leftImage = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: left),
              let rightImage = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: right) else {
            return [whole(image, order: 30)]
        }
        return [
            component("left-panel", .leftFrontPanel, .clothing, 30, leftImage),
            component("right-panel", .rightFrontPanel, .clothing, 31, rightImage)
        ]
    }

    private static func splitTrousers(
        _ image: CGImage,
        anchors: [String: TryOnPoint],
        canvas: TryOnCanvas
    ) -> [TryOnComponentImage] {
        guard let crotch = anchors["crotchCenter"], let bytes = TryOnBitmap.rgba(from: image) else {
            return [whole(image, order: 20)]
        }
        var left = [UInt8](repeating: 0, count: bytes.bytes.count)
        var right = [UInt8](repeating: 0, count: bytes.bytes.count)
        var waist = [UInt8](repeating: 0, count: bytes.bytes.count)
        for y in 0..<bytes.height {
            for x in 0..<bytes.width {
                let index = (y * bytes.width + x) * 4
                guard bytes.bytes[index + 3] > 16 else { continue }
                let point = TryOnPoint(x: Double(x) / Double(canvas.width), y: Double(y) / Double(canvas.height))
                if point.y < crotch.y {
                    copy(bytes.bytes, index, into: &waist)
                } else if point.x < crotch.x {
                    copy(bytes.bytes, index, into: &left)
                } else {
                    copy(bytes.bytes, index, into: &right)
                }
            }
        }
        guard let waistImage = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: waist),
              let leftImage = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: left),
              let rightImage = TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: right) else {
            return [whole(image, order: 20)]
        }
        return [
            component("waist", .mainBody, .clothing, 20, waistImage),
            component("left-leg", .leftLeg, .clothing, 21, leftImage),
            component("right-leg", .rightLeg, .clothing, 22, rightImage)
        ]
    }

    private static func component(
        _ id: String,
        _ kind: TryOnComponentKind,
        _ depth: TryOnDepthGroup,
        _ order: Int,
        _ image: CGImage
    ) -> TryOnComponentImage {
        TryOnComponentImage(
            id: id,
            kind: kind,
            depthGroup: depth,
            renderOrder: order,
            image: image,
            bounds: normalizedBounds(of: image) ?? TryOnRect(x: 0, y: 0, width: 1, height: 1)
        )
    }

    private static func normalizedBounds(of image: CGImage) -> TryOnRect? {
        guard let stats = TryOnBitmap.stats(of: image), stats.opaqueCount > 0 else { return nil }
        return TryOnRect(
            x: Double(stats.bounds.minX) / Double(image.width),
            y: Double(stats.bounds.minY) / Double(image.height),
            width: Double(stats.bounds.width) / Double(image.width),
            height: Double(stats.bounds.height) / Double(image.height)
        )
    }

    private static func copy(_ source: [UInt8], _ index: Int, into destination: inout [UInt8]) {
        destination[index] = source[index]
        destination[index + 1] = source[index + 1]
        destination[index + 2] = source[index + 2]
        destination[index + 3] = source[index + 3]
    }

    private static func protectedChest(anchors: [String: TryOnPoint], template: TryOnTemplateID) -> TryOnRect? {
        guard template != .trousers,
              let left = anchors["leftShoulderSeam"],
              let right = anchors["rightShoulderSeam"],
              let neck = anchors["necklineCenter"],
              let hem = anchors["hemCenter"] else { return nil }
        let minX = min(left.x, right.x) + abs(right.x - left.x) * 0.2
        let width = abs(right.x - left.x) * 0.6
        let minY = neck.y
        let height = max(hem.y - neck.y, 0) * 0.45
        guard width > 0.02, height > 0.02 else { return nil }
        return TryOnRect(x: minX, y: minY, width: width, height: height)
    }

    private static func displaced(
        _ point: TryOnPoint,
        template: TryOnTemplateID,
        anchors: [String: TryOnPoint],
        landmarks: TryOnLandmarks,
        appliedShift: TryOnPoint
    ) -> (point: TryOnPoint, pulled: Bool) {
        let links = template == .trousers
            ? [("leftHip", ["leftHip"]), ("rightHip", ["rightHip"])]
            : [
                ("leftShoulderSeam", ["leftShoulderEdge", "leftShoulderJoint"]),
                ("rightShoulderSeam", ["rightShoulderEdge", "rightShoulderJoint"])
            ]
        var pull = TryOnPoint.zero
        var found = false
        for link in links {
            guard let garment = anchors[link.0] else { continue }
            guard let avatar = link.1.compactMap({ landmarks.point(named: $0) }).first else { continue }
            let distance = hypot(point.x - garment.x, point.y - garment.y)
            guard distance < 0.06 else { continue }
            let residualX = avatar.x - (garment.x + appliedShift.x)
            let residualY = avatar.y - (garment.y + appliedShift.y)
            pull.x += residualX
            pull.y += residualY
            found = true
        }
        guard found else { return (point, false) }
        let limit = TryOnVersions.maxLocalDisplacement
        pull.x = min(max(pull.x, -limit), limit)
        pull.y = min(max(pull.y, -limit), limit)
        return (TryOnPoint(x: point.x + pull.x, y: point.y + pull.y), true)
    }

    private static func median(_ values: [TryOnPoint]) -> TryOnPoint {
        TryOnPoint(x: median(values.map(\.x)), y: median(values.map(\.y)))
    }

    private static func median(_ values: [Double]) -> Double {
        let sorted = values.sorted()
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }
}
