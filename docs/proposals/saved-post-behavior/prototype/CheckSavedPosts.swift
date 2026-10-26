import Foundation

// SOCIAL-P03 (#186): runs the proposal's scenarios against both grid strategies. Not part of the app.
// From the repository root:
//   xcrun swiftc dressed/Common/Models/*.swift dressed/Discovery/SavedPostFilters.swift \
//     docs/proposals/saved-post-behavior/prototype/*.swift -o /private/tmp/saved-post-check
//   /private/tmp/saved-post-check

// MARK: - Scenarios

private func saveScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    let write = parent.tapToggle("post_001", showing: Fixtures.post001)
    parent.expect(write?.save == true, "a Save tap sends one save write")
    parent.expect(parent.state.isWorking("post_001") && !parent.state.isSaved("post_001"),
                  "the toggle is working and still shows Save until the write succeeds")
    parent.expect(parent.tapToggle("post_001") == nil, "a tap while working sends nothing")
    parent.expect(parent.report("post_001", save: true) == nil,
                  "a second report while the save is in flight sends nothing, such as a fast double tap")
    parent.finish(write)
    parent.expect(parent.state.isSaved("post_001") && parent.availableIds == ["post_001"],
                  "after the write succeeds the toggle shows Saved and the grid has the card")
    parent.expect(parent.writesSent.count == 1, "exactly one write was sent")
    parent.expect(parent.store.documentIds(ownerId: "user_a") == ["post_001"], "the store has one saved document")
    return parent.problems
}

private func repeatedSaveScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.expect(parent.report("post_001", save: true) == nil, "saving a post that is already saved sends nothing")
    // Another device saves post_001 again: the store overwrites the same document.
    parent.store.perform(SavedPostWrite(postId: "post_001", save: true), ownerId: "user_a", at: Fixtures.date)
    // A lost reply: the store applies the save, but the app sees a failure and the user retries.
    let lost = parent.tapToggle("post_002", showing: Fixtures.post002)
    parent.finish(lost, .appliedButReportedFailed)
    parent.expect(!parent.state.isSaved("post_002") && parent.state.lastFailure == lost.map { .write($0) },
                  "after a lost reply the toggle shows Save with an error")
    parent.finish(parent.tapToggle("post_002", showing: Fixtures.post002))
    parent.expect(parent.store.documentIds(ownerId: "user_a") == ["post_001", "post_002"],
                  "the store still has one document per post")
    parent.refresh()
    parent.expect(parent.gridIds == ["post_001", "post_002"], "after a refresh each post appears once")
    parent.expect(parent.writesSent.count == 3, "the app sent three writes: a save, the lost save and its retry")
    return parent.problems
}

private func unsaveScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.save(Fixtures.post002)
    let unsave = parent.tapToggle("post_001")
    parent.expect(unsave?.save == false, "a Saved tap sends one unsave write")
    parent.finish(unsave)
    parent.expect(!parent.state.isSaved("post_001") && parent.gridIds == ["post_002"],
                  "after the unsave the toggle shows Save and the grid drops the post")
    parent.expect(parent.store.documentIds(ownerId: "user_a") == ["post_002"], "the saved document is removed")
    parent.expect(parent.report("post_001", save: false) == nil, "unsaving a post that is not saved sends nothing")
    return parent.problems
}

private func failedWriteScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    let save = parent.tapToggle("post_001", showing: Fixtures.post001)
    parent.finish(save, .rejected)
    parent.expect(!parent.state.isSaved("post_001") && !parent.state.isWorking("post_001") && parent.gridIds.isEmpty,
                  "a rejected save leaves Save, re-enabled, and no grid entry")
    parent.expect(parent.state.lastFailure == save.map { .write($0) }, "a rejected save is reported")
    parent.save(Fixtures.post002)
    let unsave = parent.tapToggle("post_002")
    parent.finish(unsave, .rejected)
    parent.expect(parent.state.isSaved("post_002") && parent.gridIds == ["post_002"],
                  "a rejected unsave keeps Saved and the grid entry")
    parent.finish(parent.tapToggle("post_002"))
    parent.expect(!parent.state.isSaved("post_002") && parent.state.lastFailure == nil,
                  "retrying the unsave works and clears the error")
    return parent.problems
}

private func refreshScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    parent.store.perform(SavedPostWrite(postId: "post_003", save: true), ownerId: "user_a", at: Fixtures.date)
    parent.refresh()
    parent.expect(parent.gridIds == ["post_003"], "a refresh shows a save made on another device")
    parent.store.nextReadFails = true
    parent.refresh()
    parent.expect(parent.gridIds == ["post_003"] && parent.state.lastFailure == .refresh,
                  "a failed refresh keeps the grid and reports an error")
    let early = parent.startRefresh()
    parent.save(Fixtures.post001)
    parent.apply(early)
    parent.expect(Set(parent.availableIds) == ["post_001", "post_003"],
                  "a save confirmed during a refresh is kept, with its card")
    let older = parent.startRefresh()
    parent.save(Fixtures.post002)
    let newer = parent.startRefresh()
    parent.apply(newer)
    parent.expect(!parent.apply(older), "an older refresh that finishes last is ignored")
    parent.expect(Set(parent.availableIds) == ["post_001", "post_002", "post_003"],
                  "every confirmed save is still shown as a card")
    return parent.problems
}

private func orderScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    parent.save(Fixtures.post003)
    parent.save(Fixtures.post001)
    let before = parent.gridIds
    parent.refresh()
    parent.expect(parent.gridIds == before, "a refresh keeps the grid order \(before), got \(parent.gridIds)")
    return parent.problems
}

private func deletedPostScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.save(Fixtures.post002)
    parent.store.deletePost("post_001")
    parent.expect(parent.availableIds == ["post_001", "post_002"],
                  "before the next refresh the grid still shows the card it was given")
    parent.refresh()
    parent.expect(parent.unavailableIds == ["post_001"] && parent.availableIds == ["post_002"],
                  "after a refresh the deleted post is an unavailable entry and post_002 is still a card")
    parent.expect(parent.state.isSaved("post_001"), "the deleted post's ID stays saved until the user removes it")
    parent.finish(parent.tapGridEntry("post_001"))
    parent.expect(parent.store.documentIds(ownerId: "user_a") == ["post_002"],
                  "unsaving from the unavailable entry removes its document")
    return parent.problems
}

/// The ticket's example: save post_001 twice, it disappears, no fake card, unsave reports it once.
private func ticketExampleScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.expect(parent.report("post_001", save: true) == nil, "the second save of post_001 sends nothing")
    parent.store.perform(SavedPostWrite(postId: "post_001", save: true), ownerId: "user_a", at: Fixtures.date)
    parent.store.deletePost("post_001")
    parent.refresh()
    parent.expect(parent.availableIds.isEmpty, "the grid shows no post card for post_001")
    parent.expect(parent.unavailableIds == ["post_001"], "post_001 stays identifiable for cleanup")
    parent.finish(parent.tapGridEntry("post_001"))
    let removals = parent.writesSent.filter { $0.postId == "post_001" && !$0.save }
    parent.expect(removals.count == 1, "unsaving reports post_001 once, not \(removals.count) times")
    parent.expect(parent.store.documentIds(ownerId: "user_a").isEmpty, "no saved document is left")
    return parent.problems
}

private func duplicatePostsScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    parent.save(Fixtures.post002)
    // Overlapping pages supply post_002 twice, and its saved ID twice.
    parent.refresh(supplying: [Fixtures.post001, Fixtures.post002, Fixtures.post002], ids: ["post_002", "post_002"])
    parent.expect(parent.gridIds == ["post_002"], "post_002 appears once")
    return parent.problems
}

private func relaunchScenario(_ strategy: SavedGridStrategy) -> [String] {
    let parent = parentForUserA(strategy)
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.save(Fixtures.post003)
    // A save is in flight when the app closes; the store still receives it.
    let inFlight = parent.tapToggle("post_002", showing: Fixtures.post002)
    if let inFlight {
        parent.store.perform(inFlight, ownerId: "user_a", at: Fixtures.date)
    }
    parent.relaunch()
    parent.expect(!parent.state.hasLoaded && parent.gridIds.isEmpty, "after relaunch nothing shows until a refresh")
    if let inFlight {
        parent.deliver(inFlight, succeeded: true)
    }
    parent.expect(parent.gridIds.isEmpty && !parent.state.isSaved("post_002"),
                  "the result of a write sent before the relaunch changes nothing")
    parent.store.nextReadFails = true
    parent.refresh()
    parent.expect(!parent.state.hasLoaded && parent.state.lastFailure == .refresh,
                  "a failed first refresh is an error, not an empty Saved list")
    parent.refresh()
    parent.expect(parent.state.hasLoaded && parent.gridIds == ["post_001", "post_002", "post_003"],
                  "after relaunch the grid matches the store, including the save that landed")
    return parent.problems
}

private func signOutScenario(_ strategy: SavedGridStrategy) -> [String] {
    let store = SavedPostsFixtureStore(posts: Fixtures.all)
    let userA = FixtureParent(ownerId: "user_a", store: store, strategy: strategy)
    userA.refresh()
    userA.save(Fixtures.post001)
    let pending = userA.tapToggle("post_002", showing: Fixtures.post002)
    // user_a signs out and user_c signs in; user_a's late result reaches the new state.
    let userC = FixtureParent(ownerId: "user_c", store: store, strategy: strategy)
    if let pending {
        userC.deliver(pending, succeeded: true)
    }
    userC.expect(userC.gridIds.isEmpty && !userC.state.isSaved("post_002"),
                 "user_a's late write result changes nothing for user_c")
    userC.refresh()
    userC.expect(userC.gridIds.isEmpty && !userC.state.isSaved("post_001") && !userC.state.isSaved("post_002"),
                 "user_c sees none of user_a's saved posts")
    return userA.problems + userC.problems
}

/// Supplying only the recent feed page instead of looking up the saved IDs.
private func feedPageOnlyCheck() -> [String] {
    var problems: [String] = []
    for strategy in SavedGridStrategy.allCases {
        let parent = parentForUserA(strategy)
        parent.refresh()
        parent.save(Fixtures.post003)
        parent.refresh(supplying: [Fixtures.post001, Fixtures.post002])
        if strategy == .idsFirst && parent.unavailableIds != ["post_003"] {
            problems.append("IDs-first should show the existing post_003 as unavailable")
        }
        if strategy == .postsFirst && !parent.gridIds.isEmpty {
            problems.append("posts-first should hide post_003")
        }
    }
    return problems
}

// MARK: - Report

private struct Scenario {
    let name: String
    let postsFirstShouldFail: Bool
    let run: (SavedGridStrategy) -> [String]
}

private func cell(_ text: String, _ width: Int) -> String {
    text.padding(toLength: width, withPad: " ", startingAt: 0)
}

@main
struct CheckSavedPosts {
    static func main() {
        let scenarios = [
            Scenario(name: "save", postsFirstShouldFail: false, run: saveScenario),
            Scenario(name: "repeated save", postsFirstShouldFail: false, run: repeatedSaveScenario),
            Scenario(name: "unsave", postsFirstShouldFail: false, run: unsaveScenario),
            Scenario(name: "failed write", postsFirstShouldFail: false, run: failedWriteScenario),
            Scenario(name: "refresh", postsFirstShouldFail: false, run: refreshScenario),
            Scenario(name: "order after refresh", postsFirstShouldFail: true, run: orderScenario),
            Scenario(name: "deleted post", postsFirstShouldFail: true, run: deletedPostScenario),
            Scenario(name: "ticket example", postsFirstShouldFail: true, run: ticketExampleScenario),
            Scenario(name: "same post supplied twice", postsFirstShouldFail: true, run: duplicatePostsScenario),
            Scenario(name: "relaunch", postsFirstShouldFail: false, run: relaunchScenario),
            Scenario(name: "sign-out", postsFirstShouldFail: false, run: signOutScenario)
        ]
        print("SOCIAL-P03 (#186) saved-post scenarios\n")
        print(cell("Scenario", 26) + cell("IDs-first", 12) + "Posts-first (#148 filter)")
        var notes: [String] = []
        var unexpected: [String] = []
        for scenario in scenarios {
            let idsFirst = scenario.run(.idsFirst)
            let postsFirst = scenario.run(.postsFirst)
            print(cell(scenario.name, 26) + cell(idsFirst.isEmpty ? "pass" : "FAIL", 12)
                  + (postsFirst.isEmpty ? "pass" : "FAIL"))
            if let first = idsFirst.first { unexpected.append("IDs-first, \(scenario.name): \(first)") }
            if let first = postsFirst.first { notes.append("Posts-first, \(scenario.name): \(first)") }
            if postsFirst.isEmpty == scenario.postsFirstShouldFail {
                unexpected.append("Posts-first, \(scenario.name): result differs from the proposal")
            }
        }
        print("\nFirst problem in each failing posts-first scenario:")
        notes.forEach { print("- \($0)") }
        let lookup = feedPageOnlyCheck()
        unexpected += lookup
        print("\nFeed page instead of a lookup by saved ID: " + (lookup.isEmpty
            ? "IDs-first marks the existing post_003 unavailable and posts-first hides it, as documented."
            : "unexpected result"))
        if unexpected.isEmpty {
            print("\nIDs-first passed every scenario; posts-first failed exactly the scenarios the proposal lists.")
            exit(0)
        }
        print("\nUnexpected results:")
        unexpected.forEach { print("- \($0)") }
        exit(1)
    }
}
