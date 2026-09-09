import Testing

@testable import Tastko

// MARK: - Completion Token Cache Tests
struct AppleCompletionTokenCacheTests {
    // MARK: - Shared Work and Instruction Changes
    @Test func concurrentRequestsShareCountsAndChangedInstructionsRecount() async throws {
        let cache = AppleCompletionTokenCache()
        let counter = TokenCounter()
        async let first = cache.counts(instructions: "first") { try await counter.calculate() }
        async let second = cache.counts(instructions: "first") { try await counter.calculate() }
        #expect(try await first == second)
        #expect(await counter.calls == 1)
        _ = try await cache.counts(instructions: "second") { try await counter.calculate() }
        #expect(await counter.calls == 2)
    }

    // MARK: - Error Recovery
    @Test func failedCountsCanBeRetried() async throws {
        let cache = AppleCompletionTokenCache()
        await #expect(throws: AIProviderError.invalidOutput) {
            try await cache.counts(instructions: "same") { throw AIProviderError.invalidOutput }
        }
        let result = try await cache.counts(instructions: "same") {
            .init(instructions: 20, schema: 10)
        }
        #expect(result == .init(instructions: 20, schema: 10))
    }

    // MARK: - Consumer Cancellation
    @Test func cancellingOneRequestPreservesSharedCounts() async throws {
        let cache = AppleCompletionTokenCache()
        let counter = TokenCounter()
        let cancelled = Task {
            try await cache.counts(instructions: "same") { try await counter.calculate() }
        }
        while await counter.calls == 0 { await Task.yield() }
        cancelled.cancel()
        let result = try await cache.counts(instructions: "same") { try await counter.calculate() }
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(result == .init(instructions: 20, schema: 10))
        #expect(await counter.calls == 1)
    }
}

// MARK: - Counting Fixture
private actor TokenCounter {
    private(set) var calls = 0

    // MARK: - Delayed Token Count
    func calculate() async throws -> AppleCompletionTokenCache.Counts {
        calls += 1
        try await Task.sleep(for: .milliseconds(20))
        return .init(instructions: 20, schema: 10)
    }
}
