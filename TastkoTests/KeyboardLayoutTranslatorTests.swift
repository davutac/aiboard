import Carbon
import Observation
import Synchronization
import Testing

@testable import Tastko

// MARK: - KeyboardLayoutTranslatorTests
@MainActor
struct KeyboardLayoutTranslatorTests {
    // MARK: - Layers
    @Test func nativeUSLayersAndDeadKeys() throws {
        let translator = try keyboardLayoutTranslator("com.apple.keylayout.US")
        #expect(translator.label(for: KeyStroke(.a))?.title == "a")
        #expect(translator.label(for: KeyStroke(.a, modifiers: [.shift]))?.title == "A")
        #expect(translator.label(for: KeyStroke(.a, modifiers: [.capsLock]))?.title == "A")
        #expect(translator.label(for: KeyStroke(.two, modifiers: [.option]))?.title == "™")
        #expect(translator.label(for: KeyStroke(.two, modifiers: [.option, .shift]))?.title == "€")
        let accent = try #require(translator.label(for: KeyStroke(.e, modifiers: [.option])))
        #expect(accent.isDeadKey)
        #expect(!accent.title.isEmpty)
        #expect(
            translator.label(for: KeyStroke(.e)) == KeyboardKeyLabel(title: "e", isDeadKey: false)
        )
    }

    @Test func sourceSwitchInvalidatesCachedTranslationsAndUnsupportedSourcesFallBack() throws {
        let translator = try keyboardLayoutTranslator("com.apple.keylayout.US")
        #expect(translator.label(for: KeyStroke(.y))?.title == "y")
        let invalidated = Mutex(false)
        withObservationTracking {
            _ = translator.label(for: KeyStroke(.y))
        } onChange: {
            invalidated.withLock { $0 = true }
        }
        translator.setSource(
            try keyboardLayoutSource("com.apple.keylayout.German"),
            keyboardType: UInt32(LMGetKbdType())
        )
        #expect(invalidated.withLock { $0 })
        #expect(translator.label(for: KeyStroke(.y))?.title == "z")
        #expect(translator.label(for: KeyStroke(.l, modifiers: [.option]))?.title == "@")
        translator.setSource(nil, keyboardType: 0)
        #expect(translator.label(for: KeyStroke(.y)) == nil)
    }
}
