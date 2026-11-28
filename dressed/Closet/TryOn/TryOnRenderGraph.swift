import Foundation

struct TryOnDrawItem: Equatable, Identifiable {
    var id: String
    var imagePath: String
    var bounds: TryOnRect
    var placement: TryOnGarmentPlacement
    var mesh: TryOnMesh?
    var occlusionPath: String?
    var occlusionBounds: TryOnRect?
    var occlusionPlacement: TryOnGarmentPlacement?
    var garmentID: String?
}

struct TryOnScene: Equatable {
    var textureEpoch: Int
    var items: [TryOnDrawItem]
}

enum TryOnRenderGraph {
    static func scene(
        avatar: TryOnAvatar?,
        garments: [TryOnGarmentAsset],
        outfit: TryOnOutfit?,
        meshes: [String: TryOnMesh],
        root: URL,
        textureEpoch: Int,
        suppressGarmentOverlays: Bool = false
    ) -> TryOnScene {
        guard let avatar, let outfit else { return TryOnScene(textureEpoch: textureEpoch, items: []) }
        let ready = Dictionary(uniqueKeysWithValues: garments.filter {
            ($0.status == .ready || $0.status == .needsReview)
                && $0.avatarID == avatar.id
                && $0.avatarVersion == avatar.version
        }.map { ($0.id, $0) })
        var items: [TryOnDrawItem] = []
        func addLayer(_ id: String, _ path: String?) {
            guard let path else { return }
            items.append(layer(id, path: file(path, root), placementID: "avatar"))
        }
        addLayer("back-hair", avatar.layers.backHairPath)
        let worn = outfit.selectedGarmentIDs.compactMap { ready[$0] }.filter { outfit.placement(for: $0.id).visible }
        let baked = Set(outfit.compositeBakedGarmentIDs ?? [])
        let wornBodyPartIDs = worn.filter {
            $0.bodyPartImagePath != nil && $0.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration
        }.map(\.id)

        if outfit.alignedOutfitFittingActive, let composite = outfit.compositeImagePath {
            addLayer("body", composite)
            return TryOnScene(textureEpoch: textureEpoch, items: items)
        }

        if TryOnVersions.bodyPartTileCompositingEnabled,
           outfit.bodyPartFittingActive,
           let composite = outfit.compositeImagePath {
            addLayer("back-arms", avatar.layers.backArmsPath)
            addLayer("body", composite)
            addLayer("front-arms", avatar.layers.frontArmsPath)
            addLayer("front-hair", avatar.layers.frontHairPath)
            addLayer("face", avatar.layers.faceForegroundPath)
            return TryOnScene(textureEpoch: textureEpoch, items: items)
        }

        let hasBodyPartLayers = !wornBodyPartIDs.isEmpty
        let preferBodyPartLayers = TryOnVersions.bodyPartTileCompositingEnabled
            && hasBodyPartLayers
            && !outfit.bodyPartFittingActive
        let overlayGarments: [TryOnGarmentAsset]
        let suppressTiles = suppressGarmentOverlays
            || outfit.alignedOutfitFittingActive
            || (TryOnVersions.bodyPartTileCompositingEnabled && (hasBodyPartLayers || outfit.bodyPartFittingActive))
        if suppressTiles {
            overlayGarments = []
        } else if outfit.compositeDisplayActive {
            overlayGarments = worn.filter { !baked.contains($0.id) }
        } else {
            overlayGarments = worn
        }
        items.append(contentsOf: components(
            overlayGarments,
            outfit: outfit,
            meshes: meshes,
            root: root,
            depth: .behindAvatar,
            landmarks: avatar.fittingMap.landmarks,
            preferBodyPartLayers: preferBodyPartLayers
        ))
        addLayer("back-arms", avatar.layers.backArmsPath)
        let bodyPath: String?
        if TryOnVersions.bodyPartTileCompositingEnabled,
           outfit.bodyPartFittingActive,
           let composite = outfit.compositeImagePath {
            bodyPath = composite
        } else if outfit.compositeDisplayActive, let composite = outfit.compositeImagePath {
            bodyPath = composite
        } else {
            bodyPath = avatar.layers.bodyBasePath ?? avatar.canonicalImagePath
        }
        addLayer("body", bodyPath)
        items.append(contentsOf: components(
            overlayGarments,
            outfit: outfit,
            meshes: meshes,
            root: root,
            depth: .clothing,
            landmarks: avatar.fittingMap.landmarks,
            preferBodyPartLayers: preferBodyPartLayers
        ))
        addLayer("front-arms", avatar.layers.frontArmsPath)
        addLayer("front-hair", avatar.layers.frontHairPath)
        addLayer("face", avatar.layers.faceForegroundPath)
        items.append(contentsOf: components(
            overlayGarments,
            outfit: outfit,
            meshes: meshes,
            root: root,
            depth: .inFrontOfAvatar,
            landmarks: avatar.fittingMap.landmarks,
            preferBodyPartLayers: preferBodyPartLayers
        ))
        return TryOnScene(textureEpoch: textureEpoch, items: items)
    }

    static func hitGarment(in scene: TryOnScene, at point: TryOnPoint) -> String? {
        for item in scene.items.reversed() {
            guard let garmentID = item.garmentID else { continue }
            let local = TryOnTransform.inverse(point, pivot: item.bounds.center, placement: item.placement)
            if item.bounds.contains(local) { return garmentID }
        }
        return nil
    }

    private static func components(
        _ garments: [TryOnGarmentAsset],
        outfit: TryOnOutfit,
        meshes: [String: TryOnMesh],
        root: URL,
        depth: TryOnDepthGroup,
        landmarks: TryOnLandmarks,
        preferBodyPartLayers: Bool
    ) -> [TryOnDrawItem] {
        var items: [TryOnDrawItem] = []
        for (index, garment) in garments.enumerated() {
            let placement = outfit.placement(for: garment.id)
            let outer = garments.dropFirst(index + 1).first
            let mesh = garment.meshPath.flatMap { meshes[$0] }
            if preferBodyPartLayers, depth == .clothing,
               let path = garment.bodyPartImagePath,
               garment.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration,
               let slot = garment.tryOnBodySlot {
                let slotFrame = slot.figureFrame(landmarks: landmarks)
                items.append(TryOnDrawItem(
                    id: "\(garment.id)-body-part",
                    imagePath: file(path, root),
                    bounds: slotFrame,
                    placement: placement,
                    mesh: nil,
                    garmentID: garment.id
                ))
                continue
            }
            let ordered = garment.components
                .filter { $0.depthGroup == depth }
                .filter { component in
                    outfit.componentOverrides.first {
                        $0.garmentID == garment.id && $0.componentID == component.id
                    }?.visible ?? true
                }
                .sorted { $0.defaultRenderOrder < $1.defaultRenderOrder }
            for component in ordered {
                var item = TryOnDrawItem(
                    id: "\(garment.id)-\(component.id)",
                    imagePath: file(component.imagePath, root),
                    bounds: garment.contentBounds,
                    placement: placement,
                    mesh: mesh,
                    garmentID: garment.id
                )
                if depth == .clothing, let outer, let fitted = outer.fittedReferencePath {
                    item.occlusionPath = file(fitted, root)
                    item.occlusionBounds = outer.contentBounds
                    item.occlusionPlacement = outfit.placement(for: outer.id)
                }
                items.append(item)
            }
        }
        return items
    }

    private static func layer(_ id: String, path: String, placementID: String) -> TryOnDrawItem {
        TryOnDrawItem(
            id: id,
            imagePath: path,
            bounds: TryOnRect(x: 0, y: 0, width: 1, height: 1),
            placement: .identity(garmentID: placementID)
        )
    }

    private static func file(_ relative: String, _ root: URL) -> String {
        root.appendingPathComponent(relative).path
    }
}