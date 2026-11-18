#if DEBUG
import SwiftUI

// Debug-only catalog of design system components. Launch with -designSystemGallery.
struct DesignSystemGallery: View {
    @State private var chip = "Shirts"
    @State private var feed = "For You"
    @State private var liked = false
    @State private var tab = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                section("Chips") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DSSpacing.sm) {
                            ForEach(["Outfits", "Shirts", "Accessories", "Hoodies"], id: \.self) { title in
                                DSChip(title: title, isSelected: chip == title) { chip = title }
                            }
                        }
                        .padding(.vertical, DSSpacing.md)
                        .padding(.horizontal, DSSpacing.xs)
                    }
                }

                section("Header") {
                    HStack {
                        DSCircleButton(content: .initial("E"), accessibilityLabel: "Profile") {}
                        Spacer()
                        DSSegmentedControl(options: ["For You", "Friends"], selection: $feed) { $0 }
                        Spacer()
                        DSCircleButton(content: .icon("TablerPlus"), accessibilityLabel: "New post") {}
                    }
                }

                section("Tiles") {
                    LazyVGrid(columns: [GridItem(spacing: DSSpacing.md), GridItem()], spacing: DSSpacing.md) {
                        ForEach(["PreviewShirtGingham", "PreviewTeeBlueGraphic", "PreviewTeeNavy", "PreviewTeeBlack"],
                                id: \.self) { name in
                            DSTile { Image(name).resizable().scaledToFit() }
                        }
                    }
                }

                section("Buttons") {
                    HStack(spacing: DSSpacing.sm) {
                        Button("Back") {}.buttonStyle(.ds(.secondary))
                        DSThumbnailSlot { Image("PreviewJeans").resizable().scaledToFit() }
                        DSThumbnailSlot { Image("PreviewNecklace").resizable().scaledToFit() }
                        Spacer()
                        Button {} label: {
                            Image("TablerSearch").resizable().frame(width: 24, height: 24)
                        }
                        .buttonStyle(.ds(.primary))
                        .accessibilityLabel("Search")
                    }
                    DSColor.textMuted
                        .frame(height: 120)
                        .overlay { Image("OutfitPostPlaceholder").resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md))
                        .overlay(alignment: .bottomTrailing) {
                            Button("Skip") {}.buttonStyle(.ds(.glass)).padding(DSSpacing.sm)
                        }
                    DSFloatingSearchButton(title: "Search Your Closet") {}
                }

                section("Candidate rows") {
                    ForEach(["PreviewSweaterBrown", "PreviewTeeBrown", "PreviewSweatshirtBrown"], id: \.self) { name in
                        DSCandidateRow(title: "Lorem Ipsum", subtitle: "Sit amet") {
                            Image(name).resizable().scaledToFit()
                        }
                    }
                }

                section("Icons") {
                    HStack(spacing: DSSpacing.md) {
                        ForEach(["TablerSearch", "TablerHeart", "TablerMessageCircle", "TablerBuildingStore",
                                 "TablerShirt", "TablerFilter", "TablerAlertTriangle"], id: \.self) { name in
                            DSIcon(name)
                        }
                    }
                    Label("View at Store", tabler: "TablerArrowUpRight", size: 12).font(.caption)
                }

                section("Tab bar") {
                    DSTabBar(
                        items: [
                            .init(tag: 0, title: "Closet", icon: "TablerHanger2"),
                            .init(tag: 1, title: "Discovery", icon: "TablerCompass"),
                            .init(tag: 2, title: "Avatar", icon: "TablerUser"),
                            .init(tag: 3, title: "Camera", icon: "TablerCamera")
                        ],
                        selection: $tab
                    )
                }

                section("Post card") {
                    DSPostCard(
                        handle: "@janedoe123",
                        date: "11.21.26",
                        caption: "Lorem Ipsum sit amet",
                        commentCount: 2,
                        likeCount: liked ? 22 : 21,
                        isLiked: liked,
                        onLike: { liked.toggle() }
                    ) {
                        Image("OutfitPostPlaceholder").resizable().scaledToFill()
                    }
                    DSPageIndicator(count: 7, current: 0)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(DSSpacing.lg)
        }
        .background(DSColor.background)
        .preferredColorScheme(.light)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.md) {
            Text(title).font(.caption).foregroundStyle(DSColor.textMuted)
            content()
        }
    }
}

#Preview {
    DesignSystemGallery()
}
#endif
