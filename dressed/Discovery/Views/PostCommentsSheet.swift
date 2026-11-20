import SwiftUI

struct PostCommentsSheet: View {
    @StateObject private var model: CommentsViewModel
    @Environment(\.dismiss) private var dismiss

    init(postId: String, service: any CommentService) {
        _model = StateObject(wrappedValue: CommentsViewModel(postId: postId, service: service))
    }

    private var isEmpty: Bool { model.hasLoaded && model.comments.isEmpty && !model.isRemoved }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if model.isLoading && !model.hasLoaded {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                    }
                    if isEmpty {
                        DSEmptyState(
                            icon: "TablerMessageCircle",
                            title: "No comments yet",
                            message: "Be the first to say something about this look."
                        )
                        .frame(minHeight: 360)
                    }
                    ForEach(model.comments) { comment in
                        commentRow(comment)
                        if comment.id != model.comments.last?.id {
                            Divider().overlay(DSColor.divider).padding(.leading, 52)
                        }
                    }
                    if model.comments.count == 50 {
                        Text("Showing the latest 50 comments")
                            .font(DSFont.search).foregroundStyle(DSColor.textMuted)
                            .padding(.top, DSSpacing.md)
                    }
                    if let error = model.errorMessage {
                        Text(error).font(DSFont.search).foregroundStyle(DSColor.textMuted)
                            .accessibilityIdentifier("comments.error")
                            .padding(.top, DSSpacing.md)
                        if !model.isRemoved {
                            Button("Refresh comments") { Task { await model.load() } }
                                .buttonStyle(.ds(.secondary))
                                .disabled(model.isLoading || model.isSending)
                                .padding(.top, DSSpacing.sm)
                        }
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.top, DSSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .refreshable { await model.load() }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !model.isRemoved { composer }
            }
            .foregroundStyle(DSColor.textPrimary)
            .background(DSColor.background)
            .navigationTitle(model.comments.isEmpty ? "Comments" : "Comments · \(model.comments.count)")
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

    private func commentRow(_ comment: PostComment) -> some View {
        let isYou = comment.authorId == model.currentUserId
        return HStack(alignment: .top, spacing: DSSpacing.md) {
            Text(isYou ? "Y" : "M")
                .font(DSFont.button)
                .foregroundStyle(isYou ? Color.white : DSColor.iconMuted)
                .frame(width: 40, height: 40)
                .background(Circle().fill(isYou ? DSColor.brand : DSColor.tile))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.sm) {
                    Text(isYou ? "You" : "Member").font(DSFont.bodyEmphasis)
                    Text(comment.createdAt, style: .relative)
                        .font(DSFont.search).foregroundStyle(DSColor.textMuted)
                }
                Text(comment.text).font(DSFont.body).textSelection(.enabled)
            }
        }
        .padding(.vertical, DSSpacing.md)
        .accessibilityElement(children: .combine)
    }

    private var composer: some View {
        VStack(alignment: .trailing, spacing: DSSpacing.xs) {
            HStack(alignment: .bottom, spacing: DSSpacing.sm) {
                TextField("Add a comment…", text: $model.draft, axis: .vertical)
                    .font(DSFont.body)
                    .lineLimit(1...4)
                    .padding(.horizontal, DSSpacing.md)
                    .frame(minHeight: 50)
                    .background(DSColor.tile, in: RoundedRectangle(cornerRadius: DSRadius.md, style: .continuous))
                    .disabled(model.isSending || model.hasPendingSubmission)
                    .accessibilityIdentifier("comments.input")
                Button {
                    Task { await model.send() }
                } label: {
                    if model.isSending {
                        ProgressView().tint(.white)
                    } else if model.hasPendingSubmission {
                        Text("Retry")
                    } else {
                        DSIcon("TablerArrowUp", size: 24)
                    }
                }
                .buttonStyle(.ds(.primary))
                .opacity(model.canSend || model.isSending ? 1 : 0.4)
                .disabled(!model.canSend)
                .accessibilityLabel(model.hasPendingSubmission ? "Retry sending comment" : "Send comment")
                .accessibilityIdentifier("comments.send")
            }
            if model.draft.count > 800 {
                Text("\(model.draft.count)/1,000").font(DSFont.search)
                    .foregroundStyle(model.draft.count > 1_000 ? Color.red : DSColor.textMuted)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.md)
        .padding(.bottom, DSSpacing.sm)
        .background(DSColor.background)
        .overlay(alignment: .top) { Divider().overlay(DSColor.divider) }
    }
}
