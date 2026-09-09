import Testing

@testable import Tastko

// MARK: - Apple Completion Budget Tests
struct AppleCompletionBudgetTests {
    @Test func reservesSchemaOutputAndHeadroom() throws {
        let budget = AppleCompletionBudget(
            instructionTokens: 1024,
            promptTokens: 512,
            schemaTokens: 200,
            contextSize: 4096
        )
        try budget.validate()
        #expect(budget.responseTokens == 640)
        #expect(budget.totalTokens == 2632)
    }

    @Test func oversizedCustomPromptIsRejected() {
        let budget = AppleCompletionBudget(
            instructionTokens: 1025,
            promptTokens: 10,
            schemaTokens: 100,
            contextSize: 4096
        )
        #expect(throws: AIProviderError.self) { try budget.validate() }
    }

    @Test func combinedContextMustFitEvenWhenInstructionsFit() {
        let budget = AppleCompletionBudget(
            instructionTokens: 1000,
            promptTokens: 1300,
            schemaTokens: 200,
            contextSize: 4096
        )
        #expect(throws: AIProviderError.self) { try budget.validate() }
        #expect(AppleCompletionBudget.instructionLimit(for: 2048) == 512)
    }
}
