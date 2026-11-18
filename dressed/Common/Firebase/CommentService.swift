import Foundation

enum CommentError: LocalizedError {
    case signedOut, postRemoved, invalidText, conflictingRetry

    var errorDescription: String? {
        switch self {
        case .signedOut: "Sign in to view and send comments."
        case .postRemoved: "This post is no longer available."
        case .invalidText: "Enter a comment of 1–1,000 characters."
        case .conflictingRetry: "This comment could not be retried. Close comments and try again."
        }
    }
}

@MainActor
protocol CommentService {
    var currentUserId: String? { get }
    var isDemo: Bool { get }
    func fetch(postId: String) async throws -> [PostComment]
    func submit(postId: String, id: String, text: String) async throws
}
