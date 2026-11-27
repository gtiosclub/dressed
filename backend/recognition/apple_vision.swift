// Apple Vision garment regions for the iOS simulator, which cannot run the body-pose model.
// local_service.py compiles this with the app's GarmentPoseRegions.swift. Runs on this Mac only.
// Usage: apple_vision <image> <import-id>  ->  recognition bridge JSON on stdout
import Foundation
import Vision

@main
struct AppleVisionRegions {
    static func main() throws {
        let arguments = CommandLine.arguments
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
        let request = VNDetectHumanBodyPoseRequest()
        try VNImageRequestHandler(data: data).perform([request])
        let candidates = GarmentPoseRegions.regions(in: request.results?.first).map { part, region -> [String: Any] in
            let (name, category) = switch part {
            case "upper": ("Top", "tops")
            case "shoes": ("Shoes", "shoes")
            default: ("Bottom", "pants")
            }
            return ["id": part, "suggestedName": name, "suggestedCategory": category,
                    "boundingBox": ["x": region.x, "y": region.y, "width": region.width, "height": region.height]]
        }
        let result: [String: Any] = ["importId": arguments[2], "candidates": candidates]
        FileHandle.standardOutput.write(try JSONSerialization.data(withJSONObject: result))
    }
}
