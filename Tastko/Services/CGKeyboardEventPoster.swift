import CoreGraphics

// MARK: - CGKeyboardEventPoster
struct CGKeyboardEventPoster: KeyboardEventPosting {
    // Distinguish our posted events from physical or other applications' input.
    static let predictionEventTag: Int64 = 0x41_6962_6F61_7264
    private let source = CGEventSource(stateID: .combinedSessionState)

    // MARK: - System-Focus Text
    func postTextToSystemFocus(_ text: String) throws {
        let down = try unicodeEvent(text, keyDown: true)
        let up = try unicodeEvent(text, keyDown: false)
        down.flags = []
        up.flags = []
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    func postText(_ text: String, to target: FocusedKeyboardTarget) throws {
        let keyDown = try unicodeEvent(text, keyDown: true)
        let keyUp = try unicodeEvent(text, keyDown: false)

        keyDown.postToPid(target.processIdentifier)
        keyUp.postToPid(target.processIdentifier)
    }

    // MARK: - Prediction Replacement
    func replacePrefix(_ count: Int, with text: String, to target: FocusedKeyboardTarget) throws {
        // Prepare every event before changing text, so allocation failure cannot
        // leave a partially deleted prefix. Deliver all events to the captured app.
        var events: [CGEvent] = []
        for _ in 0..<count {
            for down in [true, false] {
                guard
                    let event = CGEvent(
                        keyboardEventSource: source,
                        virtualKey: 0x33,
                        keyDown: down
                    )
                else { throw KeyboardServiceError.eventCreationFailed }
                event.flags = []
                event.setIntegerValueField(.eventSourceUserData, value: Self.predictionEventTag)
                events.append(event)
            }
        }
        if !text.isEmpty {
            events.append(try unicodeEvent(text, keyDown: true))
            events.append(try unicodeEvent(text, keyDown: false))
        }
        for event in events {
            event.flags = []
            event.postToPid(target.processIdentifier)
        }
    }

    // MARK: - Key Delivery
    func postKey(
        _ key: Key,
        modifiers: KeyModifiers,
        keyDown: Bool
    ) throws {
        guard
            let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: key.cgKeyCode,
                keyDown: keyDown
            )
        else {
            throw KeyboardServiceError.eventCreationFailed
        }

        event.flags = modifiers.cgEventFlags
        event.setIntegerValueField(.eventSourceUserData, value: Self.predictionEventTag)
        event.post(tap: .cghidEventTap)
    }

    // MARK: - Events
    private func unicodeEvent(_ text: String, keyDown: Bool) throws -> CGEvent {
        guard
            let event = CGEvent(
                keyboardEventSource: source,
                virtualKey: 0,
                keyDown: keyDown
            )
        else {
            throw KeyboardServiceError.eventCreationFailed
        }

        let characters = Array(text.utf16)
        event.setIntegerValueField(.eventSourceUserData, value: Self.predictionEventTag)

        characters.withUnsafeBufferPointer { buffer in
            event.keyboardSetUnicodeString(
                stringLength: characters.count,
                unicodeString: buffer.baseAddress
            )
        }

        return event
    }

}
