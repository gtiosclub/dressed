import Foundation
import Vision

// Runs an image-based Vision request, retrying on the CPU when the default
// device fails on hardware.
//
// The simulator is excluded on purpose. Its GPU cannot create a Vision inference
// context ("Failed to create espresso context"), and its CPU path returns the
// same output for every image (identical classifier labels; feature-print
// distance ~0 between unrelated photos), which would merge every same-category
// piece. On the simulator the request fails, so callers use their fallbacks:
// "Piece" for recognition and name matching for grouping.
enum VisionRequestRunner {
    nonisolated static func perform<Request: VNRequest>(
        _ makeRequest: () -> Request,
        on imageData: Data
    ) throws -> Request {
        let request = makeRequest()
        do {
            try VNImageRequestHandler(data: imageData).perform([request])
            return request
        } catch {
            #if targetEnvironment(simulator)
            throw error
            #else
            let cpuRequest = makeRequest()
            guard let cpu = (try? cpuRequest.supportedComputeStageDevices[.main])?.first(where: {
                if case .cpu = $0 { return true }
                return false
            }) else { throw error }
            cpuRequest.setComputeDevice(cpu, for: .main)
            try VNImageRequestHandler(data: imageData).perform([cpuRequest])
            return cpuRequest
            #endif
        }
    }
}
