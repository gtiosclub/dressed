import SwiftUI

// Friends feed card: handle and date, outfit photo, shop button, caption, comment and like counts.
// Presentational only; the parent owns liking, comments and the shop sheet.
struct DSPostCard<Photo: View>: View {
    let handle: String
    let date: String
    let caption: String
    let commentCount: Int
    var commentCountText: String? = nil
    let likeCount: Int
    var isLiked = false
    var isLikeEnabled = true
    /// Overrides the default "N likes" label, e.g. "Like outfit" / "Unlike outfit".
    var likeLabel: String?
    var shopID: String? = nil
    var commentID: String?
    var likeID: String?
    var errorMessage: String? = nil
    var onShop: () -> Void = {}
    var onComment: () -> Void = {}
    var onLike: () -> Void = {}
    var onRetryLike: (() -> Void)? = nil
    @ViewBuilder let photo: () -> Photo

    @State private var isCaptionExpanded = false

    private var commentDisplayText: String {
        commentCountText ?? "\(commentCount)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(handle) · \(Text(date).foregroundStyle(DSColor.textMuted))")
                .font(DSFont.bodyEmphasis)
                .padding(.horizontal, 18)
                .frame(height: 56)

            // Overlay keeps a scaledToFill photo from widening the card.
            Color.clear
                .aspectRatio(4 / 5, contentMode: .fit)
                .overlay { photo() }
                .clipShape(RoundedRectangle(cornerRadius: DSRadius.xs))
                .overlay(alignment: .bottomTrailing) {
                    Button(action: onShop) {
                        Image("TablerBuildingStore").resizable().frame(width: 24, height: 24)
                    }
                    .buttonStyle(.ds(.glass))
                    .accessibilityLabel("Shop this look")
                    .optionalAccessibilityIdentifier(shopID)
                    .padding(11)
                }

            HStack(alignment: isCaptionExpanded ? .top : .center, spacing: DSSpacing.lg) {
                Text(caption)
                    .lineLimit(isCaptionExpanded ? nil : 1)
                    .fixedSize(horizontal: false, vertical: isCaptionExpanded)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !caption.isEmpty else { return }
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isCaptionExpanded.toggle()
                        }
                    }
                Button(action: onComment) {
                    count(icon: "TablerMessageCircle", text: commentDisplayText)
                }
                .accessibilityLabel("\(commentDisplayText) comments")
                .optionalAccessibilityIdentifier(commentID)
                Button(action: onLike) {
                    count(icon: isLiked ? "TablerHeartFilled" : "TablerHeart", text: "\(likeCount)")
                }
                .disabled(!isLikeEnabled)
                .accessibilityLabel(likeLabel ?? "\(likeCount) likes")
                .accessibilityValue(likeLabel == nil ? "" : "\(likeCount) likes")
                .accessibilityAddTraits(isLiked ? .isSelected : [])
                .optionalAccessibilityIdentifier(likeID)
            }
            .buttonStyle(.plain)
            .font(DSFont.bodyEmphasis)
            .foregroundStyle(DSColor.textPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, isCaptionExpanded ? DSSpacing.sm : 0)
            .frame(minHeight: 56)

            if let errorMessage {
                HStack(spacing: DSSpacing.sm) {
                    Text(errorMessage)
                        .font(DSFont.search)
                        .foregroundStyle(DSColor.destructive)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let onRetryLike {
                        Button("Retry", action: onRetryLike)
                            .buttonStyle(.ds(.text))
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, DSSpacing.sm)
            }
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

    private func count(icon: String, text: String) -> some View {
        HStack(spacing: DSSpacing.xs) {
            Image(icon).resizable().frame(width: 22, height: 22)
            Text(text).monospacedDigit()
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }
}

private extension View {
    @ViewBuilder
    func optionalAccessibilityIdentifier(_ id: String?) -> some View {
        if let id {
            accessibilityIdentifier(id)
        } else {
            self
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
