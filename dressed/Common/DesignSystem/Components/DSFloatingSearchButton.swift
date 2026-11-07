import SwiftUI

// Floating pill above the tab bar ("Search Your Closet", "Search Styles"). Tapping opens search;
// use SearchField for the text entry itself.
struct DSFloatingSearchButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DSSpacing.xs) {
                Image("TablerSearch")
                    .resizable()
                    .frame(width: 13, height: 13)
                    .accessibilityHidden(true)
                Text(title)
                    .font(DSFont.search)
                    .tracking(0.1172)
            }
            .foregroundStyle(DSColor.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                    .fill(DSColor.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                            .stroke(DSColor.fieldBorder, lineWidth: 1)
                    )
                    .dsShadow(.floating)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        DSColor.tile.ignoresSafeArea()
        VStack(spacing: DSSpacing.lg) {
            DSFloatingSearchButton(title: "Search Your Closet") {}
            DSFloatingSearchButton(title: "Search Styles") {}
        }
        .padding(DSSpacing.lg)
    }
}
