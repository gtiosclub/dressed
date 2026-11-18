import SwiftUI

/// Connects SavePostToggle (#149) to the user's saved posts and shows a failed save or remove below it.
struct SavedPostControl: View {
    let postId: String
    /// The post on screen, so a confirmed save shows its card in the Saved grid before the next refresh.
    var post: Post?
    @ObservedObject var model: SavedPostsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            SavePostToggle(
                postId: postId,
                isSaved: model.isSaved(postId),
                isWorking: model.isWorking(postId),
                onToggle: { id, save in model.toggle(postId: id, save: save, post: post) }
            )
            .tint(.primary)

            if let message = model.errorMessage(for: postId) {
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("savedPostControl.\(postId)")
    }
}
