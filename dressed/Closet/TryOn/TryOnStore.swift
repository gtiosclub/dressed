import CoreGraphics
import Foundation

struct TryOnLibrarySnapshot: Equatable {
    var root: URL
    var avatar: TryOnAvatar?
    var garments: [TryOnGarmentAsset]
    var outfits: [TryOnOutfit]
    var draft: TryOnOutfit?
}

actor TryOnLibrary {
    let root: URL

    init(ownerId: String) {
        let trimmed = ownerId.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.isEmpty ? "local" : trimmed.replacingOccurrences(of: "/", with: "_")
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PrototypeCloset", isDirectory: true)
            .appendingPathComponent(safe, isDirectory: true)
            .appendingPathComponent("tryon", isDirectory: true)
    }

    func snapshot() -> TryOnLibrarySnapshot {
        TryOnLibrarySnapshot(
            root: root,
            avatar: loadCurrentAvatar(),
            garments: loadGarments(),
            outfits: loadOutfits(),
            draft: decode(TryOnOutfit.self, relative: "draft.json")
        )
    }

    func saveAvatar(_ avatar: TryOnAvatar, image: CGImage, silhouette: CGImage?) throws -> TryOnAvatar {
        var stored = avatar
        let directory = "avatars/\(avatar.id)"
        stored.canonicalImagePath = try write(image, "\(directory)/canonical.png")
        stored.layers.bodyBasePath = stored.canonicalImagePath
        if let silhouette {
            stored.fittingMap.masks.silhouettePath = try write(silhouette, "\(directory)/silhouette.png")
        }
        try writeJSON(stored, "\(directory)/avatar.json")
        try write(Data(avatar.id.utf8), "current-avatar-id.txt")
        return stored
    }

    func saveOriginalIfNeeded(garmentID: String, image: CGImage) throws -> String {
        let relative = "garments/\(garmentID)/original.png"
        if FileManager.default.fileExists(atPath: url(relative).path) { return relative }
        return try write(image, relative)
    }

    func saveMesh(_ mesh: TryOnMesh, garmentID: String) throws -> String {
        let relative = "garments/\(garmentID)/mesh.json"
        try writeJSON(mesh, relative)
        return relative
    }

    func loadMesh(relative: String) -> TryOnMesh? {
        decode(TryOnMesh.self, relative: relative)
    }

    func saveGarment(
        _ asset: TryOnGarmentAsset,
        fitted: CGImage?,
        mask: CGImage?,
        components: [TryOnComponentImage]
    ) throws -> TryOnGarmentAsset {
        var stored = asset
        let directory = "garments/\(asset.id)"
        if let fitted {
            stored.fittedReferencePath = try write(fitted, "\(directory)/fitted.png")
        }
        if let mask {
            stored.occlusionPath = try write(mask, "\(directory)/alpha.png")
        }
        var savedComponents: [TryOnGarmentComponent] = []
        for component in components {
            let imagePath = try write(component.image, "\(directory)/\(component.id).png")
            let maskPath = TryOnBitmap.mask(from: component.image).flatMap { image in
                try? write(image, "\(directory)/\(component.id)-mask.png")
            }
            savedComponents.append(TryOnGarmentComponent(
                id: component.id,
                kind: component.kind,
                imagePath: imagePath,
                alphaMaskPath: maskPath,
                canvas: TryOnCanvas.canonical,
                depthGroup: component.depthGroup,
                defaultRenderOrder: component.renderOrder
            ))
        }
        if !savedComponents.isEmpty {
            stored.components = savedComponents
        }
        stored.updatedAt = Date()
        try writeJSON(stored, "\(directory)/asset.json")
        return stored
    }

    func saveAttempt(_ image: CGImage, garmentID: String, attempt: Int) throws -> String {
        try write(image, "garments/\(garmentID)/attempts/\(attempt).png")
    }

    func saveDraft(_ outfit: TryOnOutfit) throws {
        try writeJSON(outfit, "draft.json")
    }

    func saveOutfit(_ outfit: TryOnOutfit) throws {
        try writeJSON(outfit, "outfits/\(outfit.id).json")
    }

    func saveOutfitComposite(_ image: CGImage, outfitID: String) throws -> String {
        let relative = "outfits/\(outfitID)/composite.png"
        _ = try write(image, relative)
        return relative
    }

    func deleteOutfit(id: String) throws {
        try FileManager.default.removeItem(at: url("outfits/\(id).json"))
    }

    func exportURL(hash: String, pose: TryOnPose) -> URL {
        url("exports/\(hash)/\(pose.rawValue).png")
    }

    func saveExport(_ image: CGImage, hash: String, pose: TryOnPose) throws -> URL {
        let relative = "exports/\(hash)/\(pose.rawValue).png"
        _ = try write(image, relative)
        return url(relative)
    }

    private func loadCurrentAvatar() -> TryOnAvatar? {
        guard let data = try? Data(contentsOf: url("current-avatar-id.txt")),
              let id = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty else { return nil }
        return decode(TryOnAvatar.self, relative: "avatars/\(id)/avatar.json")
    }

    private func loadGarments() -> [TryOnGarmentAsset] {
        let directory = url("garments")
        guard let folders = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return folders.compactMap { decode(TryOnGarmentAsset.self, relative: "garments/\($0.lastPathComponent)/asset.json") }
    }

    private func loadOutfits() -> [TryOnOutfit] {
        let directory = url("outfits")
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        return files.compactMap { decode(TryOnOutfit.self, relative: "outfits/\($0.lastPathComponent)") }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private func write(_ image: CGImage, _ relative: String) throws -> String {
        guard let data = TryOnBitmap.pngData(from: image) else {
            throw TryOnStoreError.unreadableImage
        }
        try write(data, relative)
        return relative
    }

    private func writeJSON<T: Encodable>(_ value: T, _ relative: String) throws {
        try write(try TryOnCoding.encoder.encode(value), relative)
    }

    private func write(_ data: Data, _ relative: String) throws {
        let destination = url(relative)
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: destination, options: .atomic)
    }

    private func decode<T: Decodable>(_ type: T.Type, relative: String) -> T? {
        guard let data = try? Data(contentsOf: url(relative)) else { return nil }
        return try? TryOnCoding.decoder.decode(type, from: data)
    }

    private func url(_ relative: String) -> URL {
        root.appendingPathComponent(relative)
    }
}

enum TryOnStoreError: LocalizedError {
    case unreadableImage

    var errorDescription: String? {
        switch self {
        case .unreadableImage: return "An image could not be saved."
        }
    }
}
