import SwiftUI

// Category pill from the closet mockup. Selected chips look pressed in.
// An optional leading Tabler icon marks removable chips, such as applied filters.
struct DSChip: View {
    let title: String
    let isSelected: Bool
    var icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xs) {
                if let icon { DSIcon(icon, size: 14) }
                Text(title)
            }
            .font(DSFont.label)
            .foregroundStyle(DSColor.textStrong)
            .fixedSize()
            .padding(.horizontal, DSSpacing.lg)
            .frame(height: 43)
            .background { background }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var background: some View {
        if isSelected {
            Capsule()
                .fill(DSColor.pressed.shadow(DSShadow.pressedInner))
                .overlay(Capsule().stroke(DSColor.pressedBorder, lineWidth: 1))
        } else {
            Capsule()
                .fill(DSColor.raised)
                .dsShadow(.raised)
        }
    }
}

#Preview("Chip row") {
    @Previewable @State var selection = "Shirts"
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: DSSpacing.sm) {
            ForEach(["Outfits", "Shirts", "Accessories", "Hoodies"], id: \.self) { title in
                DSChip(title: title, isSelected: selection == title) { selection = title }
            }
        }
        .padding(DSSpacing.lg)
    }
    .background(DSColor.background)
}

#Preview("Removable") {
    HStack(spacing: DSSpacing.sm) {
        DSChip(title: "Y2K", isSelected: true, icon: "TablerX") {}
        DSChip(title: "Vintage", isSelected: true, icon: "TablerX") {}
    }
    .padding(DSSpacing.lg)
}
