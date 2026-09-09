import Foundation

// MARK: - Provider Values
nonisolated enum AIProviderID: String, Codable, CaseIterable, Identifiable, Sendable {
    case apple
    var id: String { rawValue }
    var name: String { "Apple Foundation Model" }
}

nonisolated struct AIOptionChoice: Codable, Equatable, Identifiable, Sendable {
    let id: String
    let name: String
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
    var modelID: String? = nil
    var optionID: String? = nil
}

nonisolated struct AIProviderDiscovery: Sendable {
    let models: [AIModelDescriptor]
    let version: String
    let source: String
    var accountDescription: String? = nil
}

nonisolated struct AIProviderStatus: Sendable {
    var models: [AIModelDescriptor] = []
    var version: String? = nil
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
    var sentenceCompletions = false
    var systemInstructions: String? = nil
}

nonisolated struct AIGenerationResult: Sendable {
    let text: String
    let selection: AIProviderSelection
}

nonisolated enum AIProviderError: Error, LocalizedError, Equatable, Sendable {
    case noActiveProvider, unavailableSelection, timeout, cancelled
    case invalidOutput
    case persistence(String)
    case unavailable(String)
    case generation(String)

    var errorDescription: String? {
        switch self {
        case .noActiveProvider: "Choose an active AI provider in Settings."
        case .unavailableSelection:
            "The selected model or option is unavailable. Review AI Providers in Settings."
        case .timeout: "The provider request timed out."
        case .cancelled: "The provider request was cancelled."
        case .invalidOutput: "The provider returned invalid structured output."
        case .persistence(let detail): "Could not save or load app data: \(detail)"
        case .unavailable(let detail), .generation(let detail): detail
        }
    }
}

// MARK: - Provider Adapter
nonisolated protocol AIProviderAdapter: Sendable {
    func discover() async throws
        -> AIProviderDiscovery
    func generate(
        request: AIGenerationRequest,
        selection: AIProviderSelection,
        model: AIModelDescriptor
    ) async throws -> String
    func shutdown() async
}

extension AIProviderAdapter {
    // MARK: - Shutdown
    nonisolated func shutdown() async {}
}
