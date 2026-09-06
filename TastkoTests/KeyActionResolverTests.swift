import Testing

@testable import Tastko

// MARK: - KeyActionResolverTests
struct KeyActionResolverTests {
    // MARK: - Caps Lock
    @Test func capsLockDoesNotRepeatWhileHeld() {
        let action = KeyAction.keyStroke(KeyStroke(.capsLock))
        #expect(action.isModifier)
        #expect(!action.isRepeatable)
    }

    @Test(arguments: [KeyActionTrigger.leftClick, .rightClick])
    func capsLockControlsLetterCase(_ trigger: KeyActionTrigger) {
        let action = KeyActionResolver.action(
            for: trigger,
            primaryAction: .keyStroke(KeyStroke(.a)),
            secondaryAction: .keyStroke(KeyStroke(.a, modifiers: [.shift])),
            activeOneShotModifiers: [],
            isCapsLockEnabled: true,
            primaryTitle: "A"
        )
        let flags: KeyModifiers = trigger == .leftClick ? [.capsLock] : []
        #expect(action == .keyStroke(KeyStroke(.a, modifiers: flags)))
    }

    @Test func capsLockRightClickUsesLowercaseEvenWithoutASecondaryAction() {
        let action = KeyActionResolver.action(
            for: .rightClick,
            primaryAction: .keyStroke(KeyStroke(.semicolon)),
            secondaryAction: .none,
            activeOneShotModifiers: [.leftShift],
            isCapsLockEnabled: true,
            primaryTitle: "Ö"
        )
        #expect(action == .keyStroke(KeyStroke(.semicolon)))
    }

    @Test func capsLockPreservesNumberAndPunctuationActions() {
        for trigger in [KeyActionTrigger.leftClick, .rightClick] {
            let action = KeyActionResolver.action(
                for: trigger,
                primaryAction: .keyStroke(KeyStroke(.one)),
                secondaryAction: .keyStroke(KeyStroke(.one, modifiers: [.shift])),
                activeOneShotModifiers: [],
                isCapsLockEnabled: true,
                primaryTitle: "1"
            )
            let flags: KeyModifiers = trigger == .rightClick ? [.shift] : []
            #expect(action == .keyStroke(KeyStroke(.one, modifiers: flags)))
        }
    }

    @Test func capsLockChangesTextActionCase() {
        for trigger in [KeyActionTrigger.leftClick, .rightClick] {
            let action = KeyActionResolver.action(
                for: trigger,
                primaryAction: .text("Hello ä"),
                secondaryAction: .none,
                activeOneShotModifiers: [],
                isCapsLockEnabled: true
            )
            #expect(action == .text(trigger == .leftClick ? "HELLO Ä" : "hello ä"))
        }
    }

    @Test func capsLockDoesNotChangeKeyboardShortcuts() {
        let action = KeyActionResolver.action(
            for: .leftClick,
            primaryAction: .keyStroke(KeyStroke(.s)),
            secondaryAction: .keyStroke(KeyStroke(.s, modifiers: [.shift])),
            activeOneShotModifiers: [.leftCommand, .leftShift],
            isCapsLockEnabled: true,
            primaryTitle: "S"
        )
        #expect(action == .keyStroke(KeyStroke(.s, modifiers: [.command, .shift])))
    }

    // MARK: - Resolution
    @Test func leftClickUsesPrimaryActionWithoutShift() {
        let action = KeyActionResolver.action(
            for: .leftClick,
            primaryAction: .keyStroke(KeyStroke(.one)),
            secondaryAction: .keyStroke(KeyStroke(.one, modifiers: [.shift])),
            activeOneShotModifiers: []
        )

        #expect(action == .keyStroke(KeyStroke(.one)))
    }

    @Test func rightClickUsesSecondaryAction() {
        let action = KeyActionResolver.action(
            for: .rightClick,
            primaryAction: .keyStroke(KeyStroke(.one)),
            secondaryAction: .keyStroke(KeyStroke(.one, modifiers: [.shift])),
            activeOneShotModifiers: []
        )

        #expect(action == .keyStroke(KeyStroke(.one, modifiers: [.shift])))
    }

    @Test func leftClickWithActiveShiftUsesSecondaryAction() {
        let action = KeyActionResolver.action(
            for: .leftClick,
            primaryAction: .keyStroke(KeyStroke(.one)),
            secondaryAction: .keyStroke(KeyStroke(.one, modifiers: [.shift])),
            activeOneShotModifiers: [.leftShift]
        )

        #expect(action == .keyStroke(KeyStroke(.one, modifiers: [.shift])))
    }

    @Test func leftClickWithActiveShiftFallsBackToPrimaryWhenSecondaryActionIsNone() {
        let action = KeyActionResolver.action(
            for: .leftClick,
            primaryAction: .keyStroke(KeyStroke(.one)),
            secondaryAction: .none,
            activeOneShotModifiers: [.leftShift]
        )

        #expect(action == .keyStroke(KeyStroke(.one, modifiers: [.shift])))
    }

    @Test func modifierPrimaryBypassesShiftSecondaryAction() {
        let action = KeyActionResolver.action(
            for: .leftClick,
            primaryAction: .modifier(.leftShift),
            secondaryAction: .keyStroke(KeyStroke(.one, modifiers: [.shift])),
            activeOneShotModifiers: [.leftShift]
        )

        #expect(action == .modifier(.leftShift))
    }

    @Test func resolvedKeyStrokeSnapshotsAllActiveModifiers() {
        let action = KeyActionResolver.action(
            for: .leftClick,
            primaryAction: .keyStroke(KeyStroke(.s)),
            secondaryAction: .keyStroke(KeyStroke(.s, modifiers: [.shift])),
            activeOneShotModifiers: [.leftCommand, .leftShift]
        )

        #expect(action == .keyStroke(KeyStroke(.s, modifiers: [.command, .shift])))
    }
}
