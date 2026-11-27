import Foundation
import Vision

// Body landmarks suggest separate review regions when a worn outfit is visible.
// They are not garment segmentation or product recognition; every result starts unselected.
nonisolated enum OnDeviceGarmentRegions {
    static func detect(imageData: Data, importID: String,
                       images: RecognitionImageSession? = nil,
                       metrics: RecognitionMetrics? = nil) async throws -> [ImportCandidate] {
        let regions = try await RecognitionExecution.offMain {
            try Task.checkCancellation()
            let request: VNDetectHumanBodyPoseRequest
            do {
                let start = ProcessInfo.processInfo.systemUptime
                defer { metrics?.record("body pose", since: start) }
                request = try VisionRequestRunner.perform({ VNDetectHumanBodyPoseRequest() }, on: imageData)
            } catch {
                metrics?.warning("Vision body pose failed; using whole-image fallback.", error: error)
                throw error
            }
            try Task.checkCancellation()
            return GarmentPoseRegions.regions(in: request.results?.first)
        }

        var candidates: [ImportCandidate] = []
        for (part, region) in regions {
            try Task.checkCancellation()
            let defaults: (String, ClothingCategory) = switch part {
            case "upper": ("Top", .tops)
            case "shoes": ("Shoes", .shoes)
            default: ("Bottom", .pants)
            }
            let prototype = ImportCandidate(
                id: SharedImportDraftStore.stableID(importID: importID, part: part),
                name: defaults.0,
                category: defaults.1,
                destination: .closet,
                temporaryCutoutPath: nil,
                region: region,
                suggestionSource: "Body region suggestion",
                selected: false,
                tags: [],
                suggestedTags: []
            )
            let crop = try images?.crop(prototype) ?? SharedImportDraftStore.imageData(for: prototype, in: imageData)
            let suggestion = try? await PrototypeGarmentRecognition.analyze(crop, metrics: metrics)
            try Task.checkCancellation()
            var candidate = prototype
            if let suggestion {
                candidate.name = suggestion.name
                candidate.category = suggestion.category
            }
            candidates.append(candidate)
        }
        return candidates
    }

    /// Bounds of Vision's foreground subjects, used to frame a single product photo.
    /// Returns nil when Vision finds no subject or cannot run (for example on the simulator).
    nonisolated static func foregroundBounds(imageData: Data) -> NormalizedImageRegion? {
        guard let request = try? VisionRequestRunner.perform({ VNGenerateForegroundInstanceMaskRequest() }, on: imageData),
              let observation = request.results?.first else { return nil }
        let mask = observation.instanceMask
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let width = CVPixelBufferGetWidth(mask), height = CVPixelBufferGetHeight(mask)
        let stride = CVPixelBufferGetBytesPerRow(mask)
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            let row = base.advanced(by: y * stride).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width where row[x] != 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY else { return nil }
        let pad = 0.03
        let left = max(0, Double(minX) / Double(width) - pad)
        let top = max(0, Double(minY) / Double(height) - pad)
        let right = min(1, Double(maxX + 1) / Double(width) + pad)
        let bottom = min(1, Double(maxY + 1) / Double(height) + pad)
        let result = NormalizedImageRegion(x: left, y: top, width: right - left, height: bottom - top)
        return result.isValid && result.width >= 0.08 && result.height >= 0.08 ? result : nil
    }
}
