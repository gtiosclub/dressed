import Combine
import Foundation
import UIKit

struct ReviewImage: Identifiable {
    let id: String
    let data: Data
    let source: String
    let isShared: Bool
}

enum PrototypeImportError: LocalizedError {
    case unavailableStorage
    case invalidImage
    case emptyName
    case invalidIdentifier
    case missingItem
    case couldNotRemovePhoto

    var errorDescription: String? {
        switch self {
        case .unavailableStorage: "Local storage is unavailable. Please try again."
        case .invalidImage: "This image could not be opened. Please choose another."
        case .emptyName: "Enter a name before saving."
        case .invalidIdentifier: "This import has an invalid identifier. Choose the image again."
        case .missingItem: "This piece is no longer in your closet."
        case .couldNotRemovePhoto: "Could not remove the private photo. Please try again."
        }
    }
}

@MainActor
final class PrototypeClosetStore: ObservableObject {
    @Published private(set) var items: [ClothingItem] = []
    @Published private(set) var error: String?

    private let ownerId: String
    private let directory: URL

    init(ownerId: String) {
        self.ownerId = ownerId
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("PrototypeCloset", isDirectory: true)
            .appendingPathComponent(ownerId, isDirectory: true)
        reload()
    }

    func reload() {
        do {
            try cleanupPendingPhotoDeletes()
            let file = directory.appendingPathComponent("items.json")
            guard FileManager.default.fileExists(atPath: file.path) else {
                items = []
                error = nil
                return
            }
            items = try JSONDecoder().decode([ClothingItem].self, from: Data(contentsOf: file))
                .filter { $0.ownerId == ownerId }
                .sorted { $0.createdAt > $1.createdAt }
            error = nil
        } catch {
            self.error = "Could not load your saved pieces: \(error.localizedDescription)"
        }
    }

    func image(for item: ClothingItem) -> UIImage? {
        guard item.ownerId == ownerId else { return nil }
        let directURL = directory.appendingPathComponent(item.imagePath)
        if FileManager.default.fileExists(atPath: directURL.path) {
            return UIImage(contentsOfFile: directURL.path)
        }
        let pngURL = directory.appendingPathComponent("images/\(item.id).png")
        if FileManager.default.fileExists(atPath: pngURL.path) {
            return UIImage(contentsOfFile: pngURL.path)
        }
        let jpgURL = directory.appendingPathComponent("images/\(item.id).jpg")
        if FileManager.default.fileExists(atPath: jpgURL.path) {
            return UIImage(contentsOfFile: jpgURL.path)
        }
        return nil
    }

    func item(id: String) -> ClothingItem? {
        items.first { $0.id == id && $0.ownerId == ownerId }
    }

    func save(imageData: Data, draftId: String, name: String, category: ClothingCategory) throws {
        guard error == nil else { throw PrototypeImportError.unavailableStorage }
        guard UUID(uuidString: draftId) != nil else { throw PrototypeImportError.invalidIdentifier }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw PrototypeImportError.emptyName }
        guard let image = UIImage(data: imageData) else {
            throw PrototypeImportError.invalidImage
        }

        let isPNG = (imageData.count >= 8 && imageData.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
        let imageExtension = isPNG ? "png" : "jpg"
        let fileData = isPNG ? (image.pngData() ?? imageData) : (image.jpegData(compressionQuality: 0.85) ?? imageData)

        let fileManager = FileManager.default
        let imageDirectory = directory.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let imagePath = "images/\(draftId).\(imageExtension)"
        let imageURL = directory.appendingPathComponent(imagePath)
        let record = ClothingItem(
            id: draftId,
            ownerId: ownerId,
            name: trimmedName,
            category: category,
            imagePath: imagePath,
            createdAt: items.first(where: { $0.id == draftId })?.createdAt ?? Date()
        )
        let updated = [record] + items.filter { $0.id != draftId }

        // The stable draft ID makes a retry replace the same item rather than create another.
        let previousImage = fileManager.fileExists(atPath: imageURL.path)
            ? try Data(contentsOf: imageURL) : nil
        try fileData.write(to: imageURL, options: .atomic)
        do {
            try persist(updated)
            items = updated
            error = nil
        } catch {
            if let previousImage {
                try previousImage.write(to: imageURL, options: .atomic)
            } else {
                try fileManager.removeItem(at: imageURL)
            }
            throw error
        }
    }

    func updateDetails(id: String, name: String, category: ClothingCategory) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw PrototypeImportError.emptyName }
        guard let index = items.firstIndex(where: { $0.id == id && $0.ownerId == ownerId }) else {
            throw PrototypeImportError.missingItem
        }
        var updated = items
        updated[index].name = trimmedName
        updated[index].category = category
        try persist(updated)
        items = updated
        error = nil
    }

    func delete(id: String) throws {
        guard let item = item(id: id) else { throw PrototypeImportError.missingItem }
        guard item.imagePath == "images/\(item.id).jpg" || item.imagePath == "images/\(item.id).png" else {
            throw PrototypeImportError.invalidIdentifier
        }
        let imageURL = directory.appendingPathComponent(item.imagePath)
        let backupURL = directory.appendingPathComponent("images/\(UUID().uuidString).deleting")
        let fileManager = FileManager.default
        let hadPhoto = fileManager.fileExists(atPath: imageURL.path)
        if hadPhoto { try fileManager.moveItem(at: imageURL, to: backupURL) }

        let updated = items.filter { $0.id != id }
        do {
            try persist(updated)
        } catch {
            if hadPhoto { try fileManager.moveItem(at: backupURL, to: imageURL) }
            throw error
        }
        items = updated
        if hadPhoto {
            do {
                try fileManager.removeItem(at: backupURL)
            } catch {
                // Record removal succeeded; retain an actionable cleanup error.
                throw PrototypeImportError.couldNotRemovePhoto
            }
        }
        error = nil
    }

    private func persist(_ records: [ClothingItem]) throws {
        let encoded = try JSONEncoder().encode(records)
        try encoded.write(to: directory.appendingPathComponent("items.json"), options: .atomic)
    }

    private func cleanupPendingPhotoDeletes() throws {
        let imageDirectory = directory.appendingPathComponent("images", isDirectory: true)
        guard FileManager.default.fileExists(atPath: imageDirectory.path) else { return }
        let files = try FileManager.default.contentsOfDirectory(at: imageDirectory, includingPropertiesForKeys: nil)
        for file in files where file.pathExtension == "deleting" {
            try FileManager.default.removeItem(at: file)
        }
    }
}

struct SharedImageEnvelope: Decodable {
    let id: String
    let ownerId: String
    let createdAt: Date
}

enum SharedImageInbox {
    static let groupId = "group.gtiosclub.dressed"
    private static let ownerKey = "activeOwnerId"

    static func setActiveOwner(_ ownerId: String?) {
        UserDefaults(suiteName: groupId)?.set(ownerId, forKey: ownerKey)
    }

    static func next(for ownerId: String) -> ReviewImage? {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            return nil
        }
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
            return nil
        }
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let envelope = try? JSONDecoder().decode(SharedImageEnvelope.self, from: data) else {
                continue
            }
            if Date().timeIntervalSince(envelope.createdAt) >= 24 * 60 * 60 {
                remove(id: envelope.id)
                continue
            }
            guard envelope.ownerId == ownerId,
                  let imageData = try? Data(contentsOf: inbox.appendingPathComponent("\(envelope.id).jpg")) else { continue }
            return ReviewImage(id: envelope.id, data: imageData, source: "Shared image", isShared: true)
        }
        return nil
    }

    static func remove(id: String) {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            return
        }
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.removeItem(at: inbox.appendingPathComponent("\(id).jpg"))
        try? FileManager.default.removeItem(at: inbox.appendingPathComponent("\(id).json"))
    }
}
