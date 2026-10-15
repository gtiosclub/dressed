import SwiftUI
import RealityKit

// MARK: - Customization options

enum AvatarPart: String, CaseIterable, Identifiable {
    case bangs, hair, color, eyes, body
    var id: String { rawValue }
}

enum AvatarPalette {
    static let skin: [UIColor] = [
        UIColor(red: 0.98, green: 0.87, blue: 0.78, alpha: 1),
        UIColor(red: 0.95, green: 0.80, blue: 0.68, alpha: 1),
        UIColor(red: 0.89, green: 0.72, blue: 0.58, alpha: 1),
        UIColor(red: 0.80, green: 0.62, blue: 0.46, alpha: 1),
        UIColor(red: 0.69, green: 0.50, blue: 0.36, alpha: 1),
        UIColor(red: 0.55, green: 0.38, blue: 0.27, alpha: 1),
        UIColor(red: 0.42, green: 0.28, blue: 0.20, alpha: 1),
        UIColor(red: 0.30, green: 0.20, blue: 0.15, alpha: 1)
    ]
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
    // brown, dark brown, hazel, green, blue, gray
    static let eyes: [UIColor] = [
        UIColor(red: 0.30, green: 0.18, blue: 0.10, alpha: 1),
        UIColor(red: 0.12, green: 0.08, blue: 0.06, alpha: 1),
        UIColor(red: 0.50, green: 0.38, blue: 0.18, alpha: 1),
        UIColor(red: 0.28, green: 0.50, blue: 0.32, alpha: 1),
        UIColor(red: 0.25, green: 0.45, blue: 0.75, alpha: 1),
        UIColor(red: 0.55, green: 0.58, blue: 0.62, alpha: 1)
    ]
}

extension AvatarPart {
    static let hairStyleNames = ["None", "Short", "Long", "Bun", "Curly", "Ponytail"]
    static let bangsNames = ["None", "Straight", "Side", "Curtain"]

    var title: String {
        switch self {
        case .bangs: return "Bangs"
        case .hair: return "Hair"
        case .color: return "Color"
        case .eyes: return "Eyes"
        case .body: return "Skin"
        }
    }

    var optionCount: Int {
        switch self {
        case .bangs: return Self.bangsNames.count
        case .hair: return Self.hairStyleNames.count
        case .color: return AvatarPalette.hair.count
        case .eyes: return AvatarPalette.eyes.count
        case .body: return AvatarPalette.skin.count
        }
    }

    /// Color swatch for options that are colors; nil for options that need a text label.
    func swatch(_ index: Int) -> Color? {
        switch self {
        case .color: return Color(uiColor: AvatarPalette.hair[index % AvatarPalette.hair.count])
        case .eyes: return Color(uiColor: AvatarPalette.eyes[index % AvatarPalette.eyes.count])
        case .body: return Color(uiColor: AvatarPalette.skin[index % AvatarPalette.skin.count])
        case .bangs, .hair: return nil
        }
    }

    func label(_ index: Int) -> String {
        switch self {
        case .bangs: return Self.bangsNames[index % Self.bangsNames.count]
        case .hair: return Self.hairStyleNames[index % Self.hairStyleNames.count]
        default: return ""
        }
    }
}

// MARK: - Clothing layout (2D overlay)

extension ClothingCategory {
    /// Back-to-front draw order on the avatar.
    static let layerOrder: [ClothingCategory] = [.pants, .skirts, .dresses, .tops, .outerwear, .shoes]

    /// Where a garment sits on the avatar, as fractions of the avatar's height.
    var avatarSlot: (y: CGFloat, size: CGFloat) {
        switch self {
        case .pants: return (0.66, 0.30)
        case .skirts: return (0.58, 0.22)
        case .dresses: return (0.50, 0.42)
        case .tops: return (0.36, 0.22)
        case .outerwear: return (0.38, 0.28)
        case .shoes: return (0.93, 0.10)
        default: return (0.50, 0.20)
        }
    }
}

// MARK: - AvatarView

// 3D figure built from RealityKit shapes (needs iOS 18 for RealityView with a virtual camera).
// Clothes are still the 2D placeholder, drawn on top of the figure.
// Set use3D to false to get the old flat mannequin (used for the take-pic snapshot).
struct AvatarView: View {
    let look: [AvatarPart: Int]
    let worn: [ClothingCategory: ClothingItem]
    let image: (ClothingItem) -> Image
    var zoom: Double = 1
    var use3D: Bool = true

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            ZStack {
                if use3D {
                    RealityView { content in
                        content.camera = .virtual
                        content.add(AvatarScene.makeRoot(look: look))
                    } update: { content in
                        guard let root = content.entities.first(where: { $0.name == AvatarScene.rootName }) else { return }
                        AvatarScene.refreshFigure(in: root, look: look)
                    }
                } else {
                    Image(systemName: "figure.stand")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(uiColor: AvatarScene.skinColor(look)))
                        .frame(height: height * 0.95)
                        .position(x: width / 2, y: height / 2)
                }

                ForEach(ClothingCategory.layerOrder, id: \.self) { category in
                    if let item = worn[category] {
                        let slot = category.avatarSlot
                        image(item)
                            .resizable()
                            .scaledToFit()
                            .frame(width: width * 0.5, height: height * slot.size)
                            .position(x: width / 2, y: height * slot.y)
                    }
                }
            }
            .scaleEffect(zoom, anchor: .top)
        }
        .background(Color(white: 0.93))
        .clipped()
    }
}

// MARK: - RealityKit scene

private enum AvatarScene {
    static let rootName = "avatarRoot"
    static let figurePrefix = "figure-"

    static func skinColor(_ look: [AvatarPart: Int]) -> UIColor {
        AvatarPalette.skin[(look[.body] ?? 2) % AvatarPalette.skin.count]
    }

    static func makeRoot(look: [AvatarPart: Int]) -> Entity {
        let root = Entity()
        root.name = rootName

        // The figure is 1 unit tall, feet at y = 0. A narrow field of view from far away
        // gives a nearly flat framing where the figure fills 95% of the view height,
        // which is what the 2D clothing overlay assumes.
        let fov: Float = 20
        let distance = (0.5 / 0.95) / tan(fov * .pi / 360)
        let camera = PerspectiveCamera()
        camera.camera.fieldOfViewInDegrees = fov
        camera.position = [0, 0.5, distance]
        root.addChild(camera)

        let key = DirectionalLight()
        key.light.intensity = 2500
        root.addChild(key)
        key.look(at: [0, 0.5, 0], from: [0.8, 1.5, 2], relativeTo: nil)

        let fill = DirectionalLight()
        fill.light.intensity = 1000
        root.addChild(fill)
        fill.look(at: [0, 0.5, 0], from: [-1, 0.5, 2], relativeTo: nil)

        refreshFigure(in: root, look: look)
        return root
    }

    /// Rebuilds the figure only when the look actually changed (not on every zoom tick).
    static func refreshFigure(in root: Entity, look: [AvatarPart: Int]) {
        let signature = figurePrefix + look
            .sorted { $0.key.rawValue < $1.key.rawValue }
            .map { "\($0.key.rawValue)\($0.value)" }
            .joined(separator: "-")

        if root.children.contains(where: { $0.name == signature }) { return }

        for child in root.children where child.name.hasPrefix(figurePrefix) {
            child.removeFromParent()
        }
        root.addChild(buildFigure(look: look, name: signature))
    }

    // Everything is an ellipsoid: a unit sphere with a non-uniform scale.
    // Positions use y = 1 - (fraction of height measured from the top).
    private static func buildFigure(look: [AvatarPart: Int], name: String) -> Entity {
        let skin = skinColor(look)
        let hairColor = AvatarPalette.hair[(look[.color] ?? 2) % AvatarPalette.hair.count]
        let eyeColor = AvatarPalette.eyes[(look[.eyes] ?? 0) % AvatarPalette.eyes.count]
        let hairStyle = look[.hair] ?? 1
        let bangs = look[.bangs] ?? 0

        let figure = Entity()
        figure.name = name

        func add(_ radii: SIMD3<Float>, _ position: SIMD3<Float>, _ color: UIColor, rotationZ: Float = 0) {
            let entity = ModelEntity(
                mesh: .generateSphere(radius: 1),
                materials: [SimpleMaterial(color: color, roughness: 0.6, isMetallic: false)]
            )
            entity.scale = radii
            entity.position = position
            if rotationZ != 0 {
                entity.orientation = simd_quatf(angle: rotationZ, axis: [0, 0, 1])
            }
            figure.addChild(entity)
        }

        // Head, neck, torso, hips
        let headY: Float = 0.935
        add([0.045, 0.062, 0.050], [0, headY, 0], skin)
        add([0.022, 0.025, 0.022], [0, 0.86, 0], skin)
        add([0.095, 0.165, 0.058], [0, 0.68, 0], skin)
        add([0.090, 0.060, 0.060], [0, 0.50, 0], skin)

        // Arms and legs (left and right)
        for side: Float in [-1, 1] {
            add([0.022, 0.075, 0.022], [side * 0.120, 0.73, 0], skin)   // upper arm
            add([0.019, 0.070, 0.019], [side * 0.125, 0.60, 0], skin)   // forearm
            add([0.018, 0.025, 0.012], [side * 0.128, 0.50, 0], skin)   // hand
            add([0.040, 0.115, 0.040], [side * 0.050, 0.37, 0], skin)   // thigh
            add([0.030, 0.105, 0.030], [side * 0.050, 0.16, 0], skin)   // calf
            add([0.030, 0.020, 0.055], [side * 0.050, 0.035, 0.025], skin)  // foot
        }

        // Face: eyes, nose, mouth
        for side: Float in [-1, 1] {
            add([0.007, 0.007, 0.007], [side * 0.018, headY + 0.006, 0.047], eyeColor)
        }
        add([0.008, 0.010, 0.010], [0, headY - 0.012, 0.050], skin)
        add([0.013, 0.004, 0.006], [0, headY - 0.035, 0.046], UIColor(red: 0.70, green: 0.35, blue: 0.35, alpha: 1))

        // Hair style (0 = none)
        if hairStyle != 0 {
            if hairStyle == 4 {
                add([0.066, 0.072, 0.064], [0, headY + 0.012, -0.012], hairColor)   // curly volume
            } else {
                add([0.049, 0.058, 0.054], [0, headY + 0.012, -0.008], hairColor)   // cap
            }
            switch hairStyle {
            case 2: add([0.052, 0.120, 0.030], [0, headY - 0.075, -0.035], hairColor)  // long
            case 3: add([0.026, 0.026, 0.026], [0, headY + 0.065, -0.030], hairColor)  // bun
            case 5: add([0.015, 0.055, 0.015], [0, headY - 0.035, -0.068], hairColor)  // ponytail
            default: break
            }
        }

        // Bangs (0 = none)
        switch bangs {
        case 1: add([0.044, 0.016, 0.012], [0, headY + 0.036, 0.040], hairColor)
        case 2: add([0.044, 0.014, 0.012], [0.010, headY + 0.038, 0.040], hairColor, rotationZ: -0.3)
        case 3:
            add([0.022, 0.020, 0.012], [-0.020, headY + 0.034, 0.040], hairColor, rotationZ: 0.4)
            add([0.022, 0.020, 0.012], [0.020, headY + 0.034, 0.040], hairColor, rotationZ: -0.4)
        default: break
        }

        return figure
    }
}

#Preview {
    AvatarView(look: [:], worn: [:], image: { _ in Image(systemName: "photo") })
}
