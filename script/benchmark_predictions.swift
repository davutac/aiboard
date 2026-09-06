import AppKit
import Foundation

// MARK: - PredictionBenchmark
@main
struct PredictionBenchmark {
    // MARK: - Entry Point
    @MainActor
    static func main() async throws {
        let native = NativeWordPredictionProvider()
        let model = FoundationWordPredictionProvider()
        let samples = [
            ("en", "I would like to say hel"), ("en", "Have a wonderful "),
            ("en", "We can meet tom"), ("en", "Thank you for your "),
            ("de", "Ich wünsche dir einen schönen "), ("de", "Viele Grü"),
            ("de", "Wir treffen uns mor"), ("de", "Vielen Dank für deine "),
        ]
        var nativeCompletionTimes: [Double] = []
        var nativeNextWordTimes: [Double] = []
        var modelTimes: [Double] = []
        var firstModelTimes: [Double] = []
        for (language, text) in samples {
            let input = PredictionInput(
                text: text,
                range: .init(location: text.utf16.count, length: 0),
                language: language
            )!
            for _ in 0..<5 {
                let start = ContinuousClock.now
                let words = await native.predictions(for: input)
                if input.prefix.isEmpty {
                    nativeNextWordTimes.append(milliseconds(since: start))
                }
                else {
                    nativeCompletionTimes.append(milliseconds(since: start))
                }
                print(
                    "native \(language): \(input.validated(words).prefix(PredictionInput.maximumSuggestions))"
                )
            }
            if CommandLine.arguments.contains("--native-only") { continue }
            if let reason = model.unavailableReason(language: language) {
                print("model unavailable: \(reason)")
                continue
            }
            model.prewarm()
            try await Task.sleep(for: .seconds(1))
            let start = ContinuousClock.now
            do {
                var firstResult: Double?
                let words = try await model.predictions(for: input) { words in
                    if firstResult == nil, !input.validated(words).isEmpty {
                        firstResult = milliseconds(since: start)
                    }
                }
                modelTimes.append(milliseconds(since: start))
                if let firstResult {
                    firstModelTimes.append(firstResult)
                }
                else if !input.validated(words).isEmpty {
                    firstModelTimes.append(milliseconds(since: start))
                }
                print(
                    "model \(language): raw=\(words) valid=\(input.validated(words).prefix(PredictionInput.maximumSuggestions))"
                )
            }
            catch { print("model failure: \(error)") }
            model.reset()
        }
        report("Native partial word (includes first request)", nativeCompletionTimes)
        report("Native next word", nativeNextWordTimes)
        report("Prewarmed model (excludes 150 ms debounce)", modelTimes)
        report("First valid AI suggestion (excludes 150 ms debounce)", firstModelTimes)
    }

    // MARK: - Timing
    static func milliseconds(since start: ContinuousClock.Instant) -> Double {
        let duration = start.duration(to: .now).components
        return Double(duration.seconds) * 1_000 + Double(duration.attoseconds) / 1e15
    }

    static func report(_ label: String, _ values: [Double]) {
        guard !values.isEmpty else { return }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        let median =
            sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        let p95 = sorted[min(sorted.count - 1, Int(ceil(Double(sorted.count) * 0.95)) - 1)]
        print(
            String(format: "%@: n=%d median=%.1f ms p95=%.1f ms", label, sorted.count, median, p95)
        )
    }
}
