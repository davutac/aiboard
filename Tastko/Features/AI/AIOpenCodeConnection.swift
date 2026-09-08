import Foundation

// MARK: - OpenCode HTTP Client
nonisolated struct AIOpenCodeConnection: Sendable {
    let url: URL
    let password: String
    let session: URLSession

    // MARK: - HTTP Request
    func request(
        _ path: String,
        method: String = "GET",
        body: AIJSON? = nil,
        maximumBytes: Int = 4 * 1024 * 1024
    ) async throws -> AIJSON {
        var request = URLRequest(url: url.appending(path: path))
        request.httpMethod = method
        request.timeoutInterval = 180
        request.setValue(
            "Basic " + Data("opencode:\(password)".utf8).base64EncodedString(),
            forHTTPHeaderField: "Authorization"
        )
        if let body {
            request.httpBody = try body.data()
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let data: Data
        let response: URLResponse
        do { (data, response) = try await session.data(for: request) }
        catch {
            if Task.isCancelled { throw AIProviderError.cancelled }
            if (error as? URLError)?.code == .timedOut { throw AIProviderError.timeout }
            throw AIProviderError.server("Could not reach the local OpenCode server.")
        }
        guard let response = response as? HTTPURLResponse else {
            throw AIProviderError.invalidOutput
        }
        if response.statusCode == 401 || response.statusCode == 403 {
            throw AIProviderError.authentication
        }
        guard (200..<300).contains(response.statusCode) else {
            throw AIProviderError.server("HTTP \(response.statusCode).")
        }
        guard data.count <= maximumBytes else { throw AIProviderError.outputTooLarge }
        return data.isEmpty ? .null : try AIJSON.decode(data)
    }
}
