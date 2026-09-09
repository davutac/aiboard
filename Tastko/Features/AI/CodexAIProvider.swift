import Foundation

// MARK: - Codex Provider
nonisolated struct CodexAIProvider: AIProviderAdapter {
    // MARK: - Discovery
    @concurrent func discover(executable: String, environment: [String: String]) async throws
        -> AIProviderDiscovery
    {
        try await withAIDeadline(seconds: 30) {
            let directory = try AIWorkspace.create()
            defer { try? FileManager.default.removeItem(at: directory) }
            let child = try AIChildProcess(
                executable: executable,
                arguments: ["app-server"],
                environment: environment,
                directory: directory
            )
            defer { child.stop() }
            return try await withTaskCancellationHandler {
                let rpc = AICodexRPC(child: child)
                let initialized = try await rpc.request(
                    "initialize",
                    params: .object([
                        "clientInfo": .object([
                            "name": .string("tastko"), "version": .string("1.0"),
                        ]),
                        "capabilities": .object(["experimentalApi": .bool(true)]),
                    ])
                )
                try await rpc.notify("initialized")
                let account = try await rpc.request("account/read", params: .object([:]))
                var models: [AIModelDescriptor] = []
                var cursor: AIJSON = .null
                var cursors: Set<String> = []
                repeat {
                    let page = try await rpc.request(
                        "model/list",
                        params: .object(["cursor": cursor, "limit": .number(100)])
                    )
                    models += Self.models(page)
                    cursor = page["nextCursor"]
                    if let token = cursor.string, !cursors.insert(token).inserted {
                        throw AIProviderError.invalidOutput
                    }
                } while cursor.string != nil
                return AIProviderDiscovery(
                    models: models,
                    version: try AITextOutput.version(initialized["userAgent"].string ?? ""),
                    authentication: account["account"] != .null
                        ? .authenticated
                        : account["requiresOpenaiAuth"].bool == true ? .signedOut : .unknown,
                    source: "Codex CLI",
                    accountDescription: Self.accountDescription(account["account"])
                )
            } onCancel: {
                child.stop()
            }
        }
    }

    // MARK: - Transient Account Description
    static func accountDescription(_ account: AIJSON) -> String? {
        guard account != .null else { return nil }
        var description =
            account["email"].string.map { "Authenticated as \($0)" } ?? "Authenticated"
        if let plan = account["planType"].string, !plan.isEmpty {
            description += " · ChatGPT \(plan.capitalized)"
        }
        return description
    }

    // MARK: - Model Mapping
    static func models(_ page: AIJSON) -> [AIModelDescriptor] {
        page["data"].array.compactMap { model in
            guard let id = model["model"].string, !id.isEmpty else { return nil }
            let choices = model["supportedReasoningEfforts"].array.compactMap {
                value -> AIOptionChoice? in
                guard let effort = value["reasoningEffort"].string else { return nil }
                return AIOptionChoice(id: effort, name: effort.capitalized)
            }
            return AIModelDescriptor(
                id: id,
                name: model["displayName"].string ?? id,
                option: choices.isEmpty
                    ? nil
                    : AIOptionDescriptor(
                        id: "reasoningEffort",
                        name: "Reasoning",
                        choices: choices,
                        defaultValue: model["defaultReasoningEffort"].string
                    ),
                isDefault: model["isDefault"].bool ?? false
            )
        }
    }

    // MARK: - Generation Arguments
    static func arguments(
        selection: AIProviderSelection,
        schema: URL,
        output: URL,
        mcpNames: [String]
    ) throws -> [String] {
        var arguments = [
            "exec", "--ephemeral", "--skip-git-repo-check", "-s", "read-only",
            "--model", selection.modelID ?? "", "--output-schema", schema.path,
            "--output-last-message", output.path,
            "-c", "approval_policy=\"never\"", "-c", "web_search=\"disabled\"", "-c",
            "project_doc_max_bytes=0",
        ]
        // Explicitly turn off execution/integration features inherited from the user's global config.
        for feature in [
            "shell_tool", "unified_exec", "apply_patch_freeform", "apps", "plugins", "hooks",
            "codex_hooks",
            "multi_agent", "multi_agent_v2", "js_repl", "computer_use", "browser_use",
            "image_generation",
        ] {
            arguments += ["-c", "features.\(feature)=false"]
        }
        for name in mcpNames {
            // Codex splits override paths on dots and does not parse quoted path segments.
            guard name.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil else {
                throw AIProviderError.process(
                    "Codex MCP names must use letters, numbers, hyphens or underscores for restricted generation."
                )
            }
            arguments += ["-c", "mcp_servers.\(name).enabled=false"]
        }
        if let option = selection.optionID {
            let quoted = String(
                decoding: try JSONEncoder().encode(option),
                as: UTF8.self
            )
            arguments += ["-c", "model_reasoning_effort=\(quoted)"]
        }
        return arguments + ["-"]
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
        let schema = directory.appending(path: "schema.json")
        let output = directory.appending(path: "output.json")
        try Data(AITextOutput.schema.utf8).write(to: schema)
        // Listing configuration does not start MCP servers. Disable each configured entry explicitly.
        // Use the same plugin/app feature settings as generation. Plugin-derived entries do not
        // necessarily have a config-file transport and cannot be overridden as configured servers.
        let mcpResult = try await AIProcessRunner.run(
            executable: executable,
            arguments: [
                "-c", "features.plugins=false", "-c", "features.apps=false", "mcp", "list",
                "--json",
            ],
            environment: environment,
            directory: directory
        )
        let mcpNames = try AIJSON.decode(mcpResult.checked()).array.compactMap { $0["name"].string }
        let result = try await AIProcessRunner.run(
            executable: executable,
            arguments: try Self.arguments(
                selection: selection,
                schema: schema,
                output: output,
                mcpNames: mcpNames
            ),
            environment: environment,
            directory: directory,
            input: Data(AITextOutput.prompt(request).utf8),
            timeout: request.timeout
        )
        _ = try result.checked()
        guard let size = try output.resourceValues(forKeys: [.fileSizeKey]).fileSize,
            size <= 4 * 1024 * 1024
        else {
            throw AIProviderError.outputTooLarge
        }
        return try AITextOutput.decode(Data(contentsOf: output))
    }
}
