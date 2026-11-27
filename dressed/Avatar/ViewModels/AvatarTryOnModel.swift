import Combine
import Foundation
import UIKit

/// Coordinates the generated try-on look: the reference photo, the cache and the generator.
/// Views read `phase`, `lookImage` and `lookPieces`; the closet supplies piece photos.
final class AvatarTryOnModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case generating
        case ready
        case failed(String)
    }

    static let maxPieces = 6

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var lookImage: UIImage?
    /// The pieces in the current or in-progress look, in layer order.
    @Published private(set) var lookPieces: [ClothingItem] = []
    @Published private(set) var referenceImage: UIImage?
    @Published private(set) var isSavingReference = false
    @Published var settingsError: String?

    private let store: AvatarMediaStore?
    private let generator: any AvatarImageGenerating
    private var task: Task<Void, Never>?
    /// The last try-on request, kept for Retry and for starting it once a reference photo is added.
    private var lastRequest: (worn: [ClothingItem], pieceImage: (ClothingItem) -> UIImage?)?

    /// `ownerId` nil is for previews, which must not read or write anyone's photos.
    init(ownerId: String?, generator: any AvatarImageGenerating = AvatarImageGenerators.current(),
         baseDirectory: URL? = nil) {
        store = ownerId.map { AvatarMediaStore(ownerId: $0, baseDirectory: baseDirectory) }
        self.generator = generator
        referenceImage = store?.referenceData().flatMap(UIImage.init(data:))
    }

    var hasReference: Bool { referenceImage != nil }

    /// True when `worn` is exactly the look on screen (or being generated).
    func isShowing(_ worn: [ClothingCategory: ClothingItem]) -> Bool {
        Set(worn.values.map(\.id)) == Set(lookPieces.map(\.id)) && phase != .idle
    }

    // MARK: Generation

    /// Shows the cached look for these pieces, or generates one. A new call cancels the one in progress.
    func generate(worn: [ClothingCategory: ClothingItem], pieceImage: @escaping (ClothingItem) -> UIImage?,
                  force: Bool = false) {
        let items = Self.ordered(worn)
        lastRequest = (items, pieceImage)
        task?.cancel()
        guard !items.isEmpty else {
            phase = .failed("Pick at least one piece to try on.")
            return
        }
        lookPieces = items
        guard let store, let reference = store.referenceData() else {
            // The view asks for a photo; `saveReference` resumes this request.
            lookImage = nil
            phase = .idle
            return
        }

        let photos = items.map { pieceImage($0) }
        task = Task { [weak self, generator] in
            let request = await Task.detached(priority: .userInitiated) {
                Self.prepare(reference: reference, items: items, photos: photos)
            }.value
            guard let self, !Task.isCancelled else { return }
            guard let request else {
                phase = .failed("These pieces have no photos to try on.")
                return
            }
            if !force, let cached = store.cachedLook(key: request.key), let image = UIImage(data: cached) {
                lookImage = image
                phase = .ready
                return
            }
            lookImage = nil
            phase = .generating
            do {
                let data = try await generator.generate(request.request)
                guard !Task.isCancelled else { return }
                guard let image = UIImage(data: data) else {
                    phase = .failed("The look couldn't be generated. Try again.")
                    return
                }
                try? store.storeLook(data, key: request.key)
                lookImage = image
                phase = .ready
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error.localizedDescription)
            }
        }
    }

    func retry(force: Bool = false) {
        guard let lastRequest else { return }
        var worn: [ClothingCategory: ClothingItem] = [:]
        for item in lastRequest.worn { worn[item.category] = item }
        generate(worn: worn, pieceImage: lastRequest.pieceImage, force: force)
    }

    func cancel() {
        task?.cancel()
        task = nil
        if phase == .generating { phase = .idle }
    }

    // MARK: Reference photo

    func saveReference(_ data: Data) async {
        guard let store else { return }
        isSavingReference = true
        defer { isSavingReference = false }
        do {
            let saved = try await Task.detached(priority: .userInitiated) { try store.saveReference(data) }.value
            referenceImage = UIImage(data: saved)
            settingsError = nil
            // A new photo invalidates the look on screen; regenerate the pending request.
            lookImage = nil
            phase = .idle
            if lastRequest != nil { retry() }
        } catch {
            settingsError = error.localizedDescription
        }
    }

    func removeReference() {
        task?.cancel()
        do {
            try store?.removeReference()
            referenceImage = nil
            lookImage = nil
            phase = .idle
        } catch {
            settingsError = "Your photo could not be removed: \(error.localizedDescription)"
        }
    }

    // MARK: Helpers

    /// Back-to-front layer order first, then accessories and other pieces; at most `maxPieces`.
    nonisolated static func ordered(_ worn: [ClothingCategory: ClothingItem]) -> [ClothingItem] {
        let order = ClothingCategory.layerOrder + [.accessories, .other]
        return Array(order.compactMap { worn[$0] }.prefix(maxPieces))
    }

    nonisolated static func label(for item: ClothingItem) -> String {
        let kind = switch item.category {
        case .tops: "top"
        case .pants: "pants"
        case .skirts: "skirt"
        case .dresses: "dress"
        case .shoes: "shoes"
        case .outerwear: "jacket, worn over the top"
        case .accessories: "accessory"
        case .other: "garment"
        }
        return "\(item.name) (\(kind))"
    }

    private nonisolated static func prepare(reference: Data, items: [ClothingItem],
                                            photos: [UIImage?]) -> (request: AvatarGenerationRequest, key: String)? {
        var pieces: [AvatarGenerationRequest.Piece] = []
        var keyed: [(id: String, image: Data)] = []
        for (item, photo) in zip(items, photos) {
            guard let photo, let data = AvatarMediaStore.downscaledPNG(photo, maxSide: 768) else { continue }
            pieces.append(.init(image: data, label: label(for: item)))
            keyed.append((item.id, data))
        }
        guard !pieces.isEmpty else { return nil }
        return (AvatarGenerationRequest(reference: reference, pieces: pieces),
                AvatarMediaStore.cacheKey(reference: reference, pieces: keyed))
    }

    #if DEBUG
    /// UI tests: `-avatarReferenceFixture` saves a plain rendered reference photo for this owner,
    /// `-avatarReferencePath <file>` saves a photo from a path the simulator can read, and
    /// `-avatarNoReference` removes the saved one.
    static func applyDebugLaunchArguments(ownerId: String) {
        let arguments = ProcessInfo.processInfo.arguments
        let store = AvatarMediaStore(ownerId: ownerId)
        if arguments.contains("-avatarNoReference") {
            try? store.removeReference()
        } else if let index = arguments.firstIndex(of: "-avatarReferencePath"), index + 1 < arguments.count,
                  let data = FileManager.default.contents(atPath: arguments[index + 1]) {
            // Simulator only: reads a consented test photo from the Mac without adding it to the repo.
            try? store.saveReference(data)
        } else if arguments.contains("-avatarReferenceFixture") {
            let size = CGSize(width: 300, height: 600)
            let photo = UIGraphicsImageRenderer(size: size).image { context in
                UIColor(white: 0.9, alpha: 1).setFill()
                context.fill(CGRect(origin: .zero, size: size))
                UIColor(white: 0.6, alpha: 1).setFill()
                context.cgContext.fillEllipse(in: CGRect(x: 110, y: 30, width: 80, height: 100))
                context.fill(CGRect(x: 90, y: 140, width: 120, height: 420))
            }
            if let data = photo.jpegData(compressionQuality: 0.9) { try? store.saveReference(data) }
        }
    }
    #endif
}
