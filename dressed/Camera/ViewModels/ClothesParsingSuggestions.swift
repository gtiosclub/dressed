import CoreML
import Foundation

// Runs the optional clothes-parsing model and saves each piece's cutout with its review draft.
// Without a model (the default build), callers fall back to body-region suggestions.
enum ClothesParsingSuggestions {
    /// The bundled model, or in Debug the one named by `-clothesModelPath <path to .mlpackage>`.
    nonisolated static var modelURL: URL? {
        #if DEBUG
        if let path = UserDefaults.standard.string(forKey: "clothesModelPath"),
           FileManager.default.fileExists(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        #endif
        return Bundle.main.url(forResource: "ClothesParser", withExtension: "mlmodelc")
    }

    /// Nil when there is no model, it fails, or it finds no clothing.
    static func detect(imageData: Data, importID: String) async throws -> [ImportCandidate]? {
        guard let url = modelURL else { return nil }
        let task = Task.detached(priority: .userInitiated) { () throws -> [(ParsedPiece, Data?)] in
            let model = try await ClothesParser.load(modelAt: url)
            try Task.checkCancellation()
            guard let image = GarmentImage.upright(imageData) else { throw ClothesParserError.unreadableImage }
            return try ClothesParser.parse(image, model: model).map { piece in
                try Task.checkCancellation()
                return (piece, GarmentImage.cutout(of: image, mask: piece.mask))
            }
        }
        let found: [(ParsedPiece, Data?)]
        do {
            found = try await withTaskCancellationHandler { try await task.value } onCancel: { task.cancel() }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            print("Clothes parsing failed; using body regions. \(error)")
            return nil
        }
        try Task.checkCancellation()
        guard !found.isEmpty else { return nil }
        return found.map { piece, cutout in
            let id = SharedImportDraftStore.stableID(importID: importID, part: "parsed-\(piece.part)")
            return ImportCandidate(
                id: id, name: piece.name, category: piece.category, destination: .closet,
                temporaryCutoutPath: cutout.flatMap { SharedImportDraftStore.writeCutout($0, for: id) },
                region: piece.region, suggestionSource: "Clothing outline suggestion",
                selected: false, tags: [], suggestedTags: [])
        }
    }
}
