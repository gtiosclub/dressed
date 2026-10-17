import SwiftUI
import RealityKit

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

// 3D mannequin on a turntable: drag sideways to spin it, double-tap to face front again.
// Clothes are still the 2D placeholder drawn over the figure; they narrow and fade as it turns away.
// Set use3D to false to get the old flat mannequin (used for the take-pic snapshot).
struct AvatarView: View {
    let look: [AvatarPart: Int]
    let worn: [ClothingCategory: ClothingItem]
    let image: (ClothingItem) -> Image
    var uiImage: ((ClothingItem) -> UIImage?)? = nil
    var zoom: Double = 1
    var use3D: Bool = true

    @State private var orbit = AvatarOrbit()

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                AvatarBackdrop(size: size, zoom: zoom, showsFloorShadow: use3D)
                if use3D {
                    AvatarStage(look: look, worn: worn, uiImage: uiImage, zoom: zoom, orbit: orbit)
                } else {
                    Image(systemName: AvatarGender(look: look).symbol)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(uiColor: AvatarScene.tint(look)))
                        .frame(height: size.height * 0.95)
                        .position(x: size.width / 2, y: size.height / 2)
                        .scaleEffect(zoom, anchor: .top)

                    GarmentOverlay(worn: worn, image: image, size: size, orbit: orbit)
                        .scaleEffect(zoom, anchor: .top)
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(turnGesture(viewWidth: size.width), including: use3D ? .all : .none)
            .onTapGesture(count: 2) {
                if use3D { orbit.resetToFront() }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Avatar")
            .accessibilityHint(use3D ? "Swipe up or down to turn the avatar." : "")
            .accessibilityAdjustableAction { direction in
                guard use3D else { return }
                switch direction {
                case .increment: orbit.turn(by: .pi / 4)
                case .decrement: orbit.turn(by: -.pi / 4)
                @unknown default: break
                }
            }
        }
        .clipped()
    }

    private func turnGesture(viewWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { orbit.dragChanged(translation: $0.translation.width, viewWidth: viewWidth) }
            .onEnded { orbit.dragEnded(velocity: $0.velocity.width, viewWidth: viewWidth) }
    }
}

/// The RealityKit scene. It reads the orbit itself, so spinning re-renders only this view.
private struct AvatarStage: View {
    let look: [AvatarPart: Int]
    let worn: [ClothingCategory: ClothingItem]
    let uiImage: ((ClothingItem) -> UIImage?)?
    let zoom: Double
    let orbit: AvatarOrbit

    var body: some View {
        let yaw = orbit.yaw
        RealityView { content in
            content.camera = .virtual
            content.add(AvatarScene.makeRoot(look: look, worn: worn, uiImage: uiImage, zoom: zoom, yaw: yaw))
        } update: { content in
            guard let root = content.entities.first(where: { $0.name == AvatarScene.rootName }) else { return }
            AvatarScene.update(root, look: look, worn: worn, uiImage: uiImage, zoom: zoom, yaw: yaw)
        }
        // Let the SwiftUI backdrop show through instead of the system background.
        .backgroundStyle(Color.clear)
    }
}

/// The 2D clothing placeholder. Flat images can't turn, so they narrow and fade as the avatar spins away.
private struct GarmentOverlay: View {
    let worn: [ClothingCategory: ClothingItem]
    let image: (ClothingItem) -> Image
    let size: CGSize
    let orbit: AvatarOrbit

    var body: some View {
        let facing = CGFloat(cos(orbit.yaw))
        ZStack {
            ForEach(ClothingCategory.layerOrder, id: \.self) { category in
                if let item = worn[category] {
                    let slot = category.avatarSlot
                    image(item)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size.width * 0.5, height: size.height * slot.size)
                        .position(x: size.width / 2, y: size.height * slot.y)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .scaleEffect(x: max(facing, 0.01), y: 1)
        .opacity(Double(min(max((facing - 0.35) / 0.65, 0), 1)))
    }
}

/// Soft studio backdrop with a contact shadow where the feet meet the floor.
private struct AvatarBackdrop: View {
    let size: CGSize
    let zoom: Double
    let showsFloorShadow: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.97), Color(white: 0.88)], startPoint: .top, endPoint: .bottom)
            RadialGradient(
                colors: [Color.white.opacity(0.85), Color.white.opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.4),
                startRadius: 0,
                endRadius: size.height * 0.55
            )
            if showsFloorShadow {
                floorShadow.scaleEffect(zoom, anchor: .top)
            }
        }
    }

    private var floorShadow: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.12))
                .frame(width: size.height * 0.24, height: size.height * 0.035)
                .blur(radius: size.height * 0.012)
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: size.height * 0.14, height: size.height * 0.014)
                .blur(radius: size.height * 0.005)
        }
        .position(x: size.width / 2, y: size.height * AvatarScene.floorFraction)
    }
}

// MARK: - RealityKit scene

private enum AvatarScene {
    static let rootName = "avatarRoot"
    private static let cameraName = "avatarCamera"
    private static let turntableName = "avatarTurntable"
    private static let bodyPrefix = "body-"
    private static let hairPrefix = "hair-"

    // Framing: the figure is 1 unit tall with feet at y = 0. At zoom 1 it fills 95% of the view height,
    // which the 2D overlay assumes. Zooming narrows the view but keeps its top edge fixed, matching the
    // overlay's scaleEffect(anchor: .top). A narrow lens from far away keeps proportions natural.
    private static let fieldOfView: Float = 20
    private static let visibleHeight: Float = 1 / 0.95
    private static let frameTop: Float = 0.5 + visibleHeight / 2

    /// Where the floor under the feet lands, as a fraction of the view height at zoom 1.
    static let floorFraction: CGFloat = 0.978

    static func tint(_ look: [AvatarPart: Int]) -> UIColor {
        AvatarPalette.mannequin[AvatarPart.skin.selection(in: look)]
    }

    /// Name of the empty anchor where a 3D garment of this category can attach later.
    /// Anchors live on the turntable, so they turn with the avatar and survive body changes.
    static func slotName(for category: ClothingCategory) -> String {
        "slot-\(category.rawValue)"
    }

    static func makeRoot(
        look: [AvatarPart: Int],
        worn: [ClothingCategory: ClothingItem],
        uiImage: ((ClothingItem) -> UIImage?)?,
        zoom: Double,
        yaw: Double
    ) -> Entity {
        let root = Entity()
        root.name = rootName

        let camera = PerspectiveCamera()
        camera.name = cameraName
        camera.camera.fieldOfViewInDegrees = fieldOfView
        root.addChild(camera)

        addLights(to: root)

        let turntable = Entity()
        turntable.name = turntableName
        root.addChild(turntable)
        for category in ClothingCategory.layerOrder {
            let slot = Entity()
            slot.name = slotName(for: category)
            slot.position = [0, frameTop - Float(category.avatarSlot.y) * visibleHeight, 0]
            turntable.addChild(slot)
        }

        update(root, look: look, worn: worn, uiImage: uiImage, zoom: zoom, yaw: yaw)
        return root
    }

    /// Cheap enough to run every frame while spinning: meshes rebuild only when the look changes.
    static func update(
        _ root: Entity,
        look: [AvatarPart: Int],
        worn: [ClothingCategory: ClothingItem],
        uiImage: ((ClothingItem) -> UIImage?)?,
        zoom: Double,
        yaw: Double
    ) {
        root.findEntity(named: cameraName)?.position = cameraPosition(zoom: zoom)
        guard let turntable = root.findEntity(named: turntableName) else { return }
        turntable.orientation = simd_quatf(angle: Float(yaw), axis: [0, 1, 0])

        let avatar = AvatarLook(look)

        // Gender is part of every signature: it changes which body and face presets the indices point to.
        replaceChild(of: turntable, prefix: bodyPrefix, signature: signature(look, [.gender, .body, .face, .skin])) {
            model(Mannequin.body(avatar.body, face: avatar.face, nose: NoseShape.presets[0]), material: porcelain(avatar.skin))
        }

        let hairParts: [AvatarPart] = [.gender, .hair, .bangs, .color, .face, .body]
        replaceChild(of: turntable, prefix: hairPrefix, signature: signature(look, hairParts)) {
            model(
                Mannequin.hair(avatar.hair, bangs: avatar.bangs, face: avatar.face, body: avatar.body),
                material: hairFinish(avatar.hairColor)
            )
        }

        // 3D procedural preset clothing pieces turning 360 degrees on the turntable
        for category in ClothingCategory.allCases {
            let garmentPrefix = "garment-\(category.rawValue)-"
            if let item = worn[category] {
                let img = uiImage?(item)
                let color = GarmentColorExtractor.dominantColor(from: img)
                let preset = GarmentPreset.detect(name: item.name, category: category, itemId: item.id)
                let colorKey = "\(color.hashValue)"
                let sig = "\(item.id)-\(preset.rawValue)-\(colorKey)-\(avatar.body.name)"

                replaceChild(of: turntable, prefix: garmentPrefix, signature: sig) {
                    let mesh = MannequinGarments.mesh(for: preset, shape: avatar.body)
                    return model(mesh, material: fabricFinish(color))
                }
            } else {
                turntable.children.filter { $0.name.hasPrefix(garmentPrefix) }.forEach { $0.removeFromParent() }
            }
        }
    }

    private static func fabricFinish(_ color: UIColor) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: 0.58)
        material.metallic = .init(floatLiteral: 0.04)
        material.clearcoat = .init(floatLiteral: 0.15)
        material.clearcoatRoughness = .init(floatLiteral: 0.25)
        material.faceCulling = .none
        return material
    }

    private static func cameraPosition(zoom: Double) -> SIMD3<Float> {
        let height = visibleHeight / Float(max(zoom, 1))
        let distance = (height / 2) / tan(fieldOfView * .pi / 360)
        return [0, frameTop - height / 2, distance]
    }

    /// Studio three-point lighting on top of RealityKit's default environment light.
    /// The lights stay put while the turntable spins, like a photo studio.
    private static func addLights(to root: Entity) {
        let key = DirectionalLight()
        key.light.intensity = 2600
        key.shadow = DirectionalLightComponent.Shadow(maximumDistance: 5, depthBias: 2)
        root.addChild(key)
        key.look(at: [0, 0.55, 0], from: [0.9, 1.8, 2.2], relativeTo: nil)

        let fill = DirectionalLight()
        fill.light.intensity = 900
        root.addChild(fill)
        fill.look(at: [0, 0.5, 0], from: [-1.4, 0.7, 1.6], relativeTo: nil)

        let rim = DirectionalLight()
        rim.light.intensity = 1400
        root.addChild(rim)
        rim.look(at: [0, 0.6, 0], from: [-0.6, 1.4, -2], relativeTo: nil)
    }

    private static func signature(_ look: [AvatarPart: Int], _ parts: [AvatarPart]) -> String {
        parts.map { "\($0.rawValue)\($0.selection(in: look))" }.joined(separator: "-")
    }

    private static func replaceChild(of parent: Entity, prefix: String, signature: String, build: () -> Entity) {
        let name = prefix + signature
        if parent.children.contains(where: { $0.name == name }) { return }
        parent.children.filter { $0.name.hasPrefix(prefix) }.forEach { $0.removeFromParent() }
        let entity = build()
        entity.name = name
        parent.addChild(entity)
    }

    private static func model(_ mesh: MannequinMesh, material: PhysicallyBasedMaterial) -> Entity {
        guard !mesh.isEmpty, let resource = try? mesh.resource() else { return Entity() }
        return ModelEntity(mesh: resource, materials: [material])
    }

    /// Satin porcelain, like a display mannequin.
    private static func porcelain(_ color: UIColor) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: 0.45)
        material.metallic = .init(floatLiteral: 0)
        material.clearcoat = .init(floatLiteral: 0.3)
        material.clearcoatRoughness = .init(floatLiteral: 0.25)
        return material
    }

    /// Glossy finish for reflective materials.
    private static func glossy(_ color: UIColor, roughness: Float, clearcoat: Float) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: roughness)
        material.metallic = .init(floatLiteral: 0)
        material.clearcoat = .init(floatLiteral: clearcoat)
        material.clearcoatRoughness = .init(floatLiteral: 0.15)
        return material
    }

    /// Hair shells are open, so both sides render.
    private static func hairFinish(_ color: UIColor) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.roughness = .init(floatLiteral: 0.55)
        material.metallic = .init(floatLiteral: 0)
        material.faceCulling = .none
        return material
    }
}

private extension MannequinMesh {
    func resource() throws -> MeshResource {
        var descriptor = MeshDescriptor(name: "mannequin")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)
        return try MeshResource.generate(from: [descriptor])
    }
}

#Preview {
    AvatarView(look: [:], worn: [:], image: { _ in Image(systemName: "photo") })
}
