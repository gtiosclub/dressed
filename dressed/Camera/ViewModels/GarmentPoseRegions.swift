import Foundation
import Vision

// Turns body landmarks into upper, lower and shoe review regions. Shared by the app and the
// Mac recognition bridge (backend/recognition/apple_vision.swift), so keep it free of app services.
nonisolated enum GarmentPoseRegions {
    static func regions(in person: VNHumanBodyPoseObservation?) -> [(String, NormalizedImageRegion)] {
        guard let person else { return [(String, NormalizedImageRegion)]() }

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
        // Shoes only when both ankles are confidently visible above the bottom edge.
        if let leftAnkle = point(.leftAnkle), let rightAnkle = point(.rightAnkle),
           min(leftAnkle.y, rightAnkle.y) > 0.06,
           let shoes = region(points: [leftAnkle, rightAnkle,
                                       CGPoint(x: leftAnkle.x, y: max(0, leftAnkle.y - 0.06)),
                                       CGPoint(x: rightAnkle.x, y: max(0, rightAnkle.y - 0.06))],
                              horizontalMargin: 0.07, topMargin: 0.02, bottomMargin: 0.02) {
            found.append(("shoes", shoes))
        }
        return found
    }

    private static func region(points: [CGPoint], horizontalMargin: Double,
                               topMargin: Double, bottomMargin: Double) -> NormalizedImageRegion? {
        let left = max(0, Double(points.map(\.x).min() ?? 0) - horizontalMargin)
        let right = min(1, Double(points.map(\.x).max() ?? 1) + horizontalMargin)
        let top = max(0, 1 - Double(points.map(\.y).max() ?? 1) - topMargin)
        let bottom = min(1, 1 - Double(points.map(\.y).min() ?? 0) + bottomMargin)
        let result = NormalizedImageRegion(x: left, y: top, width: right - left, height: bottom - top)
        return result.isValid && result.width >= 0.08 && result.height >= 0.08 ? result : nil
    }
}
