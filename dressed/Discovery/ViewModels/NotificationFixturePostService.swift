import Foundation

/// Lets the notification prototype open the fixture post `post_002` in the existing
/// post-detail screen without reading Firestore. Kept apart from `NotificationFixtures`
/// so the logic checks build without Firebase.
struct NotificationFixturePostService: PostFunctions {
    func fetchRecentPosts() async throws -> [Post] { [] }

    func fetchPost(id: String) async throws -> Post? {
        NotificationFixtures.post(id: id)
    }
}
