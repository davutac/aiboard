import Foundation
import SwiftData
import Testing

@testable import Tastko

// MARK: - Persistence Tests
@MainActor struct AIPersistenceTests {
    // MARK: - Seed and Reopen
    @Test func reopensVersionedStoreWithoutDuplicateSettings() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Tastko.store")
        do {
            let service = AIProviderService(
                persistence: AppPersistence(storeURL: url)
            )
            service.start()
            service.start()
            #expect(service.activeProvider == nil)
            service.selectProvider(.apple)
            for provider in AIProviderID.allCases {
                service.updateSelection(
                    AIProviderSelection(provider: provider, modelID: "saved-\(provider.rawValue)")
                )
            }
            let context = try #require(service.persistence.container?.mainContext)
            #expect(try context.fetchCount(FetchDescriptor<AISettings>()) == 1)
            #expect(
                try context.fetchCount(FetchDescriptor<AIProviderConfiguration>())
                    == AIProviderID.allCases.count
            )
        }
        let reopened = AIProviderService(
            persistence: AppPersistence(storeURL: url)
        )
        reopened.start()
        #expect(reopened.activeProvider == .apple)
        for provider in AIProviderID.allCases {
            #expect(reopened.selections[provider]?.modelID == "saved-\(provider.rawValue)")
        }
        #expect(AppMigrationPlan.schemas.count == 1)
        #expect(AppMigrationPlan.stages.isEmpty)
    }

    // MARK: - Legacy Provider Migration
    @Test(arguments: ["codex", "claude", "opencode", nil])
    func migratesLegacySelectionAndPreservesOff(_ active: String?) throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Tastko.store")
        do {
            let persistence = AppPersistence(storeURL: url)
            persistence.open()
            let context = try #require(persistence.container?.mainContext)
            let settings = AISettings()
            settings.activeProvider = active
            context.insert(settings)
            let legacy = AIProviderConfiguration(providerID: "codex")
            legacy.executableOverride = "/legacy/path"
            legacy.modelID = "legacy-model"
            context.insert(legacy)
            try context.save()
        }
        let service = AIProviderService(persistence: AppPersistence(storeURL: url))
        service.start()
        #expect(service.availableProviders == [.apple])
        #expect(service.activeProvider == (active == nil ? nil : .apple))
        #expect(service.selections[.apple]?.modelID == "system-default")
        let context = try #require(service.persistence.container?.mainContext)
        let legacy = try #require(
            context.fetch(FetchDescriptor<AIProviderConfiguration>()).first {
                $0.providerID == "codex"
            }
        )
        #expect(legacy.modelID == "legacy-model")
        service.start()
        #expect(service.activeProvider == (active == nil ? nil : .apple))
    }

    // MARK: - Previously Cleared Apple Selection
    @Test func restoresEmptyAppleModelWithoutChangingUnavailableSelections() throws {
        let persistence = AppPersistence(inMemory: true)
        persistence.open()
        let context = try #require(persistence.container?.mainContext)
        let configuration = AIProviderConfiguration(providerID: AIProviderID.apple.rawValue)
        context.insert(configuration)
        try context.save()
        let service = AIProviderService(persistence: persistence)
        service.start()
        #expect(configuration.modelID == AppleFoundationModelProvider.modelID)
        #expect(service.selections[.apple]?.modelID == AppleFoundationModelProvider.modelID)
        configuration.modelID = "unavailable-saved-model"
        try context.save()
        service.start()
        #expect(service.selections[.apple]?.modelID == "unavailable-saved-model")
    }

    // MARK: - Non-Destructive Failure
    @Test func invalidStoreIsPreservedOnOpenAndRetry() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Tastko.store")
        let original = Data("Do not replace this store".utf8)
        try original.write(to: url)
        let persistence = AppPersistence(storeURL: url)
        persistence.open()
        #expect(persistence.container == nil)
        #expect(persistence.error != nil)
        persistence.open()
        #expect(try Data(contentsOf: url) == original)
    }

    // MARK: - Application Store Isolation
    @Test func storeNamesAreGeneralAndBundleScoped() {
        let debug = AppPersistence.defaultStoreURL(
            bundleIdentifier: "com.davutcaliskan.Tastko.debug"
        )
        let release = AppPersistence.defaultStoreURL(bundleIdentifier: "com.davutcaliskan.Tastko")
        #expect(debug != release)
        #expect(debug.lastPathComponent == "Tastko.store")
        #expect(release.lastPathComponent == "Tastko.store")
    }
    // MARK: - Temporary Store
    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

}
