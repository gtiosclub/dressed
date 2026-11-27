import CryptoKit
import Foundation
import UIKit

/// Keeps one account's avatar media on this device, next to its closet: the full-body reference photo
/// and the generated try-on images. Nothing here is uploaded to Firebase; the reference photo leaves the
/// device only when the owner generates a look.
nonisolated struct AvatarMediaStore {
    /// Bump when the request or prompt changes so older cached looks are not reused.
    static let cacheVersion = 2 // 2: stylized game-avatar prompt (bridge v2)

    let directory: URL

    init(ownerId: String, baseDirectory: URL? = nil) {
        let base = baseDirectory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrototypeCloset", isDirectory: true)
        directory = base.appendingPathComponent(ownerId, isDirectory: true)
    }

    private var referenceURL: URL { directory.appendingPathComponent("avatar-reference.jpg") }
    private var looksDirectory: URL { directory.appendingPathComponent("avatar-looks", isDirectory: true) }

    // MARK: Reference photo

    func referenceData() -> Data? {
        try? Data(contentsOf: referenceURL)
    }

    /// Saves a downscaled JPEG copy and drops cached looks made from the previous photo.
    @discardableResult
    func saveReference(_ original: Data) throws -> Data {
        guard let data = Self.downscaledJPEG(original, maxSide: 1536) else {
            throw AvatarMediaError.unreadablePhoto
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: referenceURL, options: [.atomic, .completeFileProtection])
        try? FileManager.default.removeItem(at: looksDirectory)
        return data
    }

    func removeReference() throws {
        for url in [referenceURL, looksDirectory] where FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    // MARK: Generated looks

    /// Stable for the same photo, pieces and piece images, in any order.
    static func cacheKey(reference: Data, pieces: [(id: String, image: Data)]) -> String {
        var hasher = SHA256()
        hasher.update(data: Data("v\(cacheVersion)|".utf8))
        hasher.update(data: Data(SHA256.hash(data: reference)))
        for piece in pieces.sorted(by: { $0.id < $1.id }) {
            hasher.update(data: Data("|\(piece.id)|".utf8))
            hasher.update(data: Data(SHA256.hash(data: piece.image)))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func cachedLook(key: String) -> Data? {
        try? Data(contentsOf: looksDirectory.appendingPathComponent("\(key).jpg"))
    }

    func storeLook(_ data: Data, key: String) throws {
        try FileManager.default.createDirectory(at: looksDirectory, withIntermediateDirectories: true)
        try data.write(to: looksDirectory.appendingPathComponent("\(key).jpg"), options: [.atomic, .completeFileProtection])
    }

    // MARK: Image preparation

    static func downscaledJPEG(_ data: Data, maxSide: CGFloat, quality: CGFloat = 0.85) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return resized(image, maxSide: maxSide, opaque: true).jpegData(compressionQuality: quality)
    }

    /// PNG keeps a cutout's transparency, which JPEG would turn black.
    static func downscaledPNG(_ image: UIImage, maxSide: CGFloat) -> Data? {
        resized(image, maxSide: maxSide, opaque: false).pngData()
    }

    private static func resized(_ image: UIImage, maxSide: CGFloat, opaque: Bool) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxSide ? maxSide / longest : 1
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            if opaque {
                UIColor.white.setFill()
                UIRectFill(CGRect(origin: .zero, size: size))
            }
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

nonisolated enum AvatarMediaError: LocalizedError {
    case unreadablePhoto

    var errorDescription: String? {
        "That photo could not be read. Try another one."
    }
}
