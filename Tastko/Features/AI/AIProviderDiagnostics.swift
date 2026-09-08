#if DEBUG
    import Foundation

    // MARK: - Developer Diagnostics
    enum AIProviderDiagnostics {
        // MARK: - Argument Value
        private static func argument(_ name: String, in arguments: [String]) -> String? {
            guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1)
            else {
                return nil
            }
            return arguments[index + 1]
        }

        // MARK: - Run Explicit Diagnostics
        @MainActor static func run(arguments: [String]) async -> Int32 {
            let service = AIProviderService(persistence: AppPersistence(inMemory: true))
            service.start()
            let providerArgument = argument("--provider", in: arguments)
            let modelArgument = argument("--model", in: arguments)
            let promptArgument = argument("--prompt", in: arguments)
            let providers = AIProviderID.allCases.filter { provider in
                providerArgument == nil || providerArgument == provider.rawValue
            }
            var failed = false
            for provider in providers {
                await service.refreshProvider(provider)
                let status = service.statuses[provider] ?? AIProviderStatus()
                print(
                    "\(provider.rawValue): version=\(status.version ?? "unknown") auth=\(status.authentication.rawValue) models=\(status.models.count)"
                )
                for model in status.models {
                    print(
                        "  \(model.id): \(model.option?.choices.map(\.id).joined(separator: ",") ?? "default")"
                    )
                }
                if let error = status.error {
                    print("  Discovery failed: \(error)")
                    failed = true
                    continue
                }
                guard arguments.contains("--generate") else { continue }
                guard
                    status.authentication == .authenticated || status.authentication == .notRequired
                else {
                    print("  Generation skipped: authentication not verified.")
                    continue
                }
                service.selectProvider(provider)
                if let modelArgument, var selection = service.selections[provider] {
                    selection.modelID = modelArgument
                    service.updateSelection(selection)
                }
                if var selection = service.selections[provider],
                    let model = status.models.first(where: { $0.id == selection.modelID }),
                    model.option?.choices.contains(where: { $0.id == "low" }) == true
                {
                    selection.optionID = "low"
                    service.updateSelection(selection)
                }
                let start = Date()
                do {
                    let result = try await service.generate(
                        AIGenerationRequest(
                            prompt: promptArgument ?? "Return exactly Tastko AI OK as text."
                        )
                    )
                    print(
                        "  Generated \(result.text.debugDescription) using \(result.selection.modelID ?? "") / \(result.selection.optionID ?? "default") in \(Date().timeIntervalSince(start))s"
                    )
                    if promptArgument == nil && result.text != "Tastko AI OK" { failed = true }
                }
                catch {
                    print("  Generation failed: \(error.localizedDescription)")
                    failed = true
                }
            }
            await service.shutdown()
            return failed || providers.isEmpty ? 1 : 0
        }
    }
#endif
