import Foundation

struct OnDeviceImportRecognitionService: GarmentRecognitionService {
    func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        try await AutomaticImportSuggestions.detect(imageData: imageData, importID: importID)
    }
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
    static func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        // No loopback service or hosted provider, including in Debug.
        // Keep the original processing path as the default until the phone quality/speed gate passes.
        let mode: RecognitionMode = UserDefaults.standard.bool(forKey: "recognition.nativeProcessing")
            ? .nativePixels : .baseline
        let run = try await OnDeviceRecognitionPipeline.run(imageData: imageData, importID: importID, mode: mode)
        var candidates = run.candidates
        guard let root = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedImageInbox.groupId) else { return candidates }
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
