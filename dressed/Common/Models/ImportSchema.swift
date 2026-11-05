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

// A reviewed retailer link is a wishlist entry, not an owned ClothingItem.
struct SavedProductLink: Codable, Identifiable {
    var id: String
    var ownerId: String
    var name: String
    var category: ClothingCategory
    var productURL: URL
    var createdAt: Date
    // Optional details the person confirmed from a read page. Older saved
    // links decode without them. Price and availability are never guessed.
    var retailer: String? = nil
    var imageURL: URL? = nil
    var price: ProductPrice? = nil
    var availability: String? = nil
    var variant: String? = nil
    var importId: String? = nil
}

struct ProductPrice: Codable {
    var amount: String
    var currency: String
}

// Draft returned by the product link reader (backend/links). Every field says
// where its value came from; state is from_page, from_link, suggested or open.
// A draft is review input, not a saved record.
struct ProductImportField<Value: Codable>: Codable {
    var value: Value?
    var source: String?
    var evidence: String?
    var state: String
}

struct ProductImportDraft: Codable {
    struct Fields: Codable {
        var name: ProductImportField<String>
        var retailer: ProductImportField<String>
        var image: ProductImportField<String>
        var category: ProductImportField<String>
        var link: ProductImportField<String>
        var price: ProductImportField<ProductPrice>
        var availability: ProductImportField<String>
        var variant: ProductImportField<String>
    }

    var importId: String
    var status: String // ready, blocked or failed
    var message: String?
    var fields: Fields
    var canonicalLink: String?
    var elapsedMs: Int
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
    var region: NormalizedImageRegion?
    // Optional user-drawn contour in full-image coordinates. A rectangle remains
    // the fallback when no contour has been drawn.
    var outline: [NormalizedImagePoint]? = nil
    var suggestionSource: String?
    var selected: Bool
    var tags: [String]
    var suggestedTags: [String]
}

struct NormalizedImagePoint: Codable {
    var x: Double
    var y: Double

    nonisolated var isValid: Bool {
        x.isFinite && y.isFinite && (0...1).contains(x) && (0...1).contains(y)
    }
}

// Coordinates use the displayed image's top-left corner as (0, 0).
struct NormalizedImageRegion: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    nonisolated var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite)
            && x >= 0 && y >= 0 && width > 0 && height > 0
            && x + width <= 1 && y + height <= 1
    }
}
