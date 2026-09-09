import Foundation

// MARK: - Claude Provider
nonisolated struct ClaudeAIProvider: AIProviderAdapter {
    // MARK: - Environment
    static func environment(_ inherited: [String: String]) -> [String: String] {
        var environment = inherited
        environment["ENABLE_CLAUDEAI_MCP_SERVERS"] = "false"
        environment["CLAUDE_CODE_AUTO_CONNECT_IDE"] = "0"
        environment["CLAUDE_CODE_IDE_SKIP_AUTO_INSTALL"] = "1"
        return environment
    }

    // MARK: - Discovery
    @concurrent func discover(executable: String, environment: [String: String]) async throws
        -> AIProviderDiscovery
    {
        let directory = try AIWorkspace.create()
        defer { try? FileManager.default.removeItem(at: directory) }
        let versionResult = try await AIProcessRunner.run(
            executable: executable,
            arguments: ["--version"],
            environment: environment,
            directory: directory
        )
        let version = try AITextOutput.version(
            String(decoding: versionResult.checked(), as: UTF8.self)
        )
        guard AITextOutput.version(version, atLeast: "2.1.0") else {
            throw AIProviderError.unsupportedVersion(version)
        }
        let authResult = try await AIProcessRunner.run(
            executable: executable,
            arguments: ["auth", "status", "--json"],
            environment: Self.environment(environment),
            directory: directory
        )
        let auth = try AIJSON.decode(authResult.stdout)
        guard let loggedIn = auth["loggedIn"].bool else { throw AIProviderError.invalidOutput }
        return AIProviderDiscovery(
            models: try ClaudeModelCatalog.models(version: version),
            version: version,
            authentication: loggedIn ? .authenticated : .signedOut,
            source: "Bundled Claude catalog",
            accountDescription: loggedIn
                ? auth["email"].string.map { "Authenticated as \($0)" } : nil
        )
    }

    // MARK: - Generation Arguments
    static func arguments(selection: AIProviderSelection, model: AIModelDescriptor) throws
        -> [String]
    {
        var settings: [String: AIJSON] = ["disableAllHooks": .bool(true)]
        var arguments = [
            "-p", "--output-format", "json", "--json-schema", AITextOutput.schema,
            "--model", model.id, "--tools", "", "--disable-slash-commands", "--strict-mcp-config",
            "--mcp-config", "{\"mcpServers\":{}}", "--permission-mode", "dontAsk",
            "--no-session-persistence",
            "--setting-sources", "user",
        ]
        if let option = selection.optionID {
            if model.option?.id == "thinking" {
                settings["alwaysThinkingEnabled"] = .bool(option == "on")
            }
            else {
                let argument =
                    model.option?.choices.first(where: { $0.id == option })?.argument ?? option
                arguments += ["--effort", argument]
            }
        }
        arguments += [
            "--settings", String(decoding: try AIJSON.object(settings).data(), as: UTF8.self),
        ]
        return arguments
    }

    // MARK: - Generate
    func generate(
        request: AIGenerationRequest,
        selection: AIProviderSelection,
        model: AIModelDescriptor,
        executable: String,
        environment: [String: String]
    ) async throws -> String {
        let directory = try AIWorkspace.create()
        defer { try? FileManager.default.removeItem(at: directory) }
        let result = try await AIProcessRunner.run(
            executable: executable,
            arguments: Self.arguments(selection: selection, model: model),
            environment: Self.environment(environment),
            directory: directory,
            input: Data(AITextOutput.prompt(request).utf8),
            timeout: request.timeout
        )
        return try AITextOutput.claude(result.checked())
    }
}
