import Foundation

// MARK: - Stable Completion Token Counts
actor AppleCompletionTokenCache {
    struct Counts: Sendable, Equatable {
        let instructions: Int
        let schema: Int
    }

    private struct Entry {
        let id: UUID
        let instructions: String
        let task: Task<Counts, Error>
    }

    private var entry: Entry?

    // MARK: - Shared Token Counts
    func counts(
        instructions: String,
        calculate: @escaping @Sendable () async throws -> Counts
    ) async throws -> Counts {
        let current: Entry
        if let entry, entry.instructions == instructions {
            current = entry
        }
        else {
            current = Entry(
                id: UUID(),
                instructions: instructions,
                task: Task { try await calculate() }
            )
            entry = current
        }
        let result: Counts
        do { result = try await current.task.value }
        catch {
            if entry?.id == current.id { entry = nil }
            throw error
        }
        // A cancelled consumer must not discard successful work shared by a newer request.
        try Task.checkCancellation()
        return result
    }
}
