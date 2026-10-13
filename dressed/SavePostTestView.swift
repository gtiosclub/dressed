//
//  SavePostTestView.swift
//  dressed
//
//  Created by vasanth aggala on 10/13/26.
//

import SwiftUI
import FirebaseFirestore

struct SavePostTestView: View {
    @State private var log: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("1. Save post_001 for alice") { Task { await save(owner: "alice") } }
            Button("2. Save again + count docs") { Task { await save(owner: "alice"); await count() } }
            Button("3. Save for bob (should fail)") { Task { await save(owner: "bob") } }
            ForEach(log, id: \.self) { Text($0).font(.caption) }
        }
        .padding()
    }

    func save(owner: String) async {
        let post = SavedPost(id: "post_001", schemaVersion: 1, ownerId: owner,
                             postId: "post_001",
                             createdAt: Date(timeIntervalSince1970: 1_790_000_000))
        do {
            try await savePost(post)
            add("✅ Saved users/\(owner)/savedPosts/post_001")
        } catch {
            add("❌ Threw for \(owner)")
            print(error)
        }
    }

    func count() async {
        let snap = try? await Firestore.firestore()
            .collection("users").document("alice")
            .collection("savedPosts").getDocuments()
        add("📄 alice savedPosts count: \(snap?.documents.count ?? -1)")
    }

    func add(_ s: String) { log.append(s); print(s) }
}
