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
    static func promptBody(
        request: AIGenerationRequest,
        selection: AIProviderSelection,
        structuredOutput: Bool = true
    ) throws
        -> AIJSON
    {
        guard let id = selection.modelID, let slash = id.firstIndex(of: "/"), slash != id.startIndex
        else {
            throw AIProviderError.unavailableSelection
        }
        let instructions =
            request.sentenceCompletions
            ? SentenceCompletionPrompt.resolvedInstructions(request.systemInstructions)
            : "Respond to the user with your answer in the text field."
        let schema = request.sentenceCompletions ? AITextOutput.sentenceSchema : AITextOutput.schema
        let format: AIJSON
        let system: String
        if structuredOutput {
            format = .object([
                "type": .string("json_schema"),
                "schema": try AIJSON.decode(Data(schema.utf8)),
            ])
            system =
                instructions
                + "\nReturn the result using StructuredOutput. Other tools are unavailable."
        }
        else {
            format = .object(["type": .string("text")])
            system =
                instructions
                + "\nReturn only a JSON object matching this schema, without commentary or tools:\n"
                + schema
        }
        var body: [String: AIJSON] = [
            "system": .string(system),
            "format": format,
            "model": .object([
                "providerID": .string(String(id[..<slash])),
                "modelID": .string(String(id[id.index(after: slash)...])),
            ]),
            "parts": .array([
                .object([
                    "type": .string("text"), "text": .string(request.prompt),
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
                        ]),
                        // OpenCode implements schema output as a tool; keep only that tool enabled.
                        .object([
                            "permission": .string("StructuredOutput"), "pattern": .string("*"),
                            "action": .string("allow"),
                        ]),
                    ]),
                ])
            )
            guard let id = created["id"].string,
                id.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil
            else {
                throw AIProviderError.invalidOutput
            }
            do {
                var response = try await connection.request(
                    "session/\(id)/message",
                    method: "POST",
                    body: Self.promptBody(request: request, selection: selection)
                )
                if Self.requiresAutomaticToolChoice(response) {
                    try Task.checkCancellation()
                    response = try await connection.request(
                        "session/\(id)/message",
                        method: "POST",
                        body: Self.promptBody(
                            request: request,
                            selection: selection,
                            structuredOutput: false
                        )
                    )
                }
                let text = try AITextOutput.openCode(
                    response,
                    sentenceCompletions: request.sentenceCompletions
                )
                await Self.cleanup(connection, id: id, abort: false)
                return text
            }
            catch {
                await Self.cleanup(connection, id: id, abort: true)
                throw error
            }
        }
    }

    // MARK: - Upstream Compatibility
    static func requiresAutomaticToolChoice(_ response: AIJSON) -> Bool {
        guard let message = response["info"]["error"]["data"]["message"].string else {
            return false
        }
        let normalized = message.lowercased()
        return normalized.contains("tool_choice")
            && normalized.range(of: "only.{0,20}auto.{0,30}supported", options: .regularExpression)
                != nil
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
