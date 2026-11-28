import CoreGraphics
import Foundation
import UIKit

struct GarmentBodyPartStore {
    let ownerId: String
    private(set) var closetRoot: URL

  init(ownerId: String) {
        let trimmed = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ownerId = trimmed.isEmpty ? "local" : trimmed
        closetRoot = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrototypeCloset", isDirectory: true)
            .appendingPathComponent(self.ownerId, isDirectory: true)
    }

    private var indexURL: URL {
        closetRoot.appendingPathComponent("body-parts/index.json")
    }

    private var imagesDirectory: URL {
        closetRoot.appendingPathComponent("body-parts/images", isDirectory: true)
    }

    func loadAll() -> [GarmentBodyPartRecord] {
        guard let data = try? Data(contentsOf: indexURL),
              let records = try? JSONDecoder().decode([GarmentBodyPartRecord].self, from: data) else {
            return []
        }
        return records.filter { $0.ownerId == ownerId }
    }

    func record(for itemId: String) -> GarmentBodyPartRecord? {
        loadAll().first { $0.itemId == itemId && $0.ownerId == ownerId }
    }

    func isCurrent(_ record: GarmentBodyPartRecord) -> Bool {
        record.generationVersion == TryOnVersions.bodyPartGeneration
            && record.promptVersion == TryOnVersions.bodyPartPrompt
            && record.providerVersion == TryOnVersions.provider
            && record.status == .ready
    }

    func image(for record: GarmentBodyPartRecord) -> CGImage? {
        let path = closetRoot.appendingPathComponent(record.localImagePath).path
        guard let source = CGImage.fromPNGFile(path) else { return nil }
        return TryOnBitmap.placed(source, canvas: .canonical)
    }

    func save(
        item: ClothingItem,
        slot: TryOnBodySlot,
        image: CGImage,
        avatar: TryOnAvatar?
    ) throws -> GarmentBodyPartRecord {
        try FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)
        let relative = "body-parts/images/\(item.id).png"
        let fileURL = closetRoot.appendingPathComponent(relative)
        guard let data = TryOnBitmap.pngData(from: image) else {
            throw TryOnImageError.emptyImage
        }
        try data.write(to: fileURL, options: .atomic)
        let now = Date()
        let existing = record(for: item.id)
        let record = GarmentBodyPartRecord(
            id: item.id,
            ownerId: ownerId,
            itemId: item.id,
            slot: slot,
            category: item.category,
            localImagePath: relative,
            storagePath: "users/\(ownerId)/items/\(item.id)/body-part.png",
            generationVersion: TryOnVersions.bodyPartGeneration,
            promptVersion: TryOnVersions.bodyPartPrompt,
            providerVersion: TryOnVersions.provider,
            avatarId: avatar?.id,
            avatarVersion: avatar?.version,
            status: .ready,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
        var all = loadAll().filter { $0.itemId != item.id }
        all.append(record)
        let encoded = try JSONEncoder().encode(all)
        try encoded.write(to: indexURL, options: .atomic)
        return record
    }

    func replaceLocalImage(from record: GarmentBodyPartRecord, pngData: Data) throws -> GarmentBodyPartRecord {
        let fileURL = closetRoot.appendingPathComponent(record.localImagePath)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try pngData.write(to: fileURL, options: .atomic)
        var updated = record
        updated.status = .ready
        updated.updatedAt = Date()
        var all = loadAll().filter { $0.itemId != record.itemId }
        all.append(updated)
        try JSONEncoder().encode(all).write(to: indexURL, options: .atomic)
        return updated
    }

    func itemsNeedingGeneration(from items: [ClothingItem], avatar: TryOnAvatar?) -> [ClothingItem] {
        let existing = Dictionary(uniqueKeysWithValues: loadAll().map { ($0.itemId, $0) })
        return items.filter { item in
            guard item.ownerId == ownerId, TryOnBodySlot.slot(for: item.category) != nil else { return false }
            guard let record = existing[item.id], isCurrent(record) else { return true }
            if let avatar, record.avatarId != avatar.id || record.avatarVersion != avatar.version {
                return true
            }
            return false
        }
    }
}

private extension CGImage {
    static func fromPNGFile(_ path: String) -> CGImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let image = UIImage(data: data) else { return nil }
        return image.cgImage
    }
}