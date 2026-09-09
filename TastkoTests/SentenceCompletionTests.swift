import Foundation
import Observation
import Testing

@testable import Tastko

// MARK: - Sentence Completion Tests
@Suite(.serialized)
@MainActor
struct SentenceCompletionTests {
    // MARK: - Custom Instructions
    @Test func blankInstructionsUseDefaultAndCustomInstructionsArePreserved() {
        for value in [nil, "", " \n\t"] as [String?] {
            #expect(
                SentenceCompletionPrompt.resolvedInstructions(value)
                    == SentenceCompletionPrompt.instructions
            )
        }
        let custom = "Use short German completions.\nKeep my punctuation."
        #expect(SentenceCompletionPrompt.resolvedInstructions(custom) == custom)
        let request = AIGenerationRequest(
            prompt: "sample context",
            sentenceCompletions: true,
            systemInstructions: custom
        )
        let cliPrompt = AITextOutput.prompt(request)
        #expect(cliPrompt.contains(custom))
        #expect(!cliPrompt.contains(SentenceCompletionPrompt.instructions))
        #expect(cliPrompt.contains("sample context"))
    }

    // MARK: - Word Hints
    @Test func wordHintsAreCappedAndDoNotRestartGeneration() async throws {
        let fixture = SentenceFixture()
        fixture.words = ["want", "was", "will", "wish", "wonder", "work"]
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        let payload = try #require(
            JSONSerialization.jsonObject(with: Data(fixture.prompts[0].utf8)) as? [String: Any]
        )
        #expect(payload["wordSuggestions"] as? [String] == Array(fixture.words.prefix(5)))
        #expect(payload["textBeforeCursor"] as? String == "I want")
        fixture.words = ["changed"]
        await Task.yield()
        #expect(fixture.requests.count == 1)
        fixture.finish(0, #"["I want to rest."]"#)
        await eventually { !fixture.service.suggestions.isEmpty }
    }

    // MARK: - Output Validation
    @Test func preservesPartialWordsAndSpacingWithoutRewritingInput() {
        #expect(
            SentenceCompletionService.completions(
                from:
                    #"["I wan to go home.","I wan to go home.","I want to rest.","Rewritten input"]"#,
                input: "I wan"
            ) == [" to go home.", "t to rest."]
        )
        #expect(
            SentenceCompletionService.completions(from: #"["Hi\nthere", "Hi"]"#, input: "Hi")
                .isEmpty
        )
        #expect(SentenceCompletionService.completions(from: "not JSON", input: "Hi").isEmpty)
    }

    // MARK: - Generation Lifecycle
    @Test func showsLoadingPublishesAndInsertsOnlySuffix() async {
        let fixture = SentenceFixture()
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        #expect(fixture.service.isGenerating)
        fixture.finish(0, #"["I want to go home.","I want to rest."]"#)
        await eventually { fixture.service.suggestions.count == 2 }
        #expect(!fixture.service.isGenerating)
        #expect(fixture.service.accept(" to rest."))
        #expect(fixture.insertions == [" to rest."])
        #expect(fixture.service.suggestions.isEmpty)
    }

    @Test func contextChangesCancelAndRejectLateResults() async {
        let fixture = SentenceFixture()
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        fixture.current = predictionContext("Tomorrow")
        await eventually { fixture.requests.count == 2 }
        fixture.finish(0, #"["I want to go home."]"#)
        await Task.yield()
        #expect(fixture.service.suggestions.isEmpty)
        await eventually { fixture.requests.count == 2 }
        fixture.finish(1, #"["Tomorrow will be sunny."]"#)
        await eventually { !fixture.service.suggestions.isEmpty }
        fixture.current = predictionContext("Tomorrow", elementID: 2)
        #expect(!fixture.service.accept(" will be sunny."))
        fixture.service.stop()
    }

    @Test func refreshUsesLatestTextAfterThrottleInterval() async throws {
        let fixture = SentenceFixture()
        fixture.interval = .milliseconds(150)
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        fixture.finish(0, #"["I want to rest."]"#)
        await eventually { !fixture.service.isGenerating }
        fixture.current = predictionContext("I want t")
        fixture.current = predictionContext("I want to")
        await eventually { fixture.requests.count == 2 }
        let payload = try #require(
            JSONSerialization.jsonObject(with: Data(fixture.prompts[1].utf8)) as? [String: Any]
        )
        #expect(payload["textBeforeCursor"] as? String == "I want to")
        fixture.finish(1, #"["I want to rest."]"#)
        await eventually { !fixture.service.isGenerating }
        #expect(fixture.requests.count == 2)
    }

    @Test func typingReusesMatchingResultsDuringConcurrentRefresh() async throws {
        let fixture = SentenceFixture()
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        fixture.current = predictionContext("I want to")
        await eventually { fixture.requests.count == 2 }
        fixture.finish(0, #"["I want to rest.","I want a break."]"#)
        await eventually { fixture.requests.count == 2 }
        await eventually { fixture.service.suggestions == [" rest."] }
        #expect(fixture.service.isGenerating)
        let payload = try #require(
            JSONSerialization.jsonObject(with: Data(fixture.prompts[1].utf8)) as? [String: Any]
        )
        #expect(payload["textBeforeCursor"] as? String == "I want to")
        fixture.current = predictionContext("I want to r")
        await eventually { fixture.service.suggestions == ["est."] }
        fixture.finish(1, #"["I want to rest."]"#)
        await eventually { fixture.requests.count == 3 }
        fixture.finish(2, #"["I want to rest."]"#)
        await eventually { !fixture.service.isGenerating }
        #expect(fixture.service.accept("est."))
        #expect(fixture.insertions == ["est."])
    }

    @Test func limitsConcurrencyAndCancelsOlderResultsAfterNewerFinishes() async {
        let fixture = SentenceFixture()
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        for count in 1...4 {
            fixture.current = predictionContext("I want " + String(repeating: "x", count: count))
            await eventually { fixture.requests.count == count + 1 }
        }
        fixture.current = predictionContext("I want xxxxx")
        try? await Task.sleep(for: .milliseconds(25))
        #expect(fixture.requests.count == 5)
        fixture.finish(4, #"["I want xxxxx to rest."]"#)
        await eventually { fixture.requests.count == 6 }
        #expect(fixture.service.suggestions == [" to rest."])
        fixture.finish(5, #"["I want xxxxx to sleep."]"#)
        await eventually { fixture.service.suggestions == [" to sleep."] }
        for index in 0..<4 {
            fixture.finish(index, #"["I want xxxxx stale result."]"#)
        }
        await eventually { fixture.cancelled.count == 4 }
        #expect(fixture.service.suggestions == [" to sleep."])
        #expect(!fixture.service.isGenerating)
        #expect(fixture.requests.count == 6)
    }

    @Test func newerCompletedSuggestionsReplaceImmediatelyWhileLaterRequestsRun() async {
        let fixture = SentenceFixture()
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        fixture.current = predictionContext("I want to")
        await eventually { fixture.requests.count == 2 }
        fixture.current = predictionContext("I want to ")
        await eventually { fixture.requests.count == 3 }
        fixture.finish(0, #"["I want to rest."]"#)
        await eventually { fixture.service.suggestions == ["rest."] }
        fixture.finish(1, #"["I want to walk."]"#)
        await eventually { fixture.service.suggestions == ["walk."] }
        #expect(fixture.service.isGenerating)
        fixture.finish(2, #"["I want to sleep."]"#)
        await eventually { !fixture.service.isGenerating }
        #expect(fixture.service.suggestions == ["sleep."])
    }

    // MARK: - Failed Refresh
    @Test func failedNewerRequestDoesNotDiscardPendingSuggestion() async {
        let fixture = SentenceFixture()
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        fixture.current = predictionContext("I want to")
        await eventually { fixture.requests.count == 2 }
        fixture.requests[1]?.resume(throwing: AIProviderError.timeout)
        fixture.requests[1] = nil
        await eventually { fixture.service.error != nil }
        fixture.finish(0, #"["I want to rest."]"#)
        await eventually { !fixture.service.isGenerating }
        #expect(fixture.service.suggestions == [" rest."])
    }

    // MARK: - Empty Refresh
    @Test func emptyNewerResultDoesNotDiscardPendingSuggestion() async {
        let fixture = SentenceFixture()
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        fixture.current = predictionContext("I want to")
        await eventually { fixture.requests.count == 2 }
        fixture.finish(1, #"["I want to"]"#)
        await eventually { fixture.service.error != nil }
        #expect(fixture.service.isGenerating)
        fixture.finish(0, #"["I want to rest."]"#)
        await eventually { !fixture.service.isGenerating }
        #expect(fixture.service.suggestions == [" rest."])
        #expect(fixture.service.error == nil)
    }

    @Test func providerOffAndMissingContextClearAndCancel() async {
        let fixture = SentenceFixture()
        fixture.service.start()
        defer { fixture.service.stop() }
        await eventually { fixture.requests.count == 1 }
        fixture.selected = nil
        await eventually { !fixture.service.isGenerating }
        fixture.finish(0, #"["I want to go home."]"#)
        await Task.yield()
        #expect(fixture.service.suggestions.isEmpty)
        fixture.current = nil
        fixture.selected = AIProviderSelection(provider: .apple)
        await Task.yield()
        #expect(fixture.requests.count == 1)
    }

    // MARK: - Target Validation
    @Test func insertionRevalidatesFocusAndDoesNotDeleteTypedText() {
        let fixture = PredictionFixture()
        fixture.native.immediateWords = []
        fixture.model.reason = "Unavailable"
        fixture.source.context = predictionContext("I wan")
        fixture.service.start(polling: false)
        defer { fixture.service.stop() }
        let expected = fixture.source.context!
        fixture.source.context = predictionContext("I wan", elementID: 2)
        #expect(!fixture.service.acceptCompletion("t to rest.", context: expected))
        #expect(fixture.insertions.isEmpty)
        fixture.source.context = expected
        #expect(fixture.service.acceptCompletion("t to rest.", context: expected))
        #expect(fixture.insertions == ["t to rest."])
        #expect(fixture.deletions == [0])
    }
}

// MARK: - Sentence Fixture
@Observable @MainActor
private final class SentenceFixture {
    var current: PredictionContext? = predictionContext("I want")
    var selected: AIProviderSelection? = AIProviderSelection(provider: .apple)
    var requests: [CheckedContinuation<String, Error>?] = []
    var insertions: [String] = []
    var words: [String] = []
    var prompts: [String] = []
    var cancelled: [Int] = []
    var interval: Duration = .zero
    @ObservationIgnored lazy var service = SentenceCompletionService(
        minimumInterval: interval,
        context: { [unowned self] in current },
        wordSuggestions: { [unowned self] _ in words },
        selection: { [unowned self] in selected },
        generate: { [unowned self] prompt in
            prompts.append(prompt)
            let index = requests.count
            let result = try await withCheckedThrowingContinuation { requests.append($0) }
            if Task.isCancelled { cancelled.append(index) }
            return result
        },
        insert: { [unowned self] suffix, _ in
            insertions.append(suffix)
            return true
        }
    )

    // MARK: - Response
    func finish(_ index: Int, _ text: String) {
        requests[index]?.resume(returning: text)
        requests[index] = nil
    }
}
