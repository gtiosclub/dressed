import Foundation

/// App Group storage for the prototype import inbox and share extension.
/// Falls back to app-local Application Support when the group container is unavailable
/// (unsigned simulator builds, Personal Team without the entitlement).
enum AppGroupContainer {
    static let groupId = "group.gtiosclub.dressed"

    private static let activeOwnerKey = "activeOwnerId"
    private static let localActiveOwnerKey = "prototypeImport.activeOwnerId"
    private static let localStorageFolder = "PrototypeImportInbox"

    /// `true` when the process can read and write the shared app group container.
    static var isAvailable: Bool {
        containerURL != nil
    }

    /// Security-scoped app group URL; `nil` without a matching entitlement and signing.
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupId)
    }

    /// Suite defaults only when the group container exists (avoids CFPrefs console noise).
    static var sharedUserDefaults: UserDefaults? {
        guard containerURL != nil else { return nil }
        return UserDefaults(suiteName: groupId)
    }

    /// App group root, or a private inbox directory when the group is unavailable.
    static var storageRoot: URL? {
        if let containerURL {
            return containerURL
        }
        guard let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let root = support.appendingPathComponent(localStorageFolder, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return root
    }

    static func setActiveOwner(_ ownerId: String?) {
        if let sharedUserDefaults {
            if let ownerId {
                sharedUserDefaults.set(ownerId, forKey: activeOwnerKey)
            } else {
                sharedUserDefaults.removeObject(forKey: activeOwnerKey)
            }
        }
        if let ownerId {
            UserDefaults.standard.set(ownerId, forKey: localActiveOwnerKey)
        } else {
            UserDefaults.standard.removeObject(forKey: localActiveOwnerKey)
        }
    }

    static func activeOwnerId() -> String? {
        if let id = sharedUserDefaults?.string(forKey: activeOwnerKey), !id.isEmpty {
            return id
        }
        if let id = UserDefaults.standard.string(forKey: localActiveOwnerKey), !id.isEmpty {
            return id
        }
        return nil
    }
}