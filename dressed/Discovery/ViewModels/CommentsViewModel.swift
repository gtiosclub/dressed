import Combine
import Foundation

@MainActor
final class CommentsViewModel: ObservableObject {
    @Published private(set) var comments: [PostComment] = []
    @Published var draft = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isSending = false
    @Published private(set) var hasLoaded = false
    @Published private(set) var isRemoved = false
    @Published private(set) var errorMessage: String?
    private var pending: (id: String, text: String)?
    private let postId: String
    private let service: any CommentService

    init(postId: String, service: any CommentService) {
        self.postId = postId
        self.service = service
    }

    var isDemo: Bool { service.isDemo }
    var currentUserId: String? { service.currentUserId }
    var hasPendingSubmission: Bool { pending != nil }
    var canSend: Bool {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return hasLoaded && !isLoading && !isSending && !isRemoved && currentUserId != nil
            && !text.isEmpty && text.count <= 1_000
    }

    func load() async {
        guard !isLoading, !isSending, !isRemoved else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let fetched = try await service.fetch(postId: postId)
            try Task.checkCancellation()
            comments = fetched
            hasLoaded = true
        } catch {
            handle(error)
        }
    }

    func send() async {
        guard canSend else { return }
        if pending == nil {
            pending = (UUID().uuidString, draft.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard let submission = pending else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            try await service.submit(postId: postId, id: submission.id, text: submission.text)
            try Task.checkCancellation()
            pending = nil
            draft = ""
            // A successful write is distinct from a failed refresh. Never offer
            // to resubmit an already acknowledged comment after a read failure.
            let fetched = try await service.fetch(postId: postId)
            try Task.checkCancellation()
            comments = fetched
        } catch {
            handle(error)
        }
    }

    func delete(commentId: String) async {
        errorMessage = nil
        do {
            try await service.delete(postId: postId, commentId: commentId)
            try Task.checkCancellation()
            comments.removeAll { $0.id == commentId }
        } catch {
            handle(error)
        }
    }

    private func handle(_ error: Error) {
        guard !Task.isCancelled, !(error is CancellationError) else { return }
        if case CommentError.postRemoved = error {
            isRemoved = true
            comments = []
        }
        errorMessage = error.localizedDescription
    }
}
