import SwiftUI

/// Queues per-item body-part generation on closet save and backfills when the closet or studio loads.
@MainActor
final class GarmentBodyPartCoordinator {
    private static var instances: [String: GarmentBodyPartCoordinator] = [:]

    static func shared(for ownerId: String) -> GarmentBodyPartCoordinator {
        let key = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = instances[key] { return existing }
        let created = GarmentBodyPartCoordinator(ownerId: key)
        instances[key] = created
        return created
    }

    private let ownerId: String
    private let service: GarmentBodyPartService
    private let store: GarmentBodyPartStore
    private weak var tryOn: TryOnEditorModel?
    private var backfillTask: Task<Void, Never>?

    private init(ownerId: String) {
        self.ownerId = ownerId
        service = GarmentBodyPartService(ownerId: ownerId)
        store = GarmentBodyPartStore(ownerId: ownerId)
    }

    func attach(tryOn: TryOnEditorModel) {
        self.tryOn = tryOn
    }

    func itemSaved(_ item: ClothingItem, image: UIImage?) {
        guard let image else { return }
        if let tryOn {
            enqueue([item], photos: [item.id: image], tryOn: tryOn)
            return
        }
        Task { await generateStandalone(item: item, photo: image) }
    }

    func backfill(items: [ClothingItem], photos: [String: UIImage]) {
        guard let tryOn else { return }
        registerCachedBodyParts(items: items, tryOn: tryOn)
        enqueue(items, photos: photos, tryOn: tryOn)
    }

    /// Attaches saved body-part PNGs to try-on assets even when OpenAI is unavailable.
    func registerCachedBodyParts(items: [ClothingItem], tryOn: TryOnEditorModel) {
        for item in items {
            guard let record = store.record(for: item.id),
                  store.isCurrent(record),
                  store.image(for: record) != nil else { continue }
            tryOn.registerBodyPart(record)
        }
    }

    func backfillFromCloset(items: [ClothingItem], imageLoader: @escaping (ClothingItem) -> UIImage?) {
        backfillTask?.cancel()
        backfillTask = Task {
            let pending = store.itemsNeedingGeneration(from: items, avatar: await currentAvatar())
            guard !pending.isEmpty else { return }
            var photos: [String: UIImage] = [:]
            for item in pending {
                if let record = store.record(for: item.id), !store.isCurrent(record) {
                    _ = await service.restoreFromCloud(itemId: item.id)
                }
                if let image = imageLoader(item) { photos[item.id] = image }
            }
            guard let tryOn = self.tryOn else { return }
            enqueue(store.itemsNeedingGeneration(from: items, avatar: tryOn.avatar), photos: photos, tryOn: tryOn)
        }
    }

    private func enqueue(_ items: [ClothingItem], photos: [String: UIImage], tryOn: TryOnEditorModel) {
        registerCachedBodyParts(items: items, tryOn: tryOn)
        let pending = store.itemsNeedingGeneration(from: items, avatar: tryOn.avatar)
        guard !pending.isEmpty else { return }
        Task {
            guard var avatar = tryOn.avatar else {
                await tryOn.begin(from: TryOnBitmap.neutralFigure())
                guard let created = tryOn.avatar else { return }
                await runBackfill(pending, photos: photos, avatar: created, tryOn: tryOn)
                return
            }
            await runBackfill(pending, photos: photos, avatar: avatar, tryOn: tryOn)
        }
    }

    private func runBackfill(
        _ items: [ClothingItem],
        photos: [String: UIImage],
        avatar: TryOnAvatar,
        tryOn: TryOnEditorModel
    ) async {
        let apiKey = TryOnAPIKey.openAI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { return }
        for item in items {
            guard let photo = photos[item.id],
                  let template = TryOnTemplateID.suggested(for: item.category) else { continue }
            let record = await service.generateIfNeeded(
                item: item,
                photo: photo,
                template: template,
                avatar: avatar,
                apiKey: apiKey,
                progress: { progress in
                    #if DEBUG
                    Task { @MainActor in
                        NSLog("[TryOn] body-part %@", progress)
                    }
                    #endif
                }
            )
            if let record {
                tryOn.registerBodyPart(record)
            }
        }
    }

    private func currentAvatar() async -> TryOnAvatar? {
        let library = TryOnLibrary(ownerId: ownerId)
        return await library.snapshot().avatar
    }

    private func generateStandalone(item: ClothingItem, photo: UIImage) async {
        guard let avatar = await currentAvatar(),
              let template = TryOnTemplateID.suggested(for: item.category) else { return }
        let apiKey = TryOnAPIKey.openAI.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !apiKey.isEmpty else { return }
        let record = await service.generateIfNeeded(
            item: item,
            photo: photo,
            template: template,
            avatar: avatar,
            apiKey: apiKey,
            progress: { progress in
                #if DEBUG
                Task { @MainActor in
                    NSLog("[TryOn] body-part %@", progress)
                }
                #endif
            }
        )
        if let record {
            tryOn?.registerBodyPart(record)
        }
    }
}