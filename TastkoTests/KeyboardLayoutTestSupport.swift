import Carbon
import Testing

@testable import Tastko

// MARK: - Layout Translator Fixture
@MainActor
func keyboardLayoutTranslator(_ id: String) throws -> KeyboardLayoutTranslator {
    let translator = KeyboardLayoutTranslator()
    translator.setSource(try keyboardLayoutSource(id), keyboardType: UInt32(LMGetKbdType()))
    return translator
}

// MARK: - Native Input Source Fixture
@MainActor
func keyboardLayoutSource(_ id: String) throws -> TISInputSource {
    let sources =
        TISCreateInputSourceList(
            [kTISPropertyInputSourceID: id] as CFDictionary,
            true
        ).takeRetainedValue() as! [TISInputSource]
    return try #require(sources.first)
}
