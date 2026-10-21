import Combine
import Foundation

struct ReviewProductLink: Identifiable {
    let id: String
    let url: URL
    let isShared: Bool
}

enum ProductLinkError: LocalizedError {
    case invalidURL
    case emptyName
    case unavailableStorage

    var errorDescription: String? {
        switch self {
        case .invalidURL: "Enter a public HTTPS product link."
        case .emptyName: "Enter a product name before saving."
        case .unavailableStorage: "Could not save this link on this device. Please try again."
        }
    }
}

enum ProductLinkValidation {
    static func normalize(_ text: String) -> URL? {
        guard text.count <= 4096,
              var parts = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme?.lowercased() == "https",
              let host = parts.host?.lowercased(), !host.isEmpty,
              host != "localhost", !host.hasSuffix(".localhost"),
              !host.hasSuffix(".local"), !host.contains(":"),
              !host.allSatisfy({ $0.isNumber || $0 == "." }),
              parts.user == nil, parts.password == nil,
              parts.port == nil || parts.port == 443 else { return nil }
        parts.scheme = "https"
        parts.host = host
        parts.fragment = nil
        if parts.port == 443 { parts.port = nil }
        return parts.url
    }
}

@MainActor
final class ProductLinkStore: ObservableObject {
    @Published private(set) var links: [SavedProductLink] = []
    @Published private(set) var error: String?

    private let ownerId: String
    private let file: URL

    init(ownerId: String) {
        self.ownerId = ownerId
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = root.appendingPathComponent("ProductLinks", isDirectory: true)
            .appendingPathComponent(ownerId, isDirectory: true)
            .appendingPathComponent("links.json")
        reload()
    }

    func reload() {
        do {
            guard FileManager.default.fileExists(atPath: file.path) else {
                links = []
                error = nil
                return
            }
            links = try JSONDecoder().decode([SavedProductLink].self, from: Data(contentsOf: file))
                .filter { $0.ownerId == ownerId && ProductLinkValidation.normalize($0.productURL.absoluteString) != nil }
                .sorted { $0.createdAt > $1.createdAt }
            error = nil
        } catch {
            self.error = ProductLinkError.unavailableStorage.localizedDescription
        }
    }

    func save(_ review: ReviewProductLink, name: String, category: ClothingCategory) throws {
        guard error == nil else { throw ProductLinkError.unavailableStorage }
        guard let url = ProductLinkValidation.normalize(review.url.absoluteString) else {
            throw ProductLinkError.invalidURL
        }
        let title = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { throw ProductLinkError.emptyName }
        let old = links.first { $0.productURL == url }
        let item = SavedProductLink(id: old?.id ?? review.id, ownerId: ownerId,
                                    name: title, category: category, productURL: url,
                                    createdAt: old?.createdAt ?? Date())
        let updated = [item] + links.filter { $0.id != item.id && $0.productURL != url }
        try persist(updated)
        links = updated
        error = nil
    }

    func delete(id: String) throws {
        let updated = links.filter { $0.id != id }
        try persist(updated)
        links = updated
    }

    private func persist(_ records: [SavedProductLink]) throws {
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: file, options: .atomic)
        } catch {
            throw ProductLinkError.unavailableStorage
        }
    }
}

private struct SharedLinkEnvelope: Decodable {
    let id: String
    let ownerId: String
    let createdAt: Date
    let productURL: URL
}

enum SharedProductLinkInbox {
    enum Next {
        case link(ReviewProductLink)
        case discarded(String)
        case none
    }

    static func next(for ownerId: String) -> Next {
        guard let root = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedImageInbox.groupId
        ) else { return .none }
        let directory = root.appendingPathComponent("Links", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ).filter({ $0.pathExtension == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) else {
            return .none
        }
        for file in files {
            guard let data = try? Data(contentsOf: file),
                  let record = try? JSONDecoder().decode(SharedLinkEnvelope.self, from: data),
                  record.id == file.deletingPathExtension().lastPathComponent,
                  UUID(uuidString: record.id) != nil else {
                try? FileManager.default.removeItem(at: file)
                return .discarded("A shared product link could not be read. Share it again.")
            }
            let age = Date().timeIntervalSince(record.createdAt)
            if age < -60 || age >= 24 * 60 * 60 {
                remove(id: record.id)
                continue
            }
            guard record.ownerId == ownerId else { continue }
            guard let url = ProductLinkValidation.normalize(record.productURL.absoluteString) else {
                remove(id: record.id)
                return .discarded("This shared product link is invalid. Share it again.")
            }
            return .link(ReviewProductLink(id: record.id, url: url, isShared: true))
        }
        return .none
    }

    static func remove(id: String) {
        guard UUID(uuidString: id) != nil,
              let root = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: SharedImageInbox.groupId
              ) else { return }
        try? FileManager.default.removeItem(at: root.appendingPathComponent("Links/\(id).json"))
    }
}
