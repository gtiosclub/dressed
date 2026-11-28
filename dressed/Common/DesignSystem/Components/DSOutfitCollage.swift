import SwiftUI

// 2 x 2 collage of an outfit's pieces: closet Outfits grid (973:5888, radius 26),
// outfit detail (1280:421, radius 16) and import review (1253:449, radius 16).
// Cells beyond `count` stay empty; `showsEmptyCells: false` leaves them white as in the detail view.
struct DSOutfitCollage<Cell: View>: View {
    var count: Int
    var cornerRadius: CGFloat = DSRadius.lg
    var gap: CGFloat = 3
    var showsEmptyCells = true
    /// Purple outline and glow on the newest outfit (973:5888).
    var isHighlighted = false
    @ViewBuilder let cell: (Int) -> Cell

    var body: some View {
        Grid(horizontalSpacing: gap, verticalSpacing: gap) {
            ForEach(0..<2, id: \.self) { row in
                GridRow {
                    ForEach(0..<2, id: \.self) { column in
                        let index = row * 2 + column
                        Rectangle()
                            .fill(index < count || showsEmptyCells ? DSColor.tile : Color.clear)
                            .aspectRatio(1, contentMode: .fit)
                            .overlay {
                                if index < count { cell(index).padding(DSSpacing.md) }
                            }
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(DSColor.brand, lineWidth: 1)
            }
        }
        .dsShadow(isHighlighted ? .selectedGlow : .none)
    }
}

#Preview {
    let names = ["PreviewSweaterBrown", "PreviewNecklace", "PreviewJeans"]
    HStack(spacing: DSSpacing.md) {
        DSOutfitCollage(count: 3) { Image(names[$0]).resizable().scaledToFit() }
        DSOutfitCollage(count: 3, cornerRadius: DSRadius.md, showsEmptyCells: false) {
            Image(names[$0]).resizable().scaledToFit()
        }
    }
    .padding(DSSpacing.lg)
}
