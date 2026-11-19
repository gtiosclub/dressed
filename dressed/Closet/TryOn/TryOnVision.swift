import CoreGraphics
import CoreImage
import Foundation
import Vision

enum TryOnVision {
    /// Reads pose landmarks and a person silhouette from the generated avatar.
    /// Joints under the confidence threshold stay nil.
    static func analyze(_ image: CGImage) -> (landmarks: TryOnLandmarks, silhouette: CGImage?) {
        let pose = VNDetectHumanBodyPoseRequest()
        let segmentation = VNGeneratePersonSegmentationRequest()
        segmentation.qualityLevel = .accurate
        segmentation.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try? handler.perform([pose, segmentation])
        var landmarks = TryOnLandmarks()
        if let observation = pose.results?.first,
           let points = try? observation.recognizedPoints(.all) {
            landmarks.neckCenter = take(points, .neck)
            landmarks.leftShoulderJoint = take(points, .leftShoulder)
            landmarks.rightShoulderJoint = take(points, .rightShoulder)
            landmarks.leftElbow = take(points, .leftElbow)
            landmarks.rightElbow = take(points, .rightElbow)
            landmarks.leftWrist = take(points, .leftWrist)
            landmarks.rightWrist = take(points, .rightWrist)
            landmarks.leftHip = take(points, .leftHip)
            landmarks.rightHip = take(points, .rightHip)
            landmarks.leftKnee = take(points, .leftKnee)
            landmarks.rightKnee = take(points, .rightKnee)
            landmarks.leftAnkle = take(points, .leftAnkle)
            landmarks.rightAnkle = take(points, .rightAnkle)
            if let left = landmarks.leftShoulderJoint, let right = landmarks.rightShoulderJoint {
                landmarks.chestCenter = TryOnPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
            }
            if let left = landmarks.leftHip, let right = landmarks.rightHip {
                landmarks.waistCenter = TryOnPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
            }
        }
        let silhouette = segmentation.results?.first.flatMap { maskImage($0.pixelBuffer, matching: image) }
        return (landmarks, silhouette)
    }

    private static func take(
        _ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        _ name: VNHumanBodyPoseObservation.JointName
    ) -> TryOnPoint? {
        guard let point = points[name], point.confidence >= 0.3 else { return nil }
        return TryOnPoint(x: Double(point.location.x), y: Double(1 - point.location.y))
    }

    private static func maskImage(_ buffer: CVPixelBuffer, matching image: CGImage) -> CGImage? {
        let source = CIImage(cvPixelBuffer: buffer)
        let scaleX = CGFloat(image.width) / max(source.extent.width, 1)
        let scaleY = CGFloat(image.height) / max(source.extent.height, 1)
        let scaled = source.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        let context = CIContext()
        guard let scaledImage = context.createCGImage(scaled, from: CGRect(x: 0, y: 0, width: image.width, height: image.height)) else {
            return nil
        }
        guard let bytes = TryOnBitmap.rgba(from: scaledImage) else { return nil }
        var output = bytes.bytes
        for index in stride(from: 0, to: output.count, by: 4) {
            let coverage = output[index]
            let on = coverage > 128 ? UInt8(255) : 0
            output[index] = on
            output[index + 1] = on
            output[index + 2] = on
            output[index + 3] = 255
        }
        return TryOnBitmap.cgImage(width: bytes.width, height: bytes.height, bytes: output)
    }
}
