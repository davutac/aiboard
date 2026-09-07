import Carbon
import Observation

// MARK: - KeyboardKeyLabel
nonisolated struct KeyboardKeyLabel: Equatable {
    let title: String
    let isDeadKey: Bool
}

// MARK: - KeyboardLayoutTranslator
@Observable
@MainActor
final class KeyboardLayoutTranslator {
    private var layoutData: CFData?
    @ObservationIgnored private var sourceID: String?
    private var keyboardType: UInt32 = 0
    @ObservationIgnored private var cache: [KeyStroke: KeyboardKeyLabel] = [:]

    // MARK: - Source
    func refresh() {
        setSource(
            TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
            keyboardType: UInt32(LMGetKbdType())
        )
    }

    func setSource(_ source: TISInputSource?, keyboardType: UInt32) {
        let id = source.flatMap { source in
            TISGetInputSourceProperty(source, kTISPropertyInputSourceID).map {
                Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String
            }
        }
        let data = source.flatMap { source in
            TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData).map {
                Unmanaged<CFData>.fromOpaque($0).takeUnretainedValue()
            }
        }
        guard id != sourceID || self.keyboardType != keyboardType || data != layoutData else {
            return
        }
        cache.removeAll()
        sourceID = id
        layoutData = data
        self.keyboardType = keyboardType
    }

    // MARK: - Labels
    func label(for stroke: KeyStroke) -> KeyboardKeyLabel? {
        guard Self.isPrintable(stroke.key),
            stroke.modifiers.intersection([.command, .control, .function]).isEmpty
        else { return nil }
        // Cached labels must still observe layout changes.
        guard let layoutData else { return nil }
        let keyboardType = keyboardType
        if let cached = cache[stroke] { return cached }
        guard let bytes = CFDataGetBytePtr(layoutData) else { return nil }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var flags = 0
        if stroke.modifiers.contains(.shift) { flags |= shiftKey }
        if stroke.modifiers.contains(.option) { flags |= optionKey }
        if stroke.modifiers.contains(.capsLock) { flags |= alphaLock }
        var state: UInt32 = 0
        var characters = [UniChar](repeating: 0, count: 255)
        var length = 0
        // Display translation is independent of the receiving editor's composition state.
        let status = UCKeyTranslate(
            layout,
            stroke.key.rawValue,
            UInt16(kUCKeyActionDisplay),
            UInt32(flags >> 8),
            keyboardType,
            OptionBits(kUCKeyTranslateNoDeadKeysMask),
            &state,
            characters.count,
            &length,
            &characters
        )
        guard status == noErr, length > 0 else { return nil }
        let title = String(utf16CodeUnits: characters, count: length)
        guard !title.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else {
            return nil
        }
        state = 0
        length = 0
        let downStatus = UCKeyTranslate(
            layout,
            stroke.key.rawValue,
            UInt16(kUCKeyActionDown),
            UInt32(flags >> 8),
            keyboardType,
            0,
            &state,
            characters.count,
            &length,
            &characters
        )
        let result = KeyboardKeyLabel(
            title: title,
            isDeadKey: downStatus == noErr && state != 0 && length == 0
        )
        cache[stroke] = result
        return result
    }

    // MARK: - Printable Keys
    nonisolated static func isPrintable(_ key: Key) -> Bool {
        if key.rawValue <= Key.grave.rawValue {
            return ![Key.return, .tab, .space].contains(key)
        }
        return [
            .keypadDecimal, .keypadMultiply, .keypadPlus, .keypadDivide, .keypadMinus,
            .keypadEquals, .keypad0, .keypad1, .keypad2, .keypad3, .keypad4, .keypad5,
            .keypad6, .keypad7, .keypad8, .keypad9, .jisYen, .jisUnderscore,
            .jisKeypadComma,
        ].contains(key)
    }
}
