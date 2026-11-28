import CryptoKit
import Foundation

/// Cached full-body aligned outfit composite (all visible worn items on the current avatar).
struct OutfitCompositeRecord: Codable, Identifiable, Equatable {
    var id: String
    var cacheKey: String
    var ownerId: String
    /// Sorted unique closet item ids baked into the composite.
    var garmentIds: [String]
    var avatarId: String?
    var avatarVersion: Int
    var processingVersion: Int
    var storagePath: String?
    var status: TryOnJobStatus
    var createdAt: Date
    var updatedAt: Date

    static func cacheKey(
        garmentIds: [String],
        avatarVersion: Int,
        processingVersion: Int = TryOnVersions.alignedOutfitProcessing
    ) -> String {
        let sorted = Array(Set(garmentIds)).sorted()
        let payload = sorted.joined(separator: ",") + "|av:\(avatarVersion)|pv:\(processingVersion)"
        let digest = SHA256.hash(data: Data(payload.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func storagePath(ownerId: String, cacheKey: String) -> String {
        "users/\(ownerId)/outfits/\(cacheKey).png"
    }

    static func localRelativePath(cacheKey: String) -> String {
        "outfits/\(cacheKey).png"
    }
}

/// Denormalized set of outfit composite cache keys for quick “what is cached” inspection.
struct OutfitCacheIndexRecord: Codable, Equatable {
    static let documentId = "index"

    var id: String
    var schemaVersion: Int
    var ownerId: String
    var cachedKeys: [String]
    var updatedAt: Date
}