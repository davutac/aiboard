import AppKit
import IOKit
import Testing

@testable import Tastko

// MARK: - PhysicalKeyboardStateTests
@MainActor
struct PhysicalKeyboardStateTests {
    // MARK: - Presses
    @Test func simultaneousKeysRepeatAndReleaseIndependently() throws {
        let state = PhysicalKeyboardState(canObserve: { true })
        state.receive(try event(.a, down: true))
        state.receive(try event(.b, down: true))
        state.receive(try event(.a, down: true, repeating: true))
        #expect(state.snapshot.pressedKeys == [.a, .b])
        state.receive(try event(.a, down: false))
        #expect(state.snapshot.pressedKeys == [.b])
        state.receive(try event(.b, down: false))
        #expect(state.snapshot.pressedKeys.isEmpty)
    }

    @Test func ignoresOurSyntheticEvents() throws {
        let state = PhysicalKeyboardState(canObserve: { true })
        let cgEvent = try #require(
            CGEvent(keyboardEventSource: nil, virtualKey: Key.a.rawValue, keyDown: true)
        )
        cgEvent.setIntegerValueField(
            .eventSourceUserData,
            value: CGKeyboardEventPoster.predictionEventTag
        )
        state.receive(try #require(NSEvent(cgEvent: cgEvent)))
        #expect(state.snapshot.pressedKeys.isEmpty)
    }

    @Test func matchesPlainKeysAndCompleteShortcutChords() {
        let snapshot = PhysicalKeyboardSnapshot(pressedKeys: [.c], modifiers: [.rightCommand])
        #expect(snapshot.isPressed(.keyStroke(KeyStroke(.c))))
        #expect(snapshot.isPressed(.keyStroke(KeyStroke(.c, modifiers: [.command]))))
        #expect(!snapshot.isPressed(.keyStroke(KeyStroke(.c, modifiers: [.command, .shift]))))
        #expect(!snapshot.isPressed(.text("c")))
        #expect(snapshot.isPressed(.modifier(.rightCommand)))
        #expect(!snapshot.isPressed(.modifier(.leftCommand)))
        let extraModifier = PhysicalKeyboardSnapshot(
            pressedKeys: [.c],
            modifiers: [.rightCommand, .leftShift]
        )
        #expect(!extraModifier.isPressed(.keyStroke(KeyStroke(.c, modifiers: [.command]))))
    }

    // MARK: - Modifier Events
    @Test func flagsChangedTracksBothSidesAndCapsLockWithoutClearingOtherKeys() throws {
        var hardware = PhysicalKeyboardSnapshot(
            pressedKeys: [.leftShift, .rightShift, .function],
            modifiers: [.leftShift, .rightShift, .function],
            isCapsLockEnabled: true
        )
        let state = PhysicalKeyboardState(readHardware: { hardware }, canObserve: { true })
        state.receive(try event(.a, down: true))
        let changed = try #require(
            NSEvent.keyEvent(
                with: .flagsChanged,
                location: .zero,
                modifierFlags: [.shift, .function, .capsLock],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: false,
                keyCode: Key.rightShift.rawValue
            )
        )
        state.receive(changed)
        #expect(state.snapshot.modifiers == [.leftShift, .rightShift, .function])
        #expect(state.snapshot.isCapsLockEnabled)
        #expect(state.snapshot.pressedKeys.contains(.a))
        hardware.modifiers.remove(.rightShift)
        hardware.pressedKeys.remove(.rightShift)
        state.receive(changed)
        #expect(state.snapshot.modifiers == [.leftShift, .function])
    }

    // MARK: - Reconciliation
    @Test func refreshesBothModifierSidesAndRecoversMissedReleases() throws {
        var hardware = PhysicalKeyboardSnapshot(
            pressedKeys: [.leftOption, .rightOption],
            modifiers: [.leftOption, .rightOption],
            isCapsLockEnabled: true
        )
        let state = PhysicalKeyboardState(readHardware: { hardware }, canObserve: { true })
        state.refresh()
        #expect(state.snapshot == hardware)
        hardware.pressedKeys.remove(.leftOption)
        hardware.modifiers.remove(.leftOption)
        state.refresh()
        #expect(state.snapshot.modifiers == [.rightOption])
        state.receive(try event(.a, down: true))
        #expect(state.snapshot.pressedKeys.contains(.a))
        state.refresh()
        #expect(!state.snapshot.pressedKeys.contains(.a))
        state.stop()
        #expect(state.snapshot == PhysicalKeyboardSnapshot())
    }

    @Test func permissionLossClearsState() throws {
        var permitted = true
        let state = PhysicalKeyboardState(canObserve: { permitted })
        state.receive(try event(.a, down: true))
        permitted = false
        state.refresh()
        #expect(state.snapshot == PhysicalKeyboardSnapshot())
        state.receive(try event(.b, down: true))
        #expect(state.snapshot.pressedKeys.isEmpty)
    }

    // MARK: - Toolbar
    @Test func mediaKeysAndFunctionKeysHighlightTheToolbar() throws {
        let state = PhysicalKeyboardState(canObserve: { true })
        state.receive(try MacOSSystemControlPerformer.event(for: .playPause, keyDown: true))
        let item = try #require(
            FunctionToolbarItem.items(functionIsActive: false).first {
                $0.action == .system(.playPause)
            }
        )
        #expect(item.isPressed(in: state.snapshot))
        state.receive(try MacOSSystemControlPerformer.event(for: .playPause, keyDown: false))
        #expect(!item.isPressed(in: state.snapshot))
        #expect(PhysicalKeyboardState.control(for: Int(NX_KEYTYPE_BRIGHTNESS_UP)) == .brightnessUp)
        let f1 = try #require(
            FunctionToolbarItem.items(functionIsActive: true).first { $0.action == .key(.f1) }
        )
        #expect(f1.isPressed(in: PhysicalKeyboardSnapshot(pressedKeys: [.f1])))
    }

    // MARK: - Fixtures
    private func event(_ key: Key, down: Bool, repeating: Bool = false) throws -> NSEvent {
        try #require(
            NSEvent.keyEvent(
                with: down ? .keyDown : .keyUp,
                location: .zero,
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: "",
                charactersIgnoringModifiers: "",
                isARepeat: repeating,
                keyCode: key.rawValue
            )
        )
    }
}
