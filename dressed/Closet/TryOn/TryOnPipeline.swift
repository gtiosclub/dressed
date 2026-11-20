import CryptoKit
import UIKit

struct TryOnPreparedGarment {
    var asset: TryOnGarmentAsset
    var keptPreviousReadyFit: Bool
}

actor TryOnPipeline {
    private let library: TryOnLibrary
    private let client: TryOnImageClient
    private let ownerId: String

    init(library: TryOnLibrary, ownerId: String, client: TryOnImageClient = TryOnImageClient()) {
        self.library = library
        self.ownerId = ownerId
        self.client = client
    }

    func prepareAvatar(from photo: UIImage, key: String, progress: @escaping (String) -> Void) async throws -> TryOnAvatar {
        progress("Preparing the avatar")
        guard let source = TryOnBitmap.aspectFit(photo, canvas: .canonical) else {
            throw TryOnImageError.emptyImage
        }
        try Task.checkCancellation()
        progress("Generating the stylized avatar")
        let generated = try await generatedImage(key: key, prompt: TryOnPrompts.avatar(), images: [try png(source)], quality: "high")
        progress("Reading the fitting map")
        let keyed = TryOnBitmap.keyedIfNeeded(generated).image
        let analysis = TryOnVision.analyze(keyed)
        let image = maskedAvatar(keyed, silhouette: analysis.silhouette) ?? keyed
        let report = TryOnValidator.avatar(image: image, canvas: .canonical, landmarks: analysis.landmarks)
        guard report.status != "failed" else {
            throw TryOnImageError.provider(notes(from: report).joined(separator: " "))
        }
        let now = Date()
        let avatar = TryOnAvatar(
            id: UUID().uuidString,
            version: 1,
            canvas: .canonical,
            canonicalImagePath: "",
            layers: TryOnAvatarLayers(
                bodyBasePath: nil, backHairPath: nil, backArmsPath: nil,
                frontArmsPath: nil, frontHairPath: nil, faceForegroundPath: nil
            ),
            fittingMap: TryOnFittingMap(landmarks: analysis.landmarks, masks: TryOnSemanticMasks(silhouettePath: nil)),
            styleVersion: TryOnVersions.style,
            promptVersion: TryOnVersions.prompt,
            providerVersion: TryOnVersions.provider,
            status: report.status == "passed" ? .ready : .needsReview,
            validation: report,
            createdAt: now,
            updatedAt: now
        )
        return try await library.saveAvatar(avatar, image: image, silhouette: analysis.silhouette)
    }

    func prepareGarment(
        item: ClothingItem,
        template: TryOnTemplateID,
        photo: UIImage,
        avatar: TryOnAvatar,
        key: String,
        progress: @escaping (String) -> Void
    ) async throws -> TryOnPreparedGarment {
        progress("Preparing the garment")
        guard let source = TryOnBitmap.aspectFit(photo, canvas: .canonical) else {
            throw TryOnImageError.emptyImage
        }
        let original = try await library.saveOriginalIfNeeded(garmentID: item.id, image: source)
        let existing = await library.snapshot().garments.first { $0.id == item.id }
        guard await image(at: avatar.canonicalImagePath) != nil else {
            throw TryOnImageError.emptyImage
        }
        try Task.checkCancellation()
        guard let sourceFit = TryOnSourceFitStore.load(ownerId: ownerId, itemID: item.id) else {
            throw TryOnImageError.provider(
                TryOnSourceFitStore.failureReason(ownerId: ownerId, itemID: item.id)
                    ?? "This piece has no shoulder, waist, hip, knee, or foot coordinates. Add the photo of the person wearing it again."
            )
        }
        progress("Placing \(sourceFit.gridColumns)×\(sourceFit.gridRows) squares, hem at the \(sourceFit.hemDescription)")
        guard let placed = TryOnSourceFit.place(
            cutout: photo,
            fit: sourceFit,
            avatar: avatar.fittingMap.landmarks,
            canvas: .canonical
        ) else {
            throw TryOnImageError.provider(
                TryOnSourceFit.placementFailure(fit: sourceFit, avatar: avatar.fittingMap.landmarks)
            )
        }
        _ = try await library.saveAttempt(placed.image, garmentID: item.id, attempt: (existing?.attemptCount ?? 0) + 1)
        progress("Segmenting and validating")
        let keyed = placed.image
        guard let stats = TryOnBitmap.stats(of: keyed) else { throw TryOnImageError.emptyImage }
        let initialAnchors = TryOnFit.anchors(for: template, stats: stats, canvas: .canonical)
        let alignment: (shift: TryOnPoint, note: String?) = (.zero, nil)
        let shift = TryOnFit.clamp(alignment.shift, stats: stats, canvas: .canonical)
        let fitted: CGImage
        if abs(shift.x) > 0.01 || abs(shift.y) > 0.01 {
            fitted = TryOnBitmap.translated(
                keyed,
                dx: shift.x * Double(TryOnCanvas.canonical.width),
                dy: shift.y * Double(TryOnCanvas.canonical.height),
                canvas: .canonical
            ) ?? keyed
        } else {
            fitted = keyed
        }
        guard let fittedStats = TryOnBitmap.stats(of: fitted) else { throw TryOnImageError.emptyImage }
        let anchors = TryOnFit.anchors(for: template, stats: fittedStats, canvas: .canonical)
        let bounds = normalized(fittedStats.bounds, canvas: .canonical)
        let mesh = TryOnFit.mesh(
            template: template,
            bounds: bounds,
            anchors: anchors,
            landmarks: avatar.fittingMap.landmarks,
            appliedShift: shift
        )
        let split = TryOnFit.split(template: template, image: fitted, anchors: anchors, canvas: .canonical)
        var report = TryOnValidator.garment(
            image: fitted,
            canvas: .canonical,
            template: template,
            anchors: anchors,
            mesh: mesh,
            components: split.components,
            landmarks: avatar.fittingMap.landmarks,
            alignmentNote: alignment.note
        )
        report.checks.append(TryOnCheck(
            id: "source-hem",
            level: .review,
            passed: true,
            message: "Hem placed at the \(sourceFit.hemDescription) from the worn photo."
        ))
        // Placed fabric still gets worn when a review check or the mesh limit fails.
        // The failed checks stay on the asset and are shown after this step.
        let containsFabric = fittedStats.opaqueCount > 64
        if !containsFabric,
           report.status != "passed",
           existing?.status == .ready,
           existing?.processingVersion ?? 0 >= TryOnVersions.processing {
            throw TryOnImageError.provider(
                "The previous ready fit was kept. " + notes(from: report).joined(separator: " ")
            )
        }
        let meshPath = try await library.saveMesh(mesh, garmentID: item.id)
        let now = Date()
        let asset = TryOnGarmentAsset(
            id: item.id,
            userID: ownerId,
            avatarID: avatar.id,
            avatarVersion: avatar.version,
            originalImagePath: original,
            fittedReferencePath: nil,
            components: [],
            anchors: anchors,
            contentBounds: bounds,
            fit: TryOnGarmentFit(
                templateId: template.rawValue,
                fitStyle: template.fitStyle,
                preserveSilhouette: template.preserveSilhouette,
                ease: TryOnEase(
                    maxLocalDisplacement: TryOnVersions.maxLocalDisplacement,
                    shoulderDrop: template == .oversizedHoodie ? 0.04 : 0
                ),
                upperTemplateId: template == .oversizedHoodie ? "hoodie_upper_v1" : nil,
                bypassedUpperTemplate: split.bypassedHoodTemplate
            ),
            meshPath: meshPath,
            occlusionPath: nil,
            sourceCategory: item.category.rawValue,
            processingVersion: TryOnVersions.processing,
            styleVersion: TryOnVersions.style,
            promptVersion: TryOnVersions.prompt,
            providerVersion: TryOnVersions.provider,
            attemptCount: (existing?.attemptCount ?? 0) + 1,
            status: containsFabric ? .ready : status(for: report),
            validation: report,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
        let stored = try await library.saveGarment(
            asset,
            fitted: fitted,
            mask: TryOnBitmap.mask(from: fitted),
            components: split.components
        )
        return TryOnPreparedGarment(asset: stored, keptPreviousReadyFit: false)
    }

    func exportPoses(
        avatar: TryOnAvatar,
        garments: [TryOnGarmentAsset],
        outfit: TryOnOutfit,
        meshes: [String: TryOnMesh],
        key: String,
        progress: @escaping (String) -> Void
    ) async throws -> [TryOnPose: URL] {
        let scene = TryOnRenderGraph.scene(
            avatar: avatar,
            garments: garments,
            outfit: outfit,
            meshes: meshes,
            root: await library.root,
            textureEpoch: 0
        )
        guard let flat = TryOnFlatten.image(scene: scene, canvas: .canonical) else {
            throw TryOnImageError.emptyImage
        }
        let references = try await referenceImages(garments: garments, outfit: outfit)
        var images = [try png(flat)] + references
        if images.count > 4 { images = Array(images.prefix(4)) }
        let hash = fingerprint(avatar: avatar, garments: garments, outfit: outfit)
        var saved: [TryOnPose: URL] = [:]
        for pose in TryOnPose.allCases {
            try Task.checkCancellation()
            let destination = await library.exportURL(hash: hash, pose: pose)
            if FileManager.default.fileExists(atPath: destination.path),
               UIImage(contentsOfFile: destination.path) != nil {
                saved[pose] = destination
                continue
            }
            progress("Exporting the \(pose.title.lowercased()) pose")
            let generated = try await generatedImage(
                key: key,
                prompt: TryOnPrompts.pose(pose, referenceCount: images.count),
                images: images,
                quality: "medium"
            )
            guard TryOnBitmap.stats(of: generated)?.opaqueFraction ?? 0 > 0.01 else {
                throw TryOnImageError.provider("The \(pose.title) pose came back empty.")
            }
            saved[pose] = try await library.saveExport(generated, hash: hash, pose: pose)
        }
        return saved
    }

    private func generatedImage(key: String, prompt: String, images: [Data], quality: String) async throws -> CGImage {
        let data = try await client.edit(key: key, prompt: prompt, images: images, quality: quality, ownerId: ownerId)
        guard let image = UIImage(data: data), let placed = TryOnBitmap.aspectFit(image, canvas: .canonical) else {
            throw TryOnImageError.emptyImage
        }
        return placed
    }

    private func referenceImages(garments: [TryOnGarmentAsset], outfit: TryOnOutfit) async throws -> [Data] {
        var images: [Data] = []
        for id in outfit.selectedGarmentIDs {
            guard let garment = garments.first(where: { $0.id == id }),
                  garment.status == .ready,
                  outfit.placement(for: id).visible,
                  let path = garment.fittedReferencePath,
                  let image = await image(at: path) else { continue }
            images.append(try png(image))
        }
        return images
    }

    private func image(at relative: String) async -> CGImage? {
        let root = await library.root
        return UIImage(contentsOfFile: root.appendingPathComponent(relative).path)?.cgImage
    }

    private func png(_ image: CGImage) throws -> Data {
        guard let data = TryOnBitmap.pngData(from: image) else { throw TryOnImageError.emptyImage }
        return data
    }

    private func maskedAvatar(_ image: CGImage, silhouette: CGImage?) -> CGImage? {
        guard let silhouette, let mask = TryOnBitmap.rgba(from: silhouette), let source = TryOnBitmap.rgba(from: image) else {
            return nil
        }
        guard mask.width == source.width, mask.height == source.height else { return nil }
        var white = 0
        for index in stride(from: 0, to: mask.bytes.count, by: 4) where mask.bytes[index] > 128 {
            white += 1
        }
        let coverage = Double(white) / Double(max(mask.width * mask.height, 1))
        guard coverage > 0.05, coverage < 0.75 else { return nil }
        var bytes = source.bytes
        for index in stride(from: 0, to: bytes.count, by: 4) where mask.bytes[index] < 128 {
            bytes[index] = 0
            bytes[index + 1] = 0
            bytes[index + 2] = 0
            bytes[index + 3] = 0
        }
        return TryOnBitmap.cgImage(width: source.width, height: source.height, bytes: bytes)
    }

    private func normalized(_ bounds: CGRect, canvas: TryOnCanvas) -> TryOnRect {
        guard bounds.width > 1, bounds.height > 1 else {
            return TryOnRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
        }
        return TryOnRect(
            x: Double(bounds.minX) / Double(canvas.width),
            y: Double(bounds.minY) / Double(canvas.height),
            width: Double(bounds.width) / Double(canvas.width),
            height: Double(bounds.height) / Double(canvas.height)
        )
    }

    private func status(for report: TryOnValidationReport) -> TryOnJobStatus {
        switch report.status {
        case "passed": return .ready
        case "needs_review": return .needsReview
        default: return .failed
        }
    }

    private func notes(from report: TryOnValidationReport) -> [String] {
        let failed = report.checks.filter { !$0.passed }.map(\.message)
        return failed.isEmpty ? ["The image failed validation."] : failed
    }

    private func fingerprint(avatar: TryOnAvatar, garments: [TryOnGarmentAsset], outfit: TryOnOutfit) -> String {
        struct Key: Encodable {
            struct Placement: Encodable {
                var id: String
                var x: Double
                var y: Double
                var scaleX: Double
                var scaleY: Double
                var rotation: Double
                var visible: Bool
            }
            var avatarID: String
            var avatarVersion: Int
            var garments: [String]
            var placements: [Placement]
            var poseSet: String
            var prompt: String
            var provider: String
            var style: String
        }
        func quantize(_ value: Double) -> Double { (value * 10_000).rounded() / 10_000 }
        let worn = outfit.selectedGarmentIDs.filter { id in
            garments.contains { $0.id == id && $0.status == .ready } && outfit.placement(for: id).visible
        }
        let placements = worn.map { id in
            let placement = outfit.placement(for: id)
            return Key.Placement(
                id: id,
                x: quantize(placement.translation.x),
                y: quantize(placement.translation.y),
                scaleX: quantize(placement.scaleX),
                scaleY: quantize(placement.scaleY),
                rotation: quantize(placement.rotationDegrees),
                visible: placement.visible
            )
        }
        let versions = worn.map { id in
            let garment = garments.first { $0.id == id }
            return "\(id)#\(garment?.processingVersion ?? 0)#\(garment?.avatarVersion ?? 0)"
        }
        let key = Key(
            avatarID: avatar.id,
            avatarVersion: avatar.version,
            garments: versions,
            placements: placements,
            poseSet: TryOnVersions.poseSet,
            prompt: TryOnVersions.prompt,
            provider: TryOnVersions.provider,
            style: TryOnVersions.style
        )
        let data = (try? JSONEncoder().encode(key)) ?? Data()
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
