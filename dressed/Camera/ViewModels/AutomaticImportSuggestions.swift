import Foundation
import UIKit

struct OnDeviceImportRecognitionService: GarmentRecognitionService {
    func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        #if DEBUG && targetEnvironment(simulator)
        // The simulator cannot run Apple's body-pose model. When the local Mac bridge is running
        // (local_service.py --apple-vision), use its pieces. UI tests stay on the in-app pipeline.
        if !ProcessInfo.processInfo.arguments.contains("-mockSignedIn"),
           ClothesParsingSuggestions.modelURL == nil,
           let found = try? await LocalGarmentRecognition()
               .detect(imageData: Self.bridgeSized(imageData), importID: importID),
           !found.isEmpty {
            try Task.checkCancellation()
            return await SharedImportDraftStore.addAutomaticCutouts(to: found, imageData: imageData)
        }
        #endif
        return try await AutomaticImportSuggestions.detect(imageData: imageData, importID: importID)
    }

    #if DEBUG && targetEnvironment(simulator)
    /// The bridge accepts 5 MB. Regions are normalized, so a smaller copy gives the same boxes.
    private static func bridgeSized(_ data: Data) -> Data {
        guard data.count > 4_500_000, let image = UIImage(data: data) else { return data }
        let scale = min(1, 2000 / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).jpegData(withCompressionQuality: 0.85) { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
    #endif
}

#if DEBUG
// Used only by the isolated lifecycle XCUITest to guarantee an interruption
// before completion, regardless of simulator speed. Production uses the adapter above.
struct DelayedImportRecognitionTestService: GarmentRecognitionService {
    func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        try await Task.sleep(for: .seconds(45))
        return try await AutomaticImportSuggestions.detect(imageData: imageData, importID: importID)
    }
}
#endif

enum AutomaticImportSuggestions {
    struct ReviewResult {
        var candidates: [ImportCandidate]
        var possibleMissing: [PossibleMissingPiece]
    }

    static func review(imageData: Data, importID: String) async throws -> ReviewResult {
        #if DEBUG
        // Explicit diagnostic opt-in preserves the on-device default from #208.
        if ProcessInfo.processInfo.arguments.contains("-recognitionGapFixture"),
           let outcome = try? await LocalGarmentRecognition().recognize(imageData: imageData, importID: importID) {
            try Task.checkCancellation()
            return ReviewResult(
                candidates: await SharedImportDraftStore.addAutomaticCutouts(to: outcome.candidates, imageData: imageData),
                possibleMissing: outcome.possibleMissing
            )
        }
        #endif
        return ReviewResult(candidates: try await detect(imageData: imageData, importID: importID), possibleMissing: [])
    }

    static func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        // Garment outlines when a parsing model is available; otherwise body regions.
        if let parsed = try await ClothesParsingSuggestions.detect(imageData: imageData, importID: importID) {
            return parsed
        }
        // The default recognition pipeline stays on-device.
        // Keep the original processing path as the default until the phone quality/speed gate passes.
        let mode: RecognitionMode = UserDefaults.standard.bool(forKey: "recognition.nativeProcessing")
            ? .nativePixels : .baseline
        let run = try await OnDeviceRecognitionPipeline.run(imageData: imageData, importID: importID, mode: mode,
                                                            allowsBackgroundFill: false)
        var candidates = run.candidates
        guard let root = AppGroupContainer.storageRoot else { return candidates }
        let directory = root.appendingPathComponent("Cutouts", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var created: [URL] = []
        do {
            for index in candidates.indices {
                try Task.checkCancellation()
                guard let png = run.cutouts[candidates[index].id] else { continue }
                let path = "Cutouts/\(candidates[index].id).png"
                let file = root.appendingPathComponent(path)
                let existed = FileManager.default.fileExists(atPath: file.path)
                try png.write(to: file, options: .atomic)
                if !existed { created.append(file) }
                candidates[index].temporaryCutoutPath = path
            }
        } catch {
            // A failed/cancelled batch must not orphan newly created temporary images.
            // Existing retry files still belong to their persisted draft.
            for file in created { try? FileManager.default.removeItem(at: file) }
            throw error
        }
        return candidates
    }
}
