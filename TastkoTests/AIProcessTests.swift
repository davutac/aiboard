import Foundation
import Testing

@testable import Tastko

// MARK: - Process Tests
struct AIProcessTests {
    // MARK: - Incremental Protocol Replies
    @Test func receivesSmallReplyBeforeProcessExits() async throws {
        let child = try AIChildProcess(
            executable: "/bin/sh",
            arguments: ["-c", "echo ready; exec /bin/sleep 30"],
            environment: [:],
            directory: FileManager.default.temporaryDirectory
        )
        defer { child.stop() }
        let data = try await withAIDeadline(seconds: 2) {
            while true {
                try Task.checkCancellation()
                let snapshot = try child.snapshot()
                if !snapshot.data.isEmpty { return snapshot.data }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
        #expect(String(decoding: data, as: UTF8.self) == "ready\n")
    }
    // MARK: - Descendant Cleanup
    @Test func stopsDescendantsAfterLauncherExits() async throws {
        let child = try AIChildProcess(
            executable: "/bin/sh",
            arguments: ["-c", "/bin/sleep 30 & echo ready"],
            environment: [:],
            directory: FileManager.default.temporaryDirectory
        )
        defer { child.stop() }
        try await Task.sleep(for: .milliseconds(150))
        #expect(!child.isRunning)
        child.stop()
        _ = try await withAIDeadline(seconds: 2) { try await child.wait() }
    }

    // MARK: - Pipe Drain
    @Test func drainsBothPipesBeyondPipeCapacity() async throws {
        let result = try await AIProcessRunner.run(
            executable: "/bin/sh",
            arguments: [
                "-c",
                "i=0; while [ $i -lt 5000 ]; do echo abcdefghijklmnopqrstuvwxyz; echo abcdefghijklmnopqrstuvwxyz >&2; i=$((i+1)); done",
            ],
            environment: [:],
            directory: FileManager.default.temporaryDirectory
        )
        #expect(result.exitCode == 0)
        #expect(result.stdout.count == 135000)
        #expect(result.stderr.count == 135000)
    }

    // MARK: - Deadline
    @Test func timeoutTerminatesChildPromptly() async throws {
        let clock = ContinuousClock()
        let start = clock.now
        await #expect(throws: AIProviderError.timeout) {
            try await AIProcessRunner.run(
                executable: "/bin/sleep",
                arguments: ["30"],
                environment: [:],
                directory: FileManager.default.temporaryDirectory,
                timeout: 0.1
            )
        }
        #expect(start.duration(to: clock.now) < .seconds(3))
    }

    // MARK: - Cancellation
    @Test func cancellationStopsProcess() async throws {
        let task = Task {
            try await AIProcessRunner.run(
                executable: "/bin/sleep",
                arguments: ["30"],
                environment: [:],
                directory: FileManager.default.temporaryDirectory
            )
        }
        try await Task.sleep(for: .milliseconds(100))
        task.cancel()
        await #expect(throws: AIProviderError.cancelled) { try await task.value }
    }

    // MARK: - Server Startup Cancellation
    @Test func cancellationDoesNotWaitForSharedServerStartup() async throws {
        let directory = try AIWorkspace.create()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "slow-server")
        try Data("#!/bin/sh\nexec /bin/sleep 30\n".utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executable.path
        )
        let owner = AIOpenCodeServerOwner()
        let task = Task {
            try await withAIDeadline(seconds: 5) {
                try await owner.withServer(executable: executable.path, environment: [:]) { _ in
                    true
                }
            }
        }
        try await Task.sleep(for: .milliseconds(100))
        let start = ContinuousClock.now
        task.cancel()
        await #expect(throws: AIProviderError.cancelled) { try await task.value }
        #expect(start.duration(to: .now) < .seconds(2))
        await owner.shutdown()
    }

    // MARK: - Output Limits
    @Test func boundsCapturedOutput() async throws {
        let child = try AIChildProcess(
            executable: "/usr/bin/yes",
            arguments: [],
            environment: [:],
            directory: FileManager.default.temporaryDirectory,
            limit: 4096
        )
        defer { child.stop() }
        await #expect(throws: AIProviderError.outputTooLarge) { try await child.wait() }
    }
}
