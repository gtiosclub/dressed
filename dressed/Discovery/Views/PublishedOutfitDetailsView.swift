import SwiftUI

/// Reads only immutable published snapshots and their separate media copies.
struct PublishedOutfitDetailsView: View {
    let post: Post
    @Environment(\.dismiss) private var dismiss
    @StateObject private var media = PublishedPostImageModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DSSpacing.md) {
                    if let name = post.outfitSnapshot.name { Text(name).font(DSFont.navTitle) }
                    if post.outfitSnapshot.items.isEmpty {
                        Text("No outfit items were attached to this post.").font(DSFont.body)
                    }
                    ForEach(Array(post.outfitSnapshot.items.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: DSSpacing.xs) {
                            DSItemRow(title: item.name) {
                                if let image = media.pieceImages[item.mediaPath] {
                                    Image(uiImage: image).resizable().scaledToFit()
                                } else { DSIcon("TablerPhoto", size: 24) }
                            }
                            Text(item.category.rawValue.capitalized).font(DSFont.search).foregroundStyle(DSColor.textMuted)
                        }
                    }
                }
                .padding(DSSpacing.lg)
            }
            .navigationTitle("Outfit details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task(id: post.id) { await media.loadItems(post) }
    }
}
