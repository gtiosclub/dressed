import SwiftUI

// 56 pt purple round button beside the floating search pill on the closet Outfits tab (973:5888): new outfit.
struct DSFloatingActionButton: View {
    static let size: CGFloat = 56

    var icon = "TablerPlus"
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            DSIcon(icon, size: 31)
                .foregroundStyle(.white)
                .frame(width: Self.size, height: Self.size)
                .background(Circle().fill(DSColor.brand))
                .dsShadow(.floating)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    HStack(spacing: DSSpacing.sm) {
        DSFloatingSearchButton(title: "Search Your Closet") {}
        DSFloatingActionButton(accessibilityLabel: "New outfit") {}
    }
    .padding(DSSpacing.lg)
}
