import SwiftUI

// Square grid tile. `.item` insets a cutout on grey (closet); `.photo` fills edge to edge (For You).
// `isHighlighted` is the purple outline and glow on the newest closet piece (915:526).
// `isChecked` (non-nil) adds the select circle from Create Outfit (1273:173); nil hides it.
struct DSTile<Content: View>: View {
    enum Style {
        case item
        case photo
    }

    var style: Style = .item
    var isHighlighted = false
    var isChecked: Bool?
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
            .overlay {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                        .stroke(DSColor.brand, lineWidth: 1)
                }
            }
            .overlay(alignment: .topLeading) {
                if let isChecked {
                    DSSelectionMark(isChecked: isChecked)
                        .padding(14)
                }
            }
            .dsShadow(isHighlighted ? .selectedGlow : .none)
    }
}

#Preview("Closet grid") {
    let columns = [GridItem(.flexible(), spacing: DSSpacing.md), GridItem(.flexible(), spacing: DSSpacing.md)]
    ScrollView {
        LazyVGrid(columns: columns, spacing: DSSpacing.md) {
            ForEach(["PreviewShirtGingham", "PreviewTeeBlueGraphic", "PreviewTeeNavy",
                     "PreviewTeeBlack", "PreviewTeeGrey", "PreviewTeeWhite"], id: \.self) { name in
                DSTile(isHighlighted: name == "PreviewShirtGingham") {
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

#Preview("Selectable") {
    HStack(spacing: DSSpacing.md) {
        DSTile(isChecked: true) { Image("PreviewTeeNavy").resizable().scaledToFit() }
        DSTile(isChecked: false) { Image("PreviewTeeBlack").resizable().scaledToFit() }
    }
    .padding(DSSpacing.lg)
}
