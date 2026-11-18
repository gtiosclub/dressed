import SwiftUI

// Bottom navigation bar from the mockups (915:662). Replaces the system tab bar, which on
// iOS 26 is a floating glass bar. Pair it with a TabView whose own bar is hidden.
struct DSTabBar<Tag: Hashable>: View {
    struct Item {
        let tag: Tag
        let title: String
        let icon: String // asset name, tinted by selection
        var accessibilityIdentifier: String?
    }

    let items: [Item]
    @Binding var selection: Tag

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tag) { item in
                let isSelected = item.tag == selection
                Button {
                    selection = item.tag
                } label: {
                    VStack(spacing: DSSpacing.xxs) {
                        Image(item.icon)
                            .resizable()
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(DSFont.tab)
                            .tracking(0.1172)
                    }
                    .foregroundStyle(isSelected ? DSColor.brand : DSColor.iconMuted)
                    .frame(maxWidth: .infinity, minHeight: 49)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
                .accessibilityIdentifier(item.accessibilityIdentifier ?? item.title)
            }
        }
        .padding(.horizontal, 5)
        .padding(.top, 7)
        .padding(.bottom, DSSpacing.xs)
        .background {
            DSColor.background
                .overlay(alignment: .top) {
                    DSColor.divider.frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

#Preview {
    @Previewable @State var selection = 0
    VStack(spacing: 0) {
        DSColor.tile
        DSTabBar(
            items: [
                .init(tag: 0, title: "Closet", icon: "TablerHanger2"),
                .init(tag: 1, title: "Discovery", icon: "TablerCompass"),
                .init(tag: 2, title: "Avatar", icon: "TablerUser"),
                .init(tag: 3, title: "Camera", icon: "TablerCamera")
            ],
            selection: $selection
        )
    }
}
