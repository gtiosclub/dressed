import Foundation

@main struct Check {
    @MainActor static func main() async {
        let fixtures = InfiniteFeedFixtures(failSecondPage: true)
        let model = ChronologicalFeedModel { try await fixtures.loadPage(cursor: $0) }
        await model.loadInitial()
        precondition(model.posts.count == 12 && model.nextCursor == "1")
        let before = model.posts.map(\.id)
        await model.loadMore()
        precondition(model.errorMessage != nil && model.posts.map(\.id) == before && model.nextCursor == "1")
        await model.loadMore()
        precondition(fixtures.requestedCursors.count == 2, "Failure must pause automatic attempts")
        await model.retry()
        precondition(model.posts.count == 23 && !model.posts.contains { $0.id == "infinite_2" })
        precondition(Set(model.posts.map(\.id)).count == model.posts.count)
        let first = Task { await model.loadMore() }
        await Task.yield()
        let second = Task { await model.loadMore() }
        await first.value
        await second.value
        precondition(fixtures.requestedCursors.filter { $0 == "2" }.count == 1)
        await model.loadMore()
        precondition(model.posts.count == 47 && !model.hasMore)
        let count = fixtures.requestedCursors.count
        await model.loadMore()
        precondition(fixtures.requestedCursors.count == count)
        precondition(zip(model.posts, model.posts.dropFirst()).allSatisfy { $0.createdAt >= $1.createdAt })
        await model.refresh()
        precondition(model.posts.count == 12 && model.nextCursor == "1")
        print("PASS: failure retention, explicit retry, deduplication, removal, concurrent request guard, chronological order, end of feed, refresh reset")
    }
}
