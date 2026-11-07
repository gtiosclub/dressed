import SwiftUI

// Square grid tile. `.item` insets a cutout on grey (closet); `.photo` fills edge to edge (For You).
struct DSTile<Content: View>: View {
    enum Style {
        case item
        case photo
    }

    var style: Style = .item
    @ViewBuilder let content: () -> Content

    var body: some View {
        RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
            .fill(DSColor.tile)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                switch style {
                case .item:
                    content().padding(24)
                case .photo:
                    content()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous))
    }
}

#Preview("Closet grid") {
    let columns = [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible(), spacing: DSSpacing.md)]
    ScrollView {
        LazyVGrid(columns: columns, spacing: DSSpacing.md) {
            ForEach(["PreviewShirtGingham", "PreviewTeeBlueGraphic", "PreviewTeeNavy",
                     "PreviewTeeBlack", "PreviewTeeGrey", "PreviewTeeWhite"], id: \.self) { name in
                DSTile {
                    Image(name).resizable().scaledToFit()
                }
            }
            ForEach(0..<2, id: \.self) { _ in
                DSTile(style: .photo) {
                    Image("OutfitPostPlaceholder")
                        .resizable()
                        .scaledToFill()
                }
            }
        }
        .padding(DSSpacing.lg)
    }
    .background(DSColor.background)
}
