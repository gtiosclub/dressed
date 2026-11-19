import SwiftUI

// Empty, error and no-results states for screens that fill the page (closet tabs, wishlist, create outfit).
// A soft round plate holds the Tabler icon, then a title, one muted line and an optional single action.
// Colors, type and radii come from the tokens; there is no Figma frame for these, so they stay quiet.
struct DSEmptyState: View {
    let icon: String
    let title: String
    var message: String?
    var actionTitle: String?
    var action: (() -> Void)?

    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            DSIcon(icon, size: 40)
                .foregroundStyle(DSColor.iconMuted)
                .frame(width: 96, height: 96)
                .background(Circle().fill(DSColor.tile))
                .scaleEffect(appeared || reduceMotion ? 1 : 0.86)

            VStack(spacing: DSSpacing.sm) {
                Text(title)
                    .font(DSFont.navTitle.weight(.medium))
                    .foregroundStyle(DSColor.textPrimary)
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .font(DSFont.body)
                        .foregroundStyle(DSColor.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: 300)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.ds(.primary))
                    .fixedSize()
            }
        }
        .padding(DSSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) { appeared = true }
        }
        .accessibilityElement(children: .contain)
    }
}

#Preview("Empty") {
    DSEmptyState(icon: "TablerHanger2", title: "Your closet is empty",
                 message: "Add a piece from Camera or share an image to Dressed.")
}

#Preview("With action") {
    DSEmptyState(icon: "TablerAlertTriangle", title: "Could not load closet",
                 message: "Something went wrong.", actionTitle: "Try Again") {}
}
