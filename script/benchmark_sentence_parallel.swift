import Foundation

// MARK: - Parallel Sentence Benchmark
extension SentenceBenchmark {
    // MARK: - Concurrent Suggestions Across Separate Sessions
    static func benchmarkParallel(
        provider: AppleFoundationModelProvider,
        selection: AIProviderSelection,
        model: AIModelDescriptor,
        samples: [(String, String)],
        instructions: String?
    ) async throws {
        // Warm the model and constant token cache equally for every configuration.
        let warmInput = PredictionInput(
            text: "I want",
            range: AccessibilityTextRange(location: 6, length: 0),
            language: "en"
        )!
        _ = try await provider.generate(
            request: AIGenerationRequest(
                prompt: warmInput.context,
                sentenceCompletions: true,
                systemInstructions: instructions
            ),
            selection: selection,
            model: model
        )
        let keepAll = CommandLine.arguments.contains("--parallel-all")
        for round in 0..<3 {
            for (sample, pair) in samples.enumerated() {
                let (text, language) = pair
                let input = PredictionInput(
                    text: text,
                    range: AccessibilityTextRange(location: text.utf16.count, length: 0),
                    language: language
                )!
                let request = AIGenerationRequest(
                    prompt: input.context,
                    sentenceCompletions: true,
                    systemInstructions: instructions
                )
                // Rotate execution order so every width runs first once per sample.
                for offset in 0..<3 {
                    let width = (round + sample + offset) % 3 + 1
                    let start = ContinuousClock.now
                    var outputs: [String] = []
                    var completionTimes: [Double] = []
                    var rejectedResults = 0
                    await withTaskGroup(of: String?.self) { group in
                        for _ in 0..<width {
                            group.addTask {
                                try? await provider.generate(
                                    request: request,
                                    selection: selection,
                                    model: model
                                )
                            }
                        }
                        for await output in group {
                            guard keepAll || outputs.isEmpty else { continue }
                            guard let output,
                                let completion = BenchmarkSupport.completion(
                                    from: output,
                                    input: text
                                )
                            else {
                                rejectedResults += 1
                                continue
                            }
                            let elapsed = BenchmarkSupport.milliseconds(start.duration(to: .now))
                            outputs.append(completion)
                            completionTimes.append(elapsed)
                            if !keepAll { group.cancelAll() }
                        }
                    }
                    let record: [String: Any] = [
                        "round": round + 1, "sample": sample, "width": width,
                        "first_ms": completionTimes.first.map { $0 as Any } ?? NSNull(),
                        "settled_ms": BenchmarkSupport.milliseconds(start.duration(to: .now)),
                        "rejected_results": rejectedResults,
                        "output": outputs.first ?? "", "outputs": outputs,
                        "completion_ms": completionTimes, "unique_count": Set(outputs).count,
                        "mode": keepAll ? "all" : "race",
                    ]
                    try BenchmarkSupport.writeJSON(record)
                }
            }
        }
    }
}
