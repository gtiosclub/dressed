import Foundation

/// Persistent comment on a published post; no private profile or closet data.
struct PostComment: Codable, Identifiable {
    var id: String
    var authorId: String
    var text: String
    var createdAt: Date
}
