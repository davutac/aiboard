import Foundation

// MARK: - Executable Resolver
actor AIExecutableResolver {
    private var cachedEnvironment: [String: String]?

    // MARK: - Initialization
    init(environment: [String: String]? = nil) { cachedEnvironment = environment }

    // MARK: - Resolve Environment
    func environment() async -> [String: String] {
        if let cachedEnvironment { return cachedEnvironment }
        var environment = ProcessInfo.processInfo.environment
        let inheritedPath = environment["PATH"] ?? "/usr/bin:/bin"
        let shell = environment["SHELL"] ?? "/bin/zsh"
        // Only request PATH, never serialize the user's complete login environment.
        if let result = try? await AIProcessRunner.run(
            executable: shell,
            arguments: ["-ilc", "printf '\\0TASTKO_PATH=%s\\0' \"$PATH\""],
            environment: environment,
            directory: FileManager.default.temporaryDirectory,
            timeout: 5
        ), result.exitCode == 0 {
            let text = String(decoding: result.stdout, as: UTF8.self)
            if let start = text.range(of: "\0TASTKO_PATH="),
                let end = text[start.upperBound...].firstIndex(of: "\0")
            {
                environment["PATH"] = String(text[start.upperBound..<end]) + ":" + inheritedPath
            }
        }
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        environment["PATH"] =
            (environment["PATH"] ?? inheritedPath)
            + ":/opt/homebrew/bin:/usr/local/bin:\(home)/.local/bin:\(home)/.opencode/bin:\(home)/.bun/bin"
        // Child CLIs are independent requests, not nested agent sessions.
        for key in ["CLAUDECODE", "CLAUDE_CODE_ENTRYPOINT", "CODEX_THREAD_ID"] {
            environment.removeValue(forKey: key)
        }
        cachedEnvironment = environment
        return environment
    }

    // MARK: - Resolve Provider Runtime
    func resolve(_ selection: AIProviderSelection) async throws
        -> (executable: String, environment: [String: String])
    {
        // System providers use no executable or shell environment.
        guard selection.provider.usesCLI else { return ("", [:]) }
        let environment = await environment()
        try Task.checkCancellation()
        return (
            try Self.resolve(
                selection.provider,
                override: selection.executableOverride,
                environment: environment
            ), environment
        )
    }

    // MARK: - Resolve Executable
    nonisolated static func resolve(
        _ provider: AIProviderID,
        override: String,
        environment: [String: String]
    ) throws -> String {
        let override = override.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates: [String]
        if !override.isEmpty {
            candidates = [(override as NSString).expandingTildeInPath]
        }
        else {
            candidates = (environment["PATH"] ?? "").split(separator: ":").filter {
                $0.hasPrefix("/")
            }
            .map { String($0) + "/" + provider.rawValue }
        }
        for path in candidates where path.hasPrefix("/") {
            var directory: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &directory),
                !directory.boolValue,
                FileManager.default.isExecutableFile(atPath: path)
            {
                return path
            }
        }
        throw AIProviderError.executableNotFound(provider.name)
    }
}
