import SwiftUI

/// Discovery tab header from the "for u" mockup (915:933): profile, For You / Friends, new post.
/// For You shows the ranked outfit grid; Friends shows chronological outfit cards.
struct DiscoveryHeader: View {
    @Binding var section: Int
    let onProfile: () -> Void
    var onSavedPosts: () -> Void = {}
    let onCreatePost: () -> Void

    var body: some View {
        HStack(spacing: DSSpacing.xs) {
            DSCircleButton(content: .icon("TablerUser"), accessibilityLabel: "Profile", action: onProfile)
                .accessibilityIdentifier("app.profileButton")
            DSSegmentedControl(options: [0, 1], selection: $section) { $0 == 0 ? "For You" : "Friends" }
                .accessibilityIdentifier("discovery.sectionPicker")
            DSCircleButton(content: .icon("TablerBookmark"), accessibilityLabel: "Saved Posts", action: onSavedPosts)
                .accessibilityIdentifier("ootd.savedPosts")
            DSCircleButton(content: .icon("TablerPlus"), accessibilityLabel: "Create Post", action: onCreatePost)
                .accessibilityIdentifier("ootd.createPost")
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.sm)
        .padding(.bottom, DSSpacing.lg)
    }
}

#Preview {
    @Previewable @State var section = 0
    DiscoveryHeader(section: $section, onProfile: {}, onCreatePost: { section = 1 })
}
