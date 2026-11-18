import SwiftUI

/// Bundled demo photos repeat independently of the posts' stable paging IDs.
struct DemoOutfitPhoto: View {
    let post: Post

    private var assetName: String {
        let suffix = String(post.id.split(separator: "_").last ?? "0")
        let index = Int(suffix) ?? max(0, Int(suffix.utf8.first ?? 65) - 65)
        return "DemoOutfitPhoto\(abs(index % 4) + 1)"
    }

    var body: some View {
        GeometryReader { geometry in
            Image(assetName)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .accessibilityLabel("Sample outfit photo")
    }
}
