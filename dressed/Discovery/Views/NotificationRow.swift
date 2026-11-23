import SwiftUI

/// One inbox row (SOCIAL-P09). Presentational: it shows the supplied row and reports taps.
/// VoiceOver reads the row as one sentence, and unread is never shown by color alone.
struct NotificationRow: View {
    let item: NotificationRowItem
    var now: Date = .now
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.md) {
                Circle()
                    .fill(item.isUnread ? DSColor.brand : Color.clear)
                    .frame(width: 8, height: 8)
                avatar
                VStack(alignment: .leading, spacing: DSSpacing.xxs) {
                    message
                    if item.availability == .postRemoved {
                        Text("Post removed")
                            .font(DSFont.button)
                            .foregroundStyle(DSColor.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                thumbnail
            }
            .padding(.leading, DSSpacing.sm)
            .padding(.trailing, DSSpacing.lg)
            .padding(.vertical, DSSpacing.md)
            .background(item.isUnread ? DSColor.brand.opacity(0.07) : DSColor.background)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySentence)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("notifications.row.\(item.id)")
    }

    // MARK: - Pieces

    private var actorText: String { item.actorName ?? "Unavailable account" }

    private var othersText: String {
        switch item.otherActorCount {
        case 0: ""
        case 1: " and 1 other"
        default: " and \(item.otherActorCount) others"
        }
    }

    private var actionText: String {
        switch item.kind {
        case .like: "liked your post"
        case .comment: "commented on your post"
        default: "started following you"
        }
    }

    private var message: Text {
        Text(actorText).fontWeight(item.isUnread ? .bold : .medium)
            + Text("\(othersText) \(actionText) ")
            + Text(Self.shortAge(from: item.latestAt, to: now)).foregroundStyle(DSColor.textMuted)
    }

    private var avatar: some View {
        Group {
            if let name = item.actorName, let initial = name.first {
                Text(String(initial).uppercased())
                    .font(DSFont.bodyEmphasis)
                    .foregroundStyle(DSColor.textMuted)
            } else {
                DSIcon("TablerUserOff", size: 20)
                    .foregroundStyle(DSColor.iconMuted)
            }
        }
        .frame(width: 40, height: 40)
        .background(Circle().fill(DSColor.tile))
    }

    @ViewBuilder private var thumbnail: some View {
        if let name = item.thumbnail {
            Color.clear
                .frame(width: 44, height: 44)
                .overlay { Image(name).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.xs))
        } else if item.availability == .postRemoved {
            DSIcon("TablerPhotoOff", size: 20)
                .foregroundStyle(DSColor.iconMuted)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: DSRadius.xs).fill(DSColor.tile))
        }
    }

    // MARK: - Text

    private var accessibilitySentence: String {
        var parts: [String] = []
        if item.isUnread { parts.append("Unread.") }
        parts.append("\(actorText)\(othersText) \(actionText).")
        parts.append("\(Self.spokenAge.localizedString(for: item.latestAt, relativeTo: now)).")
        if item.availability == .postRemoved { parts.append("Post removed.") }
        return parts.joined(separator: " ")
    }

    private static let spokenAge: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    /// "now", "2m", "1h", "2d" or "3w", like other social inboxes.
    static func shortAge(from date: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(seconds / 60)m"
        case ..<86_400: return "\(seconds / 3_600)h"
        case ..<604_800: return "\(seconds / 86_400)d"
        default: return "\(seconds / 604_800)w"
        }
    }
}

#Preview("Row states") {
    let now = Date.now
    func row(
        _ id: String, _ kind: AppNotification.Kind, _ name: String?, others: Int = 0, minutes: Double,
        unread: Bool, thumbnail: String? = nil, availability: NotificationRowItem.Availability = .available
    ) -> NotificationRowItem {
        NotificationRowItem(
            notificationIds: [id], kind: kind, actorName: name, otherActorCount: others,
            latestAt: now.addingTimeInterval(-minutes * 60), isUnread: unread, thumbnail: thumbnail,
            availability: availability, destination: nil
        )
    }
    return ScrollView {
        VStack(spacing: 0) {
            let rows = [
                row("a", .like, "maya", others: 2, minutes: 2, unread: true, thumbnail: "DemoOutfitPhoto2"),
                row("b", .comment, "jordan", minutes: 15, unread: true, availability: .postRemoved),
                row("c", .follow, nil, minutes: 60, unread: true, availability: .profileUnavailable),
                row("d", .follow, "maya", minutes: 2_880, unread: false),
                row("e", .like, "sam", minutes: 4_320, unread: false, thumbnail: "DemoOutfitPhoto3")
            ]
            ForEach(rows) { NotificationRow(item: $0) {} }
        }
    }
}
