import Combine
import FirebaseFirestore
import Foundation

enum UserProfileError: LocalizedError, Equatable {
    case invalidUserId
    case invalidUsername
    case invalidDisplayName

    var errorDescription: String? {
        switch self {
        case .invalidUserId:
            "Invalid user identifier."
        case .invalidUsername:
            "Username must be 2–30 characters using lowercase letters, numbers, periods, or underscores."
        case .invalidDisplayName:
            "Display name must be 1–50 characters."
        }
    }
}

protocol UserProfileFunctions {
    func fetch(userId: String) async throws -> UserProfile?
    func fetch(userIds: [String]) async throws -> [String: UserProfile]
    func upsert(_ profile: UserProfile) async throws
}

struct FirebaseUserProfileFunctions: UserProfileFunctions {
    private let db = Firestore.firestore()

    func fetch(userId: String) async throws -> UserProfile? {
        guard isValidFirestoreDocumentId(userId) else { return nil }
        let document = try await db
            .collection("users")
            .document(userId)
            .getDocument()
        guard document.exists else { return nil }
        return try document.data(as: UserProfile.self)
    }

    func fetch(userIds: [String]) async throws -> [String: UserProfile] {
        let validIds = Array(Set(userIds.filter(isValidFirestoreDocumentId))).sorted()
        guard !validIds.isEmpty else { return [:] }
        let batchSize = 30
        var result: [String: UserProfile] = [:]
        for start in stride(from: 0, to: validIds.count, by: batchSize) {
            let batch = Array(validIds[start..<min(start + batchSize, validIds.count)])
            let snapshot = try await db
                .collection("users")
                .whereField(FieldPath.documentID(), in: batch)
                .getDocuments()
            for document in snapshot.documents {
                if let profile = try? document.data(as: UserProfile.self) {
                    result[profile.id] = profile
                }
            }
        }
        return result
    }

    func upsert(_ profile: UserProfile) async throws {
        guard isValidFirestoreDocumentId(profile.id) else {
            throw UserProfileError.invalidUserId
        }
        let data = try Firestore.Encoder().encode(profile)
        try await db
            .collection("users")
            .document(profile.id)
            .setData(data, merge: false)
    }
}

final class DemoUserProfileFunctions: UserProfileFunctions {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private static let seededProfiles: [String: UserProfile] = {
        let baseDate = Date(timeIntervalSince1970: 1_790_000_000)
        let entries: [(id: String, username: String, displayName: String)] = [
            ("jane", "jane", "Jane"),
            ("alex", "alex", "Alex"),
            ("riley", "riley", "Riley"),
            ("sam", "sam", "Sam"),
            ("jordan", "jordan", "Jordan"),
            ("lee", "lee", "Lee"),
            ("preview_user", "preview_user", "Preview User"),
            ("user38483", "user38483", "User 38483"),
            ("dressed_demo", "dressed_demo", "Dressed Demo")
        ]
        var dict: [String: UserProfile] = [:]
        for entry in entries {
            dict[entry.id] = UserProfile(
                id: entry.id,
                schemaVersion: 1,
                username: entry.username,
                displayName: entry.displayName,
                avatarPath: nil,
                createdAt: baseDate,
                updatedAt: baseDate
            )
        }
        return dict
    }()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetch(userId: String) async throws -> UserProfile? {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(userId) else { return nil }
        if let data = defaults.data(forKey: storageKey(for: userId)),
           let stored = try? decoder.decode(UserProfile.self, from: data) {
            return stored
        }
        return Self.seededProfiles[userId]
    }

    func fetch(userIds: [String]) async throws -> [String: UserProfile] {
        try Task.checkCancellation()
        var result: [String: UserProfile] = [:]
        for userId in Set(userIds) where isValidFirestoreDocumentId(userId) {
            if let profile = try await fetch(userId: userId) {
                result[userId] = profile
            }
        }
        return result
    }

    func upsert(_ profile: UserProfile) async throws {
        try Task.checkCancellation()
        guard isValidFirestoreDocumentId(profile.id) else {
            throw UserProfileError.invalidUserId
        }
        let data = try encoder.encode(profile)
        defaults.set(data, forKey: storageKey(for: profile.id))
    }

    private func storageKey(for userId: String) -> String {
        "demoUserProfile.\(userId)"
    }
}

extension DiscoveryPostSource {
    static var currentUserProfiles: any UserProfileFunctions {
        if isDemo { return DemoUserProfileFunctions() }
        return FirebaseUserProfileFunctions()
    }
}

@MainActor
final class UserProfileStore: ObservableObject {
    @Published private(set) var profiles: [String: UserProfile] = [:]
    private let service: any UserProfileFunctions

    init(service: any UserProfileFunctions) {
        self.service = service
    }

    func profile(for userId: String) -> UserProfile? {
        profiles[userId]
    }

    func handle(for userId: String) -> String {
        if let username = profiles[userId]?.username, !username.isEmpty {
            return "@\(username)"
        }
        return "@\(userId)"
    }

    func displayName(for userId: String) -> String {
        if let name = profiles[userId]?.displayName, !name.isEmpty {
            return name
        }
        return userId
    }

    func loadIfNeeded(userIds: [String]) async {
        let missing = Array(Set(userIds.filter {
            isValidFirestoreDocumentId($0) && profiles[$0] == nil
        }))
        guard !missing.isEmpty else { return }
        do {
            let fetched = try await service.fetch(userIds: missing)
            guard !Task.isCancelled else { return }
            for (id, profile) in fetched {
                profiles[id] = profile
            }
        } catch {
            return
        }
    }

    func ensureOwnProfile(userId: String, accountName: String?) async {
        guard isValidFirestoreDocumentId(userId) else { return }
        do {
            if let existing = try await service.fetch(userId: userId) {
                guard !Task.isCancelled else { return }
                profiles[userId] = existing
                return
            }
            let now = Date()
            let sanitizedDisplayName = Self.sanitizeDisplayName(accountName, fallbackUserId: userId)
            let sanitizedUsername = Self.sanitizeUsername(accountName, fallbackUserId: userId)
            let created = UserProfile(
                id: userId,
                schemaVersion: 1,
                username: sanitizedUsername,
                displayName: sanitizedDisplayName,
                avatarPath: nil,
                createdAt: now,
                updatedAt: now
            )
            try await service.upsert(created)
            guard !Task.isCancelled else { return }
            profiles[userId] = created
        } catch {
            return
        }
    }

    func saveOwnProfile(userId: String, username: String, displayName: String) async throws {
        guard isValidFirestoreDocumentId(userId) else {
            throw UserProfileError.invalidUserId
        }
        let normalizedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard Self.isValidUsername(normalizedUsername) else {
            throw UserProfileError.invalidUsername
        }
        let normalizedDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedDisplayName.isEmpty, normalizedDisplayName.count <= 50 else {
            throw UserProfileError.invalidDisplayName
        }

        let existing: UserProfile?
        if let cached = profiles[userId] {
            existing = cached
        } else {
            let fetched = try? await service.fetch(userId: userId)
            existing = fetched ?? profiles[userId]
        }
        let now = Date()
        let updated = UserProfile(
            id: userId,
            schemaVersion: 1,
            username: normalizedUsername,
            displayName: normalizedDisplayName,
            avatarPath: existing?.avatarPath,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now
        )
        try await service.upsert(updated)
        profiles[userId] = updated
    }

    static func isValidUsername(_ username: String) -> Bool {
        guard username.count >= 2, username.count <= 30 else { return false }
        return username.unicodeScalars.allSatisfy { scalar in
            (scalar >= "a" && scalar <= "z")
                || (scalar >= "0" && scalar <= "9")
                || scalar == "."
                || scalar == "_"
        }
    }

    private static func sanitizeUsername(_ accountName: String?, fallbackUserId: String) -> String {
        let seed = (accountName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? accountName!
            : fallbackUserId
        let filtered = seed.lowercased().unicodeScalars.compactMap { scalar -> Character? in
            if (scalar >= "a" && scalar <= "z")
                || (scalar >= "0" && scalar <= "9")
                || scalar == "."
                || scalar == "_" {
                return Character(scalar)
            }
            if scalar == " " || scalar == "-" {
                return "_"
            }
            return nil
        }
        var candidate = String(filtered.prefix(30))
        if candidate.count < 2 {
            let fallback = fallbackUserId.lowercased().unicodeScalars.compactMap { scalar -> Character? in
                if (scalar >= "a" && scalar <= "z")
                    || (scalar >= "0" && scalar <= "9")
                    || scalar == "."
                    || scalar == "_" {
                    return Character(scalar)
                }
                return nil
            }
            candidate = String(fallback.prefix(30))
        }
        if candidate.count < 2 {
            candidate = "user_\(candidate)"
        }
        return String(candidate.prefix(30))
    }

    private static func sanitizeDisplayName(_ accountName: String?, fallbackUserId: String) -> String {
        let trimmedAccount = accountName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedAccount.isEmpty {
            return String(trimmedAccount.prefix(50))
        }
        let trimmedId = fallbackUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedId.isEmpty {
            return String(trimmedId.prefix(50))
        }
        return "Dressed User"
    }
}
