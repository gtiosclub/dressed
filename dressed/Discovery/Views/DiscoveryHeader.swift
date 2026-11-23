import SwiftUI

/// Discovery tab header from the "for u" mockup (915:933): profile, For You / Friends, new post.
/// For You shows the ranked outfit grid; Friends shows chronological outfit cards.
/// The notifications bell (SOCIAL-P09) is not in the mockup; it appears only when
/// `onNotifications` is supplied.
struct DiscoveryHeader: View {
    @Binding var section: Int
    var hasUnreadNotifications = false
    let onProfile: () -> Void
    var onNotifications: (() -> Void)?
    let onCreatePost: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            DSCircleButton(content: .icon("TablerUser"), accessibilityLabel: "Profile", action: onProfile)
                .accessibilityIdentifier("app.profileButton")
            // xs keeps four buttons and the switch inside a 375 pt wide screen.
            Spacer(minLength: DSSpacing.xs)
            DSSegmentedControl(options: [0, 1], selection: $section) { $0 == 0 ? "For You" : "Friends" }
                .accessibilityIdentifier("discovery.sectionPicker")
            Spacer(minLength: DSSpacing.xs)
            HStack(spacing: DSSpacing.xs) {
                if let onNotifications {
                    DSCircleButton(
                        content: .icon("TablerBell"),
                        accessibilityLabel: "Notifications",
                        showsDot: hasUnreadNotifications,
                        action: onNotifications
                    )
                    .accessibilityIdentifier("discovery.notifications")
                }
                DSCircleButton(content: .icon("TablerPlus"), accessibilityLabel: "Create Post", action: onCreatePost)
                    .accessibilityIdentifier("ootd.createPost")
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.sm)
        .padding(.bottom, DSSpacing.lg)
    }
}

#Preview {
    @Previewable @State var section = 0
    VStack {
        DiscoveryHeader(section: $section, onProfile: {}, onCreatePost: { section = 1 })
        DiscoveryHeader(
            section: $section,
            hasUnreadNotifications: true,
            onProfile: {},
            onNotifications: {},
            onCreatePost: { section = 1 }
        )
    }
}
