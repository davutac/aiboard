import Foundation
import FoundationModels

// MARK: - Guided Text Response
@Generable
nonisolated private struct AppleTextResponse {
    @Guide(description: "The assistant's response to the user's message.")
    var text: String
}

// MARK: - Guided Sentence Completion
@Generable
nonisolated private struct AppleSentenceCompletion {
    @Guide(
        description:
            "The original text copied exactly, followed by one short, natural sentence ending."
    )
    var completedText: String
}

// MARK: - Apple Foundation Model Provider
nonisolated struct AppleFoundationModelProvider: AIProviderAdapter {
    static let modelID = "system-default"
    static let modelName = "System Model"
    private let systemModel = SystemLanguageModel.default
    private let tokenCache = AppleCompletionTokenCache()

    // MARK: - Availability
    static func checkAvailability(_ availability: SystemLanguageModel.Availability) throws {
        switch availability {
        case .available: return
        case .unavailable(.deviceNotEligible):
            throw AIProviderError.unavailable("Apple Intelligence is unavailable on this Mac.")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw AIProviderError.unavailable("Enable Apple Intelligence in System Settings.")
        case .unavailable(.modelNotReady):
            throw AIProviderError.unavailable(
                "Apple Intelligence is downloading or preparing its model."
            )
        case .unavailable:
            throw AIProviderError.unavailable("Apple Intelligence is currently unavailable.")
        }
    }

    // MARK: - Model Capabilities
    static func descriptor(capabilities: LanguageModelCapabilities) -> AIModelDescriptor {
        AIModelDescriptor(
            id: modelID,
            name: modelName,
            option: capabilities.contains(.reasoning)
                ? AIOptionDescriptor(
                    id: "reasoning",
                    name: "Reasoning",
                    choices: [
                        AIOptionChoice(id: "light", name: "Light"),
                        AIOptionChoice(id: "moderate", name: "Moderate"),
                        AIOptionChoice(id: "deep", name: "Deep"),
                    ]
                ) : nil,
            isDefault: true
        )
    }

    // MARK: - Discovery
    func discover() async throws
        -> AIProviderDiscovery
    {
        try Task.checkCancellation()
        try Self.checkAvailability(systemModel.availability)
        return AIProviderDiscovery(
            models: [Self.descriptor(capabilities: systemModel.capabilities)],
            version: ProcessInfo.processInfo.operatingSystemVersionString,
            source: "macOS Foundation Models",
            accountDescription: "Available on this Mac"
        )
    }

    // MARK: - Context Options
    static func contextOptions(
        selection: AIProviderSelection,
        capabilities: LanguageModelCapabilities
    ) throws -> ContextOptions {
        guard selection.provider == .apple, selection.modelID == modelID else {
            throw AIProviderError.unavailableSelection
        }
        var context = ContextOptions(includeSchemaInPrompt: true)
        if capabilities.contains(.reasoning) {
            context.reasoningLevel = .light
        }
        if let option = selection.optionID {
            guard capabilities.contains(.reasoning) else {
                throw AIProviderError.unavailableSelection
            }
            switch option {
            case "light": context.reasoningLevel = .light
            case "moderate": context.reasoningLevel = .moderate
            case "deep": context.reasoningLevel = .deep
            default: throw AIProviderError.unavailableSelection
            }
        }
        return context
    }

    // MARK: - Generate
    @concurrent func generate(
        request: AIGenerationRequest,
        selection: AIProviderSelection,
        model _: AIModelDescriptor
    ) async throws -> String {
        try Task.checkCancellation()
        try Self.checkAvailability(systemModel.availability)
        let context = try Self.contextOptions(
            selection: selection,
            capabilities: systemModel.capabilities
        )
        let instructions =
            request.sentenceCompletions
            ? SentenceCompletionPrompt.resolvedInstructions(request.systemInstructions)
            : "You are a helpful assistant. Respond to the user and follow their requested output format."
        let prompt =
            request.sentenceCompletions
            ? String(decoding: try JSONEncoder().encode(["text": request.prompt]), as: UTF8.self)
            : request.prompt
        var responseTokens: Int?
        if request.sentenceCompletions {
            let counts = try await tokenCache.counts(instructions: instructions) { [systemModel] in
                async let instructionTokens = systemModel.tokenCount(
                    for: Instructions(instructions)
                )
                async let schemaTokens = systemModel.tokenCount(
                    for: AppleSentenceCompletion.generationSchema
                )
                return try await .init(instructions: instructionTokens, schema: schemaTokens)
            }
            let budget = AppleCompletionBudget(
                instructionTokens: counts.instructions,
                promptTokens: try await systemModel.tokenCount(for: Prompt(prompt)),
                schemaTokens: counts.schema,
                contextSize: systemModel.contextSize
            )
            try budget.validate()
            responseTokens = budget.responseTokens
        }
        try Task.checkCancellation()
        let session = LanguageModelSession(
            model: systemModel,
            tools: [],
            instructions: instructions
        )
        var options = GenerationOptions()
        options.toolCallingMode = .disallowed
        do {
            if request.sentenceCompletions {
                options.maximumResponseTokens = responseTokens
                let response = try await session.respond(
                    to: prompt,
                    generating: AppleSentenceCompletion.self,
                    options: options,
                    contextOptions: context
                )
                try Task.checkCancellation()
                return String(
                    decoding: try JSONEncoder().encode([response.content.completedText]),
                    as: UTF8.self
                )
            }
            let response = try await session.respond(
                to: prompt,
                generating: AppleTextResponse.self,
                options: options,
                contextOptions: context
            )
            try Task.checkCancellation()
            return response.content.text
        }
        catch {
            if Task.isCancelled || error is CancellationError { throw AIProviderError.cancelled }
            if let error = error as? LanguageModelError { throw Self.providerError(error) }
            throw AIProviderError.generation(
                "Apple Foundation Model could not complete the request."
            )
        }
    }

    // MARK: - Framework Errors
    static func providerError(_ error: LanguageModelError) -> AIProviderError {
        switch error {
        case .timeout: .timeout
        case .contextSizeExceeded:
            .generation(
                "The request exceeds the Apple Foundation Model context limit. Shorten the input."
            )
        case .rateLimited:
            .generation("Apple Foundation Model is busy. Try again shortly.")
        case .guardrailViolation, .refusal:
            .generation("Apple Foundation Model declined this request.")
        case .unsupportedLanguageOrLocale:
            .generation("Apple Foundation Model does not support the requested language.")
        case .unsupportedCapability: .unavailableSelection
        case .unsupportedTranscriptContent, .unsupportedGenerationGuide: .invalidOutput
        @unknown default:
            .generation("Apple Foundation Model could not complete the request.")
        }
    }
}
