import Combine
import PhotosUI
import SwiftUI
import UIKit

@MainActor
protocol PostCompositionSource {
    func load() throws -> (items: [ClothingItem], outfits: [Outfit])
    func image(for item: ClothingItem) throws -> UIImage
}

/// The composer only receives the signed-in owner's local closet. Nothing is uploaded while tagging.
@MainActor
struct LocalPostCompositionSource: PostCompositionSource {
    let ownerId: String
    let closet: PrototypeClosetStore
    let outfits: PrototypeOutfitStore

    func load() throws -> (items: [ClothingItem], outfits: [Outfit]) {
        guard closet.belongs(to: ownerId), outfits.belongs(to: ownerId),
              closet.error == nil, outfits.error == nil else { throw PrototypeImportError.unavailableStorage }
        return (closet.items, outfits.outfits)
    }

    func image(for item: ClothingItem) throws -> UIImage {
        guard item.ownerId == ownerId, closet.item(id: item.id) != nil,
              let image = closet.image(for: item) else { throw PrototypeImportError.missingItem }
        return image
    }
}

/// Re-renders pixels to strip source metadata/orientation and bound public upload sizes.
@MainActor
enum PostPhotoEncoding {
    static func jpeg(_ image: UIImage, maxDimension: CGFloat = 1_600) throws -> Data {
        guard image.size.width > 0, image.size.height > 0 else { throw PrototypeImportError.invalidImage }
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = rendered.jpegData(compressionQuality: 0.85), data.count <= 10 * 1024 * 1024 else {
            throw PrototypeImportError.invalidImage
        }
        return data
    }
}

@MainActor
final class PostComposerModel: ObservableObject {
    @Published var caption = ""
    @Published private(set) var photo: UIImage?
    @Published private(set) var items: [ClothingItem] = []
    @Published private(set) var outfits: [Outfit] = []
    @Published private(set) var selectedIds: [String] = []
    @Published private(set) var outfitName: String?
    @Published private(set) var error: String?
    @Published private(set) var isSharing = false
    @Published private(set) var isLoadingPhoto = false
    @Published private(set) var pendingDraft: PostPublicationDraft?
    private let source: (any PostCompositionSource)?
    private var thumbnails: [String: UIImage] = [:]
    private var photoRequest = UUID()
    private var loaded = false

    init(source: (any PostCompositionSource)? = nil) { self.source = source }

    // Avoid the isolated-deinit back-deployment runtime path on older simulators.
    nonisolated deinit {}

    var isLocked: Bool { isSharing || pendingDraft != nil }
    var canSubmit: Bool {
        !isSharing && !isLoadingPhoto && photo != nil && !selectedIds.isEmpty && caption.count <= 500
    }

    func load() {
        guard !loaded else { return }
        loaded = true
        do {
            if let source { (items, outfits) = try source.load() }
        } catch { self.error = error.localizedDescription }
    }

    func thumbnail(for item: ClothingItem) -> UIImage? {
        if let image = thumbnails[item.id] { return image }
        guard let source, let image = try? source.image(for: item),
              let data = try? PostPhotoEncoding.jpeg(image, maxDimension: 160) else { return nil }
        let thumbnail = UIImage(data: data)
        thumbnails[item.id] = thumbnail
        return thumbnail
    }

    func loadPhoto(_ selection: PhotosPickerItem?) async {
        guard !isLocked, let selection else { return }
        let request = UUID()
        photoRequest = request
        isLoadingPhoto = true
        photo = nil
        error = nil
        defer { if photoRequest == request { isLoadingPhoto = false } }
        do {
            guard let data = try await selection.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { throw PrototypeImportError.invalidImage }
            try Task.checkCancellation()
            guard photoRequest == request else { return }
            try selectPhoto(image)
        } catch {
            guard photoRequest == request, !Task.isCancelled else { return }
            self.error = "Could not open that photo. Please choose another."
        }
    }

    func selectPhoto(_ image: UIImage) throws {
        guard !isLocked else { return }
        photo = UIImage(data: try PostPhotoEncoding.jpeg(image))
    }

    func toggle(_ item: ClothingItem) {
        guard !isLocked else { return }
        error = nil
        if selectedIds.contains(item.id) { selectedIds.removeAll { $0 == item.id } } else {
            guard selectedIds.count < 10 else { error = "Tag up to 10 pieces."; return }
            selectedIds.append(item.id)
        }
        outfitName = nil
    }

    func select(_ outfit: Outfit) {
        guard !isLocked else { return }
        let ids = outfit.placements.sorted { $0.layer < $1.layer }.map(\.itemId)
        guard !ids.isEmpty, ids.count <= 10, Set(ids).count == ids.count,
              ids.allSatisfy({ id in items.contains { $0.id == id } }) else {
            error = "This outfit contains missing pieces or too many items. Edit it in My Closet first."
            return
        }
        selectedIds = ids
        outfitName = outfit.name
        error = nil
    }

    func submit(onShare: (PostPublicationDraft) async throws -> Void) async {
        guard canSubmit else { return }
        isSharing = true
        error = nil
        defer { isSharing = false }
        do {
            if pendingDraft == nil {
                guard let source, let photo else { throw PostPublishingError.invalidDraft }
                let selected = try selectedIds.map { id -> PostPublicationItem in
                    guard let item = items.first(where: { $0.id == id }) else { throw PrototypeImportError.missingItem }
                    return PostPublicationItem(id: id, name: item.name, category: item.category,
                                               photo: try PostPhotoEncoding.jpeg(source.image(for: item), maxDimension: 800))
                }
                pendingDraft = PostPublicationDraft(caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                                                     photo: try PostPhotoEncoding.jpeg(photo), outfitName: outfitName, items: selected)
            }
            guard let pendingDraft else { return }
            try await onShare(pendingDraft)
        } catch is CancellationError {
            error = "Sharing was cancelled. Retry to check whether it was saved."
        } catch {
            self.error = error.localizedDescription
        }
    }
}
