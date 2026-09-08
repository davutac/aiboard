import Darwin
import Foundation
import Testing

@testable import Tastko

// MARK: - OpenCode Lifecycle Tests
struct AIOpenCodeLifecycleTests {
    private struct Launch: Sendable {
        let pid: pid_t
        let directory: URL
    }

    // MARK: - Fixture
    private func withFixture(
        _ test: (AIOpenCodeServerOwner, String, [String: String], URL) async throws -> Void
    ) async throws {
        let directory = try AIWorkspace.create()
        defer { try? FileManager.default.removeItem(at: directory) }
        let executable = directory.appending(path: "server-fixture")
        let log = directory.appending(path: "launches")
        let script = #"""
            #!/bin/sh
            printf '%s\t%s\n' "$$" "$PWD" >> "$TASTKO_TEST_SERVER_LOG"
            echo 'opencode server listening on http://127.0.0.1:18764'
            exec /bin/sleep 60
            """#
        try Data(script.utf8).write(to: executable)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: executable.path
        )
        let owner = AIOpenCodeServerOwner()
        do {
            try await test(owner, executable.path, ["TASTKO_TEST_SERVER_LOG": log.path], log)
        }
        catch {
            await owner.shutdown()
            throw error
        }
        await owner.shutdown()
        for launch in try launches(log) {
            #expect(!FileManager.default.fileExists(atPath: launch.directory.path))
        }
    }

    // MARK: - Read Launches
    private func launches(_ log: URL) throws -> [Launch] {
        try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map { line in
            let fields = line.split(separator: "\t", maxSplits: 1)
            let pid = try #require(pid_t(fields[0]))
            return Launch(pid: pid, directory: URL(filePath: String(fields[1])))
        }
    }

    // MARK: - Await Exit Cleanup
    private func waitForCleanup(_ directory: URL) async throws {
        try await withAIDeadline(seconds: 3) {
            while FileManager.default.fileExists(atPath: directory.path) {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
    }

    // MARK: - Idle Crash and Concurrent Restart
    @Test func exitedServerIsCleanedUpAndNextBorrowersShareReplacement() async throws {
        try await withFixture { owner, executable, environment, log in
            let firstPassword = try await owner.withServer(
                executable: executable,
                environment: environment
            ) { $0.password }
            let first = try #require(launches(log).first)
            #expect(kill(first.pid, SIGTERM) == 0)
            try await waitForCleanup(first.directory)

            let passwords = try await withThrowingTaskGroup(of: String.self) { group in
                for _ in 0..<3 {
                    group.addTask {
                        try await owner.withServer(executable: executable, environment: environment)
                        {
                            connection in
                            try await Task.sleep(for: .milliseconds(30))
                            return connection.password
                        }
                    }
                }
                var passwords: [String] = []
                for try await password in group { passwords.append(password) }
                return passwords
            }
            #expect(Set(passwords).count == 1)
            #expect(passwords.first != firstPassword)
            #expect(try launches(log).count == 2)
        }
    }

    // MARK: - In-Flight Failure
    @Test func failedOperationIsNotReplayedAfterServerExit() async throws {
        try await withFixture { owner, executable, environment, log in
            let failure = AIProviderError.server("Fixture connection closed")
            await #expect(throws: failure) {
                try await owner.withServer(executable: executable, environment: environment) { _ in
                    let launch = try #require(launches(log).last)
                    #expect(kill(launch.pid, SIGTERM) == 0)
                    throw failure
                } as Void
            }
            #expect(try launches(log).count == 1)
            let first = try #require(launches(log).first)
            try await waitForCleanup(first.directory)
            _ = try await owner.withServer(executable: executable, environment: environment) {
                $0.password
            }
            #expect(try launches(log).count == 2)
        }
    }
}
