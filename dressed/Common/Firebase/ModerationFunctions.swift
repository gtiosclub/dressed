import Combine
import FirebaseFirestore
import Foundation

enum ReportTargetType: String, Codable {
    case post
    case comment
    case user
}

enum ModerationError: LocalizedError, Equatable {
    case invalidIdentifier
    case cannotBlockSelf
    case invalidReason

    var errorDescription: String? {
        switch self {
        case .invalidIdentifier:
            "Invalid identifier."
        case .cannotBlockSelf:
            "You cannot block yourself."
        case .invalidReason:
            "Enter a reason of 1–500 characters."
        }
    }
}

protocol ModerationFunctions {
    func fetchBlockedUserIds(ownerId: String) async throws -> Set<String>
    func setBlocked(ownerId: String, targetUserId: String, isBlocked: Bool) async throws
    func submitReport(
        reporterId: String,
        targetType: ReportTargetType,
        targetId: String,
        postId: String?,
        reason: String
    ) async throws
}

struct FirebaseModerationFunctions: ModerationFunctions {
    private let db = Firestore.firestore()

    func fetchBlockedUserIds(ownerId: String) async throws -> Set<String> {
        guard isValidFirestoreDocumentId(ownerId) else {
            throw ModerationError.invalidIdentifier
        }
        let snapshot = try await db
            .collection("users")
            .document(ownerId)
            .collection("blockedUsers")
            .getDocuments(source: .server)
        return Set(snapshot.documents.map(\.documentID))
    }

    func setBlocked(ownerId: String, targetUserId: String, isBlocked: Bool) async throws {
        guard isValidFirestoreDocumentId(ownerId), isValidFirestoreDocumentId(targetUserId) else {
            throw ModerationError.invalidIdentifier
        }
        guard ownerId != targetUserId else {
            throw ModerationError.cannotBlockSelf
        }
        let ref = db
            .collection("users")
            .document(ownerId)
            .collection("blockedUsers")
            .document(targetUserId)
        if isBlocked {
            try await ref.setData([
                "id": targetUserId,
                "schemaVersion": 1,
                "ownerId": ownerId,
                "targetUserId": targetUserId,
                "createdAt": FieldValue.serverTimestamp()
            ])
        } else {
            try await ref.delete()
        }
    }

    func submitReport(
        reporterId: String,
        targetType: ReportTargetType,
        targetId: String,
        postId: String?,
        reason: String
    ) async throws {
        guard isValidFirestoreDocumentId(reporterId), isValidFirestoreDocumentId(targetId) else {
            throw ModerationError.invalidIdentifier
        }
        if let postId, !isValidFirestoreDocumentId(postId) {
            throw ModerationError.invalidIdentifier
        }
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty, trimmedReason.count <= 500 else {
            throw ModerationError.invalidReason
        }

        let reportId = UUID().uuidString
        var payload: [String: Any] = [
            "id": reportId,
            "schemaVersion": 1,
            "reporterId": reporterId,
            "targetType": targetType.rawValue,
            "targetId": targetId,
            "reason": trimmedReason,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let postId {
            payload["postId"] = postId
        }
        try await db
            .collection("reports")
            .document(reportId)
            .setData(payload)
    }
}

final class DemoModerationFunctions: ModerationFunctions {
    struct DemoReport: Equatable {
        let reporterId: String
        let targetType: ReportTargetType
        let targetId: String
        let postId: String?
        let reason: String
    }

    private let defaults: UserDefaults
    private(set) var submittedReports: [DemoReport] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetchBlockedUserIds(ownerId: String) async throws -> Set<String> {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(ownerId) else {
            throw ModerationError.invalidIdentifier
        }
        return Set(defaults.stringArray(forKey: storageKey(ownerId: ownerId)) ?? [])
    }

    func setBlocked(ownerId: String, targetUserId: String, isBlocked: Bool) async throws {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(ownerId), isValidFirestoreDocumentId(targetUserId) else {
            throw ModerationError.invalidIdentifier
        }
        guard ownerId != targetUserId else {
            throw ModerationError.cannotBlockSelf
        }
        var blocked = Set(defaults.stringArray(forKey: storageKey(ownerId: ownerId)) ?? [])
        if isBlocked {
            blocked.insert(targetUserId)
        } else {
            blocked.remove(targetUserId)
        }
        defaults.set(Array(blocked).sorted(), forKey: storageKey(ownerId: ownerId))
    }

    func submitReport(
        reporterId: String,
        targetType: ReportTargetType,
        targetId: String,
        postId: String?,
        reason: String
    ) async throws {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(reporterId), isValidFirestoreDocumentId(targetId) else {
            throw ModerationError.invalidIdentifier
        }
        if let postId, !isValidFirestoreDocumentId(postId) {
            throw ModerationError.invalidIdentifier
        }
        let trimmedReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty, trimmedReason.count <= 500 else {
            throw ModerationError.invalidReason
        }
        submittedReports.append(
            DemoReport(
                reporterId: reporterId,
                targetType: targetType,
                targetId: targetId,
                postId: postId,
                reason: trimmedReason
            )
        )
    }

    private func storageKey(ownerId: String) -> String {
        "demoModeration.blocked.\(ownerId)"
    }
}

extension DiscoveryPostSource {
    static var currentModeration: any ModerationFunctions {
        if isDemo { return DemoModerationFunctions() }
        return FirebaseModerationFunctions()
    }
}

@MainActor
final class ModerationViewModel: ObservableObject {
    @Published private(set) var blockedUserIds: Set<String> = []
    @Published private(set) var errorMessage: String?

    private let ownerId: String
    private let service: any ModerationFunctions

    init(ownerId: String, service: any ModerationFunctions) {
        self.ownerId = ownerId
        self.service = service
    }

    func isBlocked(_ userId: String) -> Bool {
        blockedUserIds.contains(userId)
    }

    func loadBlockedUsers() async {
        errorMessage = nil
        do {
            let ids = try await service.fetchBlockedUserIds(ownerId: ownerId)
            guard !Task.isCancelled else { return }
            blockedUserIds = ids
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func block(userId: String) async {
        guard userId != ownerId, isValidFirestoreDocumentId(userId) else { return }
        errorMessage = nil
        do {
            try await service.setBlocked(ownerId: ownerId, targetUserId: userId, isBlocked: true)
            guard !Task.isCancelled else { return }
            blockedUserIds.insert(userId)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func unblock(userId: String) async {
        guard isValidFirestoreDocumentId(userId) else { return }
        errorMessage = nil
        do {
            try await service.setBlocked(ownerId: ownerId, targetUserId: userId, isBlocked: false)
            guard !Task.isCancelled else { return }
            blockedUserIds.remove(userId)
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func report(
        targetType: ReportTargetType,
        targetId: String,
        postId: String? = nil,
        reason: String
    ) async -> Bool {
        errorMessage = nil
        do {
            try await service.submitReport(
                reporterId: ownerId,
                targetType: targetType,
                targetId: targetId,
                postId: postId,
                reason: reason
            )
            return true
        } catch {
            guard !Task.isCancelled, !(error is CancellationError) else { return false }
            errorMessage = error.localizedDescription
            return false
        }
    }
}
