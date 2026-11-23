import SwiftUI

// 43 pt grey circle used for the profile initial, the new-post button and the
// notifications bell. `showsDot` adds a brand-color dot for unread activity.
struct DSCircleButton: View {
    enum Content {
        case initial(String)
        case icon(String) // asset name
    }

    let content: Content
    let accessibilityLabel: String
    var showsDot = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Group {
                switch content {
                case .initial(let letter):
                    Text(letter)
                        .font(DSFont.bodyEmphasis)
                        .foregroundStyle(DSColor.textMuted)
                case .icon(let name):
                    DSIcon(name, size: 24)
                        .foregroundStyle(DSColor.iconMuted)
                }
            }
            .frame(width: 43, height: 43)
            .background(Circle().fill(DSColor.tile))
            .overlay(alignment: .topTrailing) {
                if showsDot {
                    Circle()
                        .fill(DSColor.brand)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(DSColor.background, lineWidth: 2))
                        .offset(x: -DSSpacing.xs, y: DSSpacing.xs)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(showsDot ? "Unread activity" : "")
    }
}

#Preview {
    HStack {
        DSCircleButton(content: .initial("E"), accessibilityLabel: "Profile") {}
        Spacer()
        DSCircleButton(content: .icon("TablerBell"), accessibilityLabel: "Notifications", showsDot: true) {}
        DSCircleButton(content: .icon("TablerPlus"), accessibilityLabel: "New post") {}
    }
    .padding(DSSpacing.lg)
    .background(DSColor.background)
}
