import Foundation
import Vision

// Runs an image-based Vision request, retrying on the CPU when the default
// device fails. The iOS simulator GPU cannot create a Vision inference context
// ("Failed to create espresso context"), which otherwise makes on-device
// recognition and feature prints silently return nothing there.
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
            let cpuRequest = makeRequest()
            guard let cpu = (try? cpuRequest.supportedComputeStageDevices[.main])?.first(where: {
                if case .cpu = $0 { return true }
                return false
            }) else { throw error }
            cpuRequest.setComputeDevice(cpu, for: .main)
            try VNImageRequestHandler(data: imageData).perform([cpuRequest])
            return cpuRequest
        }
    }
}
