import SwiftUI

// Chevron plus 20 pt title for pushed screens: Outfit Name (1280:421), Select Items (1273:173).
struct DSBackHeader<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: DSSpacing.sm) {
            Button(action: onBack) {
                HStack(spacing: DSSpacing.sm) {
                    DSIcon("TablerChevronLeft", size: 24)
                    Text(title).font(DSFont.navTitle)
                }
                .foregroundStyle(DSColor.textPrimary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back, \(title)")
            Spacer(minLength: 0)
            trailing()
        }
    }
}

extension DSBackHeader where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: DSSpacing.lg) {
        DSBackHeader(title: "Outfit Name") {}
        DSBackHeader(title: "Select Items", onBack: {}) {
            HStack(spacing: DSSpacing.xs) {
                DSThumbnailSlot { Image("PreviewTeeNavy").resizable().scaledToFit() }
                DSThumbnailSlot { Image("PreviewJeans").resizable().scaledToFit() }
            }
        }
    }
    .padding(DSSpacing.lg)
}
