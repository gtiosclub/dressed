import CoreGraphics
import CoreImage
import CoreVideo
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
            landmarks.leftKnee = take(points, .leftKnee, minimum: 0.2)
            landmarks.rightKnee = take(points, .rightKnee, minimum: 0.2)
            landmarks.leftAnkle = take(points, .leftAnkle, minimum: 0.2)
            landmarks.rightAnkle = take(points, .rightAnkle, minimum: 0.2)
            landmarks = derived(landmarks)
        }
        let silhouette = segmentation.results?.first.flatMap { maskImage($0.pixelBuffer, matching: image) }
        return (landmarks, silhouette)
    }

    /// Foreground extent of an upright photo, normalized with a top-left origin.
    /// Used when a saved cutout was cropped to the person and no review region exists.
    static func foregroundBounds(_ image: CGImage) -> TryOnRect? {
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil,
              let mask = request.results?.first?.instanceMask else { return nil }
        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        guard width > 1, height > 1, rowBytes > 0, let base = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let bytesPerPixel = max(rowBytes / width, 1)
        let pointer = base.assumingMemoryBound(to: UInt8.self)
        var minX = width
        var minY = height
        var maxX = 0
        var maxY = 0
        var found = false
        for y in 0..<height {
            let row = pointer.advanced(by: y * rowBytes)
            for x in 0..<width {
                let pixel = row.advanced(by: x * bytesPerPixel)
                let on = pixel[0] != 0 || (bytesPerPixel > 1 && pixel[1] != 0)
                guard on else { continue }
                found = true
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard found, maxX > minX, maxY > minY else { return nil }
        return TryOnRect(
            x: Double(minX) / Double(width),
            y: Double(minY) / Double(height),
            width: Double(maxX - minX + 1) / Double(width),
            height: Double(maxY - minY + 1) / Double(height)
        )
    }

    /// Fills chest, waist, shoulder edges, and crotch from the joints that were actually detected.
    /// Waist sits between the chest and the hips, not on the hip line.
    static func derived(_ landmarks: TryOnLandmarks) -> TryOnLandmarks {
        var landmarks = landmarks
        if let left = landmarks.leftShoulderJoint, let right = landmarks.rightShoulderJoint {
            landmarks.chestCenter = TryOnPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
            landmarks.leftShoulderEdge = left
            landmarks.rightShoulderEdge = right
        } else if let left = landmarks.leftShoulderJoint {
            landmarks.leftShoulderEdge = left
        } else if let right = landmarks.rightShoulderJoint {
            landmarks.rightShoulderEdge = right
        }
        if let left = landmarks.leftHip, let right = landmarks.rightHip {
            let hip = TryOnPoint(x: (left.x + right.x) / 2, y: (left.y + right.y) / 2)
            landmarks.crotchCenter = TryOnPoint(x: hip.x, y: min(0.98, hip.y + 0.025))
            let upper = landmarks.chestCenter ?? landmarks.neckCenter
            if let upper {
                landmarks.waistCenter = TryOnPoint(
                    x: (hip.x + upper.x) / 2,
                    y: hip.y - (hip.y - upper.y) * 0.34
                )
                if let leftShoulder = landmarks.leftShoulderJoint, let rightShoulder = landmarks.rightShoulderJoint {
                    landmarks.leftWaist = TryOnPoint(
                        x: left.x + (leftShoulder.x - left.x) * 0.34,
                        y: left.y + (leftShoulder.y - left.y) * 0.34
                    )
                    landmarks.rightWaist = TryOnPoint(
                        x: right.x + (rightShoulder.x - right.x) * 0.34,
                        y: right.y + (rightShoulder.y - right.y) * 0.34
                    )
                }
            } else {
                landmarks.waistCenter = TryOnPoint(x: hip.x, y: max(0, hip.y - 0.05))
            }
        }
        return landmarks
    }

    private static func take(
        _ points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint],
        _ name: VNHumanBodyPoseObservation.JointName,
        minimum: Float = 0.3
    ) -> TryOnPoint? {
        guard let point = points[name], point.confidence >= minimum else { return nil }
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
