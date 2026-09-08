import Foundation

// MARK: - Provider Values
nonisolated enum AIProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case codex, claude, opencode, apple
    var id: String { rawValue }
    var usesCLI: Bool { self != .apple }
    var name: String {
        switch self {
        case .codex: "Codex"
        case .claude: "Claude Code"
        case .opencode: "OpenCode"
        case .apple: "Apple Foundation Model"
        }
    }
    var loginCommand: String? {
        switch self {
        case .codex: "codex login"
        case .claude: "claude auth login"
        case .opencode: "opencode auth login"
        case .apple: nil
        }
    }
    var website: URL {
        let address =
            switch self {
            case .codex: "https://developers.openai.com/codex/cli/"
            case .claude: "https://code.claude.com/docs/en/setup"
            case .opencode: "https://opencode.ai/docs/"
            case .apple: "https://support.apple.com/121115"
            }
        return URL(string: address)!
    }
}

nonisolated struct AIOptionChoice: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    var argument: String? = nil
}

nonisolated struct AIOptionDescriptor: Codable, Equatable, Sendable {
    let id: String
    let name: String
    let choices: [AIOptionChoice]
    var defaultValue: String? = nil
}

nonisolated struct AIModelDescriptor: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    var option: AIOptionDescriptor? = nil
    var isDefault = false
}

nonisolated struct AIProviderSelection: Codable, Equatable, Sendable {
    let provider: AIProviderID
    var executableOverride = ""
    var modelID: String? = nil
    var optionID: String? = nil
}

nonisolated enum AIAuthenticationStatus: String, Sendable {
    case authenticated, signedOut, unknown, notRequired
    var label: String {
        switch self {
        case .authenticated: "Authenticated"
        case .signedOut: "Sign-in required"
        case .unknown: "Authentication not verified"
        case .notRequired: "Not required"
        }
    }
}

nonisolated struct AIProviderDiscovery: Sendable {
    let models: [AIModelDescriptor]
    let version: String
    let authentication: AIAuthenticationStatus
    let source: String
    var accountDescription: String? = nil
}

nonisolated struct AIProviderStatus: Sendable {
    var models: [AIModelDescriptor] = []
    var version: String? = nil
    var executable: String? = nil
    var authentication: AIAuthenticationStatus = .unknown
    var source = ""
    var refreshedAt: Date? = nil
    var isCached = false
    var isRefreshing = false
    var error: String? = nil
    var accountDescription: String? = nil
}

// MARK: - Generation API
nonisolated struct AIGenerationRequest: Sendable {
    let prompt: String
    var timeout: TimeInterval = 180
}

nonisolated struct AIGenerationResult: Sendable {
    let text: String
    let selection: AIProviderSelection
}

nonisolated enum AIProviderError: Error, LocalizedError, Equatable, Sendable {
    case noActiveProvider, unavailableSelection, authentication, timeout, cancelled
    case executableNotFound(String)
    case unsupportedVersion(String)
    case process(String)
    case server(String)
    case invalidOutput
    case persistence(String)
    case outputTooLarge
    case unavailable(String)
    case generation(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProvider: "Choose an active AI provider in Settings."
        case .unavailableSelection:
            "The selected model or option is unavailable. Review AI Providers in Settings."
        case .authentication:
            "The provider requires authentication. Sign in using its CLI, then refresh."
        case .timeout: "The provider request timed out."
        case .cancelled: "The provider request was cancelled."
        case .executableNotFound(let name):
            "Could not find an executable for \(name). Install the CLI or choose its path."
        case .unsupportedVersion(let version):
            "Unsupported CLI version: \(version). Update the provider CLI."
        case .process(let detail): "Provider process failed: \(detail)"
        case .server(let detail): "Provider server failed: \(detail)"
        case .invalidOutput: "The provider returned invalid structured output."
        case .persistence(let detail): "Could not save or load app data: \(detail)"
        case .outputTooLarge: "The provider exceeded the output limit."
        case .unavailable(let detail), .generation(let detail): detail
        }
    }
}

// MARK: - Provider Adapter
nonisolated protocol AIProviderAdapter: Sendable {
    func discover(executable: String, environment: [String: String]) async throws
        -> AIProviderDiscovery
    func generate(
        request: AIGenerationRequest,
        selection: AIProviderSelection,
        model: AIModelDescriptor,
        executable: String,
        environment: [String: String]
    ) async throws -> String
    func shutdown() async
}

extension AIProviderAdapter {
    // MARK: - Shutdown
    nonisolated func shutdown() async {}
}
