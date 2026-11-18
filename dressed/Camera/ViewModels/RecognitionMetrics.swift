import Foundation

nonisolated struct RecognitionStage: Codable {
    let name: String
    let milliseconds: Double
}

// One recorder per run, including detached Vision work. No photos or owner IDs in logs.
nonisolated final class RecognitionMetrics: @unchecked Sendable {
    private let lock = NSLock()
    private var stages: [RecognitionStage] = []
    private var messages: [String] = []

    func measure<T>(_ name: String, _ work: () throws -> T) rethrows -> T {
        let start = ProcessInfo.processInfo.systemUptime
        defer { record(name, since: start) }
        return try work()
    }

    func measure<T>(_ name: String, _ work: () async throws -> T) async rethrows -> T {
        let start = ProcessInfo.processInfo.systemUptime
        defer { record(name, since: start) }
        return try await work()
    }

    func record(_ name: String, since start: TimeInterval) {
        lock.lock()
        stages.append(RecognitionStage(name: name, milliseconds:
            (ProcessInfo.processInfo.systemUptime - start) * 1_000))
        lock.unlock()
    }

    func warning(_ message: String) {
        lock.lock()
        messages.append(message)
        lock.unlock()
    }

    func warning(_ message: String, error: Error) {
        let failure = error as NSError
        // Preserve the framework/code for diagnosis without exporting userInfo,
        // which can contain file paths or other input details.
        warning("\(message) [\(failure.domain):\(failure.code)]")
    }

    func snapshot() -> (stages: [RecognitionStage], warnings: [String]) {
        lock.lock()
        defer { lock.unlock() }
        return (stages, Array(Set(messages)).sorted())
    }
}

nonisolated enum RecognitionExecution {
    // Detached work must receive parent cancellation; Task.detached alone does not.
    static func offMain<T>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        let task = Task.detached(priority: .userInitiated, operation: work)
        return try await withTaskCancellationHandler {
            let result = try await task.value
            try Task.checkCancellation()
            return result
        } onCancel: {
            task.cancel()
        }
    }
}
