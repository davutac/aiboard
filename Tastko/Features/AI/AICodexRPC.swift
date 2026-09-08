import Foundation

// MARK: - Codex Probe Protocol
actor AICodexRPC {
    private let child: AIChildProcess
    private var offset = 0
    private var requestID = 0

    // MARK: - Initialization
    init(child: AIChildProcess) { self.child = child }

    // MARK: - Notify
    func notify(_ method: String) async throws {
        var data = try AIJSON.object(["method": .string(method)]).data()
        data.append(10)
        try await child.write(data)
    }

    // MARK: - Request
    func request(_ method: String, params: AIJSON) async throws -> AIJSON {
        requestID += 1
        let id = AIJSON.number(Double(requestID))
        var data = try AIJSON.object(["id": id, "method": .string(method), "params": params]).data()
        data.append(10)
        try await child.write(data)
        while true {
            try Task.checkCancellation()
            let snapshot = try child.snapshot()
            while let newline = snapshot.data[offset...].firstIndex(of: 10) {
                let line = snapshot.data[offset..<newline]
                offset = newline + 1
                guard !line.isEmpty else { continue }
                let message = try AIJSON.decode(Data(line))
                if message["id"] == id {
                    guard message["error"] == .null else {
                        throw AIProviderError.process("Codex rejected the \(method) probe.")
                    }
                    return message["result"]
                }
            }
            if snapshot.finished {
                throw AIProviderError.process("Codex app-server closed before responding.")
            }
            try await Task.sleep(for: .milliseconds(20))
        }
    }
}
