import SwiftUI

// Product match row from the share-to-Dressed mockup: grey thumbnail panel, title, muted subtitle.
// Selection and saving belong to the parent review screen.
struct DSCandidateRow<Thumbnail: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let thumbnail: () -> Thumbnail

    var body: some View {
        HStack(spacing: DSSpacing.lg) {
            thumbnail()
                .padding(DSSpacing.xs)
                .frame(width: 128, height: 92)
                .background(DSColor.thumbnail)

            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(DSFont.bodyEmphasis)
                    .foregroundStyle(DSColor.textPrimary)
                Text(subtitle)
                    .font(DSFont.body)
                    .foregroundStyle(DSColor.textPlaceholder)
            }
            .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(height: 92)
        .background(DSColor.background)
        .clipShape(RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
        .dsShadow(.card)
    }
}

#Preview {
    VStack(spacing: DSSpacing.sm) {
        ForEach(["PreviewSweaterBrown", "PreviewTeeBrown", "PreviewSweatshirtBrown"], id: \.self) { name in
            DSCandidateRow(title: "Lorem Ipsum", subtitle: "Sit amet") {
                Image(name).resizable().scaledToFit()
            }
        }
    }
    .padding(9)
    .background(DSColor.background)
}
