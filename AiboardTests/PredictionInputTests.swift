import Foundation
import Testing

@testable import Aiboard

// MARK: - PredictionInputTests
struct PredictionInputTests {
    // MARK: - Unicode and Boundaries
    @Test func capturesUnicodeWithoutSplittingCharacters() throws {
        let text = String(repeating: "👩🏽‍💻", count: 520) + " Grü"
        let input = try #require(makeInput(text))
        #expect(input.context.count == 512)
        #expect(input.prefix == "Grü")
        #expect(input.insertion(for: "Grüße") == "ße ")
        let combining = try #require(makeInput("Cafe\u{301}"))
        #expect(combining.insertion(for: "Caféteria") == "teria ")
    }

    @Test func refusesSelectionInvalidOffsetsAndMiddleOfWord() {
        #expect(makeInput("hello", cursor: 2) == nil)
        #expect(makeInput("hello", cursor: 0) == nil)
        #expect(makeInput("hello", cursor: 5, length: 1) == nil)
        #expect(makeInput("hello", cursor: -1) == nil)
        #expect(makeInput("hello", cursor: 6) == nil)
        #expect(makeInput("👩🏽‍💻", cursor: 1) == nil)
        #expect(makeInput("e\u{301} ", cursor: 1) == nil)
    }

    @Test func insertsSuffixOrNextWordAndAvoidsExtraSpaces() throws {
        #expect(try #require(makeInput("hel")).insertion(for: "hello") == "lo ")
        #expect(try #require(makeInput("hello ")).insertion(for: "world") == "world ")
        #expect(try #require(makeInput("hel there", cursor: 3)).insertion(for: "hello") == "lo")
        #expect(try #require(makeInput("hel,", cursor: 3)).insertion(for: "hello") == "lo")
        #expect(try #require(makeInput("")).insertion(for: "Hello") == "Hello ")
    }

    // MARK: - Punctuation Spacing
    @Test(arguments: [",", ".", "!", "?", ";", ":", "…", "?!"])
    func nextWordAddsOnlyMissingSpaceAfterPunctuation(_ punctuation: String) throws {
        let input = try #require(makeInput("hello" + punctuation))
        #expect(input.insertion(for: "world") == " world ")
        #expect(
            input.acceptance(for: "world")
                == PredictionInsertion(text: " world ", deleteBackwardCount: 0)
        )

        let spaced = try #require(makeInput("hello" + punctuation + " "))
        #expect(spaced.insertion(for: "world") == "world ")
        #expect(
            spaced.acceptance(for: "world")
                == PredictionInsertion(text: "world ", deleteBackwardCount: 0)
        )
    }

    @Test func punctuationSpacingPreservesFollowingText() throws {
        let input = try #require(makeInput("hello, there", cursor: 6))
        #expect(
            input.acceptance(for: "world")
                == PredictionInsertion(text: " world", deleteBackwardCount: 0)
        )
    }

    @Test(arguments: ["", "hello ", "hello,\n", "hello.\t", "(", "\""])
    func nextWordDoesNotAddAnUnneededLeadingSpace(_ text: String) throws {
        let input = try #require(makeInput(text))
        #expect(
            input.acceptance(for: "world")
                == PredictionInsertion(text: "world ", deleteBackwardCount: 0)
        )
    }

    // MARK: - Candidate Validation
    @Test func filtersInvalidSuggestionsAndPreservesTypedCase() throws {
        let input = try #require(makeInput("Hel"))
        #expect(
            input.validated([
                "hello", "HELLO", "help", "Hel", "world", "hello there", "hello!", "123",
            ]) == ["Hello", "Help"]
        )
        let empty = try #require(makeInput(""))
        #expect(
            empty.validated([" can't ", "well-being", "’hi", "👋", "---", "word\nword"]) == [
                "can't", "well-being",
            ]
        )
    }

    // MARK: - Native Candidates
    @Test func visibleWordsReplaceOnlyCurrentPrefixAndHandleUnicodeAndBoundaries() throws {
        #expect(
            try #require(makeInput("We say hex")).acceptance(for: "hello")
                == PredictionInsertion(text: "hello ", deleteBackwardCount: 3)
        )
        #expect(
            try #require(makeInput("hello")).acceptance(for: "hello")
                == PredictionInsertion(text: " ", deleteBackwardCount: 0)
        )
        #expect(
            try #require(makeInput("HEL")).acceptance(for: "hello")
                == PredictionInsertion(text: "lo ", deleteBackwardCount: 0)
        )
        #expect(
            try #require(makeInput("Cafe\u{301}x")).acceptance(for: "Café")
                == PredictionInsertion(text: "Café ", deleteBackwardCount: 5)
        )
        #expect(
            try #require(makeInput("hex,", cursor: 3)).acceptance(for: "hello")
                == PredictionInsertion(text: "hello", deleteBackwardCount: 3)
        )
        #expect(
            try #require(makeInput("hello,", cursor: 5)).acceptance(for: "hello")
                == PredictionInsertion(text: "", deleteBackwardCount: 0)
        )
        #expect(try #require(makeInput("hex")).acceptance(for: "two words") == nil)
    }

    // MARK: - Native Range Validation
    @Test func nativeCandidatesRespectReplacementRangesAndOnlyCompleteTheCurrentWord() throws {
        let partial = try #require(makeInput("We can meet tom"))
        #expect(
            partial.nativeCandidate(
                replacement: "tomorrow ",
                range: NSRange(location: 12, length: 3)
            ) == "tomorrow"
        )
        #expect(
            partial.nativeCandidate(replacement: "orrow ", range: NSRange(location: 15, length: 0))
                == "tomorrow"
        )
        #expect(
            partial.nativeCandidate(replacement: "today ", range: NSRange(location: 12, length: 3))
                == nil
        )
        #expect(
            partial.nativeCandidate(
                replacement: "tomorrow ",
                range: NSRange(location: 7, length: 8)
            ) == nil
        )
        #expect(
            partial.nativeCandidate(
                replacement: "tomorrow ",
                range: NSRange(location: NSNotFound, length: 0)
            ) == nil
        )
        let boundary = try #require(makeInput("We can meet "))
        #expect(
            boundary.nativeCandidate(
                replacement: "tomorrow ",
                range: NSRange(location: 12, length: 0)
            ) == "tomorrow"
        )
        #expect(
            boundary.nativeCandidate(
                replacement: "tomorrow morning ",
                range: NSRange(location: 12, length: 0)
            ) == nil
        )
        let german = try #require(makeInput("Viele Grü"))
        #expect(
            german.nativeCandidate(replacement: "Grüße ", range: NSRange(location: 6, length: 3))
                == "Grüße"
        )
    }

    // MARK: - Fixtures
    private func makeInput(_ text: String, cursor: Int? = nil, length: Int = 0) -> PredictionInput?
    {
        PredictionInput(
            text: text,
            range: .init(location: cursor ?? text.utf16.count, length: length),
            language: "en"
        )
    }
}
