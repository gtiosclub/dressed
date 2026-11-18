import SwiftUI

/// Community identity only; the parent supplies an already-approved avatar.
struct ProfileHeader: View {
    var avatar: Image? = nil
    let name: String
    let username: String

    @ScaledMetric(relativeTo: .title) private var avatarSize = 80.0

    var body: some View {
        HStack(alignment: .center, spacing: DSSpacing.lg) {
            avatarView
            identity
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var avatarView: some View {
        Circle()
            .fill(DSColor.tile)
            .frame(width: avatarSize, height: avatarSize)
            .overlay {
                if let avatar {
                    avatar.resizable().scaledToFill()
                } else {
                    DSIcon("TablerUserCircle", size: avatarSize)
                        .foregroundStyle(DSColor.iconMuted)
                }
            }
            .clipShape(Circle())
            .overlay(Circle().stroke(DSColor.brand.opacity(0.3), lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(avatar == nil ? "No profile photo" : "Profile photo")
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Text(name)
                .font(DSFont.bodyEmphasis)
                .foregroundStyle(DSColor.textPrimary)
            Text(username.hasPrefix("@") ? username : "@\(username)")
                .font(DSFont.body)
                .foregroundStyle(DSColor.textMuted)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
