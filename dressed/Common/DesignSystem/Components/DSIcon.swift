import SwiftUI

// Tabler icon (https://tabler.io/icons) from Assets.xcassets at an explicit size.
// Asset images do not scale with .font() like SF Symbols, so always pass a size.
// Hidden from VoiceOver by default; label the enclosing control instead.
struct DSIcon: View {
    let name: String
    var size: CGFloat = 24

    init(_ name: String, size: CGFloat = 24) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(name)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// Tabler counterparts of SwiftUI's `systemImage:` initializers. Pass a smaller size next to
// caption text; the defaults suit body text (Label, Button) and empty states.
extension Label where Title == Text, Icon == DSIcon {
    init(_ titleKey: LocalizedStringKey, tabler name: String, size: CGFloat = 20) {
        self.init { Text(titleKey) } icon: { DSIcon(name, size: size) }
    }

    init<S: StringProtocol>(_ title: S, tabler name: String, size: CGFloat = 20) {
        self.init { Text(title) } icon: { DSIcon(name, size: size) }
    }
}

extension Button where Label == SwiftUI.Label<Text, DSIcon> {
    init(_ titleKey: LocalizedStringKey, tabler name: String, size: CGFloat = 20, action: @escaping () -> Void) {
        self.init(action: action) { SwiftUI.Label(titleKey, tabler: name, size: size) }
    }
}

extension ContentUnavailableView where Label == SwiftUI.Label<Text, DSIcon>, Description == Text?, Actions == EmptyView {
    init(_ titleKey: LocalizedStringKey, tabler name: String, description: Text? = nil) {
        self.init {
            SwiftUI.Label(titleKey, tabler: name, size: 48)
        } description: {
            description
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: DSSpacing.md) {
        HStack(spacing: DSSpacing.md) {
            DSIcon("TablerHanger2")
            DSIcon("TablerCompass")
            DSIcon("TablerUser")
            DSIcon("TablerCamera")
            DSIcon("TablerHeartFilled").foregroundStyle(DSColor.brand)
        }
        Label("View at Store", tabler: "TablerArrowUpRight", size: 12).font(.caption)
        Label("Save Outfit", tabler: "TablerHeart")
    }
    .padding()
}
