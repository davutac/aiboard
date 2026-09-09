import Foundation

// MARK: - Deadline
nonisolated func withAIDeadline<T: Sendable>(
    seconds: TimeInterval,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    guard seconds.isFinite, seconds > 0 else { throw AIProviderError.timeout }
    do {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw AIProviderError.timeout
            }
            defer { group.cancelAll() }
            return try await group.next()!
        }
    }
    catch is CancellationError { throw AIProviderError.cancelled }
}
