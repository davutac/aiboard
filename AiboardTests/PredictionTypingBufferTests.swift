import ApplicationServices
import Foundation
import Testing

@testable import Aiboard

// MARK: - PredictionTypingBufferTests
@MainActor
struct PredictionTypingBufferTests {
    // MARK: - Editing
    @Test func retainsContextAndDeletesWholeCharacters() throws {
        var buffer = PredictionTypingBuffer()
        buffer.observe(target: predictionContext("").target, selection: nil, inputSource: "en")
        buffer.apply(.insert("Hello 👨‍👩‍👧‍👦"))
        buffer.apply(.backspace)
        #expect(buffer.text == "Hello ")
        buffer.apply(.insert("wor"))
        let context = try #require(buffer.context(language: "en"))
        #expect(context.input.context == "Hello wor")
        #expect(context.input.prefix == "wor")
        let insertion = try #require(context.acceptance(for: "world"))
        #expect(insertion == PredictionInsertion(text: "ld ", deleteBackwardCount: 0))
        #expect(context.acceptance(for: "hello") == nil)
        #expect(PredictionSpace(insertion: insertion, context: context) == nil)
    }

    @Test func boundsContextAndNeverDeletesUnknownText() {
        var buffer = PredictionTypingBuffer()
        let target = predictionContext("").target
        buffer.observe(target: target, selection: nil, inputSource: "en")
        buffer.apply(.insert(String(repeating: "word ", count: 200)))
        #expect(buffer.text.count == 512)
        for _ in 0..<512 { buffer.apply(.backspace) }
        #expect(buffer.context(language: "en") == nil)
        let previousSession = buffer.session
        buffer.apply(.backspace)
        #expect(buffer.session != previousSession)
        buffer.apply(.insert("unanchored"))
        #expect(buffer.text.isEmpty)
    }

    // MARK: - Focus
    @Test func fieldWindowAndLanguageChangesStartFreshSessions() {
        var buffer = PredictionTypingBuffer()
        let first = target(window: 10, field: 20)
        buffer.observe(target: first, selection: nil, inputSource: "en")
        buffer.apply(.insert("hello"))
        buffer.observe(target: first, selection: nil, inputSource: "en")
        #expect(buffer.text == "hello")
        buffer.observe(target: target(window: 10, field: 21), selection: nil, inputSource: "en")
        #expect(buffer.text.isEmpty)
        buffer.apply(.insert("other field"))
        buffer.observe(target: target(window: 11, field: 21), selection: nil, inputSource: "en")
        #expect(buffer.text.isEmpty)
        buffer.apply(.insert("other window"))
        buffer.observe(target: target(window: 11, field: 21), selection: nil, inputSource: "de")
        #expect(buffer.text.isEmpty)
        buffer.observe(target: first, selection: nil, inputSource: "en")
        #expect(buffer.text.isEmpty)
    }

    @Test func revisionsRejectIdenticalTextAfterDeletionOrReset() throws {
        var buffer = PredictionTypingBuffer()
        let target = predictionContext("").target
        buffer.observe(target: target, selection: nil, inputSource: "en")
        buffer.apply(.insert("he"))
        let before = try #require(buffer.context(language: "en"))
        buffer.apply(.backspace)
        buffer.apply(.insert("e"))
        let edited = try #require(buffer.context(language: "en"))
        #expect(before != edited)
        #expect(before.hasSameSession(as: edited))
        buffer.reset()
        buffer.observe(target: target, selection: nil, inputSource: "en")
        buffer.apply(.insert("he"))
        let restarted = try #require(buffer.context(language: "en"))
        #expect(before != restarted)
        #expect(!before.hasSameSession(as: restarted))
    }

    // MARK: - Partial AX Cursor Information
    @Test func acceptsAsynchronousCursorAcknowledgmentButResetsOnCursorMovement() {
        var buffer = PredictionTypingBuffer()
        let target = predictionContext("").target
        let now = ContinuousClock.now
        buffer.observe(target: target, selection: range(10), inputSource: "en", now: now)
        buffer.apply(.insert("he"), now: now)
        buffer.observe(
            target: target,
            selection: range(10),
            inputSource: "en",
            now: now + .milliseconds(20)
        )
        #expect(buffer.text == "he")
        buffer.observe(
            target: target,
            selection: range(12),
            inputSource: "en",
            now: now + .milliseconds(30)
        )
        #expect(buffer.text == "he")
        buffer.observe(
            target: target,
            selection: range(10),
            inputSource: "en",
            now: now + .milliseconds(40)
        )
        #expect(buffer.text.isEmpty)
    }

    @Test func unacknowledgedInputExpiresAndSelectionsInvalidateTheBuffer() {
        var buffer = PredictionTypingBuffer()
        let target = predictionContext("").target
        let now = ContinuousClock.now
        buffer.observe(target: target, selection: range(10), inputSource: "en", now: now)
        buffer.apply(.insert("he"), now: now)
        buffer.observe(
            target: target,
            selection: range(10),
            inputSource: "en",
            now: now + .milliseconds(200)
        )
        #expect(buffer.text.isEmpty)
        buffer.apply(.insert("again"))
        buffer.observe(
            target: target,
            selection: AccessibilityTextRange(location: 10, length: 5),
            inputSource: "en"
        )
        #expect(buffer.context(language: "en") == nil)
        buffer.apply(.insert("selection"))
        #expect(buffer.text.isEmpty)
    }

    @Test(arguments: [PredictionTypingEdit.reset, .insert("\n"), .insert("\t")])
    func uncertainEditsDiscardContext(_ edit: PredictionTypingEdit) {
        var buffer = PredictionTypingBuffer()
        buffer.observe(target: predictionContext("").target, selection: nil, inputSource: "en")
        buffer.apply(.insert("he"))
        buffer.apply(edit)
        #expect(buffer.context(language: "en") == nil)
    }

    // MARK: - Fixtures
    private func range(_ location: Int) -> AccessibilityTextRange {
        AccessibilityTextRange(location: location, length: 0)
    }

    private func target(window: pid_t, field: pid_t) -> FocusedKeyboardTarget {
        FocusedKeyboardTarget(
            processIdentifier: 42,
            applicationName: "Fixture",
            applicationElement: AXUIElementCreateApplication(42),
            focusedTextElement: nil,
            focusedWindow: AXUIElementCreateApplication(window),
            route: .window,
            focusedElement: AXUIElementCreateApplication(field)
        )
    }
}
