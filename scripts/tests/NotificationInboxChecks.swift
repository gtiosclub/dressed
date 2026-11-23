import Foundation

@main struct Check {
    @MainActor static func main() async {
        let now = Date(timeIntervalSince1970: 1_794_225_600)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let fixtures = NotificationFixtures(now: now, failingFetches: [2], delay: .zero)
        let model = NotificationInboxModel(service: fixtures, calendar: calendar, now: { now })

        await model.loadInitial()
        let ids = model.rows.map(\.id)
        precondition(ids == ["n_003", "n_004", "n_006", "n_005", "n_007"], "Newest event first: \(ids)")

        // n_001–003: three likes on post_002 become one unread row led by the latest actor.
        let likes = model.rows[0]
        precondition(likes.notificationIds == ["n_003", "n_002", "n_001"])
        precondition(likes.actorName == "maya" && likes.otherActorCount == 2 && likes.isUnread)
        precondition(likes.destination == .post(id: "post_002") && likes.thumbnail == "DemoOutfitPhoto2")

        // n_004: the comment's post was removed, so the row keeps the actor but has no destination or thumbnail.
        let comment = model.rows[1]
        precondition(comment.availability == .postRemoved && comment.destination == nil && comment.thumbnail == nil)
        precondition(comment.actorName == "jordan" && comment.isUnread)

        // n_006: a deleted follower shows as unavailable and never becomes a destination.
        let deletedFollower = model.rows[2]
        precondition(deletedFollower.availability == .profileUnavailable && deletedFollower.actorName == nil)
        precondition(deletedFollower.destination == nil && deletedFollower.isUnread)

        // n_005: a read follow from an available account.
        let follow = model.rows[3]
        precondition(!follow.isUnread && follow.destination == .profile(id: "user_b", displayName: "maya"))

        // n_007: post_003 looked available at load.
        let stale = model.rows[4]
        precondition(stale.availability == .available && stale.destination == .post(id: "post_003"))
        precondition(model.newRows.map(\.id) == ["n_003", "n_004", "n_006"])
        precondition(model.earlierRows.map(\.id) == ["n_005", "n_007"] && model.hasUnread)

        // Opening a grouped row reports only its supplied post ID and marks every grouped ID read.
        let opened1 = await model.open(likes)
        precondition(opened1 == .open(.post(id: "post_002")))
        precondition(Set(fixtures.readIds) == ["n_001", "n_002", "n_003"])
        precondition(model.rows.first { $0.id == "n_003" }?.isUnread == false)

        // Removed content and unavailable profiles open the unavailable state, not a destination.
        let opened2 = await model.open(comment)
        precondition(opened2 == .postUnavailable)
        let opened3 = await model.open(deletedFollower)
        precondition(opened3 == .profileUnavailable)
        precondition(fixtures.readIds.contains("n_004") && fixtures.readIds.contains("n_006"))
        let opened4 = await model.open(follow)
        precondition(opened4 == .open(.profile(id: "user_b", displayName: "maya")))

        // Stale destination: removed after the load, caught by the check on tap.
        let opened5 = await model.open(stale)
        precondition(opened5 == .postUnavailable)
        let staleAfterTap = model.rows.first { $0.id == "n_007" }!
        precondition(staleAfterTap.availability == .postRemoved && staleAfterTap.destination == nil)
        precondition(!model.hasUnread)

        // Failed refresh keeps the rows; Retry asks once and the refreshed rows keep read state.
        let before = model.rows
        await model.refresh()
        precondition(model.errorMessage != nil && model.rows == before && fixtures.fetchCount == 2)
        await model.retry()
        precondition(model.errorMessage == nil && fixtures.fetchCount == 3)
        await model.retry()
        precondition(fixtures.fetchCount == 3, "Retry runs only after a failure")
        precondition(model.rows.first { $0.id == "n_007" }?.availability == .postRemoved)
        precondition(!model.hasUnread)

        // Grouping rules: follows group by day, unsupported kinds are skipped, ties break by ID.
        func record(_ id: String, _ kind: AppNotification.Kind, _ seconds: Double, post: String? = nil) -> AppNotification {
            AppNotification(id: id, schemaVersion: 1, ownerId: "user_a", kind: kind, actorId: "user_b", postId: post,
                            challengeId: nil, recommendationId: nil,
                            createdAt: now.addingTimeInterval(-seconds), readAt: nil)
        }
        let groups = NotificationInboxModel.group([
            record("f_2", .follow, 3600), record("f_1", .follow, 7200), record("f_old", .follow, 3 * 86_400),
            record("r_1", .recommendation, 10), record("l_b", .like, 60, post: "p"), record("l_a", .like, 60, post: "p")
        ], calendar: calendar)
        precondition(groups.map { $0.map(\.id) } == [["l_a", "l_b"], ["f_2", "f_1"], ["f_old"]], "\(groups.map { $0.map(\.id) })")

        // Empty inbox loads with no rows and no error.
        let empty = NotificationInboxModel(service: NotificationFixtures(now: now, empty: true, delay: .zero))
        await empty.loadInitial()
        precondition(empty.hasLoaded && empty.rows.isEmpty && empty.errorMessage == nil)

        print("PASS: ordering, grouping, unread and read, removed post, unavailable profile, stale destination, supplied destinations only, failed refresh and retry, empty inbox")
    }
}
