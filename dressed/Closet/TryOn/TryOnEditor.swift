import PhotosUI
import SwiftUI
import UIKit

@MainActor
@Observable
final class TryOnEditorModel {
    private let library: TryOnLibrary
    private let pipeline: TryOnPipeline
    private let ownerId: String

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
    private var running: Task<Void, Never>?

    init(ownerId: String) {
        let library = TryOnLibrary(ownerId: ownerId)
        self.library = library
        let resolvedOwner = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ownerId = resolvedOwner.isEmpty ? "local" : resolvedOwner
        pipeline = TryOnPipeline(library: library, ownerId: self.ownerId)
    }

    var scene: TryOnScene {
        TryOnRenderGraph.scene(
            avatar: avatar,
            garments: garments,
            outfit: draft,
            meshes: meshes,
            root: root,
            textureEpoch: textureEpoch
        )
    }

    var isBusy: Bool { activity != nil }

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
        textureEpoch += 1
    }

    /// Fits a closet piece onto the canonical avatar and wears it. Creates the avatar first if needed.
    func wearFromCloset(item: ClothingItem, template: TryOnTemplateID, image: UIImage, avatarSource: UIImage) {
        run("Fitting \(item.name)") { model in
            if model.avatar == nil {
                let key = try model.key()
                let created = try await model.pipeline.prepareAvatar(from: avatarSource, key: key) { text in
                    Task { @MainActor in model.activity = text }
                }
                model.avatar = created
                model.draft = nil
                model.ensureDraft()
                model.textureEpoch += 1
            }
            if let existing = model.asset(for: item.id), model.matchesAvatar(existing) {
                model.setWorn(existing, category: item.category, on: true)
                return
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
                Task { @MainActor in model.activity = text }
            }
            model.replace(prepared.asset)
            if prepared.asset.status == .ready {
                model.setWorn(prepared.asset, category: item.category, on: true)
                model.message = nil
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
            let avatar = try await model.pipeline.prepareAvatar(from: image, key: key) { text in
                Task { @MainActor in model.activity = text }
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
            let prepared = try await model.pipeline.prepareGarment(
                item: item,
                template: template,
                photo: image,
                avatar: avatar,
                key: key
            ) { text in
                Task { @MainActor in model.activity = text }
            }
            model.replace(prepared.asset)
            if prepared.asset.status == .ready {
                model.toggleWorn(prepared.asset, category: item.category)
                model.message = nil
            } else {
                model.message = prepared.asset.validation.checks.filter { !$0.passed }.map(\.message).joined(separator: " ")
            }
            model.textureEpoch += 1
        }
    }

    func exportPoses() {
        guard let avatar, let draft else { return }
        run("Exporting poses") { model in
            let key = try model.key()
            let urls = try await model.pipeline.exportPoses(
                avatar: avatar,
                garments: model.garments,
                outfit: draft,
                meshes: model.meshes,
                key: key
            ) { text in
                Task { @MainActor in model.activity = text }
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
        asset.status == .ready && asset.avatarID == avatar?.id && asset.avatarVersion == avatar?.version
    }

    private func toggleWorn(_ asset: TryOnGarmentAsset, category: ClothingCategory) {
        guard matchesAvatar(asset), var draft else { return }
        if let index = draft.selectedGarmentIDs.firstIndex(of: asset.id) {
            draft.selectedGarmentIDs.remove(at: index)
            draft.placements.removeAll { $0.garmentID == asset.id }
            if selectedGarmentID == asset.id { selectedGarmentID = nil }
        } else {
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

    private func run(_ label: String, _ work: @escaping (TryOnEditorModel) async throws -> Void) {
        running?.cancel()
        activity = label
        message = nil
        running = Task {
            do {
                try await work(self)
                if !Task.isCancelled { activity = nil }
            } catch is CancellationError {
                activity = nil
            } catch {
                activity = nil
                message = error.localizedDescription
            }
        }
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
