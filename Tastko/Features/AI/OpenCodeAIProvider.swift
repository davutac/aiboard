import Foundation

// MARK: - OpenCode Provider
nonisolated struct OpenCodeAIProvider: AIProviderAdapter {
    let owner: AIOpenCodeServerOwner

    // MARK: - Discovery
    @concurrent func discover(executable: String, environment: [String: String]) async throws
        -> AIProviderDiscovery
    {
        try await withAIDeadline(seconds: 45) {
            try await owner.withServer(executable: executable, environment: environment) {
                connection in
                let health = try await connection.request("global/health")
                guard health["healthy"].bool == true, let version = health["version"].string else {
                    throw AIProviderError.invalidOutput
                }
                guard AITextOutput.version(version, atLeast: "1.14.19") else {
                    throw AIProviderError.unsupportedVersion(version)
                }
                // OpenCode returns its complete upstream catalog, including disconnected providers.
                let inventory = try await connection.request(
                    "provider",
                    maximumBytes: 32 * 1024 * 1024
                )
                return AIProviderDiscovery(
                    models: Self.models(inventory),
                    version: version,
                    authentication: inventory["connected"].array.isEmpty
                        ? .unknown : .authenticated,
                    source: "OpenCode CLI",
                    accountDescription: inventory["connected"].array.isEmpty
                        ? nil
                        : "Authenticated · \(inventory["connected"].array.count) upstream providers connected through OpenCode."
                )
            }
        }
    }

    // MARK: - Model Mapping
    static func models(_ inventory: AIJSON) -> [AIModelDescriptor] {
        let connected = Set(inventory["connected"].array.compactMap(\.string))
        return inventory["all"].array.flatMap { provider -> [AIModelDescriptor] in
            guard let providerID = provider["id"].string, connected.contains(providerID) else {
                return []
            }
            return provider["models"].object.sorted(by: { $0.key < $1.key }).compactMap {
                key,
                model in
                if model["status"].string == "deprecated" { return nil }
                let variants = model["variants"].object.filter { $0.value["disabled"].bool != true }
                    .keys.sorted()
                return AIModelDescriptor(
                    id: providerID + "/" + key,
                    name:
                        "\(model["name"].string ?? key) · \(provider["name"].string ?? providerID)",
                    option: variants.isEmpty
                        ? nil
                        : AIOptionDescriptor(
                            id: "variant",
                            name: "Variant",
                            choices: variants.map { AIOptionChoice(id: $0, name: $0) }
                        ),
                    isDefault: inventory["default"][providerID].string == key
                )
            }
        }
    }

    // MARK: - Prompt Body
    static func promptBody(request: AIGenerationRequest, selection: AIProviderSelection) throws
        -> AIJSON
    {
        guard let id = selection.modelID, let slash = id.firstIndex(of: "/"), slash != id.startIndex
        else {
            throw AIProviderError.unavailableSelection
        }
        var body: [String: AIJSON] = [
            "model": .object([
                "providerID": .string(String(id[..<slash])),
                "modelID": .string(String(id[id.index(after: slash)...])),
            ]),
            "parts": .array([
                .object([
                    "type": .string("text"), "text": .string(AITextOutput.prompt(request.prompt)),
                ])
            ]),
        ]
        if let variant = selection.optionID { body["variant"] = .string(variant) }
        return .object(body)
    }

    // MARK: - Generate
    func generate(
        request: AIGenerationRequest,
        selection: AIProviderSelection,
        model: AIModelDescriptor,
        executable: String,
        environment: [String: String]
    ) async throws -> String {
        try await owner.withServer(executable: executable, environment: environment) { connection in
            let created = try await connection.request(
                "session",
                method: "POST",
                body: .object([
                    "title": .string("Tastko text generation"),
                    "permission": .array([
                        .object([
                            "permission": .string("*"), "pattern": .string("*"),
                            "action": .string("deny"),
                        ])
                    ]),
                ])
            )
            guard let id = created["id"].string,
                id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
            else {
                throw AIProviderError.invalidOutput
            }
            do {
                let response = try await connection.request(
                    "session/\(id)/message",
                    method: "POST",
                    body: Self.promptBody(request: request, selection: selection)
                )
                let text = try AITextOutput.openCode(response)
                await Self.cleanup(connection, id: id, abort: false)
                return text
            }
            catch {
                await Self.cleanup(connection, id: id, abort: true)
                throw error
            }
        }
    }

    // MARK: - Session Cleanup
    private static func cleanup(_ connection: AIOpenCodeConnection, id: String, abort: Bool) async {
        // Cleanup must run even when the parent task was cancelled.
        await Task.detached {
            try? await withAIDeadline(seconds: 5) {
                if abort {
                    _ = try? await connection.request("session/\(id)/abort", method: "POST")
                }
                _ = try? await connection.request("session/\(id)", method: "DELETE")
            }
        }.value
    }

    // MARK: - Shutdown
    func shutdown() async { await owner.shutdown() }
}
