// MARK: - PhysicalKeyboardSnapshot
nonisolated struct PhysicalKeyboardSnapshot: Equatable {
    var pressedKeys: Set<Key> = []
    var modifiers: Set<ModifierKey> = []
    var isCapsLockEnabled = false
    var pressedControls: Set<SystemControl> = []

    var modifierFlags: KeyModifiers {
        modifiers.reduce(isCapsLockEnabled ? [.capsLock] : []) { $0.union($1.modifiers) }
    }

    // MARK: - Matching
    func isPressed(_ action: KeyAction) -> Bool {
        switch action {
        case .keyStroke(let stroke):
            guard pressedKeys.contains(stroke.key) else { return false }
            // A plain key follows its physical position even during a shortcut.
            if stroke.modifiers.isEmpty { return true }
            let chordFlags: KeyModifiers = [.command, .control, .option, .shift, .function]
            return modifierFlags.intersection(chordFlags)
                == stroke.modifiers.intersection(chordFlags)
        case .modifier(let modifier):
            return modifiers.contains(modifier)
        default:
            return false
        }
    }

    // MARK: - Key State
    mutating func setKey(_ key: Key, isDown: Bool) {
        if isDown {
            pressedKeys.insert(key)
        }
        else {
            pressedKeys.remove(key)
        }
    }
}
