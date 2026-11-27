import SwiftUI

/// Reads only immutable published snapshots and their separate media copies.
struct PublishedOutfitDetailsView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @StateObject private var media = PublishedPostImageModel()
    @State private var isLoadingItems = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    if let name = post.outfitSnapshot.name {
                        Text(name)
                            .font(DSFont.navTitle)
                            .foregroundStyle(DSColor.textPrimary)
                    }
                    if post.outfitSnapshot.items.isEmpty {
                        DSEmptyState(
                            icon: "TablerHanger2",
                            title: "No outfit items",
                            message: "No outfit items were attached to this post."
                        )
                    }
                    ForEach(Array(post.outfitSnapshot.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSItemRow(title: item.name) {
                                if let image = media.pieceImages[item.mediaPath] {
                                    Image(uiImage: image).resizable().scaledToFit()
                                } else if isLoadingItems {
                                    ProgressView()
                                } else {
                                    DSIcon("TablerPhoto", size: 24).foregroundStyle(DSColor.iconMuted)
                                }
                            }
                            Text(item.category.rawValue.capitalized)
                                .font(DSFont.search)
                                .foregroundStyle(DSColor.textMuted)
                        }
                    }
                }
                .padding(DSSpacing.lg)
            }
            .background(DSColor.background)
            .foregroundStyle(DSColor.textPrimary)
            .navigationTitle("Outfit details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .tint(DSColor.brand)
        .task(id: post.id) {
            isLoadingItems = true
            await media.loadItems(post)
            isLoadingItems = false
        }
    }
}
