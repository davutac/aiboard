import Foundation
import SwiftData
import Testing

@testable import Tastko

// MARK: - Provider Service Tests
@MainActor struct AIProviderServiceTests {
    // MARK: - Fixture
    private func fixture(_ adapter: AIFixtureAdapter) throws -> AIProviderService {
        let persistence = AppPersistence(inMemory: true)
        persistence.open()
        let context = try #require(persistence.container?.mainContext)
        for provider in AIProviderID.allCases {
            let configuration = AIProviderConfiguration(providerID: provider.rawValue)
            configuration.executableOverride = "/bin/echo"
            context.insert(configuration)
        }
        try context.save()
        let service = AIProviderService(
            persistence: persistence,
            resolver: AIExecutableResolver(environment: [:]),
            adapters: Dictionary(uniqueKeysWithValues: AIProviderID.allCases.map { ($0, adapter) })
        )
        service.start()
        return service
    }

    // MARK: - Refresh Failure and Cache
    @Test func failedRefreshKeepsCatalogAndSavedMissingModel() async throws {
        let adapter = AIFixtureAdapter()
        let service = try fixture(adapter)
        await service.refreshProvider(.codex)
        #expect(service.statuses[.codex]?.models.count == 2)
        #expect(service.selections[.codex]?.modelID == "fixture")
        var selection = try #require(service.selections[.codex])
        selection.modelID = "removed-model"
        service.updateSelection(selection)
        await adapter.configure(fail: true)
        await service.refreshProvider(.codex)
        #expect(service.statuses[.codex]?.models.count == 2)
        #expect(service.statuses[.codex]?.isCached == true)
        #expect(service.selections[.codex]?.modelID == "removed-model")
        service.selectProvider(.codex)
        await #expect(throws: AIProviderError.unavailableSelection) {
            try await service.generate(AIGenerationRequest(prompt: "test"))
        }
        let context = try #require(service.persistence.container?.mainContext)
        #expect(try context.fetchCount(FetchDescriptor<AIModelCatalogCache>()) == 1)
        let reopened = AIProviderService(persistence: service.persistence)
        reopened.start()
        #expect(reopened.statuses[.codex]?.isCached == true)
        #expect(reopened.statuses[.codex]?.authentication == .unknown)
    }

    // MARK: - Settings Refresh Lifecycle
    @Test func settingsRefreshRepeatsAndStopsOnCancellation() async throws {
        let adapter = AIFixtureAdapter()
        let service = try fixture(adapter)
        let task = Task { await service.refreshProvidersWhileVisible(interval: .milliseconds(30)) }
        defer { task.cancel() }
        try await withAIDeadline(seconds: 3) {
            while await adapter.discoveryCount < AIProviderID.allCases.count * 2 {
                try await Task.sleep(for: .milliseconds(10))
            }
        }
        task.cancel()
        await task.value
        let count = await adapter.discoveryCount
        try await Task.sleep(for: .milliseconds(100))
        #expect(await adapter.discoveryCount == count)
        #expect(service.activeProvider == nil)
        #expect(service.statuses.values.allSatisfy { $0.authentication == .authenticated })
        await service.shutdown()
    }

    // MARK: - Native Provider Routing
    @Test func nativeProviderSkipsExecutableResolution() async throws {
        let adapter = AIFixtureAdapter()
        let service = try fixture(adapter)
        var selection = try #require(service.selections[.apple])
        selection.executableOverride = "/does/not/exist"
        selection.modelID = "fixture"
        service.updateSelection(selection)
        await service.refreshProvider(.apple)
        #expect(service.statuses[.apple]?.error == nil)
        #expect(service.statuses[.apple]?.executable == nil)
        service.selectProvider(.apple)
        let result = try await service.generate(AIGenerationRequest(prompt: "test"))
        #expect(result.selection.provider == .apple)
        #expect(result.text == " output ")
        await service.shutdown()
    }

    // MARK: - Independent Selection
    @Test func activationAndModelChangesPreserveOtherProviders() async throws {
        let service = try fixture(AIFixtureAdapter())
        await service.refreshProviders()
        await #expect(throws: AIProviderError.noActiveProvider) {
            try await service.generate(AIGenerationRequest(prompt: "test"))
        }
        var selection = try #require(service.selections[.codex])
        selection.optionID = "low"
        service.updateSelection(selection)
        service.selectProvider(.codex)
        service.selectProvider(.claude)
        #expect(service.activeProvider == .claude)
        #expect(service.selections[.codex]?.optionID == "low")
        selection.modelID = "no-options"
        service.updateSelection(selection)
        #expect(service.selections[.codex]?.optionID == nil)
        #expect(service.selections[.claude]?.modelID == "fixture")
        service.selectProvider(nil)
        #expect(service.activeProvider == nil)
    }

    // MARK: - Generation Snapshot
    @Test func requestKeepsItsSelectionWhileSettingsChange() async throws {
        let adapter = AIFixtureAdapter()
        await adapter.configure(delay: true)
        let service = try fixture(adapter)
        await service.refreshProviders()
        service.selectProvider(.codex)
        let task = Task { try await service.generate(AIGenerationRequest(prompt: "test")) }
        try await Task.sleep(for: .milliseconds(50))
        service.selectProvider(.claude)
        let result = try await task.value
        #expect(result.selection.provider == .codex)
        #expect(result.text == " output ")
        #expect(service.activeProvider == .claude)
    }
}
