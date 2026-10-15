//
//  testView.swift
//  dressed
//
//  Created by vasanth aggala on 10/15/26.
//

import SwiftUI

struct testView: View {
    @State private var log: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button("Run filterSavedPosts tests") { runTests() }
                ForEach(Array(log.enumerated()), id: \.offset) { Text($0.element).font(.caption) }
            }
            .padding()
        }
    }
    
    func makeSnapshot() -> PublishedOutfitSnapshot {
        PublishedOutfitSnapshot(name: nil, items: [])
    }

    // Fill in Post's other required fields from Common/Models/SocialSchema.swift.
    func makePost(_ id: String) -> Post {
        Post(
            id: id,
            schemaVersion: 1,
            authorId: "bob",
            caption: "",
            outfitSnapshot: makeSnapshot(),
            mediaPath: "",
            createdAt: Date(timeIntervalSince1970: 1_790_000_000)
        )
    }
    func ids(_ posts: [Post]) -> String {
        "[" + posts.map(\.id).joined(separator: ", ") + "]"
    }

    func runTests() {
        log.removeAll()
        let posts = [makePost("post_001"), makePost("post_002"), makePost("post_003")]

        // 1. Ticket example: only saved posts, in input order
        let saved: Set<String> = ["post_003", "post_001"]
        let r1 = filterSavedPosts(posts, savedPostIds: saved)
        add("1. Example → \(ids(r1))  (expected [post_001, post_003])")

        // 2. Unknown/deleted saved ID adds nothing
        let r2 = filterSavedPosts(posts, savedPostIds: ["post_001", "post_999"])
        add("2. Unknown ID → \(ids(r2))  (expected [post_001])")

        // 3. Empty set returns nothing
        let r3 = filterSavedPosts(posts, savedPostIds: [])
        add("3. Empty set → \(ids(r3))  (expected [])")

        // 4. Inputs unchanged
        add("4. Posts after → \(ids(posts))  (expected [post_001, post_002, post_003])")
        add("   Saved IDs after → \(saved.sorted())  (expected [\"post_001\", \"post_003\"])")
    }

    func add(_ s: String) { log.append(s); print(s) }
}
