import FoundationModels
import Testing

@testable import Tastko

// MARK: - Apple Foundation Model Tests
struct AppleFoundationModelProviderTests {
    // MARK: - Availability
    @Test func unavailableStatesGiveSetupInstructions() throws {
        try AppleFoundationModelProvider.checkAvailability(.available)
        #expect(
            throws: AIProviderError.unavailable("Enable Apple Intelligence in System Settings.")
        ) {
            try AppleFoundationModelProvider.checkAvailability(
                .unavailable(.appleIntelligenceNotEnabled)
            )
        }
        #expect(
            throws: AIProviderError.unavailable(
                "Apple Intelligence is downloading or preparing its model."
            )
        ) {
            try AppleFoundationModelProvider.checkAvailability(.unavailable(.modelNotReady))
        }
        #expect(
            throws: AIProviderError.unavailable("Apple Intelligence is unavailable on this Mac.")
        ) {
            try AppleFoundationModelProvider.checkAvailability(.unavailable(.deviceNotEligible))
        }
    }

    // MARK: - Capabilities
    @Test func reasoningOnlyAppearsWhenSupported() throws {
        let basic = LanguageModelCapabilities([.guidedGeneration])
        let reasoning = LanguageModelCapabilities([.guidedGeneration, .reasoning])
        #expect(AppleFoundationModelProvider.descriptor(capabilities: basic).option == nil)
        #expect(
            AppleFoundationModelProvider.descriptor(capabilities: reasoning).option?.choices.map(
                \.id
            )
                == ["light", "moderate", "deep"]
        )
        let selection = AIProviderSelection(provider: .apple, modelID: "system-default")
        #expect(
            try AppleFoundationModelProvider.contextOptions(
                selection: selection,
                capabilities: basic
            ).reasoningLevel == nil
        )
        for (id, level) in [
            ("light", ContextOptions.ReasoningLevel.light), ("moderate", .moderate),
            ("deep", .deep),
        ] {
            var selected = selection
            selected.optionID = id
            #expect(
                try AppleFoundationModelProvider.contextOptions(
                    selection: selected,
                    capabilities: reasoning
                ).reasoningLevel == level
            )
            #expect(throws: AIProviderError.unavailableSelection) {
                try AppleFoundationModelProvider.contextOptions(
                    selection: selected,
                    capabilities: basic
                )
            }
        }
    }

    // MARK: - Unavailable Saved Selection
    @Test func unknownModelAndOptionAreRejected() {
        for selection in [
            AIProviderSelection(provider: .apple, modelID: "removed"),
            AIProviderSelection(provider: .apple, modelID: "system-default", optionID: "unknown"),
        ] {
            #expect(throws: AIProviderError.unavailableSelection) {
                try AppleFoundationModelProvider.contextOptions(
                    selection: selection,
                    capabilities: .init([.reasoning])
                )
            }
        }
    }

    // MARK: - macOS 27 Errors
    @Test func frameworkErrorsMapToProviderErrors() {
        #expect(
            AppleFoundationModelProvider.providerError(
                .contextSizeExceeded(
                    .init(contextSize: 4096, tokenCount: 5000, debugDescription: "fixture")
                )
            )
                == .generation(
                    "The request exceeds the Apple Foundation Model context limit. Shorten the input."
                )
        )
        #expect(
            AppleFoundationModelProvider.providerError(
                .guardrailViolation(.init(debugDescription: "fixture"))
            )
                == .generation("Apple Foundation Model declined this request.")
        )
        #expect(
            AppleFoundationModelProvider.providerError(
                .unsupportedCapability(.init(capability: .reasoning, debugDescription: "fixture"))
            )
                == .unavailableSelection
        )
    }
}
