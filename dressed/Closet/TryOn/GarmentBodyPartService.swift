import UIKit

actor GarmentBodyPartService {
    private let ownerId: String
    private let store: GarmentBodyPartStore
    private let pipeline: TryOnPipeline
    private let library: TryOnLibrary
    private var inFlight: Set<String> = []

    init(ownerId: String) {
        let trimmed = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ownerId = trimmed.isEmpty ? "local" : trimmed
        store = GarmentBodyPartStore(ownerId: self.ownerId)
        library = TryOnLibrary(ownerId: self.ownerId)
        pipeline = TryOnPipeline(library: library, ownerId: self.ownerId)
    }

    func record(for itemId: String) -> GarmentBodyPartRecord? {
        store.record(for: itemId)
    }

    func generateIfNeeded(
        item: ClothingItem,
        photo: UIImage,
        template: TryOnTemplateID,
        avatar: TryOnAvatar,
        apiKey: String,
        progress: @escaping @Sendable (String) -> Void
    ) async -> GarmentBodyPartRecord? {
        guard let slot = TryOnBodySlot.slot(for: item) else { return nil }
        if let existing = store.record(for: item.id), store.isCurrent(existing),
           existing.avatarId == avatar.id, existing.avatarVersion == avatar.version {
            return existing
        }
        guard inFlight.insert(item.id).inserted else { return store.record(for: item.id) }
        defer { inFlight.remove(item.id) }
        guard TryOnAPIKey.isConfigured, !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        do {
            let image = try await pipeline.generateBodyPartRegion(
                item: item,
                slot: slot,
                template: template,
                photo: photo,
                avatar: avatar,
                key: apiKey,
                progress: progress
            )
            let record = try store.save(item: item, slot: slot, image: image, avatar: avatar)
            if let png = TryOnBitmap.pngData(from: image) {
                await GarmentBodyPartFunctions.upload(record: record, pngData: png)
            }
            return record
        } catch {
            return nil
        }
    }

    func restoreFromCloud(itemId: String) async -> GarmentBodyPartRecord? {
        guard let remote = try? await GarmentBodyPartFunctions.downloadMetadata(ownerId: ownerId, itemId: itemId),
              let path = remote.storagePath else { return nil }
        guard let data = try? await GarmentBodyPartFunctions.downloadPNG(storagePath: path),
              !data.isEmpty else { return nil }
        guard var local = store.record(for: itemId) else {
            let placeholder = GarmentBodyPartRecord(
                id: itemId,
                ownerId: ownerId,
                itemId: itemId,
                slot: remote.slot,
                category: remote.category,
                localImagePath: "body-parts/images/\(itemId).png",
                storagePath: path,
                generationVersion: remote.generationVersion,
                promptVersion: remote.promptVersion,
                providerVersion: remote.providerVersion,
                avatarId: remote.avatarId,
                avatarVersion: remote.avatarVersion,
                status: .ready,
                createdAt: remote.createdAt,
                updatedAt: Date()
            )
            return try? store.replaceLocalImage(from: placeholder, pngData: data)
        }
        return try? store.replaceLocalImage(from: local, pngData: data)
    }
}