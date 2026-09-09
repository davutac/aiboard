import AppKit
import FoundationModels
import Observation

// MARK: - Observable Typing Input
@Observable @MainActor final class TypingInput {
    var current: PredictionContext?
    var launches = 0
    var cancellations = 0
    var active = 0
    var peak = 0
    let element = AXUIElementCreateApplication(42)

    // MARK: - Replay Snapshot
    func set(_ text: String, language: String) {
        let range = AccessibilityTextRange(location: text.utf16.count, length: 0)
        current = PredictionContext(
            target: FocusedKeyboardTarget(
                processIdentifier: 42,
                applicationName: "Benchmark",
                applicationElement: element,
                focusedTextElement: element,
                focusedWindow: nil,
                route: .textElement
            ),
            value: FocusedTextValue(
                text: text,
                selectedText: nil,
                selectedRange: range,
                numberOfCharacters: text.utf16.count
            ),
            input: PredictionInput(text: text, range: range, language: language)!
        )
    }
}

// MARK: - Real Model Typing Replay
@main @MainActor struct TypingBenchmark {
    private let provider = AppleFoundationModelProvider()
    private let selected = AIProviderSelection(provider: .apple, modelID: "system-default")
    private let model = AppleFoundationModelProvider.descriptor(
        capabilities: SystemLanguageModel.default.capabilities
    )

    // MARK: - Run Comparison
    static func main() async throws {
        let benchmark = Self()
        let rounds: Int
        if let argument = try BenchmarkSupport.argument("--rounds") {
            guard let value = Int(argument), (1...10).contains(value) else {
                throw UsageError(description: "--rounds must be between 1 and 10")
            }
            rounds = value
        }
        else {
            rounds = 3
        }
        let cases = [
            ("I want to send the report to", "en", 120),
            ("Wir sollten morgen gemeinsam", "de", 120),
            ("Could you please confirm the date", "en", 250),
            ("Vielen Dank für das Gespräch. Ich möchte", "de", 250),
        ]
        for round in 0..<rounds {
            for (index, sample) in cases.enumerated() {
                for offset in 0..<2 {
                    let mode = (round + index + offset) % 2
                    try await benchmark.run(sample, index: index, mode: mode, round: round)
                }
            }
        }
    }

    // MARK: - Replay One Sequence
    private func run(_ sample: (String, String, Int), index: Int, mode: Int, round: Int)
        async throws
    {
        let input = TypingInput()
        let generation: (String) async throws -> String = { prompt in
            input.launches += 1
            input.active += 1
            input.peak = max(input.peak, input.active)
            defer { input.active -= 1 }
            do {
                return try await provider.generate(
                    request: AIGenerationRequest(
                        prompt: prompt,
                        sentenceCompletions: true
                    ),
                    selection: selected,
                    model: model
                )
            }
            catch {
                if Task.isCancelled { input.cancellations += 1 }
                throw error
            }
        }
        let service = SentenceCompletionService(
            minimumInterval: mode == 0 ? .milliseconds(500) : .zero,
            maximumConcurrentRequests: mode == 0 ? 5 : 1,
            context: { input.current },
            selection: { selected },
            generate: generation,
            insert: { _, _ in true }
        )
        let (text, language, interval) = sample
        let start = ContinuousClock.now
        let initial = text.count - 7
        input.set(String(text.prefix(initial)), language: language)
        service.start()
        for length in (initial + 1)...text.count {
            try await Task.sleep(for: .milliseconds(interval))
            input.set(String(text.prefix(length)), language: language)
        }
        // Let Observation deliver the final input before checking the visible result.
        try await Task.sleep(for: .milliseconds(5))
        let stopped = ContinuousClock.now
        while service.suggestions.isEmpty && stopped.duration(to: .now) < .seconds(6) {
            try await Task.sleep(for: .milliseconds(5))
        }
        let wait = BenchmarkSupport.milliseconds(stopped.duration(to: .now))
        let suggestion = service.suggestions.first ?? ""
        let record: [String: Any] = [
            "round": round + 1, "case": index, "mode": ["baseline", "serial"][mode],
            "interval_ms": interval, "after_typing_ms": wait,
            "total_ms": BenchmarkSupport.milliseconds(start.duration(to: .now)),
            "launches": input.launches, "cancellations": input.cancellations,
            "peak": input.peak, "input": text, "suggestion": suggestion,
        ]
        service.stop()
        while input.active > 0 { try await Task.sleep(for: .milliseconds(10)) }
        try BenchmarkSupport.writeJSON(record)
    }
}
