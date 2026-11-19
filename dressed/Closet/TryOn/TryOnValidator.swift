import CoreGraphics
import Foundation

enum TryOnValidator {
    static func garment(
        image: CGImage,
        canvas: TryOnCanvas,
        template: TryOnTemplateID,
        anchors: [String: TryOnPoint],
        mesh: TryOnMesh,
        components: [TryOnComponentImage],
        landmarks: TryOnLandmarks,
        alignmentNote: String?
    ) -> TryOnValidationReport {
        var checks: [TryOnCheck] = []
        checks.append(check("canvas", .required, image.width == canvas.width && image.height == canvas.height,
                            "Fitted image matches the \(canvas.width) by \(canvas.height) canvas."))
        let stats = TryOnBitmap.stats(of: image)
        checks.append(check("opaque", .required, (stats?.opaqueFraction ?? 0) > 0.01,
                            "The garment image contains visible fabric."))
        checks.append(check("not-empty-mask", .required, (stats?.opaqueFraction ?? 1) < 0.98,
                            "The garment is not an opaque rectangle covering the canvas."))
        let clipped = (stats?.topBorderOpaque ?? 0) > 40
            || (stats?.leftBorderOpaque ?? 0) > 40
            || (stats?.rightBorderOpaque ?? 0) > 40
        checks.append(check("clip", .review, !clipped, "The garment is inside the canvas."))
        for name in template.requiredAnchors {
            let point = anchors[name]
            let valid = point?.isFinite == true && point.map { (0...1).contains($0.x) && (0...1).contains($0.y) } == true
            checks.append(check("anchor-\(name)", .required, valid, "Anchor \(name) is present and inside the canvas."))
        }
        checks.append(contentsOf: meshChecks(mesh))
        let sameCanvas = components.allSatisfy { $0.image.width == canvas.width && $0.image.height == canvas.height }
        checks.append(check("components", .required, !components.isEmpty && sameCanvas,
                            "Components share the canonical canvas."))
        if template == .openJacket {
            let open = (stats?.centerBandAlpha ?? 1) < 0.25
            checks.append(check("opening", .required, open, "The jacket center stays transparent."))
        }
        if template == .trousers {
            let separated = (stats?.centerBandAlpha ?? 1) < 0.55
            checks.append(check("leg-gap", .review, separated, "The trouser legs stay separated."))
        }
        if template.preserveSilhouette, let left = anchors["leftShoulderSeam"], let right = anchors["rightShoulderSeam"] {
            let garmentWidth = abs(right.x - left.x)
            let avatarWidth: Double
            if let avatarLeft = landmarks.leftShoulderJoint ?? landmarks.leftShoulderEdge,
               let avatarRight = landmarks.rightShoulderJoint ?? landmarks.rightShoulderEdge {
                avatarWidth = abs(avatarRight.x - avatarLeft.x)
            } else {
                avatarWidth = 0
            }
            let oversized = avatarWidth == 0 || garmentWidth > avatarWidth * 1.02
            checks.append(check("oversized", .review, oversized, "The oversized silhouette is wider than the shoulders."))
        }
        if let neck = landmarks.neckCenter, template == .tShirt, let stats {
            let above = opaqueFraction(image, above: neck.y)
            checks.append(check("neck", .review, above < 0.12, "The shirt stays below the neck."))
        }
        if let alignmentNote {
            checks.append(check("alignment", .review, false, alignmentNote))
        }
        return report(checks)
    }

    static func avatar(image: CGImage, canvas: TryOnCanvas, landmarks: TryOnLandmarks) -> TryOnValidationReport {
        var checks: [TryOnCheck] = []
        checks.append(check("canvas", .required, image.width == canvas.width && image.height == canvas.height,
                            "Avatar image matches the canonical canvas."))
        let fraction = TryOnBitmap.stats(of: image)?.opaqueFraction ?? 0
        checks.append(check("visible", .required, fraction > 0.01, "The avatar image is visible."))
        let hasTorso = landmarks.neckCenter != nil || landmarks.chestCenter != nil || landmarks.leftShoulderJoint != nil
        checks.append(check("landmarks", .review, hasTorso, "A neck or shoulder landmark was detected."))
        return report(checks)
    }

    private static func meshChecks(_ mesh: TryOnMesh) -> [TryOnCheck] {
        let count = mesh.vertices.count
        let indexOK = !mesh.indices.isEmpty && mesh.indices.count.isMultiple(of: 3)
            && mesh.indices.allSatisfy { Int($0) < count }
        var coordinatesOK = true
        var protectedOK = true
        var displacementOK = true
        for vertex in mesh.vertices {
            let position = TryOnPoint(x: Double(vertex.x), y: Double(vertex.y))
            let uv = TryOnPoint(x: Double(vertex.u), y: Double(vertex.v))
            if !position.isFinite || !uv.isFinite || uv.x < -0.01 || uv.x > 1.01 || uv.y < -0.01 || uv.y > 1.01 {
                coordinatesOK = false
            }
            let distance = hypot(position.x - uv.x, position.y - uv.y)
            if vertex.constraint == .protected && distance > 0.01 { protectedOK = false }
            if distance > TryOnVersions.maxLocalDisplacement + 0.005 { displacementOK = false }
        }
        return [
            check("mesh-index", .required, indexOK, "Mesh indices form triangles inside the vertex list."),
            check("mesh-coordinates", .required, coordinatesOK, "Mesh coordinates are finite and UVs stay in range."),
            check("mesh-protected", .required, protectedOK, "Protected graphics were not moved."),
            check("mesh-limit", .required, displacementOK, "Local deformation stays within the template limit.")
        ]
    }

    private static func opaqueFraction(_ image: CGImage, above y: Double) -> Double {
        guard let bytes = TryOnBitmap.rgba(from: image) else { return 0 }
        let limit = Int(y * Double(bytes.height))
        var aboveCount = 0
        var total = 0
        for row in 0..<bytes.height {
            for column in 0..<bytes.width {
                let alpha = bytes.bytes[(row * bytes.width + column) * 4 + 3]
                guard alpha > 16 else { continue }
                total += 1
                if row < limit { aboveCount += 1 }
            }
        }
        guard total > 0 else { return 0 }
        return Double(aboveCount) / Double(total)
    }

    private static func check(_ id: String, _ level: TryOnCheckLevel, _ passed: Bool, _ message: String) -> TryOnCheck {
        TryOnCheck(id: id, level: level, passed: passed, message: passed ? message : message)
    }

    private static func report(_ checks: [TryOnCheck]) -> TryOnValidationReport {
        let status: String
        if checks.contains(where: { $0.level == .required && !$0.passed }) {
            status = "failed"
        } else if checks.contains(where: { $0.level == .review && !$0.passed }) {
            status = "needs_review"
        } else {
            status = "passed"
        }
        return TryOnValidationReport(status: status, checks: checks)
    }
}
