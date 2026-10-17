import CryptoKit
import Foundation
import UIKit

enum SharedImportDraftError: LocalizedError {
    case unavailable
    case invalidDraft
    case noSelection
    case invalidCrop

    var errorDescription: String? {
        switch self {
        case .unavailable: "The shared image is unavailable. Please share it again."
        case .invalidDraft: "This import can no longer be resumed. Please share the image again."
        case .noSelection: "Select at least one piece before saving."
        case .invalidCrop: "A selected piece has an invalid image region. Adjust it and try again."
        }
    }
}

enum SharedImportDraftStore {
    static func stableID(importID: String, part: String) -> String {
        let digest = SHA256.hash(data: Data("\(importID):\(part)".utf8))
        let hex = digest.prefix(16).map { String(format: "%02X", $0) }.joined()
        return "\(hex.prefix(8))-\(hex.dropFirst(8).prefix(4))-\(hex.dropFirst(12).prefix(4))-\(hex.dropFirst(16).prefix(4))-\(hex.dropFirst(20).prefix(12))"
    }

    static func loadOrCreate(image: ReviewImage, ownerId: String) throws -> ImportDraft {
        guard image.isShared, UUID(uuidString: image.id) != nil, !ownerId.isEmpty else {
            throw SharedImportDraftError.invalidDraft
        }
        let file = try reviewFile(for: image.id)
        if FileManager.default.fileExists(atPath: file.path) {
            let draft = try JSONDecoder().decode(ImportDraft.self, from: Data(contentsOf: file))
            guard draft.id == image.id, draft.ownerId == ownerId,
                  draft.source.kind == .sharedImage,
                  draft.temporaryImagePath == "Inbox/\(image.id).jpg",
                  draft.expiresAt > Date() else {
                throw SharedImportDraftError.invalidDraft
            }
            return draft
        }
        let now = Date()
        let draft = ImportDraft(
            id: image.id,
            schemaVersion: 1,
            ownerId: ownerId,
            source: ClothingSource(kind: .sharedImage, originalURL: nil, importedAt: now),
            temporaryImagePath: "Inbox/\(image.id).jpg",
            status: .received,
            candidates: [],
            createdAt: now,
            expiresAt: now.addingTimeInterval(24 * 60 * 60)
        )
        try save(draft)
        return draft
    }

    static func save(_ draft: ImportDraft) throws {
        guard UUID(uuidString: draft.id) != nil, !draft.ownerId.isEmpty,
              draft.temporaryImagePath == "Inbox/\(draft.id).jpg",
              draft.candidates.allSatisfy({ candidate in
                  guard UUID(uuidString: candidate.id) != nil,
                        candidate.region?.isValid ?? true else { return false }
                  guard let outline = candidate.outline else { return true }
                  return outline.count >= 3 && outline.allSatisfy(\.isValid)
              }),
              Set(draft.candidates.map(\.id)).count == draft.candidates.count else {
            throw SharedImportDraftError.invalidDraft
        }
        let file = try reviewFile(for: draft.id)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(draft).write(to: file, options: .atomic)
    }

    static func imageData(for candidate: ImportCandidate, in source: Data) throws -> Data {
        guard let image = UIImage(data: source) else { throw SharedImportDraftError.unavailable }
        if let outline = candidate.outline {
            guard outline.count >= 3, outline.allSatisfy(\.isValid) else {
                throw SharedImportDraftError.invalidCrop
            }
            let left = outline.map(\.x).min()!
            let top = outline.map(\.y).min()!
            let right = outline.map(\.x).max()!
            let bottom = outline.map(\.y).max()!
            let width = right - left
            let height = bottom - top
            guard width >= 0.01, height >= 0.01 else { throw SharedImportDraftError.invalidCrop }
            let size = CGSize(width: max(2, ceil(image.size.width * width)),
                              height: max(2, ceil(image.size.height * height)))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            format.opaque = false
            let renderer = UIGraphicsImageRenderer(size: size, format: format)
            return renderer.pngData { context in
                let path = UIBezierPath()
                for (index, point) in outline.enumerated() {
                    let location = CGPoint(x: (point.x - left) / width * size.width,
                                           y: (point.y - top) / height * size.height)
                    if index == 0 { path.move(to: location) } else { path.addLine(to: location) }
                }
                path.close()
                path.addClip()
                image.draw(in: CGRect(x: -left / width * size.width,
                                      y: -top / height * size.height,
                                      width: size.width / width,
                                      height: size.height / height))
            }
        }
        if let path = candidate.temporaryCutoutPath,
           path == "Cutouts/\(candidate.id).png",
           let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedImageInbox.groupId),
           let data = try? Data(contentsOf: root.appendingPathComponent(path)),
           UIImage(data: data) != nil {
            return data
        }
        guard let region = candidate.region else {
            guard let jpeg = image.jpegData(compressionQuality: 0.85) else {
                throw SharedImportDraftError.unavailable
            }
            return jpeg
        }
        guard region.isValid else { throw SharedImportDraftError.invalidCrop }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        let upright = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        guard let pixels = upright.cgImage else { throw SharedImportDraftError.invalidCrop }
        let bounds = CGRect(
            x: region.x * Double(pixels.width),
            y: region.y * Double(pixels.height),
            width: region.width * Double(pixels.width),
            height: region.height * Double(pixels.height)
        ).integral.intersection(CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height))
        guard bounds.width >= 2, bounds.height >= 2,
              let cropped = pixels.cropping(to: bounds),
              let jpeg = UIImage(cgImage: cropped).jpegData(compressionQuality: 0.85) else {
            throw SharedImportDraftError.invalidCrop
        }
        return jpeg
    }

    static func addAutomaticCutouts(to candidates: [ImportCandidate], imageData: Data) async -> [ImportCandidate] {
        var result = candidates
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedImageInbox.groupId) else {
            return result
        }
        let directory = root.appendingPathComponent("Cutouts", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for index in result.indices {
            guard !Task.isCancelled else { break }
            let candidate = result[index]
            guard candidate.outline == nil,
                  candidate.temporaryCutoutPath == nil,
                  let crop = try? Self.imageData(for: candidate, in: imageData),
                  let png = await AutomaticGarmentCutout.png(from: crop) else { continue }
            let path = "Cutouts/\(candidate.id).png"
            do {
                try png.write(to: root.appendingPathComponent(path), options: .atomic)
                result[index].temporaryCutoutPath = path
            } catch {
                // Keep the rectangular crop if the temporary file cannot be written.
            }
        }
        return result
    }

    static func removeAutomaticCutouts(for candidates: [ImportCandidate]) {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedImageInbox.groupId) else {
            return
        }
        for candidate in candidates where candidate.temporaryCutoutPath == "Cutouts/\(candidate.id).png" {
            try? FileManager.default.removeItem(at: root.appendingPathComponent("Cutouts/\(candidate.id).png"))
        }
    }

    private static func reviewFile(for id: String) throws -> URL {
        guard UUID(uuidString: id) != nil,
              let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedImageInbox.groupId) else {
            throw SharedImportDraftError.unavailable
        }
        return root.appendingPathComponent("Reviews", isDirectory: true)
            .appendingPathComponent("\(id).json")
    }
}
