import SwiftUI

// 43 pt grey circle used for the profile initial and the new-post button.
struct DSCircleButton: View {
    enum Content {
        case initial(String)
        case icon(String) // asset name
    }

    let content: Content
    let accessibilityLabel: String
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
                    Image(name)
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundStyle(DSColor.textPrimary)
                }
            }
            .frame(width: 43, height: 43)
            .background(Circle().fill(DSColor.tile))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    HStack {
        DSCircleButton(content: .initial("E"), accessibilityLabel: "Profile") {}
        Spacer()
        DSCircleButton(content: .icon("TablerPlus"), accessibilityLabel: "New post") {}
    }
    .padding(DSSpacing.lg)
    .background(DSColor.background)
}
