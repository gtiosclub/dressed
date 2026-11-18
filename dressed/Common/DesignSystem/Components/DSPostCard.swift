import SwiftUI

// Friends feed card: handle and date, outfit photo, shop button, caption, comment and like counts.
// Presentational only; the parent owns liking, comments and the shop sheet.
struct DSPostCard<Photo: View>: View {
    let handle: String
    let date: String
    let caption: String
    let commentCount: Int
    let likeCount: Int
    var isLiked = false
    var onShop: () -> Void = {}
    var onComment: () -> Void = {}
    var onLike: () -> Void = {}
    @ViewBuilder let photo: () -> Photo

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(handle) · \(Text(date).foregroundStyle(DSColor.textMuted))")
                .font(DSFont.bodyEmphasis)
                .padding(.horizontal, 18)
                .frame(height: 56)

            // Overlay keeps a scaledToFill photo from widening the card.
            Color.clear
                .frame(height: 475)
                .overlay { photo() }
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.xs))
                .overlay(alignment: .bottomTrailing) {
                    Button(action: onShop) {
                        Image("TablerBuildingStore").resizable().frame(width: 24, height: 24)
                    }
                    .buttonStyle(.ds(.glass))
                    .accessibilityLabel("Shop this look")
                    .padding(11)
                }

            HStack(spacing: DSSpacing.md) {
                Text(caption)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onComment) {
                    count(icon: "TablerMessageCircle", value: commentCount)
                }
                .accessibilityLabel("\(commentCount) comments")
                Button(action: onLike) {
                    count(icon: isLiked ? "TablerHeartFilled" : "TablerHeart", value: likeCount)
                }
                .accessibilityLabel("\(likeCount) likes")
                .accessibilityAddTraits(isLiked ? .isSelected : [])
            }
            .buttonStyle(.plain)
            .font(DSFont.bodyEmphasis)
            .foregroundStyle(DSColor.textPrimary)
            .padding(.horizontal, 19)
            .frame(height: 56)
        }
        .background {
            RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                .fill(DSColor.background)
                .overlay(
                    RoundedRectangle(cornerRadius: DSRadius.lg, style: .continuous)
                        .stroke(DSColor.brand.opacity(0.5), lineWidth: 0.5)
                )
                .dsShadow(.brandGlow)
        }
    }

    private func count(icon: String, value: Int) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Image(icon).resizable().frame(width: 22, height: 22)
            Text("\(value)")
        }
    }
}

#Preview {
    @Previewable @State var liked = false
    VStack(spacing: DSSpacing.lg) {
        DSPostCard(
            handle: "@janedoe123",
            date: "11.21.26",
            caption: "Lorem Ipsum sit amet",
            commentCount: 2,
            likeCount: liked ? 22 : 21,
            isLiked: liked,
            onLike: { liked.toggle() }
        ) {
            Image("OutfitPostPlaceholder").resizable().scaledToFill()
        }
        DSPageIndicator(count: 7, current: 0)
    }
    .padding(DSSpacing.lg)
    .background(DSColor.background)
}
