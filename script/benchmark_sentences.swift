import Foundation
import FoundationModels

// MARK: - Live Sentence Benchmark
@main struct SentenceBenchmark {
    // MARK: - Fixed English and German Samples
    static func main() async throws {
        let provider = AppleFoundationModelProvider()
        let selection = AIProviderSelection(provider: .apple, modelID: "system-default")
        let model = AppleFoundationModelProvider.descriptor(
            capabilities: SystemLanguageModel.default.capabilities
        )
        let instructions = try BenchmarkSupport.argument("--instructions-file").map {
            try String(contentsOfFile: $0, encoding: .utf8)
        }
        let samples =
            CommandLine.arguments.contains("--quality")
            ? SentenceBenchmarkSamples.quality : SentenceBenchmarkSamples.standard
        if CommandLine.arguments.contains("--parallel")
            || CommandLine.arguments.contains("--parallel-all")
        {
            try await benchmarkParallel(
                provider: provider,
                selection: selection,
                model: model,
                samples: samples,
                instructions: instructions
            )
            return
        }
        let instructionTokens = try await SystemLanguageModel.default.tokenCount(
            for: Instructions(instructions ?? SentenceCompletionPrompt.instructions)
        )
        print("Instruction tokens: \(instructionTokens)")
        var times: [Double] = []
        var validCount = 0
        for (text, language) in samples {
            let input = PredictionInput(
                text: text,
                range: AccessibilityTextRange(location: text.utf16.count, length: 0),
                language: language
            )!
            let start = ContinuousClock.now
            let output = try await provider.generate(
                request: AIGenerationRequest(
                    prompt: SentenceCompletionPrompt.input(input),
                    sentenceCompletions: true,
                    systemInstructions: instructions
                ),
                selection: selection,
                model: model
            )
            let milliseconds = BenchmarkSupport.milliseconds(start.duration(to: .now))
            let valid = BenchmarkSupport.completion(from: output, input: text) != nil
            if valid { validCount += 1 }
            times.append(milliseconds)
            print(String(format: "%.1f ms valid=%@", milliseconds, String(valid)))
            print("  \(text.debugDescription) → \(output)")
        }
        let sorted = times.sorted()
        let middle = sorted.count / 2
        let median =
            sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        print(
            String(
                format: "Requests: %d; median: %.1f ms; max: %.1f ms",
                times.count,
                median,
                sorted.last!
            )
        )
        print(
            "Nonempty completions passing prefix/format checks: \(validCount)/\(times.count). Inspect outputs for language quality."
        )
        if CommandLine.arguments.contains("--quality") {
            print(
                "Quality checks also require unchanged output for the two already-complete sentences."
            )
        }
        print(
            "Provider timings include token counting; exclude typing throttle, Accessibility capture, and UI display."
        )
    }
}
