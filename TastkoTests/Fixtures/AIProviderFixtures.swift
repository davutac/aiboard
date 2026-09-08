import Foundation

@testable import Tastko

// MARK: - Fixture Adapter
actor AIFixtureAdapter: AIProviderAdapter {
    private(set) var discoveryCount = 0
    var fail = false
    var delay = false
    let models = [
        AIModelDescriptor(
            id: "fixture",
            name: "Fixture",
            option: AIOptionDescriptor(
                id: "effort",
                name: "Reasoning",
                choices: [AIOptionChoice(id: "low", name: "Low")]
            )
        ), AIModelDescriptor(id: "no-options", name: "No Options"),
    ]

    // MARK: - Configure
    func configure(fail: Bool = false, delay: Bool = false) {
        self.fail = fail
        self.delay = delay
    }

    // MARK: - Discover
    func discover(executable: String, environment: [String: String]) async throws
        -> AIProviderDiscovery
    {
        discoveryCount += 1
        if fail { throw AIProviderError.process("Fixture failure") }
        return AIProviderDiscovery(
            models: models,
            version: "1.0.0",
            authentication: .authenticated,
            source: "Fixture"
        )
    }

    // MARK: - Generate
    func generate(
        request: AIGenerationRequest,
        selection: AIProviderSelection,
        model: AIModelDescriptor,
        executable: String,
        environment: [String: String]
    ) async throws -> String {
        if delay { try await Task.sleep(for: .milliseconds(200)) }
        return " output "
    }
}
