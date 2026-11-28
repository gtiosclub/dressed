import SwiftUI

struct PostCommentsSheet: View {
    @StateObject private var model: CommentsViewModel
    @ObservedObject private var userProfiles: UserProfileStore
    @ObservedObject private var moderation: ModerationViewModel
    @Environment(\.dismiss) private var dismiss

    private let postId: String
    private let hasProfiles: Bool
    private let moderationEnabled: Bool

    init(
        postId: String,
        service: any CommentService,
        userProfiles: UserProfileStore? = nil,
        moderation: ModerationViewModel? = nil
    ) {
        self.postId = postId
        self.hasProfiles = userProfiles != nil
        self.moderationEnabled = moderation != nil
        _userProfiles = ObservedObject(wrappedValue: userProfiles ?? UserProfileStore(service: DemoUserProfileFunctions()))
        _moderation = ObservedObject(wrappedValue: moderation ?? ModerationViewModel(ownerId: "preview_user", service: DemoModerationFunctions()))
        _model = StateObject(wrappedValue: CommentsViewModel(postId: postId, service: service))
    }

    private var visibleComments: [PostComment] {
        model.comments.filter { !(moderationEnabled && moderation.isBlocked($0.authorId)) }
    }

    private var isEmpty: Bool { model.hasLoaded && visibleComments.isEmpty && !model.isRemoved }

    var body: some View {
        let displayedComments = visibleComments
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
                    ForEach(displayedComments) { comment in
                        commentRow(comment)
                        if comment.id != displayedComments.last?.id {
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
            .navigationTitle(displayedComments.isEmpty ? "Comments" : "Comments · \(displayedComments.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.accessibilityLabel("Close comments")
                }
            }
            .task {
                await model.load()
                if hasProfiles {
                    await userProfiles.loadIfNeeded(userIds: model.comments.map(\.authorId))
                }
            }
            .task(id: model.comments.map(\.authorId)) {
                if hasProfiles {
                    await userProfiles.loadIfNeeded(userIds: model.comments.map(\.authorId))
                }
            }
        }
        .tint(DSColor.brand)
    }

    private func commentRow(_ comment: PostComment) -> some View {
        let isYou = comment.authorId == model.currentUserId
        let authorName = isYou ? "You" : (hasProfiles ? userProfiles.displayName(for: comment.authorId) : "Member")
        let initial = authorName.first.map { String($0).uppercased() } ?? "M"
        let hasMenu = isYou || moderationEnabled
        return HStack(alignment: .top, spacing: DSSpacing.md) {
            Text(initial)
                .font(DSFont.button)
                .foregroundStyle(isYou ? Color.white : DSColor.iconMuted)
                .frame(width: 40, height: 40)
                .background(Circle().fill(isYou ? DSColor.brand : DSColor.tile))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DSSpacing.xs) {
                HStack(spacing: DSSpacing.sm) {
                    Text(authorName).font(DSFont.bodyEmphasis)
                    Text(comment.createdAt, style: .relative)
                        .font(DSFont.search).foregroundStyle(DSColor.textMuted)
                }
                Text(comment.text).font(DSFont.body).textSelection(.enabled)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            if hasMenu {
                DSMoreMenu(accessibilityLabel: "Comment options") {
                    if isYou {
                        Button("Delete", role: .destructive) {
                            Task { await model.delete(commentId: comment.id) }
                        }
                    } else if moderationEnabled {
                        Button("Report comment") {
                            Task {
                                _ = await moderation.report(
                                    targetType: .comment,
                                    targetId: comment.id,
                                    postId: postId,
                                    reason: "Inappropriate comment"
                                )
                            }
                        }
                        Button("Block user", role: .destructive) {
                            Task { await moderation.block(userId: comment.authorId) }
                        }
                    }
                }
            }
        }
        .padding(.vertical, DSSpacing.md)
        .accessibilityElement(children: .contain)
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
                    .foregroundStyle(model.draft.count > 1_000 ? DSColor.destructive : DSColor.textMuted)
            }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.md)
        .padding(.bottom, DSSpacing.sm)
        .background(DSColor.background)
        .overlay(alignment: .top) { Divider().overlay(DSColor.divider) }
    }
}
