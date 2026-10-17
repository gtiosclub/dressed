import SwiftUI

// Choices on the avatar customization screen. The shapes behind them live in Mannequin.swift.

enum AvatarPart: String, CaseIterable, Identifiable {
    case gender, body, skin, face, hair, bangs, color
    var id: String { rawValue }
}

enum AvatarPalette {
    // Fair to deep. The mannequin wears these tones as they are.
    static let skin: [UIColor] = [
        UIColor(red: 0.99, green: 0.90, blue: 0.82, alpha: 1),
        UIColor(red: 0.96, green: 0.84, blue: 0.73, alpha: 1),
        UIColor(red: 0.93, green: 0.77, blue: 0.63, alpha: 1),
        UIColor(red: 0.87, green: 0.69, blue: 0.52, alpha: 1),
        UIColor(red: 0.79, green: 0.60, blue: 0.42, alpha: 1),
        UIColor(red: 0.70, green: 0.50, blue: 0.34, alpha: 1),
        UIColor(red: 0.58, green: 0.40, blue: 0.27, alpha: 1),
        UIColor(red: 0.46, green: 0.31, blue: 0.21, alpha: 1),
        UIColor(red: 0.35, green: 0.23, blue: 0.16, alpha: 1),
        UIColor(red: 0.25, green: 0.16, blue: 0.12, alpha: 1)
    ]
    static let mannequin: [UIColor] = AvatarPalette.skin

    // black, dark brown, chestnut, auburn, blonde, platinum, ginger, gray
    static let hair: [UIColor] = [
        UIColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1),
        UIColor(red: 0.22, green: 0.13, blue: 0.09, alpha: 1),
        UIColor(red: 0.36, green: 0.21, blue: 0.12, alpha: 1),
        UIColor(red: 0.55, green: 0.22, blue: 0.12, alpha: 1),
        UIColor(red: 0.86, green: 0.70, blue: 0.40, alpha: 1),
        UIColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 1),
        UIColor(red: 0.78, green: 0.35, blue: 0.15, alpha: 1),
        UIColor(red: 0.60, green: 0.60, blue: 0.62, alpha: 1)
    ]


}

extension AvatarGender {
    init(look: [AvatarPart: Int]) {
        self = AvatarGender(rawValue: AvatarPart.gender.selection(in: look)) ?? .female
    }
}

/// Everything the mannequin needs, resolved from the user's picks.
struct AvatarLook {
    let gender: AvatarGender
    let body: BodyShape
    let face: FaceShape
    let hair: HairStyle
    let bangs: BangsStyle
    let hairColor: UIColor
    let skin: UIColor

    init(_ look: [AvatarPart: Int]) {
        let gender = AvatarGender(look: look)
        self.gender = gender
        body = BodyShape.presets(for: gender)[AvatarPart.body.selection(in: look)]
        face = FaceShape.presets(for: gender)[AvatarPart.face.selection(in: look)]
        hair = HairStyle(rawValue: AvatarPart.hair.selection(in: look)) ?? .short
        bangs = BangsStyle(rawValue: AvatarPart.bangs.selection(in: look)) ?? .open
        hairColor = AvatarPalette.hair[AvatarPart.color.selection(in: look)]
        skin = AvatarPalette.mannequin[AvatarPart.skin.selection(in: look)]
    }
}

extension AvatarPart {
    var title: String {
        switch self {
        case .gender: return "Gender"
        case .body: return "Body"
        case .skin: return "Skin"
        case .face: return "Face"
        case .hair: return "Hair"
        case .bangs: return "Bangs"
        case .color: return "Hair color"
        }
    }

    var optionCount: Int {
        switch self {
        case .gender: return AvatarGender.allCases.count
        case .body: return BodyShape.presets(for: .female).count   // same count for every gender
        case .skin: return AvatarPalette.mannequin.count
        case .face: return FaceShape.presets(for: .female).count
        case .hair: return HairStyle.allCases.count
        case .bangs: return BangsStyle.allCases.count
        case .color: return AvatarPalette.hair.count
        }
    }

    /// The option the avatar wears before the user picks one.
    var defaultIndex: Int {
        switch self {
        case .hair: return HairStyle.short.rawValue
        case .color: return 2
        case .skin: return 3
        case .gender, .body, .face, .bangs: return 0
        }
    }

    /// The chosen option, or the default when none is set.
    func selection(in look: [AvatarPart: Int]) -> Int {
        (look[self] ?? defaultIndex) % optionCount
    }

    /// Color swatch for options that are colors; nil for options that get a preview.
    func swatch(_ index: Int) -> Color? {
        switch self {
        case .color: return Color(uiColor: AvatarPalette.hair[index % AvatarPalette.hair.count])
        case .skin: return Color(uiColor: AvatarPalette.mannequin[index % AvatarPalette.mannequin.count])
        case .gender, .body, .face, .hair, .bangs: return nil
        }
    }

    /// Labels depend on gender because body and face presets differ.
    func label(_ index: Int, in look: [AvatarPart: Int]) -> String {
        let gender = AvatarGender(look: look)
        switch self {
        case .gender: return AvatarGender(rawValue: index)?.title ?? ""
        case .bangs: return BangsStyle(rawValue: index)?.title ?? ""
        case .hair: return HairStyle(rawValue: index)?.title ?? ""
        case .face:
            let presets = FaceShape.presets(for: gender)
            return presets[index % presets.count].name
        case .body:
            let presets = BodyShape.presets(for: gender)
            return presets[index % presets.count].name
        case .color, .skin: return ""
        }
    }
}

// MARK: - Option previews

/// Small pictures for the option cards, drawn from the same meshes as the 3D avatar:
/// flat-shaded triangles, back to front, in plain Core Graphics.
/// Cached (and capped, so memory stays bounded) so scrolling stays smooth.
@MainActor
enum AvatarPreviews {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 160
        return cache
    }()

    private struct Shot {
        let crop: CGRect      // the part of the figure to show, in model units (feet at y = 0)
        let yaw: Float
        let fullBody: Bool
        let showsHair: Bool

        /// Head and shoulders, tall enough for long hair, ponytails and afros.
        static func head(yaw: Float) -> Shot {
            Shot(crop: CGRect(x: -0.1845, y: 0.64, width: 0.369, height: 0.41), yaw: yaw, fullBody: false, showsHair: true)
        }
        /// Close-up of the head with no hair, for comparing face shapes.
        static func face(yaw: Float) -> Shot {
            Shot(crop: CGRect(x: -0.05625, y: 0.875, width: 0.1125, height: 0.125), yaw: yaw, fullBody: false, showsHair: false)
        }
        static let full = Shot(crop: CGRect(x: -0.477, y: -0.02, width: 0.954, height: 1.06), yaw: 0, fullBody: true, showsHair: true)
    }

    private struct Facet {
        let depth: Float
        let a: CGPoint, b: CGPoint, c: CGPoint
        let color: CGColor
    }

    private static let size = CGSize(width: 90, height: 100)

    /// The preview for one option, with that option applied on top of the current look. Nil for plain colors.
    static func image(for part: AvatarPart, index: Int, in look: [AvatarPart: Int]) -> UIImage? {
        let shot: Shot
        switch part {
        case .hair, .bangs: shot = .head(yaw: 1.1)   // side view so buns and ponytails show
        case .face: shot = .head(yaw: 0.5)
        case .body, .gender: shot = .full
        case .color, .skin: return nil
        }

        let others = AvatarPart.allCases.filter { $0 != part }
            .map { "\($0.rawValue)\($0.selection(in: look))" }
            .joined(separator: "-")
        let key = "\(part.rawValue)\(index)|\(others)" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        var chosen = look
        chosen[part] = index
        let image = render(AvatarLook(chosen), shot: shot)
        cache.setObject(image, forKey: key)
        return image
    }

    private static func render(_ avatar: AvatarLook, shot: Shot) -> UIImage {
        let scale = min(size.width / shot.crop.width, size.height / shot.crop.height)
        let cosYaw = cos(shot.yaw), sinYaw = sin(shot.yaw)
        let light = SIMD3<Float>(0.352, 0.553, 0.755)

        func turn(_ p: SIMD3<Float>) -> SIMD3<Float> {
            SIMD3(p.x * cosYaw + p.z * sinYaw, p.y, -p.x * sinYaw + p.z * cosYaw)
        }
        func project(_ p: SIMD3<Float>) -> CGPoint {
            CGPoint(
                x: size.width / 2 + (CGFloat(p.x) - shot.crop.midX) * scale,
                y: size.height / 2 - (CGFloat(p.y) - shot.crop.midY) * scale
            )
        }

        var facets: [Facet] = []
        func add(_ mesh: MannequinMesh, color: UIColor, bias: Float) {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let positions = mesh.positions.map(turn)
            let normals = mesh.normals.map(turn)
            for start in stride(from: 0, to: mesh.indices.count - 2, by: 3) {
                let i = Int(mesh.indices[start]), j = Int(mesh.indices[start + 1]), k = Int(mesh.indices[start + 2])
                let normal = normals[i] + normals[j] + normals[k]
                if normal.z <= 0 { continue }   // facing away
                let length = max((normal * normal).sum().squareRoot(), 1e-6)
                let lit = max((normal * light).sum() / length, 0)
                let shade = CGFloat(0.55 + 0.45 * lit)
                facets.append(Facet(
                    depth: (positions[i].z + positions[j].z + positions[k].z) / 3 + bias,
                    a: project(positions[i]), b: project(positions[j]), c: project(positions[k]),
                    color: CGColor(red: red * shade, green: green * shade, blue: blue * shade, alpha: 1)
                ))
            }
        }

        if shot.fullBody {
            add(Mannequin.body(avatar.body, face: avatar.face, nose: NoseShape.presets[0]), color: avatar.skin, bias: 0)
        } else {
            add(Mannequin.bust(avatar.body, face: avatar.face, nose: NoseShape.presets[0]), color: avatar.skin, bias: 0)
        }
        if shot.showsHair {
            add(Mannequin.hair(avatar.hair, bangs: avatar.bangs, face: avatar.face, body: avatar.body),
                color: avatar.hairColor, bias: 0.008)
        }
        facets.sort { $0.depth < $1.depth }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            cg.setLineWidth(0.5)   // a hairline stroke in the fill color hides seams between triangles
            for facet in facets {
                cg.setFillColor(facet.color)
                cg.setStrokeColor(facet.color)
                cg.move(to: facet.a)
                cg.addLine(to: facet.b)
                cg.addLine(to: facet.c)
                cg.closePath()
                cg.drawPath(using: .fillStroke)
            }
        }
    }
}
