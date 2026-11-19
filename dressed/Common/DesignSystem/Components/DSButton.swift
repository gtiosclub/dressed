import SwiftUI

// 50 pt rounded-square buttons from the share-to-Dressed, import and create-outfit mockups.
// Add `.frame(maxWidth: .infinity)` for the full-width Import / Create Outfit buttons.
struct DSButtonStyle: ButtonStyle {
    enum Kind {
        case primary    // purple, white icon (search)
        case secondary  // warm grey (Back)
        case glass      // translucent white over photos (Skip, shop, close)
        case text       // no fill (Find More)
    }

    var kind: Kind = .secondary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DSFont.button)
            .foregroundStyle(kind == .primary ? Color.white : DSColor.textPrimary)
            .padding(.horizontal, 13)
            .frame(minWidth: 50, minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous)
                    .fill(fill)
            )
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(configuration.isPressed ? (reduceMotion ? 0.7 : 0.88) : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.62), value: configuration.isPressed)
    }

    private var fill: Color {
        switch kind {
        case .primary: DSColor.brand
        case .secondary: DSColor.secondaryFill
        case .glass: DSColor.glass
        case .text: .clear
        }
    }
}

extension ButtonStyle where Self == DSButtonStyle {
    static func ds(_ kind: DSButtonStyle.Kind) -> DSButtonStyle { DSButtonStyle(kind: kind) }
}

#Preview {
    VStack(spacing: DSSpacing.lg) {
        HStack {
            Button("Back") {}
                .buttonStyle(.ds(.secondary))
                .frame(width: 81)
            Spacer()
            Button {} label: {
                Image("TablerSearch").resizable().frame(width: 24, height: 24)
            }
            .buttonStyle(.ds(.primary))
            .accessibilityLabel("Search")
        }
        HStack {
            Button("Skip") {}
                .buttonStyle(.ds(.glass))
                .frame(width: 81)
            Button {} label: {
                Image("TablerBuildingStore").resizable().frame(width: 24, height: 24)
            }
            .buttonStyle(.ds(.glass))
            .accessibilityLabel("Shop")
        }
        .padding()
        .background(DSColor.textMuted)
    }
    .padding(DSSpacing.lg)
}
