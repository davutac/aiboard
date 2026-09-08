import Darwin
import Foundation

// MARK: - Process Output
nonisolated struct AIProcessOutput: Sendable {
    let stdout: Data
    let stderr: Data
    let exitCode: Int32

    // MARK: - Check Exit
    func checked() throws -> Data {
        guard exitCode == 0 else {
            let diagnostic = String(decoding: stderr.suffix(2048), as: UTF8.self)
            let lower = diagnostic.lowercased()
            if lower.contains("not logged in") || lower.contains("unauthorized")
                || lower.contains("authentication")
            {
                throw AIProviderError.authentication
            }
            let errorLine = diagnostic.split(separator: "\n").last {
                $0.lowercased().hasPrefix("error")
            }
            throw AIProviderError.process(
                errorLine.map { AITextOutput.diagnostic(String($0)) }
                    ?? "Exit code \(exitCode). Check the CLI in Terminal."
            )
        }
        return stdout
    }
}

// MARK: - Managed Child Process
/// Pipe readers and lifecycle operations synchronize through the lock. No provider output is logged.
nonisolated final class AIChildProcess: @unchecked Sendable {
    private let process = Process()
    private let exitSignal = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    private let input = Pipe()
    private let output = Pipe()
    private let errors = Pipe()
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()
    private var readersFinished = 0
    private var overflow = false
    private var stopped = false
    private var terminationTarget: pid_t = 0
    private let limit: Int
    var isRunning: Bool { process.isRunning }

    // MARK: - Launch
    init(
        executable: String,
        arguments: [String],
        environment: [String: String],
        directory: URL,
        limit: Int = 4 * 1024 * 1024
    ) throws {
        self.limit = limit
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.environment = environment
        process.currentDirectoryURL = directory
        process.standardInput = input
        process.standardOutput = output
        process.standardError = errors
        // A CLI can close stdin before a pending write; do not let SIGPIPE terminate Tastko.
        _ = fcntl(input.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        let exitContinuation = exitSignal.continuation
        process.terminationHandler = { _ in
            exitContinuation.yield(())
            exitContinuation.finish()
        }
        do { try process.run() }
        catch {
            throw AIProviderError.process(
                "Unable to launch \(URL(filePath: executable).lastPathComponent)."
            )
        }
        let pid = process.processIdentifier
        // Retain the original group even if the launcher exits before its descendants.
        terminationTarget = getpgid(pid) == pid ? -pid : pid
        read(output.fileHandleForReading, isError: false)
        read(errors.fileHandleForReading, isError: true)
    }

    // MARK: - Drain Pipes
    private func read(_ handle: FileHandle, isError: Bool) {
        DispatchQueue.global(qos: .utility).async { [self] in
            defer { lock.withLock { readersFinished += 1 } }
            while true {
                // availableData returns the next pipe chunk without waiting to fill a fixed-size read.
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                lock.withLock {
                    let remaining = max(0, limit - stdout.count - stderr.count)
                    if chunk.count > remaining { overflow = true }
                    if isError {
                        stderr.append(chunk.prefix(remaining))
                    }
                    else {
                        stdout.append(chunk.prefix(remaining))
                    }
                }
            }
        }
    }

    // MARK: - Input
    func write(_ data: Data, close: Bool = false) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .utility).async { [self] in
                do {
                    try input.fileHandleForWriting.write(contentsOf: data)
                    if close { try input.fileHandleForWriting.close() }
                    continuation.resume()
                }
                catch {
                    continuation.resume(
                        throwing: AIProviderError.process("Provider closed its input pipe.")
                    )
                }
            }
        }
    }

    // MARK: - Snapshot
    func snapshot() throws -> (data: Data, finished: Bool) {
        try lock.withLock {
            if overflow { throw AIProviderError.outputTooLarge }
            return (stdout, !process.isRunning && readersFinished == 2)
        }
    }

    // MARK: - Wait
    func wait() async throws -> AIProcessOutput {
        while true {
            try Task.checkCancellation()
            if try snapshot().finished {
                return lock.withLock {
                    AIProcessOutput(
                        stdout: stdout,
                        stderr: stderr,
                        exitCode: process.terminationStatus
                    )
                }
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    // MARK: - Observe Exit
    func waitForExit() async {
        for await _ in exitSignal.stream {}
    }

    // MARK: - Terminate
    func stop() {
        let shouldStop = lock.withLock {
            guard !stopped else { return false }
            stopped = true
            return true
        }
        guard shouldStop else { return }
        try? input.fileHandleForWriting.close()
        guard process.isRunning || lock.withLock({ readersFinished < 2 }) else { return }
        let target = terminationTarget
        kill(target, SIGTERM)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.5) { [self] in
            if process.isRunning || (target < 0 && kill(target, 0) == 0) { kill(target, SIGKILL) }
        }
    }
}

// MARK: - Deadline
nonisolated func withAIDeadline<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    guard seconds.isFinite, seconds > 0 else { throw AIProviderError.timeout }
    do {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw AIProviderError.timeout
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    catch is CancellationError { throw AIProviderError.cancelled }
}

// MARK: - One-Shot Process
nonisolated enum AIProcessRunner {
    // MARK: - Run
    static func run(
        executable: String,
        arguments: [String],
        environment: [String: String],
        directory: URL,
        input: Data = Data(),
        timeout: TimeInterval = 30
    ) async throws -> AIProcessOutput {
        try await withAIDeadline(seconds: timeout) {
            let child = try AIChildProcess(
                executable: executable,
                arguments: arguments,
                environment: environment,
                directory: directory
            )
            defer { child.stop() }
            return try await withTaskCancellationHandler {
                try Task.checkCancellation()
                try await child.write(input, close: true)
                return try await child.wait()
            } onCancel: {
                child.stop()
            }
        }
    }
}
