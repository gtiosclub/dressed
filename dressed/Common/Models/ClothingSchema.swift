import Foundation

// SCHEMA TEMPLATE: field contract only; no service or validation implementation.
// Primary owner: data
// Follow-up tickets: P0.1 / P1.2-P1.4
// TODO: Confirm candidate metadata, import expiry and idempotent IDs; implement validation in repositories.

// Contract templates only. Repositories must validate ownership and values before writing.
// Date uses ISO-8601 in JSON fixtures and Firestore Timestamp in future adapters.
// Schema versions are explicit so decoding never silently upgrades a stored record.

enum ClothingCategory: String, Codable, CaseIterable {
    case tops, pants, skirts, dresses, shoes, outerwear, accessories, other
}

enum ClosetDestination: String, Codable {
    case closet, wishlist
}

struct ClothingSource: Codable {
    enum Kind: String, Codable {
        case camera, photoLibrary, sharedImage, sharedURL, productURL
    }
    var kind: Kind
    var originalURL: URL?
    var importedAt: Date
}

struct ClothingItem: Codable, Identifiable {
    var id: String
    var schemaVersion: Int
    var ownerId: String
    var name: String
    var category: ClothingCategory
    var destination: ClosetDestination
    var imagePath: String
    var cutoutPath: String?
    var source: ClothingSource
    var tags: [String]
    var suggestedTags: [String]
    var brand: String?
    var size: String?
    var productURL: URL?
    var createdAt: Date
    var updatedAt: Date
}

// Private local draft. Temporary paths are not public Storage references.
struct ImportDraft: Codable, Identifiable {
    enum Status: String, Codable {
        case received, processing, review, saving, failed, saved
    }
    var id: String // Stable import ID reused for retries.
    var schemaVersion: Int
    var ownerId: String
    var source: ClothingSource
    var temporaryImagePath: String
    var status: Status
    var candidates: [ImportCandidate]
    var createdAt: Date
    var expiresAt: Date
}

struct ImportCandidate: Codable, Identifiable {
    var id: String
    var name: String
    var category: ClothingCategory
    var destination: ClosetDestination
    var temporaryCutoutPath: String?
    var selected: Bool
    var tags: [String]
    var suggestedTags: [String]
}
