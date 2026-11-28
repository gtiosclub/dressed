import Foundation

@MainActor
private final class FailingComments: CommentService {
    let currentUserId: String? = "alice"
    let isDemo = false
    var records: [PostComment] = []
    var submittedIDs: [String] = []
    var loseFirstAcknowledgement = true
    var failFetch = false
    var removed = false

    func fetch(postId: String) async throws -> [PostComment] {
        if removed { throw CommentError.postRemoved }
        if failFetch { throw URLError(.notConnectedToInternet) }
        return records
    }

    func submit(postId: String, id: String, text: String) async throws {
        submittedIDs.append(id)
        if !records.contains(where: { $0.id == id }) {
            records.append(PostComment(id: id, authorId: "alice", text: text, createdAt: .now))
        }
        if loseFirstAcknowledgement {
            loseFirstAcknowledgement = false
            throw URLError(.networkConnectionLost)
        }
    }
}

@main
struct CommentsViewModelChecks {
    @MainActor
    static func main() async {
        let service = FailingComments()
        let model = CommentsViewModel(postId: "post", service: service)
        assert(!model.canSend)
        await model.load()
        model.draft = " \n "
        assert(!model.canSend)
        model.draft = String(repeating: "a", count: 1001)
        assert(!model.canSend)
        model.draft = "  Nice fit  "
        await model.send()
        assert(model.errorMessage != nil && model.hasPendingSubmission)
        assert(model.draft == "  Nice fit  ")
        await model.send()
        assert(service.submittedIDs.count == 2 && Set(service.submittedIDs).count == 1)
        assert(model.comments.count == 1 && model.comments[0].text == "Nice fit")
        assert(model.draft.isEmpty && !model.hasPendingSubmission)

        service.failFetch = true
        model.draft = "Second"
        await model.send()
        assert(model.draft.isEmpty && !model.hasPendingSubmission && model.errorMessage != nil)
        service.failFetch = false
        await model.load()
        assert(model.comments.count == 2 && service.submittedIDs.count == 3)

        service.removed = true
        await model.load()
        assert(model.isRemoved && model.comments.isEmpty && !model.canSend)
        print("CommentsViewModel: validation, stable retry, failed refresh and removed post checks passed")
    }
}
