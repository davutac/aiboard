import Foundation
import Testing

@testable import Tastko

// MARK: - HTTP Fixture
nonisolated final class AIHTTPFixture: URLProtocol, @unchecked Sendable {
    static let lock = NSLock()
    nonisolated(unsafe) static var response: @Sendable (URLRequest) -> (Int, Data) = { _ in
        (500, Data())
    }

    // MARK: - URLProtocol
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let handler = Self.lock.withLock { Self.response }
        let (status, data) = handler(request)
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// MARK: - HTTP Journal
nonisolated final class AIHTTPJournal: @unchecked Sendable {
    let lock = NSLock()
    private var entries: [String] = []
    var paths: [String] { lock.withLock { entries } }

    // MARK: - Record
    func record(_ request: URLRequest) {
        lock.withLock { entries.append("\(request.httpMethod ?? "GET") \(request.url!.path)") }
    }
}

// MARK: - OpenCode HTTP Tests
@Suite(.serialized)
struct AIOpenCodeHTTPTests {
    // MARK: - Session Fixture
    private func session(journal: AIHTTPJournal, failure: Bool = false) -> URLSession {
        AIHTTPFixture.lock.withLock {
            AIHTTPFixture.response = { request in
                journal.record(request)
                guard
                    request.value(forHTTPHeaderField: "Authorization")?.hasPrefix("Basic ") == true
                else { return (401, Data()) }
                let body: String
                switch request.url!.path {
                case "/session" where request.httpMethod == "POST": body = #"{"id":"sess_fixture"}"#
                case "/session/sess_fixture/message":
                    body =
                        failure
                        ? #"{"info":{"error":{"name":"ProviderAuthError"}}}"#
                        : #"{"info":{},"parts":[{"type":"text","text":"{\"text\":\"fixture\"}"}]}"#
                default: body = "true"
                }
                return (200, Data(body.utf8))
            }
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIHTTPFixture.self]
        return URLSession(configuration: configuration)
    }

    // MARK: - Server Fixture
    private func executable(directory: URL) throws -> String {
        let file = directory.appending(path: "opencode-fixture")
        try Data(
            "#!/bin/sh\necho 'opencode server listening on http://127.0.0.1:18764'\nexec /bin/sleep 60\n"
                .utf8
        ).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        return file.path
    }

    // MARK: - Session Cleanup
    @Test(arguments: [false, true]) func restrictedGenerationCleansUpSession(failure: Bool)
        async throws
    {
        let directory = try AIWorkspace.create()
        defer { try? FileManager.default.removeItem(at: directory) }
        let journal = AIHTTPJournal()
        let owner = AIOpenCodeServerOwner(session: session(journal: journal, failure: failure))
        let adapter = OpenCodeAIProvider(owner: owner)
        do {
            let result = try await adapter.generate(
                request: AIGenerationRequest(prompt: "test"),
                selection: AIProviderSelection(
                    provider: .opencode,
                    modelID: "provider/model",
                    optionID: "high"
                ),
                model: AIModelDescriptor(id: "provider/model", name: "Fixture"),
                executable: executable(directory: directory),
                environment: [:]
            )
            #expect(!failure)
            #expect(result == "fixture")
        }
        catch {
            #expect(failure)
            #expect(error as? AIProviderError == .authentication)
        }
        await owner.shutdown()
        #expect(journal.paths.contains("DELETE /session/sess_fixture"))
        #expect(journal.paths.contains("POST /session/sess_fixture/abort") == failure)
    }
}
