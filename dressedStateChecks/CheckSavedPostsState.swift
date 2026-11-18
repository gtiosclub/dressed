import Foundation

// SOCIAL-P03 (#186): checks SavedPostsState without building the app. Outside the iOS app target.
// From the repository root:
//   xcrun swiftc dressed/Common/Models/*.swift dressed/Discovery/ViewModels/SavedPostsState.swift \
//     dressedStateChecks/*.swift -o /private/tmp/saved-posts-state-check
//   /private/tmp/saved-posts-state-check

private func saveScenario(_ parent: Parent) {
    parent.refresh()
    let write = parent.tap("post_001", showing: Fixtures.post001)
    parent.expect(write?.save == true, "a Save tap sends one save write")
    parent.expect(parent.state.isWorking("post_001") && !parent.state.isSaved("post_001"),
                  "the toggle is working and still shows Save until the write succeeds")
    parent.expect(parent.tap("post_001") == nil, "a tap while working sends nothing")
    parent.expect(parent.report("post_001", save: true) == nil,
                  "a second report while the save is in flight sends nothing, such as a fast double tap")
    parent.finish(write)
    parent.expect(parent.state.isSaved("post_001") && parent.availableIds == ["post_001"],
                  "after the write succeeds the toggle shows Saved and the grid has the card")
    parent.expect(parent.writesSent.count == 1, "exactly one write was sent")
    parent.expect(parent.store.documentIds(ownerId: "user_a") == ["post_001"], "the store has one saved document")
}

private func repeatedSaveScenario(_ parent: Parent) {
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.expect(parent.report("post_001", save: true) == nil, "saving a post that is already saved sends nothing")
    // Another device saves post_001 again: the store keeps the same document.
    parent.store.perform(SavedPostWrite(postId: "post_001", save: true), ownerId: "user_a")
    // A lost reply: the store applies the save, but the app sees a failure and the user retries.
    let lost = parent.tap("post_002", showing: Fixtures.post002)
    parent.finish(lost, .appliedButReportedFailed)
    parent.expect(!parent.state.isSaved("post_002") && parent.state.failedWrite == lost,
                  "after a lost reply the toggle shows Save with an error")
    parent.finish(parent.tap("post_002", showing: Fixtures.post002))
    parent.expect(parent.state.failedWrite == nil, "retrying clears the error")
    parent.expect(parent.store.documentIds(ownerId: "user_a") == ["post_001", "post_002"],
                  "the store still has one document per post")
    parent.refresh()
    parent.expect(parent.gridIds == ["post_001", "post_002"], "after a refresh each post appears once")
    parent.expect(parent.writesSent.count == 3, "the app sent three writes: a save, the lost save and its retry")
}

private func unsaveScenario(_ parent: Parent) {
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.save(Fixtures.post002)
    let unsave = parent.tap("post_001")
    parent.expect(unsave?.save == false, "a Saved tap sends one unsave write")
    parent.expect(parent.state.isSaved("post_001"), "the entry stays until the unsave succeeds")
    parent.finish(unsave)
    parent.expect(!parent.state.isSaved("post_001") && parent.gridIds == ["post_002"],
                  "after the unsave the toggle shows Save and the grid drops the post")
    parent.expect(parent.store.documentIds(ownerId: "user_a") == ["post_002"], "the saved document is removed")
    parent.expect(parent.report("post_001", save: false) == nil, "unsaving a post that is not saved sends nothing")
}

private func failedWriteScenario(_ parent: Parent) {
    parent.refresh()
    let save = parent.tap("post_001", showing: Fixtures.post001)
    parent.finish(save, .rejected)
    parent.expect(!parent.state.isSaved("post_001") && !parent.state.isWorking("post_001") && parent.gridIds.isEmpty,
                  "a rejected save leaves Save, re-enabled, and no grid entry")
    parent.expect(parent.state.failedWrite == save, "a rejected save is reported")
    parent.save(Fixtures.post002)
    parent.expect(parent.state.failedWrite == nil, "the next action clears the error")
    let unsave = parent.tap("post_002")
    parent.finish(unsave, .rejected)
    parent.expect(parent.state.isSaved("post_002") && parent.gridIds == ["post_002"],
                  "a rejected unsave keeps Saved and the grid entry")
    parent.expect(parent.state.failedWrite == unsave, "a rejected unsave is reported")
    parent.finish(parent.tap("post_002"))
    parent.expect(!parent.state.isSaved("post_002") && parent.state.failedWrite == nil,
                  "retrying the unsave works and clears the error")
}

private func refreshScenario(_ parent: Parent) {
    parent.refresh()
    parent.store.perform(SavedPostWrite(postId: "post_003", save: true), ownerId: "user_a")
    parent.refresh()
    parent.expect(parent.gridIds == ["post_003"], "a refresh shows a save made on another device")
    parent.store.nextReadFails = true
    parent.refresh()
    parent.expect(parent.gridIds == ["post_003"] && parent.state.refreshFailed,
                  "a failed refresh keeps the grid and reports an error")
    let early = parent.startRefresh()
    parent.expect(!parent.state.refreshFailed, "a retry clears the refresh error while it runs")
    parent.save(Fixtures.post001)
    parent.apply(early)
    parent.expect(parent.availableIds == ["post_001", "post_003"],
                  "a save confirmed during a refresh is kept, with its card")
    let older = parent.startRefresh()
    parent.save(Fixtures.post002)
    let newer = parent.startRefresh()
    parent.apply(newer)
    parent.expect(!parent.apply(older), "an older refresh that finishes last is ignored")
    parent.expect(parent.availableIds == ["post_001", "post_002", "post_003"],
                  "every confirmed save is still shown as a card")
    // A save still in flight during a refresh keeps its card when it lands.
    parent.finish(parent.tap("post_001"))
    let inFlight = parent.tap("post_001", showing: Fixtures.post001)
    parent.refresh(supplying: [Fixtures.post002, Fixtures.post003])
    parent.finish(inFlight)
    parent.expect(parent.availableIds.contains("post_001"), "a save in flight during a refresh keeps its card")
}

private func orderScenario(_ parent: Parent) {
    parent.refresh()
    parent.save(Fixtures.post003)
    parent.save(Fixtures.post001)
    let before = parent.gridIds
    parent.expect(before == ["post_001", "post_003"], "saves are sorted into place, got \(before)")
    parent.refresh()
    parent.expect(parent.gridIds == before, "a refresh keeps the grid order, got \(parent.gridIds)")
}

private func deletedPostScenario(_ parent: Parent) {
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
    parent.finish(parent.tap("post_001"))
    parent.expect(parent.store.documentIds(ownerId: "user_a") == ["post_002"],
                  "unsaving from the unavailable entry removes its document")
}

/// The ticket's example: save post_001 twice, it disappears, no fake card, unsave reports it once.
private func ticketExampleScenario(_ parent: Parent) {
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.expect(parent.report("post_001", save: true) == nil, "the second save of post_001 sends nothing")
    parent.store.perform(SavedPostWrite(postId: "post_001", save: true), ownerId: "user_a")
    parent.store.deletePost("post_001")
    parent.refresh()
    parent.expect(parent.availableIds.isEmpty, "the grid shows no post card for post_001")
    parent.expect(parent.unavailableIds == ["post_001"], "post_001 stays identifiable for cleanup")
    parent.finish(parent.tap("post_001"))
    let removals = parent.writesSent.filter { $0.postId == "post_001" && !$0.save }
    parent.expect(removals.count == 1, "unsaving reports post_001 once, not \(removals.count) times")
    parent.expect(parent.store.documentIds(ownerId: "user_a").isEmpty, "no saved document is left")
}

private func duplicatesScenario(_ parent: Parent) {
    parent.refresh()
    parent.save(Fixtures.post002)
    parent.refresh(supplying: [Fixtures.post001, Fixtures.post002, Fixtures.post002], ids: ["post_002", "post_002"])
    parent.expect(parent.gridIds == ["post_002"], "post_002 appears once")
}

private func relaunchScenario(_ parent: Parent) {
    parent.refresh()
    parent.save(Fixtures.post001)
    parent.save(Fixtures.post003)
    // A save is in flight when the app closes; the store still receives it.
    let inFlight = parent.tap("post_002", showing: Fixtures.post002)
    if let inFlight {
        parent.store.perform(inFlight, ownerId: "user_a")
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
    parent.expect(!parent.state.hasLoaded && parent.state.refreshFailed,
                  "a failed first refresh is an error, not an empty Saved list")
    parent.refresh()
    parent.expect(parent.state.hasLoaded && parent.gridIds == ["post_001", "post_002", "post_003"],
                  "after relaunch the grid matches the store, including the save that landed")
}

private func signOutScenario(_ parent: Parent) {
    parent.refresh()
    parent.save(Fixtures.post001)
    let pending = parent.tap("post_002", showing: Fixtures.post002)
    // user_a signs out and user_c signs in; user_a's late result reaches the new state.
    let userC = Parent(ownerId: "user_c", store: parent.store)
    if let pending {
        userC.deliver(pending, succeeded: true)
    }
    userC.expect(userC.gridIds.isEmpty && !userC.state.isSaved("post_002"),
                 "user_a's late write result changes nothing for user_c")
    userC.refresh()
    userC.expect(userC.gridIds.isEmpty && !userC.state.isSaved("post_001"),
                 "user_c sees none of user_a's saved posts")
    userC.problems.forEach { parent.expect(false, "user_c: \($0)") }
}

@main
struct CheckSavedPostsState {
    static func main() {
        let scenarios: [(name: String, run: (Parent) -> Void)] = [
            ("save", saveScenario), ("repeated save", repeatedSaveScenario), ("unsave", unsaveScenario),
            ("failed write", failedWriteScenario), ("refresh", refreshScenario),
            ("order after refresh", orderScenario), ("deleted post", deletedPostScenario),
            ("ticket example", ticketExampleScenario), ("same post supplied twice", duplicatesScenario),
            ("relaunch", relaunchScenario), ("sign-out", signOutScenario)
        ]
        var failures = 0
        for scenario in scenarios {
            let parent = Parent()
            scenario.run(parent)
            if let problem = parent.problems.first {
                failures += 1
                print("FAIL \(scenario.name): \(problem)")
            } else {
                print("pass \(scenario.name)")
            }
        }
        print(failures == 0 ? "All \(scenarios.count) scenarios passed." : "\(failures) scenarios failed.")
        exit(failures == 0 ? 0 : 1)
    }
}
