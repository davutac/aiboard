import Foundation

// MARK: - OpenCode Server Owner
actor AIOpenCodeServerOwner {
    struct Server: Sendable {
        let child: AIChildProcess
        let directory: URL
        let connection: AIOpenCodeConnection
    }
    private struct Entry {
        let id: UUID
        let task: Task<Server, Error>
        var result: Result<Server, Error>?
        var borrowers = 0
        var idleTask: Task<Void, Never>?
        var exitTask: Task<Void, Never>?
    }
    private var entries: [String: Entry] = [:]
    private var stopped = false
    private let session: URLSession

    // MARK: - Initialization
    init(session: URLSession = URLSession(configuration: .ephemeral)) { self.session = session }

    // MARK: - Borrow Server
    func withServer<T: Sendable>(
        executable: String,
        environment: [String: String],
        operation: @Sendable (AIOpenCodeConnection) async throws -> T
    ) async throws -> T {
        try Task.checkCancellation()
        guard !stopped else { throw AIProviderError.cancelled }
        // Cover the interval between process exit and delivery of its termination notification.
        if let entry = entries[executable], case .success(let server) = entry.result,
            !server.child.isRunning
        {
            entries.removeValue(forKey: executable)
            await stop(entry)
        }
        try Task.checkCancellation()
        guard !stopped else { throw AIProviderError.cancelled }
        if entries[executable] == nil {
            let session = session
            let id = UUID()
            entries[executable] = Entry(
                id: id,
                task: Task { [self] in
                    let result: Result<Server, Error>
                    do {
                        result = .success(
                            try await Self.start(
                                executable: executable,
                                environment: environment,
                                session: session
                            )
                        )
                    }
                    catch {
                        result = .failure(error)
                    }
                    if self.entries[executable]?.id == id {
                        self.entries[executable]?.result = result
                        if case .success(let server) = result {
                            self.entries[executable]?.exitTask = Task { [weak self] in
                                await server.child.waitForExit()
                                guard !Task.isCancelled else { return }
                                await self?.serverExited(executable, id: id)
                            }
                        }
                    }
                    return try result.get()
                }
            )
        }
        entries[executable]?.idleTask?.cancel()
        entries[executable]?.borrowers += 1
        guard let entry = entries[executable] else {
            throw AIProviderError.server("Server unavailable.")
        }
        defer { release(executable, id: entry.id) }
        // A borrower can cancel without cancelling startup needed by another borrower.
        while entries[executable]?.id == entry.id && entries[executable]?.result == nil {
            try Task.checkCancellation()
            try await Task.sleep(for: .milliseconds(20))
        }
        try Task.checkCancellation()
        guard entries[executable]?.id == entry.id,
            let result = entries[executable]?.result
        else { throw AIProviderError.server("OpenCode exited during startup.") }
        let server: Server
        do { server = try result.get() }
        catch {
            if entries[executable]?.id == entry.id { entries.removeValue(forKey: executable) }
            throw error
        }
        guard !stopped, server.child.isRunning else {
            if entries[executable]?.id == entry.id { entries.removeValue(forKey: executable) }
            await stop(entry)
            throw AIProviderError.server("OpenCode exited during the request.")
        }
        return try await operation(server.connection)
    }

    // MARK: - Start Server
    private static func start(
        executable: String,
        environment: [String: String],
        session: URLSession
    ) async throws -> Server {
        let directory = try AIWorkspace.create()
        var environment = environment
        let password = UUID().uuidString + UUID().uuidString
        environment["OPENCODE_SERVER_PASSWORD"] = password
        // Global auth/provider configuration remains available; the task agent cannot use any tools.
        let child: AIChildProcess
        do {
            child = try AIChildProcess(
                executable: executable,
                arguments: ["serve", "--hostname=127.0.0.1", "--port=0"],
                environment: environment,
                directory: directory
            )
        }
        catch {
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
        do {
            return try await withAIDeadline(seconds: 30) {
                try await withTaskCancellationHandler {
                    while true {
                        try Task.checkCancellation()
                        let snapshot = try child.snapshot()
                        let output = String(decoding: snapshot.data, as: UTF8.self)
                        if let range = output.range(
                            of: #"http://127\.0\.0\.1:\d+"#,
                            options: .regularExpression
                        ),
                            let url = URL(string: String(output[range]))
                        {
                            return Server(
                                child: child,
                                directory: directory,
                                connection: AIOpenCodeConnection(
                                    url: url,
                                    password: password,
                                    session: session
                                )
                            )
                        }
                        if snapshot.finished {
                            throw AIProviderError.server("OpenCode exited before it was ready.")
                        }
                        try await Task.sleep(for: .milliseconds(30))
                    }
                } onCancel: {
                    child.stop()
                }
            }
        }
        catch {
            child.stop()
            try? FileManager.default.removeItem(at: directory)
            throw error
        }
    }

    // MARK: - Idle Release
    private func release(_ executable: String, id: UUID) {
        guard var entry = entries[executable], entry.id == id else { return }
        entry.borrowers -= 1
        if entry.borrowers == 0 && entry.result == nil {
            entries.removeValue(forKey: executable)
            entry.task.cancel()
            Task { await stop(entry) }
            return
        }
        if entry.borrowers == 0 {
            entry.idleTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(30)) }
                catch { return }
                await self?.close(executable, id: id)
            }
        }
        entries[executable] = entry
    }

    // MARK: - Close Idle Server
    private func close(_ executable: String, id: UUID) async {
        guard let entry = entries[executable], entry.id == id, entry.borrowers == 0 else { return }
        entries.removeValue(forKey: executable)
        await stop(entry)
    }

    // MARK: - Unexpected Exit
    private func serverExited(_ executable: String, id: UUID) async {
        guard let entry = entries[executable], entry.id == id else { return }
        entries.removeValue(forKey: executable)
        await stop(entry)
    }

    // MARK: - Stop Entry
    private func stop(_ entry: Entry) async {
        entry.idleTask?.cancel()
        entry.exitTask?.cancel()
        entry.task.cancel()
        if let server = try? await entry.task.value {
            server.child.stop()
            try? FileManager.default.removeItem(at: server.directory)
        }
    }

    // MARK: - Shutdown
    func shutdown() async {
        stopped = true
        let previous = Array(entries.values)
        entries.removeAll()
        for entry in previous { await stop(entry) }
    }
}
