import Foundation

// Procedural fashion mannequin: a faceless figure built from smooth lofts, standing in a relaxed A-pose.
// It stands in until the team picks a licensed 3D model. A replacement must keep the same framing:
// 1 unit tall, feet at y = 0, facing +z, because the camera and the 2D clothing overlay assume it.

struct BodyShape {
    let name: String
    var shoulders: Float = 1
    var bust: Float = 1
    var waist: Float = 1
    var hips: Float = 1
    var limbs: Float = 1

    static let presets: [BodyShape] = [
        BodyShape(name: "Classic"),
        BodyShape(name: "Slim", shoulders: 0.95, bust: 0.92, waist: 0.88, hips: 0.92, limbs: 0.88),
        BodyShape(name: "Athletic", shoulders: 1.1, bust: 1.04, waist: 1.02, hips: 0.97, limbs: 1.1),
        BodyShape(name: "Curvy", shoulders: 0.98, bust: 1.12, waist: 0.96, hips: 1.16, limbs: 1.06),
        BodyShape(name: "Full", shoulders: 1.06, bust: 1.16, waist: 1.28, hips: 1.2, limbs: 1.2)
    ]
}

struct FaceShape {
    let name: String
    var width: Float = 0.044
    var depth: Float = 0.053
    /// How much the lower face narrows toward the chin.
    var jaw: Float = 0.35
    /// How far the chin sits forward.
    var chin: Float = 0.006
    /// 0 is oval; higher is boxier.
    var squareness: Float = 0

    static let presets: [FaceShape] = [
        FaceShape(name: "Oval"),
        FaceShape(name: "Round", width: 0.047, depth: 0.054, jaw: 0.14, chin: 0.003, squareness: 0.1),
        FaceShape(name: "Heart", width: 0.046, jaw: 0.5, chin: 0.007),
        FaceShape(name: "Square", width: 0.045, jaw: 0.18, chin: 0.004, squareness: 0.45)
    ]
}

enum HairStyle: Int, CaseIterable {
    case bald, short, long, bun, curly, ponytail

    var title: String {
        switch self {
        case .bald: return "None"
        case .short: return "Short"
        case .long: return "Long"
        case .bun: return "Bun"
        case .curly: return "Curly"
        case .ponytail: return "Ponytail"
        }
    }

    /// Where the hair stops, in half turns down from the crown: at the forehead and at the nape.
    fileprivate var hairline: (front: Float, back: Float)? {
        switch self {
        case .bald: return nil
        case .short: return (0.30, 0.72)
        case .long: return (0.30, 0.85)
        case .bun, .ponytail: return (0.30, 0.70)
        case .curly: return (0.27, 0.78)
        }
    }

    /// How far the hair sits outside the head at the sides; the crown gets a little extra.
    fileprivate var volume: Float {
        switch self {
        case .bald: return 0
        case .curly: return 0.010
        default: return 0.006
        }
    }
}

enum BangsStyle: Int, CaseIterable {
    case open, straight, side, curtain

    var title: String {
        switch self {
        case .open: return "None"
        case .straight: return "Straight"
        case .side: return "Side"
        case .curtain: return "Curtain"
        }
    }

    /// How far down the fringe reaches (phi from the crown) at `position` across the forehead, from -1 to 1.
    fileprivate func fringe(at position: Float) -> Float {
        switch self {
        case .open: return 0
        case .straight: return 0.42 * .pi
        case .side: return (0.31 + 0.13 * (position + 1) / 2) * .pi
        case .curtain: return (0.31 + 0.13 * pow(abs(position), 1.3)) * .pi
        }
    }
}

enum Mannequin {
    static let headCenter: SIMD3<Float> = [0, 0.9375, -0.003]
    static let headHeight: Float = 0.0625

    /// Body, neck and head as one mesh.
    static func body(_ shape: BodyShape, face: FaceShape) -> MannequinMesh {
        var mesh = torso(shape)
        mesh.append(neck(shape))
        mesh.append(head(face))
        for side: Float in [-1, 1] {
            mesh.append(leg(shape, side: side))
            mesh.append(foot(shape, side: side))
            mesh.append(arm(shape, side: side))
            mesh.append(hand(shape, side: side))
        }
        return mesh
    }

    /// Hair and bangs as one mesh (empty when bald with no bangs).
    static func hair(_ style: HairStyle, bangs: BangsStyle, face: FaceShape, body: BodyShape) -> MannequinMesh {
        var mesh = MannequinMesh()
        if let hairline = style.hairline {
            mesh.append(hairCap(face, style: style, hairline: hairline))
        }
        switch style {
        case .long: mesh.append(longHair(body))
        case .bun: mesh.append(bun())
        case .ponytail: mesh.append(ponytail())
        case .bald, .short, .curly: break
        }
        if bangs != .open {
            mesh.append(fringe(face, style: bangs, over: style))
        }
        return mesh
    }

    /// A point on the head at the given angles, or with `inflate`, on a shell that far outside it.
    /// Sharing this between head and hair keeps the hair from ever cutting into the head.
    static func headPoint(_ face: FaceShape, theta: Float, phi: Float, inflate: Float = 0) -> SIMD3<Float> {
        let across = sin(phi) * sin(theta)
        let upward = cos(phi)
        let forward = sin(phi) * cos(theta)
        let exponent = 1 - 0.4 * face.squareness
        let chinward = max(0, -upward) * max(0, -upward)
        let frontAngle = theta.remainder(dividingBy: 2 * .pi)
        let nose = 0.004 * exp(-pow(frontAngle / 0.2, 2)) * exp(-pow((upward + 0.12) / 0.2, 2)) * max(forward, 0)

        let sideways = (face.width + inflate) * curved(across, exponent) * (1 - face.jaw * chinward)
        let vertical = (headHeight + inflate) * upward
        let frontways = (face.depth + inflate) * curved(forward, exponent) * (1 - 0.5 * face.jaw * chinward)
        return headCenter + SIMD3(sideways, vertical, frontways + face.chin * chinward + nose)
    }

    // MARK: - Body parts

    private static func torso(_ shape: BodyShape) -> MannequinMesh {
        let lowerWaist = (shape.hips + shape.waist) / 2
        let upperWaist = (shape.waist + shape.bust) / 2
        let keys = [
            LoftRing([0, 0.455, -0.004], width: 0.060 * shape.hips, depth: 0.044 * shape.hips),
            LoftRing([0, 0.5, -0.007], width: 0.091 * shape.hips, depth: 0.056 * shape.hips),
            LoftRing([0, 0.535, -0.006], width: 0.093 * shape.hips, depth: 0.058 * shape.hips),
            LoftRing([0, 0.585, -0.003], width: 0.077 * lowerWaist, depth: 0.050 * lowerWaist),
            LoftRing([0, 0.635, 0], width: 0.065 * shape.waist, depth: 0.045 * shape.waist),
            LoftRing([0, 0.69, 0.003], width: 0.076 * upperWaist, depth: 0.050 * upperWaist),
            LoftRing([0, 0.735, 0.006], width: 0.085 * shape.bust, depth: 0.056 * shape.bust),
            LoftRing([0, 0.78, 0.002], width: 0.094 * shape.shoulders, depth: 0.050 * shape.bust),
            LoftRing([0, 0.81, -0.003], width: 0.096 * shape.shoulders, depth: 0.042 * shape.bust)
        ]
        return MannequinGeometry.loft(keys, sides: 40, caps: (start: 0.015, end: 0.022))
    }

    private static func neck(_ shape: BodyShape) -> MannequinMesh {
        let scale = (1 + shape.limbs) / 2
        // The wide base slopes into the shoulders like a trapezius.
        let keys = [
            LoftRing([0, 0.8, -0.01], width: 0.046 * scale, depth: 0.034 * scale),
            LoftRing([0, 0.83, -0.007], width: 0.029 * scale, depth: 0.027 * scale),
            LoftRing([0, 0.86, -0.004], width: 0.023 * scale, depth: 0.025 * scale),
            LoftRing([0, 0.89, -0.001], width: 0.021 * scale, depth: 0.023 * scale)
        ]
        return MannequinGeometry.loft(keys, sides: 24, caps: (start: 0.01, end: 0.012))
    }

    private static func head(_ face: FaceShape) -> MannequinMesh {
        MannequinGeometry.surface(columns: 64, rows: 40, point: { theta, phi in
            headPoint(face, theta: theta, phi: phi)
        })
    }

    private static func leg(_ shape: BodyShape, side: Float) -> MannequinMesh {
        let thigh = (shape.hips + shape.limbs) / 2
        let limbs = shape.limbs
        // Keep a sliver of space between the thighs.
        let hipX = max(0.05 * shape.hips, 0.046 * thigh + 0.003)
        // The top ring starts inside the torso so the hip line runs straight into the thigh.
        let keys = [
            LoftRing([side * hipX, 0.53, -0.005], width: 0.040 * thigh, depth: 0.044 * thigh),
            LoftRing([side * hipX, 0.47, -0.003], width: 0.048 * thigh, depth: 0.050 * thigh),
            LoftRing([side * hipX * 0.96, 0.38, 0], width: 0.040 * thigh, depth: 0.042 * thigh),
            LoftRing([side * 0.044, 0.285, 0.002], width: 0.026 * limbs, depth: 0.028 * limbs),
            LoftRing([side * 0.044, 0.21, -0.005], width: 0.030 * limbs, depth: 0.033 * limbs),
            LoftRing([side * 0.044, 0.12, -0.002], width: 0.021 * limbs, depth: 0.022 * limbs),
            LoftRing([side * 0.045, 0.06, -0.004], width: 0.016 * limbs, depth: 0.017 * limbs),
            LoftRing([side * 0.045, 0.038, -0.006], width: 0.016 * limbs, depth: 0.018 * limbs)
        ]
        return MannequinGeometry.loft(keys, sides: 28, caps: (start: 0.03, end: 0.014))
    }

    private static func foot(_ shape: BodyShape, side: Float) -> MannequinMesh {
        let size = (1 + shape.limbs) / 2
        let footX = side * 0.045
        let keys = [
            LoftRing([footX, 0.018, -0.022], width: 0.016 * size, depth: 0.017),
            LoftRing([footX, 0.017, 0.012], width: 0.022 * size, depth: 0.015),
            LoftRing([footX * 1.02, 0.012, 0.055], width: 0.026 * size, depth: 0.011),
            LoftRing([footX * 1.05, 0.009, 0.082], width: 0.022 * size, depth: 0.008)
        ]
        return MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.012, end: 0.012), reference: [0, 1, 0])
    }

    /// Wrists sit a little wider on fuller hips so the hands clear them.
    private static func wristX(_ shape: BodyShape) -> Float {
        0.1 * shape.shoulders + 0.025 + max(0, shape.hips - 1) * 0.06
    }

    private static func arm(_ shape: BodyShape, side: Float) -> MannequinMesh {
        let limbs = shape.limbs
        let shoulderX = 0.1 * shape.shoulders
        let keys = [
            LoftRing([side * shoulderX, 0.8, -0.004], width: 0.026 * limbs, depth: 0.028 * limbs),
            LoftRing([side * (shoulderX + 0.008), 0.72, -0.006], width: 0.022 * limbs, depth: 0.024 * limbs),
            LoftRing([side * (shoulderX + 0.015), 0.635, -0.01], width: 0.018 * limbs, depth: 0.019 * limbs),
            LoftRing([side * (shoulderX + 0.019), 0.585, -0.006], width: 0.019 * limbs, depth: 0.019 * limbs),
            LoftRing([side * wristX(shape), 0.505, 0], width: 0.0135 * limbs, depth: 0.012 * limbs)
        ]
        return MannequinGeometry.loft(keys, sides: 24, caps: (start: 0.024 * limbs, end: 0.01))
    }

    /// A relaxed mitten hand, palm facing the thigh.
    private static func hand(_ shape: BodyShape, side: Float) -> MannequinMesh {
        let size = (1 + shape.limbs) / 2
        let wrist = wristX(shape)
        let keys = [
            LoftRing([side * wrist, 0.512, 0], width: 0.011 * size, depth: 0.010 * size),
            LoftRing([side * (wrist + 0.002), 0.485, 0.002], width: 0.009 * size, depth: 0.019 * size),
            LoftRing([side * (wrist + 0.003), 0.455, 0.003], width: 0.0075 * size, depth: 0.018 * size),
            LoftRing([side * (wrist + 0.003), 0.43, 0.004], width: 0.006 * size, depth: 0.013 * size)
        ]
        return MannequinGeometry.loft(keys, sides: 16, caps: (start: 0.006, end: 0.012))
    }

    // MARK: - Hair

    /// How far the hair surface sits outside the head at the given angles, before the hairline taper.
    private static func hairHeight(_ style: HairStyle, theta: Float, phi: Float) -> Float {
        let crown = 0.004 * max(cos(phi), 0)
        let curl: Float = style == .curly ? 0.002 * (1 + sin(theta * 9) * sin(phi * 11)) : 0
        return style.volume + crown + curl
    }

    private static func hairCap(
        _ face: FaceShape, style: HairStyle, hairline: (front: Float, back: Float)
    ) -> MannequinMesh {
        let limit = { (theta: Float) -> Float in
            .pi * (hairline.front + (hairline.back - hairline.front) * (1 - cos(theta)) / 2)
        }
        return MannequinGeometry.surface(
            columns: 64,
            rows: 24,
            point: { theta, phi in
                // Thin out toward the hairline so the hair meets the skin without a hard lip.
                let taper = 1 - pow(phi / limit(theta), 8)
                let height = max(hairHeight(style, theta: theta, phi: phi) * taper, 0.0008)
                return headPoint(face, theta: theta, phi: phi, inflate: height)
            },
            phiLimit: limit
        )
    }

    private static func fringe(_ face: FaceShape, style: BangsStyle, over hair: HairStyle) -> MannequinMesh {
        let reach: Float = 1.25
        return MannequinGeometry.surface(
            columns: 24,
            rows: 12,
            thetaRange: -reach...reach,
            point: { theta, phi in
                headPoint(face, theta: theta, phi: phi, inflate: hairHeight(hair, theta: theta, phi: phi) + 0.0025)
            },
            phiLimit: { theta in style.fringe(at: theta / reach) }
        )
    }

    /// A panel falling down the back. It rests against the torso: a slight overlap hides inside the body,
    /// while a gap would show from the side.
    private static func longHair(_ body: BodyShape) -> MannequinMesh {
        let backZ = min(0.006 - 0.056 * body.bust, 0.002 - 0.050 * body.bust) - 0.009
        let keys = [
            LoftRing([0, 0.925, -0.038], width: 0.052, depth: 0.026),
            LoftRing([0, 0.875, -0.044], width: 0.056, depth: 0.02),
            LoftRing([0, 0.83, -0.052], width: 0.058, depth: 0.015),
            LoftRing([0, 0.785, backZ + 0.002], width: 0.058, depth: 0.011),
            LoftRing([0, 0.725, backZ], width: 0.054, depth: 0.010),
            LoftRing([0, 0.675, backZ + 0.003], width: 0.046, depth: 0.008)
        ]
        return MannequinGeometry.loft(keys, sides: 28, caps: (start: 0.012, end: 0.012))
    }

    private static func bun() -> MannequinMesh {
        ellipsoid(center: [0, 0.992, -0.045], radii: [0.024, 0.021, 0.022])
    }

    private static func ponytail() -> MannequinMesh {
        var mesh = ellipsoid(center: [0, 0.968, -0.06], radii: [0.009, 0.009, 0.009])
        let keys = [
            LoftRing([0, 0.972, -0.064], width: 0.012, depth: 0.012),
            LoftRing([0, 0.95, -0.077], width: 0.016, depth: 0.015),
            LoftRing([0, 0.9, -0.08], width: 0.014, depth: 0.012),
            LoftRing([0, 0.85, -0.075], width: 0.010, depth: 0.009),
            LoftRing([0, 0.815, -0.068], width: 0.006, depth: 0.006)
        ]
        mesh.append(MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.008, end: 0.01)))
        return mesh
    }

    private static func ellipsoid(center: SIMD3<Float>, radii: SIMD3<Float>) -> MannequinMesh {
        MannequinGeometry.surface(columns: 24, rows: 16, point: { theta, phi in
            center + radii * SIMD3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta))
        })
    }

    /// Signed power: exponents below 1 push an ellipse toward a rounded square.
    private static func curved(_ value: Float, _ exponent: Float) -> Float {
        value < 0 ? -pow(-value, exponent) : pow(value, exponent)
    }
}
