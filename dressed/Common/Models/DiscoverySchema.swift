import Foundation

// SCHEMA TEMPLATE: field contract only; no service or validation implementation.
// Primary owner: data (recommendations); social (engagement)
// Follow-up tickets: PS4.1 / P4.4; engagement deferred
// TODO: Confirm scoring/event retention and notification trust boundaries before enabling these later-phase records.

// Later-phase templates. No event collection or personalization is enabled by these types.
struct PreferenceEvent: Codable, Identifiable {
    enum Kind: String, Codable { case view, like, save, wear, dismiss }
    enum Target: String, Codable { case item, outfit, post }
    var id: String
    var schemaVersion: Int
    var ownerId: String
    var kind: Kind
    var targetType: Target
    var targetId: String
    var occurredAt: Date
}

struct UserPreferences: Codable, Identifiable {
    var id: String // Equal to ownerId.
    var schemaVersion: Int
    var ownerId: String
    var tagWeights: [TagWeight]
    var updatedAt: Date
}

struct TagWeight: Codable {
    var tag: String
    var weight: Double // Finite 0...1; not a claim of a calibrated probability.
}

// Response DTO, not a Firestore document. Product identity must come from provenance.
struct OutfitRecommendation: Codable, Identifiable {
    var id: String
    var outfitId: String
    var score: Double
    var explanation: String
    var corpusVersion: String
}

struct SimilarItemResult: Codable, Identifiable {
    var id: String
    var name: String
    var imageURL: URL
    var productURL: URL?
    var score: Double
    var corpusVersion: String
    var source: String
}

struct AppNotification: Codable, Identifiable {
    enum Kind: String, Codable { case follow, like, comment, recommendation, challenge }
    var id: String
    var schemaVersion: Int
    var ownerId: String // Recipient, not actor.
    var kind: Kind
    var actorId: String?
    var postId: String?
    var challengeId: String?
    var recommendationId: String?
    var createdAt: Date
    var readAt: Date?
}

struct Challenge: Codable, Identifiable {
    var id: String
    var schemaVersion: Int
    var creatorId: String
    var title: String
    var description: String
    var startsAt: Date
    var endsAt: Date
}

struct ChallengeSubmission: Codable, Identifiable {
    var id: String // Owner UID within a challenge; one submission per user.
    var schemaVersion: Int
    var ownerId: String
    var challengeId: String
    var postId: String
    var createdAt: Date
}
