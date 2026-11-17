//
//  FeedPreview.swift
//  dressed
//
//  Created by Tiana Prem  on 11/3/26.
//

import SwiftUI

struct FeedPreview: View {
    @StateObject private var model: ChronologicalFeedModel
    @State private var upwardPull: CGFloat = 0

    init() {
        let fixtures = FeedFixtures()
        _model = StateObject(
            wrappedValue: ChronologicalFeedModel { cursor in
                try await fixtures.loadPage(cursor: cursor)
            }
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                Text("Feed prototype")
                    .font(.title2.bold())

                .buttonStyle(.bordered)
                .disabled(model.isLoading)
                ForEach(model.posts) { post in
                    VStack(alignment: .leading, spacing: 12) {
                        DemoOutfitPhoto(post: post)
                            .frame(height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Text("@\(post.authorId)")
                            .font(.subheadline.bold())

                        Text(post.caption)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        Color.gray.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }

                if model.isLoading {
                    ProgressView(
                        model.isRefreshing ? "Refreshing…" : "Loading…"
                    )
                } else if let message = model.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)

                    Button("Retry") {
                        Task { await model.retry() }
                    }
                    .buttonStyle(.borderedProminent)
                } else if model.hasMore {
                    Button("Load More") {
                        Task { await model.loadMore() }
                    }
                    .buttonStyle(.borderedProminent)

                    VStack(spacing: 8) {
                        Image(systemName: "arrow.up")
                            .offset(y: -min(upwardPull / 5, 14))

                        Text(
                            upwardPull >= 70
                                ? "Release to load more"
                                : "Pull upward here to load more"
                        )
                        .font(.footnote)
                    }
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(
                        Color.gray.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 15)
                            .onChanged { value in
                                upwardPull = max(0, -value.translation.height)
                            }
                            .onEnded { value in
                                let shouldLoad =
                                    -value.translation.height >= 70

                                upwardPull = 0

                                if shouldLoad {
                                    Task { await model.loadMore() }
                                }
                            }
                    )
                    .accessibilityHidden(true)
                } else if model.hasLoaded {
                    Text(
                        model.posts.isEmpty
                            ? "No posts yet"
                            : "You're all caught up"
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .refreshable {
            let refreshTask = Task { @MainActor in
                await model.refresh()
            }
            await refreshTask.value
        }
        .task {
            await model.loadInitial()
        }
    }
}

#Preview {
    FeedPreview()
}
