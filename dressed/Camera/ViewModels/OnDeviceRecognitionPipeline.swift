import Foundation

nonisolated struct RecognitionRunSummary: Codable {
    let mode: RecognitionMode
    let milliseconds: Double
    let stages: [RecognitionStage]
    let warnings: [String]
    let pieces: [String]
    let cutoutCount: Int
    let outputBytes: Int
}

nonisolated struct RecognitionRun {
    let candidates: [ImportCandidate]
    let cutouts: [String: Data]
    let summary: RecognitionRunSummary
}

nonisolated enum OnDeviceRecognitionPipeline {
    static func run(imageData: Data, importID: String,
                    mode: RecognitionMode = .nativePixels) async throws -> RecognitionRun {
        let task = Task.detached(priority: .userInitiated) {
            try await process(imageData: imageData, importID: importID, mode: mode)
        }
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            task.cancel()
        }
    }

    private static func process(imageData: Data, importID: String,
                                mode: RecognitionMode) async throws -> RecognitionRun {
        try Task.checkCancellation()
        let start = ProcessInfo.processInfo.systemUptime
        let metrics = RecognitionMetrics()
        let images = try RecognitionImageSession(data: imageData, mode: mode, metrics: metrics)
        var candidates = (try? await OnDeviceGarmentRegions.detect(
            imageData: images.processingData, importID: importID, images: images, metrics: metrics)) ?? []
        try Task.checkCancellation()
        if candidates.isEmpty {
            let suggestion = try? await PrototypeGarmentRecognition.analyze(images.processingData, metrics: metrics)
            try Task.checkCancellation()
            candidates = [ImportCandidate(
                id: SharedImportDraftStore.stableID(importID: importID, part: "whole-image"),
                name: suggestion?.name ?? "Piece", category: suggestion?.category ?? .other,
                destination: .closet, temporaryCutoutPath: nil, region: nil,
                suggestionSource: suggestion == nil ? "Review this photo" : "On-device suggestion",
                selected: false, tags: [], suggestedTags: []
            )]
        }
        var cutouts: [String: Data] = [:]
        for candidate in candidates {
            try Task.checkCancellation()
            let crop = try images.crop(candidate)
            if let png = try await AutomaticGarmentCutout.png(
                from: crop, reuseContext: mode != .baseline, metrics: metrics) {
                cutouts[candidate.id] = png
            }
        }
        try Task.checkCancellation()
        let measured = metrics.snapshot()
        return RecognitionRun(candidates: candidates, cutouts: cutouts, summary: RecognitionRunSummary(
            mode: mode, milliseconds: (ProcessInfo.processInfo.systemUptime - start) * 1_000,
            stages: measured.stages, warnings: measured.warnings,
            pieces: candidates.map { "\($0.id):\($0.name):\($0.category.rawValue)" },
            cutoutCount: cutouts.count, outputBytes: cutouts.values.reduce(0) { $0 + $1.count }
        ))
    }
}
