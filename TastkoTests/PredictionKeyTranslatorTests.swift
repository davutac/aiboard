import Carbon
import Testing

@testable import Tastko

// MARK: - PredictionKeyTranslatorTests
@MainActor
struct PredictionKeyTranslatorTests {
    // MARK: - Keyboard Layouts
    @Test func translatesTheActualLayoutAndCaseModifiers() throws {
        var translator = PredictionKeyTranslator()
        let us = try source("com.apple.keylayout.US")
        let german = try source("com.apple.keylayout.German")
        #expect(translator.edit(for: KeyStroke(.y), source: us) == .insert("y"))
        #expect(translator.edit(for: KeyStroke(.y), source: german) == .insert("z"))
        #expect(
            translator.edit(for: KeyStroke(.a, modifiers: [.shift]), source: us) == .insert("A")
        )
        #expect(
            translator.edit(for: KeyStroke(.a, modifiers: [.capsLock]), source: us) == .insert("A")
        )
        #expect(
            translator.edit(for: KeyStroke(.one, modifiers: [.shift]), source: us) == .insert("!")
        )
        #expect(translator.edit(for: KeyStroke(.space), source: us) == .insert(" "))
    }

    @Test func handlesDeadKeyCompositionWithoutPredictingAnUncommittedAccent() throws {
        var translator = PredictionKeyTranslator()
        let german = try source("com.apple.keylayout.German")
        #expect(translator.edit(for: KeyStroke(.equal), source: german) == .unchanged)
        #expect(translator.isComposing)
        #expect(translator.edit(for: KeyStroke(.e), source: german) == .insert("é"))
        #expect(!translator.isComposing)
        _ = translator.edit(for: KeyStroke(.equal), source: german)
        translator.reset()
        #expect(!translator.isComposing)
        #expect(translator.edit(for: KeyStroke(.e), source: german) == .insert("e"))
    }

    @Test(arguments: [
        Key.leftArrow, .rightArrow, .upArrow, .downArrow, .tab, .return, .escape, .forwardDelete,
        .home, .end,
    ])
    func cursorAndSubmissionKeysReset(_ key: Key) {
        var translator = PredictionKeyTranslator()
        #expect(translator.edit(for: KeyStroke(key), source: nil) == .reset)
    }

    @Test(arguments: [KeyModifiers.command, .control, .option, .function])
    func shortcutsResetInsteadOfBecomingText(_ modifiers: KeyModifiers) throws {
        var translator = PredictionKeyTranslator()
        #expect(
            translator.edit(
                for: KeyStroke(.v, modifiers: modifiers),
                source: try source("com.apple.keylayout.US")
            ) == .reset
        )
    }

    @Test func unsupportedInputMethodsResetAndBackspaceRemainsAnEdit() {
        var translator = PredictionKeyTranslator()
        #expect(translator.edit(for: KeyStroke(.a), source: nil) == .reset)
        #expect(translator.edit(for: KeyStroke(.delete), source: nil) == .backspace)
    }

    // MARK: - Fixture Layouts
    private func source(_ id: String) throws -> TISInputSource {
        let sources =
            TISCreateInputSourceList(
                [kTISPropertyInputSourceID: id] as CFDictionary,
                true
            ).takeRetainedValue() as! [TISInputSource]
        return try #require(sources.first)
    }
}
