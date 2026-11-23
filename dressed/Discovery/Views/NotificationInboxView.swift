import SwiftUI

/// SOCIAL-P09 notification inbox: newest first, unread rows under "New", read rows under
/// "Earlier". A row opens only the destination ID it was given; a removed post or an
/// unavailable account opens a clear unavailable screen instead.
struct NotificationInboxView: View {
    @ObservedObject var model: NotificationInboxModel
    /// Reads posts for the post-detail screen.
    let postService: any PostFunctions

    @State private var route: NotificationOpenResult?
    @State private var openingId: String?

    var body: some View {
        content
            .background(DSColor.background)
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadInitial() }
            .navigationDestination(item: $route) { destination($0) }
    }

    @ViewBuilder private var content: some View {
        if model.hasLoaded {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.errorMessage != nil && !model.isLoading {
                        refreshBanner
                    }
                    if model.rows.isEmpty {
                        ContentUnavailableView(
                            "No activity yet",
                            tabler: "TablerBell",
                            description: Text("Likes, comments and new followers show up here.")
                        )
                        .padding(.top, DSSpacing.lg)
                        .accessibilityIdentifier("notifications.empty")
                    }
                    // One ForEach for headers and rows: a row that becomes read only moves within it.
                    // With a ForEach per section, a row moving between them kept its unread look.
                    ForEach(entries) { entry in
                        switch entry {
                        case .header(let title):
                            sectionHeader(title)
                        case .row(let row):
                            NotificationRow(item: row) { open(row) }
                                .disabled(openingId != nil)
                        }
                    }
                }
                .padding(.bottom, DSSpacing.lg)
            }
            .accessibilityIdentifier("notifications.list")
            .refreshable {
                // A separately owned task, as in InfiniteDiscoveryFeed, so the pull gesture can't cancel it.
                let refresh = Task { @MainActor in await model.refresh() }
                await refresh.value
            }
        } else if let message = model.errorMessage, !model.isLoading {
            FeedStatusView(status: .error(message: message)) {
                Task { await model.retry() }
            }
        } else {
            FeedStatusView(status: .loading)
        }
    }

    private enum Entry: Identifiable {
        case header(String)
        case row(NotificationRowItem)

        var id: String {
            switch self {
            case .header(let title): "header.\(title)"
            case .row(let row): row.id
            }
        }
    }

    /// "New" (unread) rows, then "Earlier" (read) rows, each under a header when non-empty.
    private var entries: [Entry] {
        var entries: [Entry] = []
        for (title, rows) in [("New", model.newRows), ("Earlier", model.earlierRows)] where !rows.isEmpty {
            entries.append(.header(title))
            entries.append(contentsOf: rows.map(Entry.row))
        }
        return entries
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(DSFont.button)
            .foregroundStyle(DSColor.textMuted)
            .padding(.horizontal, DSSpacing.lg)
            .padding(.top, DSSpacing.lg)
            .padding(.bottom, DSSpacing.xs)
            .accessibilityAddTraits(.isHeader)
    }

    private var refreshBanner: some View {
        HStack(spacing: DSSpacing.sm) {
            DSIcon("TablerWifiOff", size: 20)
                .foregroundStyle(DSColor.iconMuted)
            Text("Couldn't refresh.")
                .font(DSFont.button)
                .foregroundStyle(DSColor.textStrong)
            Spacer(minLength: DSSpacing.sm)
            Button("Retry") { Task { await model.retry() } }
                .buttonStyle(.ds(.primary))
                .accessibilityIdentifier("notifications.retry")
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.vertical, DSSpacing.sm)
        .background(DSColor.raised)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("notifications.refreshFailed")
    }

    private func open(_ row: NotificationRowItem) {
        guard openingId == nil else { return }
        openingId = row.id
        Task {
            route = await model.open(row)
            openingId = nil
        }
    }

    @ViewBuilder private func destination(_ result: NotificationOpenResult) -> some View {
        switch result {
        case .open(.post(let id)):
            DiscoveryPostDetailView(postId: id, service: postService)
        case .open(.profile(let id, let displayName)):
            // Public profiles wait on #49; the prototype shows the supplied display name
            // in the existing profile header.
            ProfileHeader(avatar: Image("TablerUserCircle"), name: displayName, username: "@\(displayName)")
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("notifications.profile.\(id)")
        case .postUnavailable:
            NotificationUnavailableView(subject: .post)
        case .profileUnavailable:
            NotificationUnavailableView(subject: .account)
        }
    }
}

/// Shown instead of a removed post or an unavailable account. It never shows cached
/// content, and a deleted account looks the same as a block, so a block isn't revealed.
struct NotificationUnavailableView: View {
    enum Subject {
        case post
        case account
    }

    let subject: Subject
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContentUnavailableView {
            Label(
                subject == .post ? "This post isn't available" : "This account isn't available",
                tabler: subject == .post ? "TablerPhotoOff" : "TablerUserOff",
                size: 48
            )
        } description: {
            Text("It may have been deleted.")
        } actions: {
            Button("Back to Notifications") { dismiss() }
                .buttonStyle(.ds(.secondary))
                .accessibilityIdentifier("notifications.unavailable.back")
        }
        .background(DSColor.background)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Inbox") {
    NavigationStack {
        NotificationInboxView(
            model: NotificationInboxModel(service: NotificationFixtures()),
            postService: NotificationFixturePostService()
        )
    }
}

#Preview("Empty") {
    NavigationStack {
        NotificationInboxView(
            model: NotificationInboxModel(service: NotificationFixtures(empty: true)),
            postService: NotificationFixturePostService()
        )
    }
}

#Preview("Unavailable post") {
    NavigationStack { NotificationUnavailableView(subject: .post) }
}
