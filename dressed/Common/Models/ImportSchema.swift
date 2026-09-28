import Foundation

// Later import work. These templates are not needed to save a manual closet item.
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

// Private local draft. Temporary paths are not public Storage references.
struct ImportDraft: Codable, Identifiable {
    enum Status: String, Codable {
        case received, processing, review, saving, failed, saved
    }
    var id: String
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
