import Foundation
import SwiftUI
import Testing

@testable import Aiboard

// MARK: - WordSuggestionButtonTests
@MainActor
struct WordSuggestionButtonTests {
    // MARK: - Completion Rendering
    @Test func typedPrefixChangesRenderedSuggestionLabel() throws {
        let fixture = PredictionFixture()
        fixture.model.reason = "Unavailable"
        fixture.native.immediateWords = ["hello"]
        fixture.service.start(polling: false)
        defer { fixture.service.stop() }
        #expect(fixture.service.typedPrefix == "he")
        let completion = try renderedSuggestion(service: fixture.service)

        fixture.source.context = predictionContext("hello ")
        fixture.service.refresh()
        #expect(fixture.service.typedPrefix.isEmpty)
        let nextWord = try renderedSuggestion(service: fixture.service)
        #expect(completion != nextWord, "The typed prefix must look different from the completion.")
    }

    // MARK: - Render Fixture
    private func renderedSuggestion(service: TextPredictionService) throws -> Data {
        let renderer = ImageRenderer(
            content: WordSuggestionButton(word: "hello", index: 0, service: service)
                .environment(\.colorScheme, .dark)
        )
        let image = try #require(renderer.cgImage)
        return try #require(image.dataProvider?.data) as Data
    }
}
