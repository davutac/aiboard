import Foundation
import Observation
import SwiftData

// MARK: - AI Provider Service
@Observable @MainActor
final class AIProviderService {
    let persistence: AppPersistence
    private(set) var activeProvider: AIProviderID?
    private(set) var selections: [AIProviderID: AIProviderSelection] = [:]
    private(set) var statuses: [AIProviderID: AIProviderStatus] = [:]
    private(set) var storageError: String?
    @ObservationIgnored private let adapters: [AIProviderID: any AIProviderAdapter]
    private struct Refresh {
        let id: UUID
        let task: Task<Void, Never>
    }
    @ObservationIgnored private var refreshes: [AIProviderID: Refresh] = [:]
    @ObservationIgnored private var generations: [UUID: Task<AIGenerationResult, Error>] = [:]
    @ObservationIgnored private var stopped = false

    // MARK: - Initialization
    init(
        persistence: AppPersistence,
        adapters: [AIProviderID: any AIProviderAdapter]? = nil
    ) {
        self.persistence = persistence
        self.adapters = adapters ?? [.apple: AppleFoundationModelProvider()]
        for provider in AIProviderID.allCases {
            selections[provider] = AIProviderSelection(provider: provider)
            statuses[provider] = AIProviderStatus()
        }
    }

    // MARK: - Available Providers
    var availableProviders: [AIProviderID] {
        AIProviderID.allCases.filter { adapters[$0] != nil }
    }

    // MARK: - Open Persistence
    func start() {
        persistence.open()
        guard let context = persistence.container?.mainContext else { return }
        do {
            let settings = try context.fetch(FetchDescriptor<AISettings>()).first ?? AISettings()
            if settings.modelContext == nil { context.insert(settings) }
            var configurations = try context.fetch(FetchDescriptor<AIProviderConfiguration>())
            for provider in AIProviderID.allCases
            where !configurations.contains(where: { $0.providerID == provider.rawValue }) {
                let configuration = AIProviderConfiguration(providerID: provider.rawValue)
                context.insert(configuration)
                configurations.append(configuration)
            }
            for configuration in configurations
            where configuration.providerID == AIProviderID.apple.rawValue
                && configuration.modelID == nil
            {
                configuration.modelID = AppleFoundationModelProvider.modelID
            }
            if let saved = settings.activeProvider, saved != AIProviderID.apple.rawValue {
                settings.activeProvider =
                    adapters[.apple] == nil ? nil : AIProviderID.apple.rawValue
            }
            try context.save()
            activeProvider = settings.activeProvider.flatMap(AIProviderID.init(rawValue:))
            for configuration in configurations {
                guard let provider = AIProviderID(rawValue: configuration.providerID) else {
                    continue
                }
                selections[provider] = AIProviderSelection(
                    provider: provider,
                    modelID: configuration.modelID,
                    optionID: configuration.optionID
                )
            }
            for cache in try context.fetch(FetchDescriptor<AIModelCatalogCache>()) {
                guard let provider = AIProviderID(rawValue: cache.providerID),
                    let models = try? JSONDecoder().decode(
                        [AIModelDescriptor].self,
                        from: cache.modelsJSON
                    )
                else { continue }
                statuses[provider] = AIProviderStatus(
                    models: models,
                    version: cache.cliVersion,
                    source: cache.source,
                    refreshedAt: cache.refreshedAt,
                    isCached: true
                )
            }
            storageError = nil
        }
        catch {
            context.rollback()
            storageError = error.localizedDescription
        }
    }

    // MARK: - Persistence Transaction
    private func save(_ update: (ModelContext) throws -> Void) -> Bool {
        guard let context = persistence.container?.mainContext else { return false }
        do {
            try update(context)
            try context.save()
            storageError = nil
            return true
        }
        catch {
            context.rollback()
            storageError = error.localizedDescription
            return false
        }
    }

    // MARK: - Select Provider
    func selectProvider(_ provider: AIProviderID?) {
        if let provider, adapters[provider] == nil { return }
        if save({ context in
            guard let settings = try context.fetch(FetchDescriptor<AISettings>()).first else {
                throw AIProviderError.persistence("Settings missing.")
            }
            settings.activeProvider = provider?.rawValue
        }) {
            activeProvider = provider
        }
    }

    // MARK: - Save Configuration
    func updateSelection(_ selection: AIProviderSelection) {
        let old = selections[selection.provider]
        var selection = selection
        if old?.modelID != selection.modelID {
            let choices =
                statuses[selection.provider]?.models.first(where: { $0.id == selection.modelID })?
                .option?.choices ?? []
            if !choices.contains(where: { $0.id == selection.optionID }) {
                selection.optionID = nil
            }
        }
        guard
            save({ context in
                guard
                    let configuration = try context.fetch(
                        FetchDescriptor<AIProviderConfiguration>()
                    ).first(where: { $0.providerID == selection.provider.rawValue })
                else {
                    throw AIProviderError.persistence("Provider configuration missing.")
                }
                configuration.modelID = selection.modelID
                configuration.optionID = selection.optionID
            })
        else { return }
        selections[selection.provider] = selection
    }

    // MARK: - Refresh All Providers
    func refreshProviders(onlyIfStale: Bool = false) async {
        await withTaskGroup(of: Void.self) { group in
            for provider in availableProviders {
                let status = statuses[provider] ?? AIProviderStatus()
                if onlyIfStale, !status.isCached, let refreshed = status.refreshedAt,
                    Date().timeIntervalSince(refreshed) < 300
                {
                    continue
                }
                group.addTask { await self.refreshProvider(provider) }
            }
        }
    }

    // MARK: - Refresh While Settings Are Visible
    func refreshProvidersWhileVisible(interval: Duration = .seconds(300)) async {
        guard !Task.isCancelled, !stopped else { return }
        await refreshProviders(onlyIfStale: true)
        while !Task.isCancelled && !stopped {
            do { try await Task.sleep(for: interval) }
            catch { return }
            guard !Task.isCancelled, !stopped else { return }
            await refreshProviders()
        }
    }

    // MARK: - Refresh Provider
    func refreshProvider(_ provider: AIProviderID) async {
        guard !stopped, persistence.container != nil, selections[provider] != nil,
            let adapter = adapters[provider]
        else { return }
        if let existing = refreshes[provider] {
            await existing.task.value
            return
        }
        let refreshID = UUID()
        let task = Task { [weak self] in
            guard let self else { return }
            statuses[provider]?.isRefreshing = true
            statuses[provider]?.error = nil
            do {
                let discovery = try await adapter.discover()
                try Task.checkCancellation()
                let now = Date()
                var modelIDs: Set<String> = []
                let models = discovery.models.filter { modelIDs.insert($0.id).inserted }
                cacheCatalog(discovery, models: models, provider: provider, refreshedAt: now)
                statuses[provider] = AIProviderStatus(
                    models: models,
                    version: discovery.version,
                    source: discovery.source,
                    refreshedAt: now,
                    accountDescription: discovery.accountDescription
                )
                // Preserve saved models even when they disappear from the catalog.
                if var current = selections[provider], current.modelID == nil,
                    let model = models.first(where: \.isDefault) ?? models.first
                {
                    current.modelID = model.id
                    updateSelection(current)
                }
            }
            catch {
                guard !Task.isCancelled else { return }
                statuses[provider]?.isRefreshing = false
                let hasModels = !(statuses[provider]?.models.isEmpty ?? true)
                statuses[provider]?.isCached = hasModels
                statuses[provider]?.accountDescription = nil
                statuses[provider]?.error = error.localizedDescription
            }
        }
        refreshes[provider] = Refresh(id: refreshID, task: task)
        await task.value
        if refreshes[provider]?.id == refreshID { refreshes[provider] = nil }
    }

    // MARK: - Cache Successful Discovery
    private func cacheCatalog(
        _ discovery: AIProviderDiscovery,
        models: [AIModelDescriptor],
        provider: AIProviderID,
        refreshedAt: Date
    ) {
        _ = save { context in
            let data = try JSONEncoder().encode(models)
            if let cache = try context.fetch(FetchDescriptor<AIModelCatalogCache>()).first(
                where: { $0.providerID == provider.rawValue })
            {
                cache.modelsJSON = data
                cache.cliVersion = discovery.version
                cache.source = discovery.source
                cache.refreshedAt = refreshedAt
            }
            else {
                context.insert(
                    AIModelCatalogCache(
                        providerID: provider.rawValue,
                        modelsJSON: data,
                        cliVersion: discovery.version,
                        source: discovery.source,
                        refreshedAt: refreshedAt
                    )
                )
            }
        }
    }

    // MARK: - Generate Complete Text
    func generate(_ request: AIGenerationRequest) async throws -> AIGenerationResult {
        guard !stopped else { throw AIProviderError.cancelled }
        guard persistence.container != nil, storageError == nil else {
            throw AIProviderError.persistence(
                storageError ?? persistence.error ?? "Store unavailable."
            )
        }
        guard let provider = activeProvider else { throw AIProviderError.noActiveProvider }
        guard let selection = selections[provider], let adapter = adapters[provider],
            let model = statuses[provider]?.models.first(where: { $0.id == selection.modelID }),
            selection.optionID == nil
                || model.option?.choices.contains(where: { $0.id == selection.optionID }) == true
        else {
            throw AIProviderError.unavailableSelection
        }
        let task = Task.detached {
            try await withAIDeadline(seconds: request.timeout) {
                let text = try await adapter.generate(
                    request: request,
                    selection: selection,
                    model: model
                )
                return AIGenerationResult(text: text, selection: selection)
            }
        }
        let id = UUID()
        generations[id] = task
        defer { generations[id] = nil }
        return try await withTaskCancellationHandler {
            try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    // MARK: - Shutdown
    func shutdown() async {
        stopped = true
        let refreshTasks = refreshes.values.map(\.task)
        let requests = Array(generations.values)
        for task in refreshTasks { task.cancel() }
        for task in requests { task.cancel() }
        for task in requests { _ = try? await task.value }
        for task in refreshTasks { await task.value }
        for adapter in adapters.values { await adapter.shutdown() }
    }
}
