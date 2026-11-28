import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class TryOnEditorModel {
    private let library: TryOnLibrary
    private let pipeline: TryOnPipeline
    private let ownerId: String
    private let bodyPartStore: GarmentBodyPartStore

    private(set) var avatar: TryOnAvatar?
    private(set) var garments: [TryOnGarmentAsset] = []
    private(set) var outfits: [TryOnOutfit] = []
    var draft: TryOnOutfit?
    private(set) var meshes: [String: TryOnMesh] = [:]
    private(set) var root = URL(fileURLWithPath: "/")
    private(set) var textureEpoch = 0
    var activity: String?
    var message: String?
    var selectedGarmentID: String?
    var exportedImages: [TryOnPose: UIImage] = [:]
    private var dragOrigin: TryOnPoint?
    private var pinchBase: Double?
    private var jobs: [(String, (TryOnEditorModel) async throws -> Void)] = []
    private var draining = false
    private var pendingFits: Set<String> = []
    /// True while an outfit composite render is queued or running; suppresses duplicate overlays in the render graph.
    private(set) var awaitingOutfitComposite = false
    var awaitingBodyPartComposite: Bool { awaitingOutfitComposite }
    /// Bumped when a fit starts and again when it finishes. A progress update from
    /// "Segmenting and validating" that lands after the job ends is ignored.
    private var activityGeneration = 0

    init(ownerId: String) {
        let library = TryOnLibrary(ownerId: ownerId)
        self.library = library
        let resolvedOwner = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ownerId = resolvedOwner.isEmpty ? "local" : resolvedOwner
        pipeline = TryOnPipeline(library: library, ownerId: self.ownerId)
        bodyPartStore = GarmentBodyPartStore(ownerId: self.ownerId)
    }

    var closetOwnerId: String { ownerId }

    var scene: TryOnScene {
        let wornBodyPartCount = draft?.selectedGarmentIDs.filter { id in
            garments.contains {
                $0.id == id
                    && $0.bodyPartImagePath != nil
                    && $0.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration
            }
        }.count ?? 0
        let suppressOverlays = awaitingOutfitComposite
            || draft?.alignedOutfitFittingActive == true
            || (TryOnVersions.bodyPartTileCompositingEnabled && (
                wornBodyPartCount > 0 || hasCachedBodyPartRecords(for: draft?.selectedGarmentIDs ?? [])
            ))
        return TryOnRenderGraph.scene(
            avatar: avatar,
            garments: garments,
            outfit: draft,
            meshes: meshes,
            root: root,
            textureEpoch: textureEpoch,
            suppressGarmentOverlays: suppressOverlays
        )
    }

    var isBusy: Bool { activity != nil }

    /// False when a worn outfit still needs the aligned AI composite (OpenAI key required).
    var wornBodyPartCompositeReady: Bool {
        guard let draft, avatar != nil else { return true }
        let slotGarmentIDs = draft.selectedGarmentIDs.filter { id in
            guard let garment = garments.first(where: { $0.id == id }),
                  draft.placement(for: id).visible,
                  let category = ClothingCategory(rawValue: garment.sourceCategory),
                  TryOnBodySlot.slot(for: category) != nil else { return false }
            return true
        }
        guard !slotGarmentIDs.isEmpty else { return true }
        if TryOnAPIKey.isConfigured {
            return draft.alignedOutfitFittingActive
        }
        if TryOnVersions.bodyPartTileCompositingEnabled {
            return draft.bodyPartFittingActive
        }
        return true
    }

    func reload() async {
        let snapshot = await library.snapshot()
        root = snapshot.root
        avatar = snapshot.avatar
        garments = snapshot.garments
        outfits = snapshot.outfits
        draft = snapshot.draft
        meshes = [:]
        for garment in garments {
            if let path = garment.meshPath, let mesh = await library.loadMesh(relative: path) {
                meshes[path] = mesh
            }
        }
        if draft?.avatarID != avatar?.id { draft = nil }
        ensureDraft()
        reconcileOutfitCompositeIfNeeded()
        textureEpoch += 1
    }

    /// Loads any saved avatar, then generates the canonical one when this closet has none yet.
    func begin(from avatarSource: UIImage) async {
        await reload()
        guard avatar == nil else { return }
        createAvatar(from: avatarSource)
    }

    /// Fits a closet piece onto the canonical avatar and wears it. Creates the avatar first if needed.
    func garmentFitIsCurrent(_ asset: TryOnGarmentAsset) -> Bool {
        guard matchesAvatar(asset) else { return false }
        if let record = bodyPartStore.record(for: asset.id), bodyPartStore.isCurrent(record) {
            return asset.bodyPartImagePath != nil
                && asset.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration
        }
        if asset.bodyPartImagePath != nil,
           asset.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration {
            return true
        }
        return asset.processingVersion >= TryOnVersions.processing
    }

    private func hasCachedBodyPartRecords(for garmentIDs: [String]) -> Bool {
        garmentIDs.contains { id in
            guard let record = bodyPartStore.record(for: id) else { return false }
            return bodyPartStore.isCurrent(record) && bodyPartStore.image(for: record) != nil
        }
    }

    /// Copies on-disk body-part PNGs onto try-on garment assets for worn slots (no OpenAI required).
    func hydrateWornBodyPartsFromCache(worn: [ClothingCategory: ClothingItem]) async {
        guard avatar != nil else { return }
        let generation = activityGeneration
        for item in worn.values {
            guard let record = bodyPartStore.record(for: item.id), bodyPartStore.isCurrent(record),
                  let template = TryOnTemplateID.suggested(for: item.category) else { continue }
            if let asset = asset(for: item.id),
               asset.bodyPartImagePath != nil,
               asset.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration {
                continue
            }
            try? await applyBodyPartFit(
                item: item,
                record: record,
                template: template,
                generation: generation
            )
        }
    }

    func awaitBodyPartCompositeIdle() async {
        reconcileOutfitCompositeIfNeeded()
        var spins = 0
        while awaitingOutfitComposite || isBusy {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(40))
            spins += 1
            if spins > 500 { break }
        }
    }

    /// Keeps worn slots, body-part assets, and the baked composite aligned with the studio picker.
    func syncWornItems(
        worn: [ClothingCategory: ClothingItem],
        uiImage: (ClothingItem) -> UIImage?,
        avatarSource: UIImage
    ) {
        let wornIDs = Set(worn.values.map(\.id))
        for garment in garments where isWorn(garment.id) && !wornIDs.contains(garment.id) {
            if let category = ClothingCategory(rawValue: garment.sourceCategory) {
                takeOff(itemID: garment.id, category: category)
            }
        }
        for item in worn.values {
            guard let template = TryOnTemplateID.suggested(for: item.category),
                  let photo = uiImage(item) else { continue }
            if let asset = asset(for: item.id), garmentFitIsCurrent(asset) {
                if !isWorn(asset.id) {
                    setWorn(asset, category: item.category, on: true)
                }
                continue
            }
            wearFromCloset(
                item: item,
                template: template,
                image: photo,
                avatarSource: avatarSource
            )
        }
        reconcileOutfitCompositeIfNeeded()
    }

    func wearFromCloset(item: ClothingItem, template: TryOnTemplateID, image: UIImage, avatarSource: UIImage) {
        guard pendingFits.insert(item.id).inserted else { return }
        run("Fitting \(item.name)") { model in
            defer { model.pendingFits.remove(item.id) }
            let generation = model.activityGeneration
            if model.avatar == nil {
                let key = try model.key()
                let created = try await model.pipeline.prepareAvatar(from: avatarSource, key: key) { text in
                    model.showActivity(text, generation: generation)
                }
                model.avatar = created
                model.draft = nil
                model.ensureDraft()
                model.textureEpoch += 1
            }
            if let record = model.bodyPartStore.record(for: item.id), model.bodyPartStore.isCurrent(record) {
                model.showActivity("Using saved body-region fit", generation: generation)
                try await model.applyBodyPartFit(
                    item: item,
                    record: record,
                    template: template,
                    generation: generation
                )
                model.reconcileOutfitCompositeIfNeeded()
                return
            }
            if let existing = model.asset(for: item.id), model.matchesAvatar(existing),
               existing.bodyPartImagePath != nil,
               existing.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration {
                model.showActivity("Using saved body-region fit", generation: generation)
                model.setWorn(existing, category: item.category, on: true)
                model.reconcileOutfitCompositeIfNeeded()
                return
            }
            if let existing = model.asset(for: item.id), model.matchesAvatar(existing) {
                if existing.processingVersion >= TryOnVersions.processing {
                    model.showActivity("Using saved fit", generation: generation)
                    model.setWorn(existing, category: item.category, on: true)
                    model.reconcileOutfitCompositeIfNeeded()
                    return
                }
                model.showActivity("Refitting with updated fitting", generation: generation)
            }
            guard let avatar = model.avatar else { return }
            let key = try model.key()
            let prepared = try await model.pipeline.prepareGarment(
                item: item,
                template: template,
                photo: image,
                avatar: avatar,
                key: key
            ) { text in
                model.showActivity(text, generation: generation)
            }
            model.replace(prepared.asset)
            if prepared.asset.status != .failed {
                model.setWorn(prepared.asset, category: item.category, on: true)
                let review = prepared.asset.validation.checks.filter { !$0.passed }.map(\.message)
                let hem = prepared.asset.validation.checks.first { $0.id == "source-hem" }?.message
                model.message = review.isEmpty ? hem : review.joined(separator: " ")
                GarmentBodyPartCoordinator.shared(for: model.ownerId).itemSaved(item, image: image)
                if TryOnAPIKey.isConfigured,
                   let record = model.bodyPartStore.record(for: item.id), model.bodyPartStore.isCurrent(record) {
                    try await model.applyBodyPartFit(item: item, record: record, template: template, generation: generation)
                }
                model.reconcileOutfitCompositeIfNeeded()
            } else {
                model.message = prepared.asset.validation.checks.filter { !$0.passed }.map(\.message).joined(separator: " ")
            }
            model.textureEpoch += 1
        }
    }

    func takeOff(itemID: String, category: ClothingCategory) {
        guard let asset = asset(for: itemID) else { return }
        setWorn(asset, category: category, on: false)
    }

    func createAvatar(from image: UIImage) {
        run("Generating the stylized avatar") { model in
            let key = try model.key()
            let generation = model.activityGeneration
            let avatar = try await model.pipeline.prepareAvatar(from: image, key: key) { text in
                model.showActivity(text, generation: generation)
            }
            model.avatar = avatar
            model.draft = nil
            model.ensureDraft()
            model.textureEpoch += 1
            model.message = avatar.status == .ready
                ? nil
                : avatar.validation.checks.filter { !$0.passed }.map(\.message).joined(separator: " ")
        }
    }

    func prepare(item: ClothingItem, template: TryOnTemplateID, image: UIImage) {
        guard let avatar else {
            message = "Create an avatar before fitting a garment."
            return
        }
        run("Fitting \(item.name)") { model in
            let key = try model.key()
            let generation = model.activityGeneration
            let prepared = try await model.pipeline.prepareGarment(
                item: item,
                template: template,
                photo: image,
                avatar: avatar,
                key: key
            ) { text in
                model.showActivity(text, generation: generation)
            }
            model.replace(prepared.asset)
            let notes = prepared.asset.validation.checks.filter { !$0.passed }.map(\.message)
            if prepared.asset.status != .failed {
                model.setWorn(prepared.asset, category: item.category, on: true)
                model.message = notes.isEmpty ? nil : notes.joined(separator: " ")
                model.reconcileOutfitCompositeIfNeeded()
            } else {
                model.message = notes.joined(separator: " ")
            }
            model.textureEpoch += 1
        }
    }

    func exportPoses() {
        guard let avatar, let draft else { return }
        run("Exporting poses") { model in
            let key = try model.key()
            let generation = model.activityGeneration
            let urls = try await model.pipeline.exportPoses(
                avatar: avatar,
                garments: model.garments,
                outfit: draft,
                meshes: model.meshes,
                key: key
            ) { text in
                model.showActivity(text, generation: generation)
            }
            var images: [TryOnPose: UIImage] = [:]
            for (pose, url) in urls {
                if let image = UIImage(contentsOfFile: url.path) { images[pose] = image }
            }
            model.exportedImages = images
        }
    }

    func open(_ outfit: TryOnOutfit) {
        draft = outfit
        selectedGarmentID = outfit.selectedGarmentIDs.last
        persistDraft()
        message = outfit.avatarID == avatar?.id ? nil : "This outfit was saved for a different avatar. Refit its garments before wearing them."
    }

    func saveOutfit(name: String) {
        guard var draft else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.name = trimmed.isEmpty ? "Outfit" : trimmed
        draft.updatedAt = Date()
        draft.revision += 1
        self.draft = draft
        let outfit = draft
        Task {
            try? await library.saveOutfit(outfit)
            await reload()
        }
    }

    func dragBegan(at point: TryOnPoint) {
        guard let hit = TryOnRenderGraph.hitGarment(in: scene, at: point) ?? selectedGarmentID else { return }
        selectedGarmentID = hit
        dragOrigin = draft?.placement(for: hit).translation
    }

    func dragMoved(by translation: CGSize, in viewSize: CGSize) {
        guard let id = selectedGarmentID, let origin = dragOrigin, viewSize.width > 0, viewSize.height > 0 else { return }
        update(id) { placement in
            placement.translation.x = min(max(origin.x + translation.width / viewSize.width, -0.35), 0.35)
            placement.translation.y = min(max(origin.y + translation.height / viewSize.height, -0.35), 0.35)
        }
    }

    func dragEnded() {
        dragOrigin = nil
        persistDraft()
    }

    func pinchBegan() {
        guard let id = selectedGarmentID else { return }
        pinchBase = draft?.placement(for: id).scaleX ?? 1
    }

    func pinchChanged(_ magnification: CGFloat) {
        guard let id = selectedGarmentID, let pinchBase else { return }
        let scale = min(max(pinchBase * magnification, 0.4), 2.5)
        update(id) { placement in
            placement.scaleX = scale
            placement.scaleY = scale
        }
    }

    func pinchEnded() {
        pinchBase = nil
        persistDraft()
    }

    func setRotation(_ degrees: Double) {
        guard let id = selectedGarmentID else { return }
        update(id) { $0.rotationDegrees = degrees }
        persistDraft()
    }

    func resetSelected() {
        guard let id = selectedGarmentID else { return }
        update(id) { placement in
            placement.translation = .zero
            placement.scaleX = 1
            placement.scaleY = 1
            placement.rotationDegrees = 0
            placement.visible = true
        }
        persistDraft()
    }

    func moveSelected(forward: Bool) {
        guard var draft, let id = selectedGarmentID, let index = draft.selectedGarmentIDs.firstIndex(of: id) else { return }
        let target = forward ? index + 1 : index - 1
        guard draft.selectedGarmentIDs.indices.contains(target) else { return }
        draft.selectedGarmentIDs.swapAt(index, target)
        draft.revision += 1
        self.draft = draft
        persistDraft()
    }

    func removeSelected() {
        guard let id = selectedGarmentID, let asset = garments.first(where: { $0.id == id }) else { return }
        toggleWorn(asset, category: ClothingCategory(rawValue: asset.sourceCategory) ?? .tops)
    }

    func setWorn(_ asset: TryOnGarmentAsset, category: ClothingCategory, on: Bool) {
        guard matchesAvatar(asset) else { return }
        if isWorn(asset.id) == on {
            selectedGarmentID = asset.id
            return
        }
        toggleWorn(asset, category: category)
    }

    var pinchIsIdle: Bool { pinchBase == nil }

    func isWorn(_ id: String) -> Bool {
        draft?.selectedGarmentIDs.contains(id) == true
    }

    func asset(for id: String) -> TryOnGarmentAsset? {
        garments.first { $0.id == id }
    }

    func matchesAvatar(_ asset: TryOnGarmentAsset) -> Bool {
        (asset.status == .ready || asset.status == .needsReview)
            && asset.avatarID == avatar?.id
            && asset.avatarVersion == avatar?.version
    }

    nonisolated fileprivate func showActivity(_ text: String, generation: Int) {
        Task { @MainActor in
            guard activityGeneration == generation else { return }
            activity = text
        }
    }

    private func toggleWorn(_ asset: TryOnGarmentAsset, category: ClothingCategory) {
        guard matchesAvatar(asset), var draft else { return }
        if let index = draft.selectedGarmentIDs.firstIndex(of: asset.id) {
            draft.selectedGarmentIDs.remove(at: index)
            draft.placements.removeAll { $0.garmentID == asset.id }
            if selectedGarmentID == asset.id { selectedGarmentID = nil }
            invalidateComposite(&draft, removedGarmentID: asset.id)
        } else {
            if let slot = TryOnBodySlot.slot(for: category) {
                let evicted = draft.selectedGarmentIDs.filter { id in
                    guard id != asset.id, let other = garments.first(where: { $0.id == id }),
                          let otherCategory = ClothingCategory(rawValue: other.sourceCategory) else { return false }
                    return TryOnBodySlot.slot(for: otherCategory) == slot
                }
                for id in evicted {
                    draft.selectedGarmentIDs.removeAll { $0 == id }
                    draft.placements.removeAll { $0.garmentID == id }
                }
            }
            let rank = TryOnStack.rank(for: category)
            let insertAt = draft.selectedGarmentIDs.firstIndex { id in
                guard let other = garments.first(where: { $0.id == id }),
                      let otherCategory = ClothingCategory(rawValue: other.sourceCategory) else { return false }
                return TryOnStack.rank(for: otherCategory) > rank
            } ?? draft.selectedGarmentIDs.endIndex
            draft.selectedGarmentIDs.insert(asset.id, at: insertAt)
            if !draft.placements.contains(where: { $0.garmentID == asset.id }) {
                draft.placements.append(.identity(garmentID: asset.id))
            }
            selectedGarmentID = asset.id
        }
        draft.revision += 1
        draft.updatedAt = Date()
        self.draft = draft
        persistDraft()
        reconcileOutfitCompositeIfNeeded()
    }

    private func replace(_ asset: TryOnGarmentAsset) {
        if let index = garments.firstIndex(where: { $0.id == asset.id }) {
            garments[index] = asset
        } else {
            garments.append(asset)
        }
        Task {
            if let path = asset.meshPath, let mesh = await library.loadMesh(relative: path) {
                meshes[path] = mesh
            }
        }
    }

    private func update(_ id: String, change: (inout TryOnGarmentPlacement) -> Void) {
        guard var draft else { return }
        if let index = draft.placements.firstIndex(where: { $0.garmentID == id }) {
            change(&draft.placements[index])
        } else {
            var placement = TryOnGarmentPlacement.identity(garmentID: id)
            change(&placement)
            draft.placements.append(placement)
        }
        draft.revision += 1
        self.draft = draft
    }

    private func ensureDraft() {
        guard let avatar, draft == nil else { return }
        let now = Date()
        draft = TryOnOutfit(
            id: UUID().uuidString,
            userID: ownerId,
            avatarID: avatar.id,
            name: "Outfit",
            selectedGarmentIDs: [],
            placements: [],
            componentOverrides: [],
            revision: 0,
            createdAt: now,
            updatedAt: now
        )
    }

    private func persistDraft() {
        guard let draft else { return }
        Task { try? await library.saveDraft(draft) }
    }

    private func key() throws -> String {
        let key = TryOnAPIKey.openAI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw TryOnImageError.missingAPIKey }
        return key
    }

    fileprivate func fittedImage(for asset: TryOnGarmentAsset) async -> UIImage? {
        guard let path = asset.fittedReferencePath else { return nil }
        return UIImage(contentsOfFile: root.appendingPathComponent(path).path)
    }

    func registerBodyPart(_ record: GarmentBodyPartRecord) {
        Task {
            guard let avatar else { return }
            guard let template = TryOnTemplateID.suggested(for: record.category) else { return }
            let item = ClothingItem(
                id: record.itemId,
                ownerId: record.ownerId,
                name: record.itemId,
                category: record.category,
                imagePath: record.localImagePath,
                createdAt: record.createdAt
            )
            if let asset = try? await ensureBodyPartAsset(item: item, record: record, avatar: avatar, template: template) {
                replace(asset)
                if isWorn(record.itemId) {
                    reconcileOutfitCompositeIfNeeded()
                } else {
                    textureEpoch += 1
                }
            }
        }
    }

    fileprivate func applyBodyPartFit(
        item: ClothingItem,
        record: GarmentBodyPartRecord,
        template: TryOnTemplateID,
        generation: Int
    ) async throws {
        guard let avatar else { return }
        let asset = try await ensureBodyPartAsset(item: item, record: record, avatar: avatar, template: template)
        replace(asset)
        setWorn(asset, category: item.category, on: true)
        reconcileOutfitCompositeIfNeeded()
        textureEpoch += 1
    }

    private func ensureBodyPartAsset(
        item: ClothingItem,
        record: GarmentBodyPartRecord,
        avatar: TryOnAvatar,
        template: TryOnTemplateID
    ) async throws -> TryOnGarmentAsset {
        let now = Date()
        let existing = asset(for: item.id)
        var asset = TryOnGarmentAsset(
            id: item.id,
            userID: ownerId,
            avatarID: avatar.id,
            avatarVersion: avatar.version,
            originalImagePath: existing?.originalImagePath ?? "garments/\(item.id)/original.png",
            fittedReferencePath: existing?.fittedReferencePath,
            bodyPartImagePath: existing?.bodyPartImagePath,
            bodyPartGenerationVersion: TryOnVersions.bodyPartGeneration,
            components: existing?.components ?? [],
            anchors: existing?.anchors ?? [:],
            contentBounds: TryOnRect(x: 0, y: 0, width: 1, height: 1),
            fit: existing?.fit ?? TryOnGarmentFit(
                templateId: template.rawValue,
                fitStyle: template.fitStyle,
                preserveSilhouette: template.preserveSilhouette,
                ease: TryOnEase(maxLocalDisplacement: TryOnVersions.maxLocalDisplacement, shoulderDrop: 0),
                upperTemplateId: nil,
                bypassedUpperTemplate: false
            ),
            meshPath: existing?.meshPath,
            occlusionPath: existing?.occlusionPath,
            sourceCategory: item.category.rawValue,
            processingVersion: TryOnVersions.bodyPartProcessing,
            styleVersion: TryOnVersions.style,
            promptVersion: TryOnVersions.bodyPartPrompt,
            providerVersion: TryOnVersions.provider,
            attemptCount: existing?.attemptCount ?? 0,
            status: .ready,
            validation: .empty,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
        let closetFile = bodyPartStore.closetRoot.appendingPathComponent(record.localImagePath)
        return try await library.saveBodyPartGarment(asset, closetBodyPartFile: closetFile)
    }

    fileprivate func refreshBodyPartComposite(generation: Int) async throws {
        guard var draft, let avatar else { return }
        let bodyRelative = avatar.layers.bodyBasePath ?? avatar.canonicalImagePath
        let bodyPath = root.appendingPathComponent(bodyRelative)
        guard let avatarBody = UIImage(contentsOfFile: bodyPath.path)?.cgImage else { return }
        let landmarks = avatar.fittingMap.landmarks
        let skinBase: CGImage
        if TryOnVersions.bodyPartTileCompositingEnabled,
           let cleared = TryOnBitmap.skinOnlyBodyPartBase(avatarBody: avatarBody, landmarks: landmarks) {
            skinBase = cleared
        } else {
            skinBase = avatarBody
        }
        var layers: [TryOnBitmap.BodyPartLayer] = []
        for id in draft.selectedGarmentIDs {
            guard draft.placement(for: id).visible,
                  let garment = garments.first(where: { $0.id == id }),
                  garment.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration,
                  let category = ClothingCategory(rawValue: garment.sourceCategory),
                  let slot = TryOnBodySlot.slot(for: category),
                  let path = garment.bodyPartImagePath,
                  path.contains("/body-part.png"),
                  let image = UIImage(contentsOfFile: root.appendingPathComponent(path).path)?.cgImage else {
                continue
            }
            layers.append(TryOnBitmap.BodyPartLayer(slot: slot, image: image))
        }
        guard !layers.isEmpty else {
            draft.compositeImagePath = nil
            draft.compositeBakedGarmentIDs = nil
            draft.compositeProcessingVersion = nil
            draft.revision += 1
            draft.updatedAt = Date()
            self.draft = draft
            persistDraft()
            textureEpoch += 1
            return
        }
        showActivity("Compositing body-region fits", generation: generation)
        guard let composite = TryOnBitmap.compositeBodyPartLayers(
            base: skinBase,
            landmarks: landmarks,
            layers: layers,
            clearSlotsBeforePaint: TryOnVersions.bodyPartTileCompositingEnabled
        ) else { return }
        let relative = try await library.saveOutfitComposite(composite, outfitID: draft.id)
        draft.compositeImagePath = relative
        draft.compositeProcessingVersion = TryOnVersions.bodyPartProcessing
        let wornReady = draft.selectedGarmentIDs.filter { id in
            garments.contains {
                $0.id == id
                    && $0.bodyPartImagePath != nil
                    && $0.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration
            }
        }
        draft.compositeBakedGarmentIDs = wornReady
        draft.revision += 1
        draft.updatedAt = Date()
        self.draft = draft
        persistDraft()
        textureEpoch += 1
    }

    fileprivate func refreshAvatarComposite(
        item: ClothingItem,
        template: TryOnTemplateID,
        sourcePhoto: UIImage,
        garmentCutout: UIImage?,
        key: String,
        generation: Int
    ) async throws {
        guard var draft, let avatar, let source = TryOnBitmap.aspectFit(sourcePhoto, canvas: .canonical) else { return }
        let cutout = garmentCutout.flatMap { TryOnBitmap.aspectFit($0, canvas: .canonical) }
        showActivity("Rendering outfit on avatar", generation: generation)
        do {
            let composite = try await pipeline.composeWornLook(
                item: item,
                template: template,
                sourcePhoto: source,
                garmentCutout: cutout,
                avatar: avatar,
                outfit: draft,
                garments: garments,
                key: key
            ) { text in
                self.showActivity(text, generation: generation)
            }
            let relative = try await library.saveOutfitComposite(composite, outfitID: draft.id)
            draft.compositeImagePath = relative
            draft.compositeProcessingVersion = TryOnVersions.processing
            let wornReady = draft.selectedGarmentIDs.filter { id in
                garments.contains { $0.id == id && ($0.status == .ready || $0.status == .needsReview) }
            }
            draft.compositeBakedGarmentIDs = wornReady
            draft.revision += 1
            draft.updatedAt = Date()
            self.draft = draft
            persistDraft()
            textureEpoch += 1
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            showActivity("AI outfit render unavailable, using overlays", generation: generation)
            draft.compositeImagePath = nil
            draft.compositeBakedGarmentIDs = nil
            draft.compositeProcessingVersion = nil
            self.draft = draft
            persistDraft()
            textureEpoch += 1
        }
    }

    func reconcileOutfitCompositeIfNeeded() {
        guard let draft, let avatar else { return }
        let visibleWorn = draft.selectedGarmentIDs.filter { id in
            guard draft.placement(for: id).visible,
                  let garment = garments.first(where: { $0.id == id }),
                  garment.status == .ready || garment.status == .needsReview else { return false }
            return true
        }
        if visibleWorn.isEmpty {
            if draft.compositeImagePath != nil {
                var cleared = draft
                cleared.compositeImagePath = nil
                cleared.compositeBakedGarmentIDs = nil
                cleared.compositeProcessingVersion = nil
                self.draft = cleared
                persistDraft()
                textureEpoch += 1
            }
            return
        }
        if TryOnAPIKey.isConfigured {
            let baked = Set(draft.compositeBakedGarmentIDs ?? [])
            let wornSet = Set(visibleWorn)
            let staleBodyPart = draft.compositeProcessingVersion == TryOnVersions.bodyPartProcessing
            let needsRefresh = staleBodyPart
                || draft.compositeProcessingVersion != TryOnVersions.alignedOutfitProcessing
                || !draft.alignedOutfitFittingActive
                || baked != wornSet
            guard needsRefresh else { return }
            awaitingOutfitComposite = true
            textureEpoch += 1
            run("Rendering aligned outfit") { model in
                let generation = model.activityGeneration
                defer {
                    model.awaitingOutfitComposite = false
                    model.textureEpoch += 1
                }
                try await model.refreshAlignedOutfitComposite(generation: generation)
            }
            return
        }
        if TryOnVersions.bodyPartTileCompositingEnabled {
            reconcileBodyPartTileCompositeIfNeeded()
        } else if draft.bodyPartFittingActive || draft.compositeProcessingVersion == TryOnVersions.bodyPartProcessing {
            var cleared = draft
            cleared.compositeImagePath = nil
            cleared.compositeBakedGarmentIDs = nil
            cleared.compositeProcessingVersion = nil
            self.draft = cleared
            persistDraft()
            textureEpoch += 1
        }
    }

    func reconcileBodyPartCompositeIfNeeded() {
        reconcileOutfitCompositeIfNeeded()
    }

    private func reconcileBodyPartTileCompositeIfNeeded() {
        guard let draft, avatar != nil else { return }
        let wornBodyParts = draft.selectedGarmentIDs.filter { id in
            garments.contains {
                $0.id == id
                    && $0.bodyPartImagePath != nil
                    && $0.bodyPartGenerationVersion == TryOnVersions.bodyPartGeneration
            }
        }
        guard !wornBodyParts.isEmpty else { return }
        let baked = Set(draft.compositeBakedGarmentIDs ?? [])
        let wornSet = Set(wornBodyParts)
        let needsRefresh = draft.compositeProcessingVersion != TryOnVersions.bodyPartProcessing
            || !draft.bodyPartFittingActive
            || baked != wornSet
        guard needsRefresh else { return }
        awaitingOutfitComposite = true
        textureEpoch += 1
        run("Recompositing body-region fits") { model in
            let generation = model.activityGeneration
            defer {
                model.awaitingOutfitComposite = false
                model.textureEpoch += 1
            }
            try await model.refreshBodyPartComposite(generation: generation)
        }
    }

    fileprivate func refreshAlignedOutfitComposite(generation: Int) async throws {
        guard var draft, let avatar else { return }
        let wornReady = draft.selectedGarmentIDs.filter { id in
            guard draft.placement(for: id).visible else { return false }
            return garments.contains { $0.id == id && ($0.status == .ready || $0.status == .needsReview) }
        }
        guard !wornReady.isEmpty else {
            draft.compositeImagePath = nil
            draft.compositeBakedGarmentIDs = nil
            draft.compositeProcessingVersion = nil
            self.draft = draft
            persistDraft()
            textureEpoch += 1
            return
        }
        let key = try key()
        showActivity("Rendering aligned outfit on avatar", generation: generation)
        do {
            let composite = try await pipeline.composeAlignedOutfit(
                avatar: avatar,
                outfit: draft,
                garments: garments,
                key: key
            ) { text in
                self.showActivity(text, generation: generation)
            }
            let relative = try await library.saveOutfitComposite(composite, outfitID: draft.id)
            draft.compositeImagePath = relative
            draft.compositeProcessingVersion = TryOnVersions.alignedOutfitProcessing
            draft.compositeBakedGarmentIDs = wornReady
            draft.revision += 1
            draft.updatedAt = Date()
            self.draft = draft
            persistDraft()
            textureEpoch += 1
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            showActivity("Aligned outfit unavailable, using garment overlays", generation: generation)
            draft.compositeImagePath = nil
            draft.compositeBakedGarmentIDs = nil
            draft.compositeProcessingVersion = nil
            self.draft = draft
            persistDraft()
            textureEpoch += 1
        }
    }

    private func invalidateComposite(_ draft: inout TryOnOutfit, removedGarmentID: String) {
        guard draft.compositeDisplayActive else { return }
        var baked = draft.compositeBakedGarmentIDs ?? []
        baked.removeAll { $0 == removedGarmentID }
        if baked.isEmpty || baked.count != draft.selectedGarmentIDs.count {
            draft.compositeImagePath = nil
            draft.compositeBakedGarmentIDs = nil
            draft.compositeProcessingVersion = nil
        } else {
            draft.compositeBakedGarmentIDs = baked
        }
    }

    private func run(_ label: String, _ work: @escaping (TryOnEditorModel) async throws -> Void) {
        jobs.append((label, work))
        guard !draining else { return }
        draining = true
        Task { @MainActor in
            activityGeneration += 1
            let generation = activityGeneration
            while !jobs.isEmpty {
                let (label, work) = jobs.removeFirst()
                activity = label
                message = nil
                do {
                    try await work(self)
                } catch is CancellationError {
                    jobs.removeAll()
                    break
                } catch {
                    message = error.localizedDescription
                }
            }
            if activityGeneration == generation {
                activity = nil
                activityGeneration += 1
            }
            draining = false
        }
    }
}

/// The generated avatar and fitted garments. Placement gestures stay off when another control
/// needs the taps, such as the body-part picker.
struct TryOnFittedFigure: View {
    @Bindable var model: TryOnEditorModel
    var allowsPlacementGestures = false
    @State private var rendererNote: String?

    var body: some View {
        GeometryReader { geo in
            TryOnMetalCanvas(scene: model.scene, note: $rendererNote)
                .accessibilityIdentifier("tryon.canvas")
                .allowsHitTesting(allowsPlacementGestures)
                .modifier(PlacementGestures(enabled: allowsPlacementGestures, model: model, size: geo.size))
        }
        .overlay {
            if model.avatar == nil && !model.isBusy {
                Text(model.message ?? "Preparing the fitting avatar")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        }
        .overlay(alignment: .top) {
            if model.isBusy {
                Text(model.activity ?? "Working")
                    .font(.caption.weight(.medium))
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = model.message, !message.isEmpty, model.avatar != nil || model.isBusy {
                Text(message)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(8)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(8)
            }
        }
    }
}

private struct PlacementGestures: ViewModifier {
    var enabled: Bool
    var model: TryOnEditorModel
    var size: CGSize

    func body(content: Content) -> some View {
        if enabled {
            content
                .gesture(drag)
                .simultaneousGesture(pinch)
        } else {
            content
        }
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                if model.selectedGarmentID == nil || value.translation == .zero {
                    let point = TryOnPoint(
                        x: value.startLocation.x / max(size.width, 1),
                        y: value.startLocation.y / max(size.height, 1)
                    )
                    model.dragBegan(at: point)
                }
                model.dragMoved(by: value.translation, in: size)
            }
            .onEnded { _ in model.dragEnded() }
    }

    private var pinch: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if model.pinchIsIdle { model.pinchBegan() }
                model.pinchChanged(value)
            }
            .onEnded { _ in model.pinchEnded() }
    }
}

struct TryOnEditorView: View {
    let items: [ClothingItem]
    var uiImage: ((ClothingItem) -> UIImage?)?
    @State private var model: TryOnEditorModel
    @State private var outfitName = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var templates: [String: TryOnTemplateID] = [:]
    @State private var rendererNote: String?

    init(ownerId: String, items: [ClothingItem], uiImage: ((ClothingItem) -> UIImage?)? = nil) {
        self.items = items
        self.uiImage = uiImage
        _model = State(initialValue: TryOnEditorModel(ownerId: ownerId))
    }

    var body: some View {
        VStack(spacing: 8) {
            canvas
            if let message = model.message, !message.isEmpty {
                Text(message).font(.footnote).foregroundStyle(.secondary).padding(.horizontal)
            }
            controls
            wardrobe
        }
        .task { await model.reload() }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    model.createAvatar(from: image)
                }
            }
        }
    }

    private var canvas: some View {
        GeometryReader { geo in
            TryOnMetalCanvas(scene: model.scene, note: $rendererNote)
                .accessibilityIdentifier("tryon.canvas")
                .gesture(drag(in: geo.size))
                .simultaneousGesture(pinch)
        }
        .frame(height: 360)
        .overlay {
            if model.avatar == nil {
                Text("Create a front-facing avatar to start fitting.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay(alignment: .top) {
            if model.isBusy {
                Text(model.activity ?? "Working")
                    .font(.caption.weight(.medium))
                    .padding(8)
                    .background(.thinMaterial, in: Capsule())
                    .padding(8)
            }
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PhotosPicker(selection: $photoItem, matching: .images) {
                    Text(model.avatar == nil ? "Choose avatar photo" : "New avatar photo")
                }
                .disabled(model.isBusy || !TryOnAPIKey.isConfigured)
                Button("Export five poses") { model.exportPoses() }
                    .disabled(model.isBusy || !TryOnAPIKey.isConfigured || model.draft?.selectedGarmentIDs.isEmpty != false)
            }
            if model.selectedGarmentID != nil {
                HStack {
                    Button("Back") { model.moveSelected(forward: false) }
                    Button("Forward") { model.moveSelected(forward: true) }
                    Button("Reset") { model.resetSelected() }
                    Button("Remove") { model.removeSelected() }
                }
                .buttonStyle(.bordered)
                if let placement = selectedPlacement {
                    Slider(
                        value: Binding(
                            get: { placement.rotationDegrees },
                            set: { model.setRotation($0) }
                        ),
                        in: -45...45
                    ) { Text("Rotation") }
                }
            }
            HStack {
                TextField("Outfit name", text: $outfitName)
                    .textFieldStyle(.roundedBorder)
                Button("Save outfit") { model.saveOutfit(name: outfitName) }
            }
            if !model.outfits.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(model.outfits) { outfit in
                            Button(outfit.name) { model.open(outfit) }
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            if !model.exportedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(TryOnPose.allCases) { pose in
                            if let image = model.exportedImages[pose] {
                                VStack {
                                    Image(uiImage: image).resizable().scaledToFit().frame(height: 90)
                                    Text(pose.title).font(.caption2)
                                }
                            }
                        }
                    }
                }
            }
            Text("Dragging, scaling, and switching outfits stays on this device. Image generation runs only for a new avatar, a garment fit, or an export.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let rendererNote {
                Text(rendererNote).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
    }

    private var wardrobe: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(items) { item in
                    garmentRow(item)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
    }

    private func garmentRow(_ item: ClothingItem) -> some View {
        let template = templates[item.id] ?? TryOnTemplateID.suggested(for: item.category)
        let asset = model.asset(for: item.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text(item.name).font(.subheadline.weight(.semibold))
            Text(item.category.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
            Picker("Fitting template", selection: Binding(
                get: { template ?? .tShirt },
                set: { templates[item.id] = $0 }
            )) {
                ForEach(TryOnTemplateID.allCases) { candidate in
                    Text(candidate.displayName).tag(candidate)
                }
            }
            .pickerStyle(.menu)
            if let asset, model.matchesAvatar(asset) {
                Button(model.isWorn(asset.id) ? "Remove from outfit" : "Wear") {
                    model.setWorn(asset, category: item.category, on: !model.isWorn(asset.id))
                }
            }
            Button(asset?.status == .ready ? "Refit" : "Prepare") {
                guard let active = template, let image = sourceImage(for: item) else { return }
                model.prepare(item: item, template: active, image: image)
            }
            .disabled(model.isBusy || !TryOnAPIKey.isConfigured || template == nil || sourceImage(for: item) == nil)
            if let asset, asset.status != .ready {
                Text(asset.status == .needsReview ? "Needs review" : "Not ready")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var selectedPlacement: TryOnGarmentPlacement? {
        guard let id = model.selectedGarmentID else { return nil }
        return model.draft?.placement(for: id)
    }

    private func sourceImage(for item: ClothingItem) -> UIImage? {
        if let image = uiImage?(item) { return image }
        if item.imagePath.hasPrefix("/") { return UIImage(contentsOfFile: item.imagePath) }
        return nil
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if model.selectedGarmentID == nil || value.translation == .zero {
                    let point = TryOnPoint(
                        x: value.startLocation.x / max(size.width, 1),
                        y: value.startLocation.y / max(size.height, 1)
                    )
                    model.dragBegan(at: point)
                }
                model.dragMoved(by: value.translation, in: size)
            }
            .onEnded { _ in model.dragEnded() }
    }

    private var pinch: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                if model.pinchIsIdle { model.pinchBegan() }
                model.pinchChanged(value)
            }
            .onEnded { _ in model.pinchEnded() }
    }
}
