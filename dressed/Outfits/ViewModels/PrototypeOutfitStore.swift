import Combine
import Foundation

enum PrototypeOutfitError: LocalizedError {
    case emptyName
    case emptyOutfit
    case missingPiece
    case unavailableStorage
    case duplicateCategory

    var errorDescription: String? {
        switch self {
        case .emptyName: "Give this outfit a name."
        case .emptyOutfit: "Select at least one piece."
        case .missingPiece: "A selected piece is no longer in your closet."
        case .unavailableStorage: "Saved outfits could not be loaded. Try again."
        case .duplicateCategory: "Choose only one piece per clothing category."
        }
    }
}

extension Outfit {
    /// Ids of the closet items in this outfit. Two outfits with the same set are the same outfit.
    var itemIds: Set<String> { Set(placements.map(\.itemId)) }
}

@MainActor
final class PrototypeOutfitStore: ObservableObject {
    @Published private(set) var outfits: [Outfit] = []
    @Published private(set) var error: String?

    private let ownerId: String
    private let file: URL

    func belongs(to userID: String) -> Bool { ownerId == userID }

    init(ownerId: String) {
        self.ownerId = ownerId
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = base.appendingPathComponent("PrototypeCloset", isDirectory: true)
            .appendingPathComponent(ownerId, isDirectory: true)
            .appendingPathComponent("outfits.json")
        reload()
    }

    func reload() {
        do {
            guard FileManager.default.fileExists(atPath: file.path) else {
                outfits = []
                error = nil
                return
            }
            outfits = try JSONDecoder().decode([Outfit].self, from: Data(contentsOf: file))
                .filter { $0.ownerId == ownerId }
                .sorted { $0.createdAt > $1.createdAt }
            error = nil
        } catch {
            self.error = "Could not load saved outfits: \(error.localizedDescription)"
        }
    }

    func save(name: String, placements: [OutfitPlacement], availableItems: [ClothingItem]) throws {
        _ = try save(id: UUID().uuidString, name: name, placements: placements, availableItems: availableItems)
    }

    @discardableResult
    func save(id: String, name: String, placements: [OutfitPlacement], availableItems: [ClothingItem]) throws -> Outfit {
        guard error == nil else { throw PrototypeOutfitError.unavailableStorage }
        guard UUID(uuidString: id) != nil else { throw PrototypeOutfitError.unavailableStorage }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw PrototypeOutfitError.emptyName }
        let selectedCategories = placements.compactMap { placement in
            availableItems.first { item in
                item.id == placement.itemId
            }?.category
        }
        guard Set(selectedCategories).count == selectedCategories.count else {
            throw PrototypeOutfitError.duplicateCategory
        }
        guard !placements.isEmpty else { throw PrototypeOutfitError.emptyOutfit }
        let ownedIds = Set(availableItems.filter { $0.ownerId == ownerId }.map(\.id))
        guard placements.allSatisfy({ ownedIds.contains($0.itemId) }) else {
            throw PrototypeOutfitError.missingPiece
        }

        let now = Date()
        let original = outfits.first { $0.id == id }
        let outfit = Outfit(
            id: id,
            schemaVersion: 1,
            ownerId: ownerId,
            name: trimmedName,
            placementSchemaVersion: 1,
            placements: placements,
            createdAt: original?.createdAt ?? now,
            updatedAt: now
        )
        let updated = [outfit] + outfits.filter { $0.id != id }
        let directory = file.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(updated).write(to: file, options: .atomic)
        outfits = updated
        return outfit
    }

    /// Saved outfits made of exactly these closet items, whatever their names or order.
    func outfits(matching itemIds: Set<String>) -> [Outfit] {
        guard !itemIds.isEmpty else { return [] }
        return outfits.filter { $0.itemIds == itemIds }
    }

    /// Removes one saved outfit. An id that isn't saved is not an error.
    func delete(id: String) throws {
        try delete { $0.id == id }
    }

    /// Removes every saved outfit made of exactly these closet items, including duplicates.
    func deleteOutfits(matching itemIds: Set<String>) throws {
        guard !itemIds.isEmpty else { return }
        try delete { $0.itemIds == itemIds }
    }

    private func delete(where shouldDelete: (Outfit) -> Bool) throws {
        guard error == nil else { throw PrototypeOutfitError.unavailableStorage }
        let remaining = outfits.filter { !shouldDelete($0) }
        guard remaining.count != outfits.count else { return }
        try JSONEncoder().encode(remaining).write(to: file, options: .atomic)
        outfits = remaining
    }
}
