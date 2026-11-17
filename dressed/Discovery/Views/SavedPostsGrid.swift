//
//  SavedPostsGrid.swift
//  dressed
//
//  Created by Tiana Prem  on 10/11/26.
//

import SwiftUI

/// Two-column grid of saved posts, placed inside the screen's scroll view. A saved post that can't be
/// found gets an unavailable entry that keeps its control, never a post card.
struct SavedPostGrid<Control: View>: View {
    let entries: [SavedGridEntry]
    let onPostTap: (Post) -> Void
    @ViewBuilder let control: (SavedGridEntry) -> Control

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        if entries.isEmpty {
            ContentUnavailableView(
                "No saved posts yet",
                systemImage: "bookmark",
                description: Text("Posts you save in OOTD appear here.")
            )
            .containerRelativeFrame(.vertical)
            .accessibilityIdentifier("savedPosts.empty")
        } else {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(entries) { entry in
                    VStack(alignment: .leading, spacing: 8) {
                        switch entry {
                        case .available(let post):
                            postCard(post)
                        case .unavailable(let postId):
                            unavailableCard(postId: postId)
                        }
                        control(entry)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func postCard(_ post: Post) -> some View {
        Button {
            onPostTap(post)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                PostArtwork(post: post)
                    .aspectRatio(1, contentMode: .fit)
                Text(post.caption)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Post by \(post.authorId): \(post.caption)")
        .accessibilityHint("Shows the pieces in this post")
        .accessibilityIdentifier("savedPosts.post.\(post.id)")
    }

    private func unavailableCard(postId: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 8) {
                Image(systemName: "eye.slash")
                    .font(.title2)
                Text("This post was removed or is hidden.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 12))

            Text("No longer available")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("savedPosts.unavailable.\(postId)")
    }
}

#Preview("Saved and removed") {
    let post = Post(id: "post_002", schemaVersion: 1, authorId: "alex", caption: "Rainy day layers",
                    outfitSnapshot: PublishedOutfitSnapshot(name: nil, items: []),
                    mediaPath: "", createdAt: .now)
    SavedPostGrid(
        entries: [.unavailable(postId: "post_001"), .available(post)],
        onPostTap: { _ in },
        control: { entry in
            SavePostToggle(postId: entry.id, isSaved: true, isWorking: false) { _, _ in }
        }
    )
}

#Preview("Empty") {
    SavedPostGrid(entries: [], onPostTap: { _ in }, control: { _ in EmptyView() })
}
