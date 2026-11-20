import SwiftUI

// Piece row under an outfit: outfit detail (1280:421) and import review (1253:449).
// 64 pt grey row, white bordered thumbnail on the left, optional trailing content on the right
// (usually `DSMoreMenu`).
struct DSItemRow<Thumbnail: View, Trailing: View>: View {
    let title: String
    @ViewBuilder let trailing: () -> Trailing
    @ViewBuilder let thumbnail: () -> Thumbnail

    var body: some View {
        HStack(spacing: 0) {
            thumbnail()
                .padding(DSSpacing.sm)
                .frame(width: 64, height: 64)
                .background(DSColor.background)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: DSRadius.sm, bottomLeadingRadius: DSRadius.sm)
                        .stroke(DSColor.thumbnail, lineWidth: 2)
                )
            Text(title)
                .font(DSFont.body)
                .foregroundStyle(DSColor.textPrimary)
                .lineLimit(1)
                .padding(.leading, DSSpacing.lg)
            Spacer(minLength: 0)
            trailing()
        }
        .frame(height: 64)
        .background(DSColor.thumbnail)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.sm, style: .continuous))
    }
}

extension DSItemRow where Trailing == EmptyView {
    init(title: String, @ViewBuilder thumbnail: @escaping () -> Thumbnail) {
        self.init(title: title, trailing: { EmptyView() }, thumbnail: thumbnail)
    }
}

// Three grey dots that open a menu of actions: the trailing control on `DSItemRow`.
struct DSMoreMenu<Content: View>: View {
    let accessibilityLabel: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu(content: content) {
            DSIcon("TablerDots", size: 24)
                .foregroundStyle(DSColor.iconMuted)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview {
    VStack(spacing: DSSpacing.xs) {
        ForEach(["PreviewSweaterBrown", "PreviewJeans", "PreviewNecklace"], id: \.self) { name in
            DSItemRow(title: "Lorem Ipsum", trailing: {
                DSMoreMenu(accessibilityLabel: "More options") { Button("Try On") {} }
            }) { Image(name).resizable().scaledToFit() }
        }
        DSItemRow(title: "No actions") { Image("PreviewTeeNavy").resizable().scaledToFit() }
    }
    .padding(DSSpacing.lg)
}
