import Foundation
import SwiftData
import Testing

@testable import Tastko

// MARK: - Persistence Tests
@MainActor struct AIPersistenceTests {
    // MARK: - Seed and Reopen
    @Test func reopensVersionedStoreWithoutDuplicateSettings() throws {
        let directory = try AIWorkspace.create()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Tastko.store")
        do {
            let service = AIProviderService(persistence: AppPersistence(storeURL: url))
            service.start()
            service.start()
            #expect(service.activeProvider == nil)
            service.selectProvider(.claude)
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
        let reopened = AIProviderService(persistence: AppPersistence(storeURL: url))
        reopened.start()
        #expect(reopened.activeProvider == .claude)
        for provider in AIProviderID.allCases {
            #expect(reopened.selections[provider]?.modelID == "saved-\(provider.rawValue)")
        }
        #expect(AppMigrationPlan.schemas.count == 1)
        #expect(AppMigrationPlan.stages.isEmpty)
    }

    // MARK: - Existing V1 Store
    @Test func addsAppleToExistingStoreAndPersistsItsSelection() throws {
        let directory = try AIWorkspace.create()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "Tastko.store")
        do {
            let persistence = AppPersistence(storeURL: url)
            persistence.open()
            let context = try #require(persistence.container?.mainContext)
            let settings = AISettings()
            settings.activeProvider = AIProviderID.codex.rawValue
            context.insert(settings)
            for provider in [AIProviderID.codex, .claude, .opencode] {
                let configuration = AIProviderConfiguration(providerID: provider.rawValue)
                configuration.modelID = "saved-\(provider.rawValue)"
                context.insert(configuration)
            }
            try context.save()
        }
        do {
            let service = AIProviderService(persistence: AppPersistence(storeURL: url))
            service.start()
            #expect(service.activeProvider == .codex)
            #expect(service.selections[.codex]?.modelID == "saved-codex")
            service.selectProvider(.apple)
            service.updateSelection(
                AIProviderSelection(provider: .apple, modelID: "system-default")
            )
        }
        let reopened = AIProviderService(persistence: AppPersistence(storeURL: url))
        reopened.start()
        #expect(reopened.activeProvider == .apple)
        #expect(reopened.selections[.apple]?.modelID == "system-default")
        #expect(reopened.selections[.codex]?.modelID == "saved-codex")
        let context = try #require(reopened.persistence.container?.mainContext)
        #expect(try context.fetchCount(FetchDescriptor<AIProviderConfiguration>()) == 4)
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
        let directory = try AIWorkspace.create()
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
}
