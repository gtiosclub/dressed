import Foundation

// Procedural fashion mannequin: a figure built from smooth lofts, standing in a relaxed A-pose.
// It stands in until the team picks a licensed 3D model. A replacement must keep the same framing:
// 1 unit tall, feet at y = 0, facing +z, because the camera and the 2D clothing overlay assume it.

enum AvatarGender: Int, CaseIterable {
    case female, male

    var title: String { self == .female ? "Female" : "Male" }
    var symbol: String { self == .female ? "figure.stand.dress" : "figure.stand" }
}

struct BodyShape {
    let name: String
    var shoulders: Float = 1
    var bust: Float = 1
    var waist: Float = 1
    var hips: Float = 1
    var limbs: Float = 1
    var neck: Float = 1

    static func presets(for gender: AvatarGender) -> [BodyShape] {
        switch gender {
        case .female: return female
        case .male: return male
        }
    }

    private static let female: [BodyShape] = [
        BodyShape(name: "Classic"),
        BodyShape(name: "Slim", shoulders: 0.95, bust: 0.92, waist: 0.88, hips: 0.92, limbs: 0.88),
        BodyShape(name: "Athletic", shoulders: 1.1, bust: 1.04, waist: 1.02, hips: 0.97, limbs: 1.1),
        BodyShape(name: "Curvy", shoulders: 0.98, bust: 1.12, waist: 0.96, hips: 1.16, limbs: 1.06),
        BodyShape(name: "Full", shoulders: 1.06, bust: 1.16, waist: 1.28, hips: 1.2, limbs: 1.2)
    ]

    // Broader shoulders, straighter waist, narrower hips, thicker neck and limbs.
    private static let male: [BodyShape] = [
        BodyShape(name: "Classic", shoulders: 1.16, bust: 1.02, waist: 1.12, hips: 0.90, limbs: 1.10, neck: 1.25),
        BodyShape(name: "Lean", shoulders: 1.08, bust: 0.94, waist: 1.00, hips: 0.84, limbs: 0.98, neck: 1.15),
        BodyShape(name: "Athletic", shoulders: 1.26, bust: 1.10, waist: 1.08, hips: 0.90, limbs: 1.22, neck: 1.35),
        BodyShape(name: "Broad", shoulders: 1.24, bust: 1.14, waist: 1.26, hips: 0.98, limbs: 1.20, neck: 1.35),
        BodyShape(name: "Heavy", shoulders: 1.20, bust: 1.20, waist: 1.50, hips: 1.10, limbs: 1.30, neck: 1.40)
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

    static func presets(for gender: AvatarGender) -> [FaceShape] {
        switch gender {
        case .female: return base
        case .male: return base.map { $0.masculine() }
        }
    }

    private static let base: [FaceShape] = [
        FaceShape(name: "Oval"),
        FaceShape(name: "Round", width: 0.047, depth: 0.054, jaw: 0.14, chin: 0.003, squareness: 0.1),
        FaceShape(name: "Heart", width: 0.046, jaw: 0.5, chin: 0.007),
        FaceShape(name: "Square", width: 0.045, jaw: 0.18, chin: 0.004, squareness: 0.45)
    ]

    /// Wider, squarer, with a stronger jaw and chin.
    private func masculine() -> FaceShape {
        var face = self
        face.width += 0.003
        face.depth += 0.001
        face.jaw *= 0.6
        face.chin += 0.002
        face.squareness = min(face.squareness + 0.15, 1)
        return face
    }
}

struct EyeShape {
    let name: String
    /// Half-width and half-height of the eye opening.
    var width: Float = 0.0085
    var height: Float = 0.0042
    /// How far each eye sits from the centerline, as an angle around the head.
    var spacing: Float = 0.47

    static let presets: [EyeShape] = [
        EyeShape(name: "Almond"),
        EyeShape(name: "Round", width: 0.0075, height: 0.0060),
        EyeShape(name: "Narrow", width: 0.0090, height: 0.0032, spacing: 0.46),
        EyeShape(name: "Large", width: 0.0095, height: 0.0065, spacing: 0.49),
        EyeShape(name: "Wide-set", width: 0.0080, height: 0.0045, spacing: 0.58)
    ]
}

struct NoseShape {
    let name: String
    /// Half-width of the tip, half-length of the bridge, and how far the tip sticks out.
    var width: Float = 0.0065
    var length: Float = 0.0105
    var projection: Float = 0.0095

    static let presets: [NoseShape] = [
        NoseShape(name: "Straight"),
        NoseShape(name: "Small", width: 0.0055, length: 0.0090, projection: 0.0075),
        NoseShape(name: "Button", width: 0.0060, length: 0.0075, projection: 0.0070),
        NoseShape(name: "Wide", width: 0.0090, length: 0.0095, projection: 0.0090),
        NoseShape(name: "Pointed", width: 0.0058, length: 0.0120, projection: 0.0125)
    ]
}

struct LipShape {
    let name: String
    /// Half-width of the mouth and thickness of the upper and lower lip.
    var width: Float = 0.0095
    var upper: Float = 0.0025
    var lower: Float = 0.0035

    static let presets: [LipShape] = [
        LipShape(name: "Medium"),
        LipShape(name: "Thin", width: 0.0085, upper: 0.0017, lower: 0.0023),
        LipShape(name: "Full", width: 0.0105, upper: 0.0035, lower: 0.0050),
        LipShape(name: "Wide", width: 0.0125, upper: 0.0025, lower: 0.0038),
        LipShape(name: "Bow", width: 0.0090, upper: 0.0036, lower: 0.0032)
    ]
}

enum HairStyle: Int, CaseIterable {
    // New styles go at the end so existing rawValues stay the same.
    case bald, short, long, bun, curly, ponytail, buzz, bob, pixie, afro, braid, pigtails, mohawk, wavy

    var title: String {
        switch self {
        case .bald: return "None"
        case .short: return "Short"
        case .long: return "Long"
        case .bun: return "Bun"
        case .curly: return "Curly"
        case .ponytail: return "Ponytail"
        case .buzz: return "Buzz"
        case .bob: return "Bob"
        case .pixie: return "Pixie"
        case .afro: return "Afro"
        case .braid: return "Braid"
        case .pigtails: return "Pigtails"
        case .mohawk: return "Mohawk"
        case .wavy: return "Wavy"
        }
    }

    /// Where the hair stops, in half turns down from the crown: at the forehead, at the nape,
    /// and how much further down (or up, if negative) it reaches over the ears.
    /// Nil means no scalp cap at all.
    fileprivate var hairline: (front: Float, back: Float, side: Float)? {
        switch self {
        case .bald, .mohawk: return nil
        case .short: return (0.30, 0.72, 0)
        case .long: return (0.30, 0.85, 0)
        case .wavy: return (0.30, 0.84, 0.08)
        case .bun, .ponytail, .braid, .pigtails: return (0.30, 0.70, 0)
        case .curly: return (0.27, 0.78, 0)
        case .buzz: return (0.32, 0.66, 0)
        case .bob: return (0.30, 0.80, 0.16)
        case .pixie: return (0.31, 0.64, -0.03)
        case .afro: return (0.27, 0.78, 0.02)
        }
    }

    /// How far the hair sits outside the head at the sides; the crown gets a little extra.
    fileprivate var volume: Float {
        switch self {
        case .bald: return 0
        case .curly: return 0.010
        case .buzz: return 0.002
        case .afro: return 0.028
        case .bob: return 0.010
        case .pixie: return 0.005
        case .wavy: return 0.009
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

    // Where the features sit on the face, as angles down from the crown.
    private static let eyePhi: Float = 1.40
    private static let nosePhi: Float = 1.671
    private static let lipsPhi: Float = 2.004

    /// Body, neck, head and nose as one skin mesh.
    static func body(_ shape: BodyShape, face: FaceShape, nose: NoseShape) -> MannequinMesh {
        var mesh = torso(shape)
        mesh.append(neck(shape))
        mesh.append(head(face))
        //mesh.append(noseMesh(face, nose))
        for side: Float in [-1, 1] {
            mesh.append(leg(shape, side: side))
            mesh.append(foot(shape, side: side))
            mesh.append(arm(shape, side: side))
            mesh.append(hand(shape, side: side))
        }
        return mesh
    }

    /// Torso, neck, head, nose and arms only (used for option previews).
    static func bust(_ shape: BodyShape, face: FaceShape, nose: NoseShape) -> MannequinMesh {
        var mesh = torso(shape)
        mesh.append(neck(shape))
        mesh.append(head(face))
        //mesh.append(noseMesh(face, nose))
        for side: Float in [-1, 1] { mesh.append(arm(shape, side: side)) }
        return mesh
    }

    /// Hair and bangs as one mesh (empty when bald: bald means no hair at all, bangs included).
    static func hair(_ style: HairStyle, bangs: BangsStyle, face: FaceShape, body: BodyShape) -> MannequinMesh {
        var mesh = MannequinMesh()
        if style == .bald { return mesh }
        if let hairline = style.hairline {
            mesh.append(hairCap(face, style: style, hairline: hairline))
        }
        switch style {
        case .long, .wavy: mesh.append(longHair(body))
        case .bun: mesh.append(bun())
        case .ponytail: mesh.append(ponytail())
        case .braid: mesh.append(braid(body))
        case .pigtails: mesh.append(pigtails())
        case .mohawk: mesh.append(mohawk(face))
        case .bald, .short, .curly, .buzz, .bob, .pixie, .afro: break
        }
        if bangs != .open && style != .mohawk {
            mesh.append(fringe(face, style: bangs, over: style))
        }
        return mesh
    }

    // MARK: - Face features (separate meshes: each gets its own color)

    static func eyeWhites(face: FaceShape, eye: EyeShape) -> MannequinMesh {
        MannequinMesh()
    }

    static func irises(face: FaceShape, eye: EyeShape) -> MannequinMesh {
        MannequinMesh()
    }

    static func pupils(face: FaceShape, eye: EyeShape) -> MannequinMesh {
        MannequinMesh()
    }

    static func lips(face: FaceShape, shape: LipShape) -> MannequinMesh {
        MannequinMesh()
    }

    /// A point on the head at the given angles, or with `inflate`, on a shell that far outside it.
    /// Sharing this between head and hair keeps the hair from ever cutting into the head.
    static func headPoint(_ face: FaceShape, theta: Float, phi: Float, inflate: Float = 0) -> SIMD3<Float> {
        let across = sin(phi) * sin(theta)
        let upward = cos(phi)
        let forward = sin(phi) * cos(theta)
        let exponent = 1 - 0.4 * face.squareness
        let chinward = max(0, -upward) * max(0, -upward)

        let sideways = (face.width + inflate) * curved(across, exponent) * (1 - face.jaw * chinward)
        let vertical = (headHeight + inflate) * upward
        let frontways = (face.depth + inflate) * curved(forward, exponent) * (1 - 0.5 * face.jaw * chinward)
        return headCenter + SIMD3(sideways, vertical, frontways + face.chin * chinward)
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
        let scale = (1 + shape.limbs) / 2 * shape.neck
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

    /// A bridge and a rounded tip, both half sunk into the face.
    private static func noseMesh(_ face: FaceShape, _ shape: NoseShape) -> MannequinMesh {
        let base = headPoint(face, theta: 0, phi: nosePhi)
        var mesh = ellipsoid(
            center: base + [0, shape.length * 0.35, shape.projection * 0.10],
            radii: [shape.width * 0.55, shape.length, shape.projection * 0.5]
        )
        mesh.append(ellipsoid(
            center: base + [0, -shape.length * 0.55, shape.projection * 0.35],
            radii: [shape.width, shape.width * 0.85, shape.projection * 0.6]
        ))
        return mesh
    }

    /// One flat dome per eye, turned to face along the surface where it sits.
    private static func eyeLayer(
        _ face: FaceShape, _ eye: EyeShape, width: Float, height: Float, depth: Float, push: Float
    ) -> MannequinMesh {
        var mesh = MannequinMesh()
        for side: Float in [-1, 1] {
            let theta = side * eye.spacing
            let anchor = headPoint(face, theta: theta, phi: eyePhi)
            let outward = SIMD3<Float>(sin(theta), 0, cos(theta))
            mesh.append(ellipsoid(center: anchor + outward * push, radii: [width, height, depth], yaw: theta))
        }
        return mesh
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

    /// A blocky mitten-style hand with a visible palm and thumb knuckle.
    private static func hand(_ shape: BodyShape, side: Float) -> MannequinMesh {
        let size = (1 + shape.limbs) / 2
        let wrist = wristX(shape)
        var mesh = MannequinMesh()

        // Palm — wide oval, clearly bigger than the wrist so it reads as a hand
        let palmKeys = [
            LoftRing([side * wrist,           0.510, 0.000], width: 0.013 * size, depth: 0.013 * size),
            LoftRing([side * (wrist + 0.002), 0.490, 0.002], width: 0.016 * size, depth: 0.022 * size),
            LoftRing([side * (wrist + 0.003), 0.465, 0.004], width: 0.017 * size, depth: 0.024 * size),
            LoftRing([side * (wrist + 0.003), 0.445, 0.005], width: 0.016 * size, depth: 0.022 * size),
            LoftRing([side * (wrist + 0.002), 0.430, 0.005], width: 0.014 * size, depth: 0.018 * size),
            LoftRing([side * (wrist + 0.001), 0.415, 0.004], width: 0.011 * size, depth: 0.013 * size)
        ]
        mesh.append(MannequinGeometry.loft(palmKeys, sides: 20, caps: (start: 0.008, end: 0.014)))

        // Thumb — short stubby oval protruding sideways off the upper palm
        let thumbDir: Float = side
        let thumbKeys = [
            LoftRing([side * (wrist + 0.003), 0.490, 0.003],
                     width: 0.009 * size, depth: 0.010 * size),
            LoftRing([side * (wrist + 0.002) + thumbDir * 0.010 * size, 0.483, 0.005],
                     width: 0.008 * size, depth: 0.009 * size),
            LoftRing([side * (wrist + 0.001) + thumbDir * 0.017 * size, 0.475, 0.006],
                     width: 0.006 * size, depth: 0.007 * size)
        ]
        mesh.append(MannequinGeometry.loft(thumbKeys, sides: 14, caps: (start: 0.005, end: 0.007)))

        return mesh
    }

    // MARK: - Hair

    /// How far the hair surface sits outside the head at the given angles, before the hairline taper.
    private static func hairHeight(_ style: HairStyle, theta: Float, phi: Float) -> Float {
        let crown = 0.004 * max(cos(phi), 0)
        let texture: Float
        switch style {
        case .curly: texture = 0.002 * (1 + sin(theta * 9) * sin(phi * 11))
        case .afro: texture = 0.003 * (1 + sin(theta * 12) * sin(phi * 14))
        case .wavy: texture = 0.0025 * (1 + sin(phi * 16))
        default: texture = 0
        }
        return style.volume + crown + texture
    }

    private static func hairCap(
        _ face: FaceShape, style: HairStyle, hairline: (front: Float, back: Float, side: Float)
    ) -> MannequinMesh {
        let limit = { (theta: Float) -> Float in
            let blend = (1 - cos(theta)) / 2
            return .pi * (hairline.front + (hairline.back - hairline.front) * blend + hairline.side * sin(theta) * sin(theta))
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

    /// Where the back of the torso sits, so hanging hair rests against it instead of floating or cutting in.
    private static func backOfTorso(_ body: BodyShape) -> Float {
        min(0.006 - 0.056 * body.bust, 0.002 - 0.050 * body.bust)
    }

    /// A panel falling down the back. It rests against the torso: a slight overlap hides inside the body,
    /// while a gap would show from the side.
    private static func longHair(_ body: BodyShape) -> MannequinMesh {
        let backZ = backOfTorso(body) - 0.009
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

    private static func braid(_ body: BodyShape) -> MannequinMesh {
        let backZ = backOfTorso(body) - 0.012
        let keys = [
            LoftRing([0, 0.94, -0.048], width: 0.015, depth: 0.013),
            LoftRing([0, 0.885, -0.064], width: 0.015, depth: 0.014),
            LoftRing([0, 0.83, backZ - 0.004], width: 0.014, depth: 0.014),
            LoftRing([0, 0.76, backZ - 0.004], width: 0.013, depth: 0.013),
            LoftRing([0, 0.69, backZ - 0.003], width: 0.011, depth: 0.011),
            LoftRing([0, 0.63, backZ - 0.002], width: 0.008, depth: 0.008)
        ]
        return MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.01, end: 0.012))
    }

    private static func pigtails() -> MannequinMesh {
        var mesh = MannequinMesh()
        for side: Float in [-1, 1] {
            mesh.append(ellipsoid(center: [side * 0.047, 0.955, -0.02], radii: [0.008, 0.008, 0.008]))
            let keys = [
                LoftRing([side * 0.050, 0.952, -0.022], width: 0.011, depth: 0.011),
                LoftRing([side * 0.062, 0.915, -0.026], width: 0.014, depth: 0.013),
                LoftRing([side * 0.066, 0.875, -0.028], width: 0.013, depth: 0.012),
                LoftRing([side * 0.062, 0.842, -0.026], width: 0.009, depth: 0.009)
            ]
            mesh.append(MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.008, end: 0.012)))
        }
        return mesh
    }

    /// A ridge of hair from forehead to nape. Nothing on the sides.
    private static func mohawk(_ face: FaceShape) -> MannequinMesh {
        var stations: [(theta: Float, phi: Float)] = []
        for step in 0...4 {
            stations.append((0, Float.pi * 0.30 * (1 - Float(step) / 4)))       // forehead -> crown
        }
        for step in 1...4 {
            stations.append((Float.pi, Float.pi * 0.62 * Float(step) / 4))       // crown -> nape
        }
        let keys = stations.map { station in
            LoftRing(
                headPoint(face, theta: station.theta, phi: station.phi, inflate: 0.012),
                width: 0.007,
                depth: 0.012
            )
        }
        return MannequinGeometry.loft(keys, sides: 20, caps: (start: 0.008, end: 0.008), reference: [0, 1, 0])
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

    /// An ellipsoid, optionally turned about the vertical axis (its local +z ends up pointing along `yaw`).
    private static func ellipsoid(center: SIMD3<Float>, radii: SIMD3<Float>, yaw: Float = 0) -> MannequinMesh {
        let cosYaw = cos(yaw), sinYaw = sin(yaw)
        return MannequinGeometry.surface(columns: 24, rows: 16, point: { theta, phi in
            let local = radii * SIMD3(sin(phi) * sin(theta), cos(phi), sin(phi) * cos(theta))
            return center + SIMD3(
                local.x * cosYaw + local.z * sinYaw,
                local.y,
                -local.x * sinYaw + local.z * cosYaw
            )
        })
    }

    /// Signed power: exponents below 1 push an ellipse toward a rounded square.
    private static func curved(_ value: Float, _ exponent: Float) -> Float {
        value < 0 ? -pow(-value, exponent) : pow(value, exponent)
    }
}
