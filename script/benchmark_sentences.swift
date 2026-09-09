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
        let samples = [
            ("I want", "en"),
            ("Kannst du mir bitte", "de"),
            ("I think we should", "en"),
            ("Ich freue mich auf", "de"),
            ("Thanks for your help with the project. I will send you", "en"),
            ("Vielen Dank für deine Nachricht. Ich würde gerne", "de"),
        ]
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
                    sentenceCompletions: true
                ),
                selection: selection,
                model: model
            )
            let elapsed = start.duration(to: .now).components
            let milliseconds = Double(elapsed.seconds) * 1000 + Double(elapsed.attoseconds) / 1e15
            let candidates = try JSONDecoder().decode([String].self, from: Data(output.utf8))
            let suffix = candidates.first.map { String($0.dropFirst(text.count)) } ?? ""
            let valid =
                candidates.count == 1 && candidates[0].hasPrefix(text)
                && !suffix.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && suffix.count <= 240 && !suffix.contains(where: { $0.isNewline })
                && !suffix.unicodeScalars.contains(where: {
                    CharacterSet.controlCharacters.contains($0)
                })
            if valid { validCount += 1 }
            times.append(milliseconds)
            print(String(format: "%.1f ms valid=%@", milliseconds, String(valid)))
            print("  \(text.debugDescription) → \(output)")
        }
        let sorted = times.sorted()
        let median = (sorted[2] + sorted[3]) / 2
        print(
            String(
                format: "Requests: %d; median: %.1f ms; max: %.1f ms",
                times.count,
                median,
                sorted.last!
            )
        )
        print(
            "Usable single completions: \(validCount)/\(times.count). Inspect outputs for language quality."
        )
        print(
            "Provider timings include token counting; exclude typing throttle, Accessibility capture, and UI display."
        )
    }
}
