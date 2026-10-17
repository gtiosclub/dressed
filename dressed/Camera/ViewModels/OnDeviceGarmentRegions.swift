import Foundation
import Vision

// Body landmarks suggest separate review regions when a worn outfit is visible.
// They are not garment segmentation or product recognition; every result starts unselected.
enum OnDeviceGarmentRegions {
    static func detect(imageData: Data, importID: String) async throws -> [ImportCandidate] {
        let regions = try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let request = VNDetectHumanBodyPoseRequest()
            try VNImageRequestHandler(data: imageData).perform([request])
            try Task.checkCancellation()
            guard let person = request.results?.first else { return [(String, NormalizedImageRegion)]() }

            func point(_ joint: VNHumanBodyPoseObservation.JointName) -> CGPoint? {
                guard let result = try? person.recognizedPoint(joint), result.confidence >= 0.35 else {
                    return nil
                }
                return result.location
            }

            guard let leftShoulder = point(.leftShoulder), let rightShoulder = point(.rightShoulder),
                  let leftHip = point(.leftHip), let rightHip = point(.rightHip) else {
                return [(String, NormalizedImageRegion)]()
            }

            var found: [(String, NormalizedImageRegion)] = []
            if let upper = region(points: [leftShoulder, rightShoulder, leftHip, rightHip],
                                  horizontalMargin: 0.08, topMargin: 0.07, bottomMargin: 0.03) {
                found.append(("upper", upper))
            }
            if let leftLeg = point(.leftAnkle) ?? point(.leftKnee),
               let rightLeg = point(.rightAnkle) ?? point(.rightKnee),
               let lower = region(points: [leftHip, rightHip, leftLeg, rightLeg],
                                  horizontalMargin: 0.07, topMargin: 0.03, bottomMargin: 0.07) {
                found.append(("lower", lower))
            }
            return found
        }.value

        var candidates: [ImportCandidate] = []
        for (part, region) in regions {
            try Task.checkCancellation()
            let prototype = ImportCandidate(
                id: SharedImportDraftStore.stableID(importID: importID, part: part),
                name: part == "upper" ? "Top" : "Bottom",
                category: part == "upper" ? .tops : .pants,
                destination: .closet,
                temporaryCutoutPath: nil,
                region: region,
                suggestionSource: "Body region suggestion",
                selected: false,
                tags: [],
                suggestedTags: []
            )
            let crop = try SharedImportDraftStore.imageData(for: prototype, in: imageData)
            let suggestion = try? await PrototypeGarmentRecognition.analyze(crop)
            var candidate = prototype
            if let suggestion {
                candidate.name = suggestion.name
                candidate.category = suggestion.category
            }
            candidates.append(candidate)
        }
        return candidates
    }

    nonisolated private static func region(points: [CGPoint], horizontalMargin: Double,
                               topMargin: Double, bottomMargin: Double) -> NormalizedImageRegion? {
        let left = max(0, Double(points.map(\.x).min() ?? 0) - horizontalMargin)
        let right = min(1, Double(points.map(\.x).max() ?? 1) + horizontalMargin)
        let top = max(0, 1 - Double(points.map(\.y).max() ?? 1) - topMargin)
        let bottom = min(1, 1 - Double(points.map(\.y).min() ?? 0) + bottomMargin)
        let result = NormalizedImageRegion(x: left, y: top, width: right - left, height: bottom - top)
        return result.isValid && result.width >= 0.08 && result.height >= 0.08 ? result : nil
    }
}
