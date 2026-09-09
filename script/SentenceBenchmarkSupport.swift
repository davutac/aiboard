import Foundation

// MARK: - Benchmark Utilities
enum BenchmarkSupport {
    // MARK: - Argument Value
    static func argument(_ name: String) throws -> String? {
        guard let index = CommandLine.arguments.firstIndex(of: name) else { return nil }
        guard CommandLine.arguments.indices.contains(index + 1),
            !CommandLine.arguments[index + 1].hasPrefix("--")
        else { throw UsageError(description: "Missing value for \(name)") }
        return CommandLine.arguments[index + 1]
    }

    // MARK: - Completion Validation
    static func completion(from output: String, input: String) -> String? {
        guard let candidates = try? JSONDecoder().decode([String].self, from: Data(output.utf8)),
            candidates.count == 1, let completion = candidates.first,
            completion.hasPrefix(input)
        else { return nil }
        let suffix = completion.dropFirst(input.count)
        guard !suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            suffix.count <= 240, !suffix.contains(where: { $0.isNewline }),
            !suffix.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else { return nil }
        return completion
    }

    // MARK: - Timing
    static func milliseconds(_ duration: Duration) -> Double {
        let value = duration.components
        return Double(value.seconds) * 1000 + Double(value.attoseconds) / 1e15
    }

    // MARK: - JSONL Output
    static func writeJSON(_ record: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

// MARK: - Benchmark Usage Error
struct UsageError: Error, CustomStringConvertible {
    let description: String
}
