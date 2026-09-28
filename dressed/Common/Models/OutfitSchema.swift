import Foundation

// SCHEMA TEMPLATE: field contract only; no service or validation implementation.
// Primary owner: viz (contract); data (persistence)
// Follow-up tickets: P2.0 / P2.1 / P4.3
// TODO: Confirm placement ranges, missing-item behavior and optional measurement consent; implement no rendering here.

struct Outfit: Codable, Identifiable {
    var id: String
    var schemaVersion: Int
    var ownerId: String
    var name: String?
    var placementSchemaVersion: Int
    var placements: [OutfitPlacement]
    var createdAt: Date
    var updatedAt: Date
}

struct OutfitPlacement: Codable {
    var itemId: String
    var centerX: Double // Normalized 0...1.
    var centerY: Double // Normalized 0...1.
    var width: Double // Fraction of canvas width, > 0 and <= 1.
    var rotationDegrees: Double
    var layer: Int
}

// Later-phase template. A mannequin composition is not a fit prediction.
struct Avatar: Codable, Identifiable {
    var id: String // Equal to ownerId for a single avatar per user.
    var schemaVersion: Int
    var ownerId: String
    var appearance: AvatarAppearance
    var measurements: BodyMeasurements?
    var updatedAt: Date
}

struct AvatarAppearance: Codable {
    var templateId: String
    var skinToneHex: String?
}

struct BodyMeasurements: Codable {
    enum Unit: String, Codable { case centimeters }
    var unit: Unit
    var height: Double?
    var chest: Double?
    var waist: Double?
    var hips: Double?
}
