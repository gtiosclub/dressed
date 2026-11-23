import Combine
import Foundation

// SOCIAL-P09 (#247) prototype. The inbox reads AppNotification records, which hold IDs
// only. Names and thumbnails come from lookups when the inbox loads, so an old
// notification can't keep showing a post or account that was removed.
// Creating notifications, push delivery and Firebase are out of scope.

/// Where a row may lead. Only IDs from a notification that passed a lookup reach it.
enum NotificationDestination: Hashable {
    case post(id: String)
    case profile(id: String, displayName: String)
}

/// What the inbox shows after tapping a row.
enum NotificationOpenResult: Hashable {
    case open(NotificationDestination)
    case postUnavailable
    case profileUnavailable
}

/// Result of checking a post a notification points to.
enum NotificationPostLookup: Equatable {
    /// `thumbnail` is a bundled asset name in the prototype; later a published media reference (#59).
    case available(thumbnail: String?)
    case removed
}

/// Supplies notification records and the community-safe details a row may show.
/// A lookup that fails should answer "unavailable" so nothing unverified opens.
@MainActor
protocol NotificationService {
    func fetchNotifications() async throws -> [AppNotification]
    /// Display name from approved public profile data (#49), or nil for a deleted or blocked account.
    func actorName(for userId: String) async -> String?
    func postLookup(for postId: String) async -> NotificationPostLookup
    func markRead(_ notificationIds: [String], at date: Date) async
}

/// One inbox row. Repeated events of the same kind on the same post (or follows on the
/// same day) share a row. It never carries captions, comment text or private media.
struct NotificationRowItem: Identifiable, Equatable {
    enum Availability: Equatable {
        case available
        case postRemoved
        case profileUnavailable
    }

    /// All grouped notification IDs, newest first.
    var notificationIds: [String]
    var kind: AppNotification.Kind
    /// The newest available actor's name; nil when no actor in the group is available.
    var actorName: String?
    var otherActorCount: Int
    var latestAt: Date
    var isUnread: Bool
    var thumbnail: String?
    var availability: Availability
    /// Nil whenever the destination can't open.
    var destination: NotificationDestination?

    var id: String { notificationIds[0] }
}

@MainActor
final class NotificationInboxModel: ObservableObject {
    @Published private(set) var rows: [NotificationRowItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var errorMessage: String?

    private let service: any NotificationService
    private let calendar: Calendar
    private let now: () -> Date

    init(
        service: any NotificationService,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { .now }
    ) {
        self.service = service
        self.calendar = calendar
        self.now = now
    }

    var newRows: [NotificationRowItem] { rows.filter(\.isUnread) }
    var earlierRows: [NotificationRowItem] { rows.filter { !$0.isUnread } }
    var hasUnread: Bool { rows.contains(where: \.isUnread) }

    func loadInitial() async {
        guard !hasLoaded, !isLoading, errorMessage == nil else { return }
        await load()
    }

    /// Keeps the current rows if the request fails.
    func refresh() async {
        guard !isLoading else { return }
        await load()
    }

    func retry() async {
        guard errorMessage != nil else { return }
        await refresh()
    }

    /// Marks the row read, then checks its destination again, since the post or account
    /// may have been removed after the last refresh.
    func open(_ row: NotificationRowItem) async -> NotificationOpenResult {
        await markRead(row)

        switch row.destination {
        case .post(let id):
            if case .available = await service.postLookup(for: id) {
                return .open(.post(id: id))
            }
            update(row.id) {
                $0.availability = .postRemoved
                $0.destination = nil
                $0.thumbnail = nil
            }
            return .postUnavailable

        case .profile(let id, _):
            if let name = await service.actorName(for: id) {
                return .open(.profile(id: id, displayName: name))
            }
            update(row.id) {
                $0.availability = .profileUnavailable
                $0.destination = nil
                $0.actorName = nil
            }
            return .profileUnavailable

        case nil:
            return row.availability == .profileUnavailable ? .profileUnavailable : .postUnavailable
        }
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let records = try await service.fetchNotifications()
            try Task.checkCancellation()
            let built = await buildRows(from: records)
            try Task.checkCancellation()
            rows = built
            hasLoaded = true
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func markRead(_ row: NotificationRowItem) async {
        guard row.isUnread else { return }
        update(row.id) { $0.isUnread = false }
        // If this write fails in a live service, the next refresh shows the row as unread again.
        await service.markRead(row.notificationIds, at: now())
    }

    private func update(_ id: String, _ change: (inout NotificationRowItem) -> Void) {
        guard let index = rows.firstIndex(where: { $0.id == id }) else { return }
        change(&rows[index])
    }

    // MARK: - Grouping

    /// Likes, comments and follows only. Recommendation and challenge notifications are later phases.
    static let supportedKinds: Set<AppNotification.Kind> = [.like, .comment, .follow]

    /// Newest first, with the ID as a tie-breaker (the same order as the feed in #184).
    static func isNewer(_ lhs: AppNotification, than rhs: AppNotification) -> Bool {
        lhs.createdAt == rhs.createdAt ? lhs.id < rhs.id : lhs.createdAt > rhs.createdAt
    }

    /// Groups records into rows: likes or comments on the same post, and follows on the same day.
    /// Groups are ordered by their newest event; each group's members are newest first.
    static func group(_ records: [AppNotification], calendar: Calendar) -> [[AppNotification]] {
        var order: [String] = []
        var groups: [String: [AppNotification]] = [:]

        for record in records.sorted(by: isNewer) where supportedKinds.contains(record.kind) {
            let key: String
            switch record.kind {
            case .follow:
                key = "follow|\(calendar.startOfDay(for: record.createdAt).timeIntervalSince1970)"
            default:
                // A like or comment without a post can't be grouped or opened.
                key = "\(record.kind.rawValue)|\(record.postId ?? "missing:\(record.id)")"
            }
            if groups[key] == nil { order.append(key) }
            groups[key, default: []].append(record)
        }
        return order.compactMap { groups[$0] }
    }

    private func buildRows(from records: [AppNotification]) async -> [NotificationRowItem] {
        names = [:]
        posts = [:]
        var rows: [NotificationRowItem] = []
        for members in Self.group(records, calendar: calendar) {
            rows.append(await row(for: members))
        }
        return rows
    }

    // Lookups made while building rows, so each actor and post is checked once per load.
    private var names: [String: String?] = [:]
    private var posts: [String: NotificationPostLookup] = [:]

    private func row(for members: [AppNotification]) async -> NotificationRowItem {
        let newest = members[0]
        var actorIds: [String] = []
        for actorId in members.compactMap(\.actorId) where !actorIds.contains(actorId) {
            actorIds.append(actorId)
        }
        let actor = await firstAvailableActor(in: actorIds)

        var row = NotificationRowItem(
            notificationIds: members.map(\.id),
            kind: newest.kind,
            actorName: actor?.name,
            otherActorCount: max(actorIds.count - 1, 0),
            latestAt: newest.createdAt,
            isUnread: members.contains { $0.readAt == nil },
            thumbnail: nil,
            availability: .available,
            destination: nil
        )

        if newest.kind == .follow {
            if let actor {
                row.destination = .profile(id: actor.id, displayName: actor.name)
            } else {
                row.availability = .profileUnavailable
            }
        } else if let postId = newest.postId, case .available(let thumbnail) = await lookUpPost(postId) {
            row.thumbnail = thumbnail
            row.destination = .post(id: postId)
        } else {
            row.availability = .postRemoved
        }
        return row
    }

    /// The newest actor whose account is still available, so a deleted latest actor
    /// doesn't hide the others.
    private func firstAvailableActor(in actorIds: [String]) async -> (id: String, name: String)? {
        for actorId in actorIds {
            if names[actorId] == nil {
                names[actorId] = .some(await service.actorName(for: actorId))
            }
            if let name = names[actorId] ?? nil {
                return (actorId, name)
            }
        }
        return nil
    }

    private func lookUpPost(_ postId: String) async -> NotificationPostLookup {
        if let cached = posts[postId] { return cached }
        let lookup = await service.postLookup(for: postId)
        posts[postId] = lookup
        return lookup
    }
}
