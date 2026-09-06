import Carbon

// MARK: - PredictionKeyTranslator
struct PredictionKeyTranslator {
    private var deadKeyState: UInt32 = 0
    private(set) var isComposing = false

    // MARK: - Input Source Identity
    static func inputSourceID() -> String? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
            let value = TISGetInputSourceProperty(source, kTISPropertyInputSourceID)
        else { return nil }
        return Unmanaged<CFString>.fromOpaque(value).takeUnretainedValue() as String
    }

    // MARK: - Posted Key Translation
    mutating func edit(for stroke: KeyStroke) -> PredictionTypingEdit {
        edit(for: stroke, source: TISCopyCurrentKeyboardInputSource()?.takeRetainedValue())
    }

    mutating func edit(for stroke: KeyStroke, source: TISInputSource?) -> PredictionTypingEdit {
        guard stroke.modifiers.intersection([.command, .control, .option, .function]).isEmpty
        else {
            reset()
            return .reset
        }
        switch stroke.key {
        case .leftShift, .rightShift, .capsLock: return .unchanged
        case .delete:
            guard !isComposing else {
                reset()
                return .reset
            }
            return .backspace
        default: break
        }
        // Only translate printable keys. Navigation, submission, and shortcuts
        // end the session, because their effect on the editor is unknown.
        let printable =
            stroke.key.rawValue <= Key.grave.rawValue
            && ![Key.return, .tab].contains(stroke.key)
        let keypad: Set<Key> = [
            .keypadDecimal, .keypadMultiply, .keypadPlus, .keypadDivide, .keypadMinus,
            .keypadEquals, .keypad0, .keypad1, .keypad2, .keypad3, .keypad4,
            .keypad5, .keypad6, .keypad7, .keypad8, .keypad9,
        ]
        guard printable || keypad.contains(stroke.key),
            let source,
            let rawLayout = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else {
            // Input methods without a Unicode layout cannot be reconstructed here.
            reset()
            return .reset
        }
        let data = Unmanaged<CFData>.fromOpaque(rawLayout).takeUnretainedValue()
        guard let bytes = CFDataGetBytePtr(data) else { return .reset }
        let layout = UnsafeRawPointer(bytes).assumingMemoryBound(to: UCKeyboardLayout.self)
        var flags = 0
        if stroke.modifiers.contains(.shift) { flags |= shiftKey }
        if stroke.modifiers.contains(.capsLock) { flags |= alphaLock }
        var characters = [UniChar](repeating: 0, count: 16)
        var length = 0
        let status = UCKeyTranslate(
            layout,
            stroke.key.rawValue,
            UInt16(kUCKeyActionDown),
            UInt32(flags >> 8),
            UInt32(LMGetKbdType()),
            0,
            &deadKeyState,
            characters.count,
            &length,
            &characters
        )
        guard status == noErr else {
            reset()
            return .reset
        }
        // The state is opaque and can remain nonzero after emitting a character.
        // Track whether translation has produced committed text separately.
        isComposing = length == 0
        guard length > 0 else { return .unchanged }
        let text = String(utf16CodeUnits: characters, count: length)
        guard !text.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
        else {
            reset()
            return .reset
        }
        return .insert(text)
    }

    // MARK: - Reset
    mutating func reset() {
        deadKeyState = 0
        isComposing = false
    }
}
