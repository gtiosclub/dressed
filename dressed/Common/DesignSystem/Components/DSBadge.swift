import SwiftUI

// Small purple or black pills: "New" on the newest closet piece (915:526) and the
// "3 of 3" counter on the share-to-Dressed photo (777:6352, 1012:282).
struct DSBadge: View {
    enum Kind {
        case new                 // 20 pt purple label
        case counter             // 28 pt black 85 % pill
        case counterSelected     // 28 pt purple pill once a candidate is chosen
    }

    let text: String
    var kind: Kind = .new

    var body: some View {
        Text(text)
            .font(kind == .new ? DSFont.badge : DSFont.badge.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, kind == .new ? DSSpacing.sm : DSSpacing.md)
            .frame(minWidth: kind == .new ? 42 : 81, minHeight: kind == .new ? 20 : 28)
            .background(Capsule().fill(fill))
    }

    private var fill: Color {
        switch kind {
        case .new, .counterSelected: DSColor.brand
        case .counter: Color.black.opacity(0.85)
        }
    }
}

#Preview {
    VStack(spacing: DSSpacing.md) {
        DSBadge(text: "New")
        DSBadge(text: "3 of 3", kind: .counter)
        DSBadge(text: "3 of 3", kind: .counterSelected)
    }
    .padding()
}
