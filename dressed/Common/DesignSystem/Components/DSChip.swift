import SwiftUI

// Category pill from the closet mockup. Selected chips look pressed in.
// An optional leading Tabler icon marks removable chips, such as applied filters.
// `.flat` is the Create Outfit filter row (1273:173): black when selected, grey when not.
struct DSChip: View {
    enum Style {
        case raised
        case flat
    }

    let title: String
    let isSelected: Bool
    var icon: String?
    var style: Style = .raised
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xs) {
                if let icon { DSIcon(icon, size: 14) }
                Text(title)
            }
            .font(DSFont.label)
            .foregroundStyle(foreground)
            .fixedSize()
            .padding(.horizontal, DSSpacing.lg)
            .frame(height: style == .flat ? 44 : 43)
            .background { background }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var foreground: Color {
        style == .flat && isSelected ? .white : (style == .flat ? DSColor.textPrimary : DSColor.textStrong)
    }

    @ViewBuilder private var background: some View {
        if style == .flat {
            Capsule().fill(isSelected ? DSColor.textPrimary : DSColor.tile)
        } else if isSelected {
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

#Preview("Flat filter row") {
    HStack(spacing: DSSpacing.sm) {
        DSChip(title: "Outfits", isSelected: false, style: .flat) {}
        DSChip(title: "Tops", isSelected: true, style: .flat) {}
        DSChip(title: "Jackets", isSelected: false, style: .flat) {}
    }
    .padding(DSSpacing.lg)
}

#Preview("Removable") {
    HStack(spacing: DSSpacing.sm) {
        DSChip(title: "Y2K", isSelected: true, icon: "TablerX") {}
        DSChip(title: "Vintage", isSelected: true, icon: "TablerX") {}
    }
    .padding(DSSpacing.lg)
}
