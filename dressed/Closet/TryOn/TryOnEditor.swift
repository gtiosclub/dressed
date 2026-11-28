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
    private var outfitCompositeReconcileTask: Task<Void, Never>?
    private var outfitCompositeRefreshInFlight = false
    private var outfitCompositeRefreshReschedule = false
    /// Worn+avatar signature where aligned composite failed; overlays are shown until the outfit changes.
    private var outfitCompositeOverlayFallbackKey: String?

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

    var isBusy: Bool {
        draining
    }

    /// False when a worn outfit still needs the aligned AI composite (OpenAI key required).
    var wornBodyPartCompositeReady: Bool {
        guard let draft, avatar != nil else { return true }
        let slotGarmentIDs = draft.selectedGarmentIDs.filter { id in
            guard let garment = garments.first(where: { $0.id == id }),
                  draft.placement(for: id).visible,
                  garment.tryOnBodySlot != nil else { return false }
            return true
        }
        guard !slotGarmentIDs.isEmpty else { return true }
        if TryOnAPIKey.isConfigured {
            let cacheKey = alignedOutfitCacheKey(for: draft) ?? ""
            if !cacheKey.isEmpty, outfitCompositeOverlayFallbackKey == cacheKey { return true }
            if awaitingOutfitComposite || outfitCompositeRefreshInFlight { return false }
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
        outfitCompositeReconcileTask?.cancel()
        outfitCompositeReconcileTask = nil
        reconcileOutfitCompositeNow()
        var spins = 0
        while awaitingOutfitComposite || outfitCompositeRefreshInFlight || isBusy {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(40))
            spins += 1
            if spins > 500 {
                awaitingOutfitComposite = false
                break
            }
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
                GarmentBodyPartCoordinator.shared(for: model.ownerId).itemSaved(item, image: image)
                if TryOnAPIKey.isConfigured,
                   let record = model.bodyPartStore.record(for: item.id), model.bodyPartStore.isCurrent(record) {
                    try await model.applyBodyPartFit(item: item, record: record, template: template, generation: generation)
                }
                model.reconcileOutfitCompositeIfNeeded()
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
        }
    }

    func prepare(item: ClothingItem, template: TryOnTemplateID, image: UIImage) {
        guard let avatar else {
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
            if prepared.asset.status != .failed {
                model.setWorn(prepared.asset, category: item.category, on: true)
                model.reconcileOutfitCompositeIfNeeded()
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
        #if DEBUG
        Task { @MainActor in
            guard activityGeneration == generation else { return }
            NSLog("[TryOn] %@", text)
        }
        #endif
    }

    private func toggleWorn(_ asset: TryOnGarmentAsset, category: ClothingCategory) {
        guard matchesAvatar(asset), var draft else { return }
        if let index = draft.selectedGarmentIDs.firstIndex(of: asset.id) {
            draft.selectedGarmentIDs.remove(at: index)
            draft.placements.removeAll { $0.garmentID == asset.id }
            if selectedGarmentID == asset.id { selectedGarmentID = nil }
            invalidateComposite(&draft, removedGarmentID: asset.id)
        } else {
            if let slot = TryOnBodySlot.slot(for: category, name: asset.sourceName) {
                let evicted = draft.selectedGarmentIDs.filter { id in
                    guard id != asset.id, let other = garments.first(where: { $0.id == id }) else { return false }
                    return other.tryOnBodySlot == slot
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
            sourceName: item.name,
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
                  let slot = garment.tryOnBodySlot,
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
        showActivity("Compositing body-region outfit tiles", generation: generation)
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
        outfitCompositeReconcileTask?.cancel()
        outfitCompositeReconcileTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            reconcileOutfitCompositeNow()
        }
    }

    private func visibleAlignedGarmentIDs(for draft: TryOnOutfit) -> [String] {
        draft.selectedGarmentIDs.filter { id in
            guard draft.placement(for: id).visible,
                  let garment = garments.first(where: { $0.id == id }),
                  garment.status == .ready || garment.status == .needsReview,
                  garment.tryOnBodySlot != nil else { return false }
            return true
        }
    }

    private func alignedOutfitCacheKey(for draft: TryOnOutfit) -> String? {
        guard let avatar else { return nil }
        let visible = visibleAlignedGarmentIDs(for: draft)
        guard !visible.isEmpty else { return nil }
        return OutfitCompositeRecord.cacheKey(garmentIds: visible, avatarVersion: avatar.version)
    }

    private func reconcileOutfitCompositeNow() {
        guard var draft, let avatar else { return }
        let visibleWorn = visibleAlignedGarmentIDs(for: draft)
        if visibleWorn.isEmpty {
            outfitCompositeOverlayFallbackKey = nil
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
            let cacheKey = OutfitCompositeRecord.cacheKey(
                garmentIds: visibleWorn,
                avatarVersion: avatar.version
            )
            if outfitCompositeOverlayFallbackKey != nil, outfitCompositeOverlayFallbackKey != cacheKey {
                outfitCompositeOverlayFallbackKey = nil
            }
            let l1Relative = OutfitCompositeRecord.localRelativePath(cacheKey: cacheKey)
            let l1URL = root.appendingPathComponent(l1Relative)
            if FileManager.default.fileExists(atPath: l1URL.path) {
                if TryOnLibrary.validatePNG(at: l1URL) {
                    outfitCompositeOverlayFallbackKey = nil
                    if baked != wornSet
                        || draft.compositeProcessingVersion != TryOnVersions.alignedOutfitProcessing
                        || draft.compositeImagePath != l1Relative
                        || !draft.alignedOutfitFittingActive {
                        var updated = draft
                        updated.compositeImagePath = l1Relative
                        updated.compositeBakedGarmentIDs = visibleWorn
                        updated.compositeProcessingVersion = TryOnVersions.alignedOutfitProcessing
                        updated.revision += 1
                        updated.updatedAt = Date()
                        self.draft = updated
                        persistDraft()
                        textureEpoch += 1
                        #if DEBUG
                        NSLog(
                            "[TryOn] composite saved path=%@ active=%@",
                            l1Relative,
                            updated.alignedOutfitFittingActive ? "yes" : "no"
                        )
                        #endif
                    }
                    return
                }
                #if DEBUG
                NSLog("[TryOn] L1 outfit composite invalid, deleting and regenerating cacheKey=%@", cacheKey)
                #endif
                try? FileManager.default.removeItem(at: l1URL)
                if draft.alignedOutfitFittingActive || draft.compositeImagePath == l1Relative {
                    var cleared = draft
                    cleared.compositeImagePath = nil
                    cleared.compositeBakedGarmentIDs = nil
                    cleared.compositeProcessingVersion = nil
                    self.draft = cleared
                    persistDraft()
                    textureEpoch += 1
                }
            }
            if let activePath = draft.compositeImagePath,
               draft.compositeProcessingVersion == TryOnVersions.alignedOutfitProcessing,
               !TryOnLibrary.validatePNG(at: root.appendingPathComponent(activePath)) {
                var cleared = draft
                cleared.compositeImagePath = nil
                cleared.compositeBakedGarmentIDs = nil
                cleared.compositeProcessingVersion = nil
                self.draft = cleared
                persistDraft()
                textureEpoch += 1
                draft = cleared
            }
            if outfitCompositeOverlayFallbackKey == cacheKey {
                return
            }
            let staleBodyPart = draft.compositeProcessingVersion == TryOnVersions.bodyPartProcessing
            let needsRefresh = staleBodyPart
                || draft.compositeProcessingVersion != TryOnVersions.alignedOutfitProcessing
                || !draft.alignedOutfitFittingActive
                || baked != wornSet
            guard needsRefresh else { return }
            scheduleAlignedOutfitCompositeRefresh()
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
        scheduleBodyPartTileCompositeRefresh()
    }

    private func scheduleAlignedOutfitCompositeRefresh() {
        guard !outfitCompositeRefreshInFlight else {
            outfitCompositeRefreshReschedule = true
            return
        }
        outfitCompositeRefreshInFlight = true
        awaitingOutfitComposite = true
        textureEpoch += 1
        run("Rendering aligned outfit") { model in
            let generation = model.activityGeneration
            defer {
                model.awaitingOutfitComposite = false
                model.outfitCompositeRefreshInFlight = false
                model.textureEpoch += 1
                if model.outfitCompositeRefreshReschedule {
                    model.outfitCompositeRefreshReschedule = false
                    model.reconcileOutfitCompositeNow()
                }
            }
            try await model.refreshAlignedOutfitComposite(generation: generation)
        }
    }

    private func scheduleBodyPartTileCompositeRefresh() {
        guard !outfitCompositeRefreshInFlight else {
            outfitCompositeRefreshReschedule = true
            return
        }
        outfitCompositeRefreshInFlight = true
        awaitingOutfitComposite = true
        textureEpoch += 1
        run("Compositing body-region outfit") { model in
            let generation = model.activityGeneration
            defer {
                model.awaitingOutfitComposite = false
                model.outfitCompositeRefreshInFlight = false
                model.textureEpoch += 1
                if model.outfitCompositeRefreshReschedule {
                    model.outfitCompositeRefreshReschedule = false
                    model.reconcileOutfitCompositeNow()
                }
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
        let cacheKey = OutfitCompositeRecord.cacheKey(
            garmentIds: wornReady,
            avatarVersion: avatar.version
        )
        let wornSet = Set(wornReady)

        if await library.alignedOutfitCacheExists(cacheKey) {
            if await library.alignedOutfitCacheIsValid(cacheKey) {
                let relative = await library.alignedOutfitCacheRelativePath(cacheKey)
                applyAlignedOutfitComposite(relative: relative, wornReady: wornReady, draft: &draft)
                self.draft = draft
                persistDraft()
                textureEpoch += 1
                return
            }
            await library.deleteAlignedOutfitCache(cacheKey: cacheKey)
            #if DEBUG
            NSLog("[TryOn] local aligned outfit cache invalid; will regenerate cacheKey=%@", cacheKey)
            #endif
        }

        if OutfitCompositeFunctions.isOwnerSignedIn(ownerId) {
            showActivity("Loading cached aligned outfit", generation: generation)
            do {
                if let remote = try await OutfitCompositeFunctions.downloadMetadata(ownerId: ownerId, cacheKey: cacheKey),
                   remote.processingVersion == TryOnVersions.alignedOutfitProcessing,
                   remote.avatarVersion == avatar.version,
                   Set(remote.garmentIds) == wornSet,
                   remote.status == .ready,
                   let storagePath = remote.storagePath {
                    let pngData = try await OutfitCompositeFunctions.downloadPNG(storagePath: storagePath)
                    guard pngData.count > 128,
                          pngData.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]),
                          let image = UIImage(data: pngData)?.cgImage,
                          image.width > 8,
                          image.height > 8,
                          TryOnBitmap.rgba(from: image) != nil else {
                        throw TryOnStoreError.unreadableImage
                    }
                    let relative = try await library.saveAlignedOutfitCache(image, cacheKey: cacheKey)
                    applyAlignedOutfitComposite(relative: relative, wornReady: wornReady, draft: &draft)
                    self.draft = draft
                    persistDraft()
                    textureEpoch += 1
                    return
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logCompositeError(error, context: "remote aligned outfit cache")
            }
        }

        showActivity("Rendering aligned outfit on avatar", generation: generation)
        do {
            let key = try key()
            let composite = try await pipeline.composeAlignedOutfit(
                avatar: avatar,
                outfit: draft,
                garments: garments,
                key: key
            ) { text in
                self.showActivity(text, generation: generation)
            }
            let relative = try await library.saveAlignedOutfitCache(composite, cacheKey: cacheKey)
            applyAlignedOutfitComposite(relative: relative, wornReady: wornReady, draft: &draft)
            if let pngData = TryOnBitmap.pngData(from: composite),
               OutfitCompositeFunctions.isOwnerSignedIn(ownerId) {
                let storagePath = OutfitCompositeRecord.storagePath(ownerId: ownerId, cacheKey: cacheKey)
                let record = OutfitCompositeRecord(
                    id: cacheKey,
                    cacheKey: cacheKey,
                    ownerId: ownerId,
                    garmentIds: wornReady.sorted(),
                    avatarId: avatar.id,
                    avatarVersion: avatar.version,
                    processingVersion: TryOnVersions.alignedOutfitProcessing,
                    storagePath: storagePath,
                    status: .ready,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                await OutfitCompositeFunctions.upload(record: record, pngData: pngData)
            }
            self.draft = draft
            persistDraft()
            textureEpoch += 1
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            let userMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            abandonAlignedOutfitComposite(
                cacheKey: cacheKey,
                draft: &draft,
                generation: generation,
                error: error,
                userMessage: userMessage.isEmpty ? "Aligned outfit unavailable." : userMessage
            )
        }
    }

    private func abandonAlignedOutfitComposite(
        cacheKey: String,
        draft: inout TryOnOutfit,
        generation: Int,
        error: Error?,
        userMessage: String
    ) {
        if let error {
            logCompositeError(error, context: "aligned outfit composite")
        }
        outfitCompositeOverlayFallbackKey = cacheKey
        showActivity("Using garment overlays", generation: generation)
        #if DEBUG
        if !userMessage.isEmpty {
            NSLog("[TryOn] aligned outfit fallback: %@", userMessage)
        }
        #endif
        draft.compositeImagePath = nil
        draft.compositeBakedGarmentIDs = nil
        draft.compositeProcessingVersion = nil
        self.draft = draft
        persistDraft()
        textureEpoch += 1
    }

    private func logCompositeError(_ error: Error, context: String) {
        #if DEBUG
        let ns = error as NSError
        NSLog(
            "[TryOn] %@ failed: %@ (domain=%@ code=%ld)",
            context,
            ns.localizedDescription,
            ns.domain,
            ns.code
        )
        #endif
    }

    private func applyAlignedOutfitComposite(
        relative: String,
        wornReady: [String],
        draft: inout TryOnOutfit
    ) {
        let fileURL = root.appendingPathComponent(relative)
        guard TryOnLibrary.validatePNG(at: fileURL) else {
            #if DEBUG
            NSLog("[TryOn] refusing invalid composite path=%@", relative)
            #endif
            outfitCompositeOverlayFallbackKey = OutfitCompositeRecord.cacheKey(
                garmentIds: wornReady,
                avatarVersion: avatar?.version ?? 0
            )
            #if DEBUG
            NSLog("[TryOn] saved outfit image was corrupt; using garment overlays")
            #endif
            draft.compositeImagePath = nil
            draft.compositeBakedGarmentIDs = nil
            draft.compositeProcessingVersion = nil
            return
        }
        outfitCompositeOverlayFallbackKey = nil
        draft.compositeImagePath = relative
        draft.compositeProcessingVersion = TryOnVersions.alignedOutfitProcessing
        draft.compositeBakedGarmentIDs = wornReady
        draft.revision += 1
        draft.updatedAt = Date()
        #if DEBUG
        NSLog(
            "[TryOn] composite saved path=%@ active=%@ display=%@",
            relative,
            draft.alignedOutfitFittingActive ? "yes" : "no",
            draft.compositeDisplayActive ? "yes" : "no"
        )
        #endif
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
                #if DEBUG
                NSLog("[TryOn] job: %@", label)
                #endif
                message = nil
                do {
                    try await work(self)
                } catch is CancellationError {
                    jobs.removeAll()
                    break
                } catch {
                    #if DEBUG
                    let ns = error as NSError
                    NSLog(
                        "[TryOn] job failed: %@ (domain=%@ code=%ld)",
                        ns.localizedDescription,
                        ns.domain,
                        ns.code
                    )
                    #endif
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

    var body: some View {
        GeometryReader { geo in
            TryOnMetalCanvas(scene: model.scene)
                .accessibilityIdentifier("tryon.canvas")
                .allowsHitTesting(allowsPlacementGestures)
                .modifier(PlacementGestures(enabled: allowsPlacementGestures, model: model, size: geo.size))
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

    init(ownerId: String, items: [ClothingItem], uiImage: ((ClothingItem) -> UIImage?)? = nil) {
        self.items = items
        self.uiImage = uiImage
        _model = State(initialValue: TryOnEditorModel(ownerId: ownerId))
    }

    var body: some View {
        VStack(spacing: 8) {
            canvas
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
            TryOnMetalCanvas(scene: model.scene)
                .accessibilityIdentifier("tryon.canvas")
                .gesture(drag(in: geo.size))
                .simultaneousGesture(pinch)
        }
        .frame(height: 360)
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
