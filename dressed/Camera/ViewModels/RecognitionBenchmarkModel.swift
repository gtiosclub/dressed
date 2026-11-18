import Combine
import CryptoKit
import Darwin
import ImageIO
import UIKit

nonisolated struct RecognitionBenchmarkEntry: Codable {
    let repetition: Int
    let firstRun: Bool
    let thermalState: Int
    let result: RecognitionRunSummary
    let cutoutDigests: [String: String]
}

nonisolated struct RecognitionBenchmarkReport: Codable {
    let schemaVersion: Int
    let implementation: String
    let applicationIdentifier: String
    let visionExecution: String
    let createdAt: Date
    let device: String
    let operatingSystem: String
    let buildConfiguration: String
    let sampleKind: String
    let sampleDigest: String
    let inputBytes: Int
    let inputPixelWidth: Int?
    let inputPixelHeight: Int?
    let lowPowerMode: Bool
    let appBuild: String
    let entries: [RecognitionBenchmarkEntry]
}

@MainActor
final class RecognitionBenchmarkModel: ObservableObject {
    @Published var imageData: Data?
    @Published var sampleKind = "Chosen photo"
    @Published var variant = RecognitionMode.nativePixels
    @Published var repetitions = 3
    @Published private(set) var isRunning = false
    @Published private(set) var progress = "Choose a photo to compare two local runs."
    @Published private(set) var entries: [RecognitionBenchmarkEntry] = []
    @Published private(set) var latest: [RecognitionMode: RecognitionRun] = [:]
    @Published private(set) var exportURL: URL?
    private var task: Task<Void, Never>?
    private var generation = UUID()

    func select(_ data: Data, kind: String) {
        guard !isRunning else { return }
        imageData = data
        sampleKind = kind
        entries = []
        latest = [:]
        exportURL = nil
        progress = "Ready. Photos stay on this device; nothing is saved to the closet."
    }

    func median(for mode: RecognitionMode) -> Double? {
        let values = entries.filter { !$0.firstRun && $0.result.mode == mode }
            .map(\.result.milliseconds).sorted()
        guard !values.isEmpty else { return nil }
        let middle = values.count / 2
        return values.count.isMultiple(of: 2) ? (values[middle - 1] + values[middle]) / 2 : values[middle]
    }

    func cancel() { task?.cancel() }

    func selectDevelopmentInputIfRequested() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-benchmarkInput"), index + 1 < arguments.count else { return }
        // Local development CLI only: accept a filename inside this app's Documents directory.
        let name = arguments[index + 1]
        guard name == URL(fileURLWithPath: name).lastPathComponent else { return }
        let file = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        guard let data = try? Data(contentsOf: file) else { return }
        select(data, kind: "Local development input")
        repetitions = 3
        if let marker = arguments.firstIndex(of: "-benchmarkRepeats"), marker + 1 < arguments.count,
           let count = Int(arguments[marker + 1]) {
            repetitions = min(5, max(1, count))
        }
        if arguments.contains("-runRecognitionBenchmark") { start() }
    }

    func start() {
        guard let imageData, !isRunning else { return }
        let attempt = UUID()
        generation = attempt
        let testedVariant = variant
        let count = repetitions
        let kind = sampleKind
        entries = []
        latest = [:]
        exportURL = nil
        isRunning = true
        task = Task {
            defer { if generation == attempt { isRunning = false } }
            do {
                // First-use runs are retained separately and excluded from repeated-run medians.
                for repetition in 0...count {
                    let modes: [RecognitionMode] = repetition.isMultiple(of: 2)
                        ? [.baseline, testedVariant] : [testedVariant, .baseline]
                    for mode in modes {
                        try Task.checkCancellation()
                        progress = "\(mode.title): \(repetition == 0 ? "first run" : "repeat \(repetition) of \(count)")"
                        let thermal = ProcessInfo.processInfo.thermalState.rawValue
                        let run = try await OnDeviceRecognitionPipeline.run(
                            imageData: imageData, importID: attempt.uuidString, mode: mode)
                        try Task.checkCancellation()
                        latest[mode] = run
                        entries.append(RecognitionBenchmarkEntry(repetition: repetition, firstRun: repetition == 0,
                                                                 thermalState: thermal, result: run.summary,
                                                                 cutoutDigests: run.cutouts.mapValues {
                                                                     SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined()
                                                                 }))
                        try export(imageData: imageData, kind: kind)
                        // Yield to UI and cancellation between independent runs.
                        await Task.yield()
                    }
                }
                progress = entries.contains { !$0.result.warnings.isEmpty }
                    ? "Finished with Vision warnings. Inspect the warnings before interpreting speed or quality."
                    : "Finished. Compare the previews and categories before keeping a speed change."
            } catch is CancellationError {
                progress = "Stopped. Completed measurements are retained; no closet items were created."
            } catch {
                progress = "Comparison failed: \(error.localizedDescription)"
            }
        }
    }

    private func export(imageData: Data, kind: String) throws {
        #if DEBUG
        let configuration = "Debug — do not treat as Release device performance"
        #else
        let configuration = "Release"
        #endif
        let report = RecognitionBenchmarkReport(
            schemaVersion: 5, implementation: "scanline-v3-simulator-cpu-classifier",
            applicationIdentifier: Bundle.main.bundleIdentifier ?? "unknown",
            visionExecution: visionExecution, createdAt: Date(),
            device: hardwareIdentifier(),
            operatingSystem: ProcessInfo.processInfo.operatingSystemVersionString,
            buildConfiguration: configuration, sampleKind: kind,
            sampleDigest: SHA256.hash(data: imageData).prefix(8).map { String(format: "%02x", $0) }.joined(),
            inputBytes: imageData.count,
            inputPixelWidth: imageProperties(imageData)?[kCGImagePropertyPixelWidth] as? Int,
            inputPixelHeight: imageProperties(imageData)?[kCGImagePropertyPixelHeight] as? Int,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
            appBuild: "\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))",
            entries: entries)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("recognition-benchmark.json")
        try encoder.encode(report).write(to: file, options: .atomic)
        exportURL = file
    }

    private func imageProperties(_ data: Data) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }

    private var visionExecution: String {
        #if targetEnvironment(simulator)
        "Simulator: CPU classifier; automatic body pose and foreground mask"
        #else
        "Device: automatic compute selection for all Vision requests"
        #endif
    }

    private func hardwareIdentifier() -> String {
        if let simulator = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return "Simulator \(simulator)"
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: &system.machine) {
            String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}

enum RecognitionDemoImage {
    // Synthetic shirt silhouette: useful for mask/geometry checks, never an accuracy dataset.
    static func make() -> Data {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 1600), format: format).jpegData(
            withCompressionQuality: 0.9) { context in
                UIColor.white.setFill()
                context.fill(CGRect(x: 0, y: 0, width: 1200, height: 1600))
                UIColor.systemBlue.setFill()
                let path = UIBezierPath()
                path.move(to: CGPoint(x: 400, y: 300))
                for point in [CGPoint(x: 200, y: 450), CGPoint(x: 310, y: 660),
                              CGPoint(x: 400, y: 580), CGPoint(x: 400, y: 1250),
                              CGPoint(x: 800, y: 1250), CGPoint(x: 800, y: 580),
                              CGPoint(x: 890, y: 660), CGPoint(x: 1000, y: 450),
                              CGPoint(x: 800, y: 300)] { path.addLine(to: point) }
                path.close()
                path.fill()
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: 510, y: 235, width: 180, height: 160)).fill()
            }
    }
}
