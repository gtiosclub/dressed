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
        guard item.ownerId == ownerId,
              item.imagePath == "images/\(item.id).jpg" || item.imagePath == "images/\(item.id).png" else { return nil }
        return UIImage(contentsOfFile: directory.appendingPathComponent(item.imagePath).path)
    }

    func item(id: String) -> ClothingItem? {
        items.first { $0.id == id && $0.ownerId == ownerId }
    }

    func belongs(to userID: String) -> Bool { ownerId == userID }

    func save(imageData: Data, draftId: String, name: String, category: ClothingCategory) throws {
        guard error == nil else { throw PrototypeImportError.unavailableStorage }
        guard UUID(uuidString: draftId) != nil else { throw PrototypeImportError.invalidIdentifier }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw PrototypeImportError.emptyName }
        guard let image = UIImage(data: imageData) else {
            throw PrototypeImportError.invalidImage
        }
        let isPNG = imageData.starts(with: [0x89, 0x50, 0x4E, 0x47])
        guard let encoded = isPNG ? image.pngData() : image.jpegData(compressionQuality: 0.85) else {
            throw PrototypeImportError.invalidImage
        }

        let fileManager = FileManager.default
        let imageDirectory = directory.appendingPathComponent("images", isDirectory: true)
        try fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
        let imagePath = "images/\(draftId).\(isPNG ? "png" : "jpg")"
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
        try encoded.write(to: imageURL, options: .atomic)
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

struct SharedImageEnvelope: Codable {
    let id: String
    let ownerId: String
    let createdAt: Date
}

enum SharedImageInbox {
    static let groupId = "group.gtiosclub.dressed"
    private static let ownerKey = "activeOwnerId"
    private static let draftLifetime: TimeInterval = 24 * 60 * 60

    enum Next {
        case image(ReviewImage)
        case discarded(String)
        case none
    }

    static func setActiveOwner(_ ownerId: String?) {
        UserDefaults(suiteName: groupId)?.set(ownerId, forKey: ownerKey)
    }

    static func next(for ownerId: String) -> Next {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            return .none
        }
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
            .filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
            return .none
        }
        for file in files {
            let fileId = file.deletingPathExtension().lastPathComponent
            guard let data = try? Data(contentsOf: file),
                  let envelope = try? JSONDecoder().decode(SharedImageEnvelope.self, from: data) else {
                discard(file: file)
                return .discarded("A shared image could not be read. Please share it again.")
            }
            guard UUID(uuidString: envelope.id) != nil, envelope.id == fileId else {
                discard(file: file)
                return .discarded("A shared image was invalid. Please share it again.")
            }
            let age = Date().timeIntervalSince(envelope.createdAt)
            if age >= draftLifetime || age < -60 {
                remove(id: envelope.id)
                if envelope.ownerId == ownerId {
                    return .discarded("This shared image expired. Please share it again.")
                }
                continue
            }
            guard envelope.ownerId == ownerId else { continue }
            guard let imageData = try? Data(contentsOf: inbox.appendingPathComponent("\(envelope.id).jpg")),
                  !imageData.isEmpty, imageData.count <= 40 * 1024 * 1024,
                  UIImage(data: imageData) != nil else {
                remove(id: envelope.id)
                return .discarded("This shared image is unavailable. Please share it again.")
            }
            return .image(ReviewImage(id: envelope.id, data: imageData, source: "Shared image", isShared: true))
        }
        return .none
    }

    static func remove(id: String) {
        guard UUID(uuidString: id) != nil else { return }
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            return
        }
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        if let data = try? Data(contentsOf: root.appendingPathComponent("Reviews/\(id).json")),
           let draft = try? JSONDecoder().decode(ImportDraft.self, from: data) {
            SharedImportDraftStore.removeAutomaticCutouts(for: draft.candidates)
        }
        try? FileManager.default.removeItem(at: inbox.appendingPathComponent("\(id).jpg"))
        try? FileManager.default.removeItem(at: inbox.appendingPathComponent("\(id).json"))
        try? FileManager.default.removeItem(at: root.appendingPathComponent("Reviews/\(id).json"))
    }

    private static func discard(file: URL) {
        try? FileManager.default.removeItem(at: file.deletingPathExtension().appendingPathExtension("jpg"))
        try? FileManager.default.removeItem(at: file)
    }

    #if DEBUG
    static func seedFixture(id: String, ownerId: String, withCandidates: Bool) throws {
        guard UUID(uuidString: id) != nil,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId) else {
            throw SharedImportDraftError.unavailable
        }
        let inbox = root.appendingPathComponent("Inbox", isDirectory: true)
        try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        let previousFixtures = try FileManager.default.contentsOfDirectory(at: inbox, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix("00000000-0000-4000-8000-") }
        for file in previousFixtures where file.deletingPathExtension().lastPathComponent != id {
            remove(id: file.deletingPathExtension().lastPathComponent)
        }
        let size = CGSize(width: 600, height: 800)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 130, y: 120, width: 340, height: 260))
            UIColor.darkGray.setFill()
            context.fill(CGRect(x: 150, y: 400, width: 300, height: 300))
            UIColor.systemYellow.setFill()
            context.fill(CGRect(x: 190, y: 20, width: 220, height: 70))
        }
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw SharedImportDraftError.unavailable
        }
        try data.write(to: inbox.appendingPathComponent("\(id).jpg"), options: .atomic)
        try JSONEncoder().encode(SharedImageEnvelope(id: id, ownerId: ownerId, createdAt: Date()))
            .write(to: inbox.appendingPathComponent("\(id).json"), options: .atomic)
        if withCandidates {
            var draft = try SharedImportDraftStore.loadOrCreate(
                image: ReviewImage(id: id, data: data, source: "Shared image", isShared: true),
                ownerId: ownerId
            )
            draft.status = .review
            draft.candidates = [
                ImportCandidate(id: SharedImportDraftStore.stableID(importID: id, part: "upper"),
                                name: "Top", category: .tops, destination: .closet,
                                temporaryCutoutPath: nil,
                                region: NormalizedImageRegion(x: 0.2, y: 0.12, width: 0.6, height: 0.38),
                                suggestionSource: "Fixture region", selected: false, tags: [], suggestedTags: []),
                ImportCandidate(id: SharedImportDraftStore.stableID(importID: id, part: "lower"),
                                name: "Pants", category: .pants, destination: .closet,
                                temporaryCutoutPath: nil,
                                region: NormalizedImageRegion(x: 0.2, y: 0.48, width: 0.6, height: 0.42),
                                suggestionSource: "Fixture region", selected: false, tags: [], suggestedTags: []),
                ImportCandidate(id: SharedImportDraftStore.stableID(importID: id, part: "accessory"),
                                name: "Hat", category: .accessories, destination: .closet,
                                temporaryCutoutPath: nil,
                                region: NormalizedImageRegion(x: 0.3, y: 0.01, width: 0.4, height: 0.12),
                                suggestionSource: "Fixture region", selected: false, tags: [], suggestedTags: [])
            ]
            try SharedImportDraftStore.save(draft)
        }
    }
    #endif
}
