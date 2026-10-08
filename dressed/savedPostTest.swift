//
//  savedPostTest.swift
//  dressed
//
// test view file
//  Created by vasanth aggala on 10/8/26.
//


import SwiftUI

struct SavePostTestView: View {
    @State private var status = "Not run"

    var body: some View {
        VStack(spacing: 16) {
            Text(status)
            Button("Save post_001") {
                Task { await runSave() }
            }
            Button("Save again (duplicate test)") {
                Task { await runSave() }
            }
        }
        .padding()
    }

    func runSave() async {
        let fixture = SavedPost(
            id: "post_001",
            schemaVersion: 1,
            ownerId: "user_a",
            postId: "post_001",
            createdAt: Date()
        )
        do {
            try await savePost(fixture)
            status = "Saved ✅"
            print("Saved users/user_a/savedPosts/post_001")
        } catch {
            status = "Failed: \(error.localizedDescription)"
            print("Save failed:", error)
        }
    }
}
