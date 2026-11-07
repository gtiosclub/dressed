import Foundation

// Keeps each account's avatar choices on this device, next to its closet and outfits,
// so signing out and back in restores the same avatar.
enum AvatarLookStore {
    private struct SavedLook: Codable {
        var schemaVersion: Int
        var selections: [String: Int]
    }

    /// Returns the saved look, or an empty look (all defaults) when nothing has been saved.
    /// Unknown parts and out-of-range indexes are dropped so older files cannot crash the avatar.
    static func load(ownerId: String) -> [AvatarPart: Int] {
        guard let data = try? Data(contentsOf: file(for: ownerId)),
              let saved = try? JSONDecoder().decode(SavedLook.self, from: data) else {
            return [:]
        }
        var look: [AvatarPart: Int] = [:]
        for (key, index) in saved.selections {
            guard let part = AvatarPart(rawValue: key), (0..<part.optionCount).contains(index) else { continue }
            look[part] = index
        }
        return look
    }

    static func save(_ look: [AvatarPart: Int], ownerId: String) throws {
        let url = file(for: ownerId)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let selections = Dictionary(uniqueKeysWithValues: look.map { ($0.key.rawValue, $0.value) })
        let data = try JSONEncoder().encode(SavedLook(schemaVersion: 1, selections: selections))
        try data.write(to: url, options: .atomic)
    }

    private static func file(for ownerId: String) -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrototypeCloset", isDirectory: true)
            .appendingPathComponent(ownerId, isDirectory: true)
            .appendingPathComponent("avatar.json")
    }
}
