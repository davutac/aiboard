import Foundation

// MARK: - Apple Completion Context Budget
nonisolated struct AppleCompletionBudget {
    let instructionTokens: Int
    let promptTokens: Int
    let schemaTokens: Int
    let contextSize: Int
    static let safetyMargin = 256

    var instructionLimit: Int { Self.instructionLimit(for: contextSize) }
    var responseTokens: Int { max(256, promptTokens * 2 + 128) }
    var totalTokens: Int {
        instructionTokens + promptTokens + schemaTokens + responseTokens + Self.safetyMargin
    }

    // MARK: - Instruction Limit
    static func instructionLimit(for contextSize: Int) -> Int { min(1024, contextSize / 4) }

    // MARK: - Validation
    func validate() throws {
        guard instructionTokens <= instructionLimit else {
            throw AIProviderError.generation(
                "The sentence prompt uses \(instructionTokens) tokens; the limit is \(instructionLimit). Shorten it in Settings or reset to default."
            )
        }
        guard totalTokens <= contextSize else {
            throw AIProviderError.generation(
                "The completion needs \(totalTokens) tokens including output space; the model supports \(contextSize). Shorten the input or sentence prompt."
            )
        }
    }
}
