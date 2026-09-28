import Foundation

// SCHEMA TEMPLATE: field contract only; no service or validation implementation.
// Primary owner: social
// Follow-up tickets: P2.2-P2.4
// TODO: Confirm profile visibility, snapshot media ownership, deletion and relationship access rules.

struct UserProfile: Codable, Identifiable {
    var id: String // Firebase auth UID. No email or private measurements here.
    var schemaVersion: Int
    var username: String
    var displayName: String
    var avatarPath: String?
    var createdAt: Date
    var updatedAt: Date
}

struct Post: Codable, Identifiable {
    var id: String
    var schemaVersion: Int
    var authorId: String
    var caption: String
    var outfitSnapshot: PublishedOutfitSnapshot
    var mediaPath: String
    var createdAt: Date
}

struct PublishedOutfitSnapshot: Codable {
    var name: String?
    var items: [PublishedClothingSnapshot]
}

struct PublishedClothingSnapshot: Codable {
    var sourceItemId: String // Provenance only; rendering must not resolve private items.
    var name: String
    var category: ClothingCategory
    var mediaPath: String // Separate publishable asset, never a private capture.
    var productURL: URL?
}

struct SavedPost: Codable, Identifiable {
    var id: String // Equal to postId within the owner's savedPosts collection.
    var schemaVersion: Int
    var ownerId: String
    var postId: String
    var createdAt: Date
}

// Later-phase relationship, separate from feed ranking.
struct Follow: Codable, Identifiable {
    var id: String // Equal to targetUserId within the owner's following collection.
    var schemaVersion: Int
    var ownerId: String
    var targetUserId: String
    var createdAt: Date
}
