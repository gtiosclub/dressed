import SwiftUI

struct PostCommentsSheet: View {
    @StateObject private var model: CommentsViewModel
    @Environment(\.dismiss) private var dismiss

    init(postId: String, service: any CommentService) {
        _model = StateObject(wrappedValue: CommentsViewModel(postId: postId, service: service))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: DSSpacing.md) {
                if model.isDemo {
                    Text("Demo comments · saved only for this preview")
                        .font(DSFont.search).foregroundStyle(DSColor.textMuted)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DSSpacing.lg) {
                        if model.isLoading { ProgressView("Loading comments…") }
                        if model.hasLoaded && model.comments.isEmpty && !model.isRemoved {
                            Text("No comments yet. Be the first.").font(DSFont.body)
                        }
                        ForEach(model.comments) { comment in
                            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                                HStack {
                                    Text(comment.authorId == model.currentUserId ? "You" : "Member")
                                        .font(DSFont.bodyEmphasis)
                                    Text(comment.createdAt, style: .relative)
                                        .font(DSFont.search).foregroundStyle(DSColor.textMuted)
                                }
                                Text(comment.text).font(DSFont.body).textSelection(.enabled)
                            }
                        }
                        if model.comments.count == 50 {
                            Text("Showing the latest 50 comments").font(DSFont.search)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .refreshable { await model.load() }

                if let error = model.errorMessage {
                    Text(error).font(DSFont.search).accessibilityIdentifier("comments.error")
                    if !model.isRemoved {
                        Button("Refresh comments") { Task { await model.load() } }
                            .buttonStyle(.ds(.secondary))
                            .disabled(model.isLoading || model.isSending)
                    }
                }
                if !model.isRemoved {
                    HStack(spacing: DSSpacing.sm) {
                        TextField("Add a comment…", text: $model.draft, axis: .vertical)
                            .font(DSFont.body)
                            .lineLimit(1...4)
                            .padding(DSSpacing.md)
                            .background(DSColor.tile, in: RoundedRectangle(cornerRadius: DSRadius.md))
                            .disabled(model.isSending || model.hasPendingSubmission)
                            .accessibilityIdentifier("comments.input")
                        Button(model.hasPendingSubmission ? "Retry" : "Send") {
                            Task { await model.send() }
                        }
                        .buttonStyle(.ds(.primary))
                        .disabled(!model.canSend)
                        .accessibilityIdentifier("comments.send")
                    }
                    if model.isSending { ProgressView("Sending comment…") }
                    Text("\(model.draft.count)/1,000").font(DSFont.search)
                        .foregroundStyle(DSColor.textMuted)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(DSSpacing.lg)
            .foregroundStyle(DSColor.textPrimary)
            .background(DSColor.background)
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityLabel("Close comments")
                }
            }
            .task { await model.load() }
        }
        .tint(DSColor.brand)
    }
}
