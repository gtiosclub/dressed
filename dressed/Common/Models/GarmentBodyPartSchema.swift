import Foundation

/// Cached AI layer: one body slot on the canonical avatar wearing a closet item.
/// Stored locally and optionally mirrored under Firestore `garmentBodyParts` plus Storage PNG.
struct GarmentBodyPartRecord: Codable, Identifiable, Equatable {
    var id: String
    var ownerId: String
    var itemId: String
    var slot: TryOnBodySlot
    var category: ClothingCategory
    /// App-support path relative to the owner's prototype closet root.
    var localImagePath: String
    var storagePath: String?
    var generationVersion: String
    var promptVersion: String
    var providerVersion: String
    var avatarId: String?
    var avatarVersion: Int?
    var status: TryOnJobStatus
    var createdAt: Date
    var updatedAt: Date
}