import CoreGraphics
import Foundation
import Testing

@testable import Tastko

// MARK: - Function Key
extension KeyboardServiceTests {
    // MARK: - Modifier Hotkeys
    @Test func functionTogglePostsImmediatelyAndHoldsUntilNextClick() async throws {
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )

        try await service.perform(.modifier(.function), behavior: .oneShot)
        #expect(poster.events == [.key(.function, [.function], true)])
        #expect(service.heldModifiers == [.function])
        #expect(service.activeOneShotModifiers.isEmpty)

        try await service.perform(.modifier(.function), behavior: .oneShot)
        #expect(poster.events == [.key(.function, [.function], true), .key(.function, [], false)])
        #expect(service.heldModifiers.isEmpty)
    }

    @Test func stickyModifierPostsImmediately() async throws {
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )

        try await service.perform(.modifier(.leftCommand), behavior: .oneShot)

        #expect(poster.events == [.key(.leftCommand, [.command], true)])
    }

    // MARK: - Fn Hardware Reconciliation
    @Test func releasingVirtualFnClearsTheFlagAndAllowsAnotherPressDespiteStaleKeycode() throws {
        let hardware = FakeHardwareState()
        let physical = PhysicalKeyboardState(
            readHardware: {
                PhysicalKeyboardState.hardwareSnapshot(
                    pressedKeys: hardware.snapshot.pressedKeys,
                    flags: hardware.snapshot.modifierFlags.cgEventFlags
                )
            },
            canObserve: { true }
        )
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster,
            physicalKeyboard: physical
        )
        let first = try #require(try service.beginFunctionPress())
        // Reproduce the live mismatch after the app's Fn click: keycode down, flag off.
        hardware.snapshot = PhysicalKeyboardSnapshot(pressedKeys: [.function])
        physical.refresh()
        try service.endFunctionPress(first)
        #expect(service.effectiveModifiers.contains(.function) == false)
        let second = try #require(try service.beginFunctionPress())
        try service.endFunctionPress(second)
        #expect(
            poster.events == [
                .key(.function, [.function], true), .key(.function, [], false),
                .key(.function, [.function], true), .key(.function, [], false),
            ]
        )
    }

    // MARK: - Held Fn
    @Test func functionPressHoldsAcrossStrokesUntilMatchingTokenEndsIt() throws {
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )
        try service.toggleOneShotModifier(.leftCommand)
        let token = try #require(try service.beginFunctionPress())
        #expect(service.heldModifiers == [.function])
        #expect(service.effectiveModifiers == [.leftCommand, .function])
        #expect(
            poster.events == [
                .key(.leftCommand, [.command], true),
                .key(.function, [.command, .function], true),
            ]
        )

        let modifiers = service.consumeActiveOneShotModifiers()
        try service.press(KeyStroke(.a), latchedModifiers: modifiers)
        #expect(service.heldModifiers == [.function])
        #expect(service.activeOneShotModifiers.isEmpty)
        #expect(
            poster.events == [
                .key(.leftCommand, [.command], true),
                .key(.function, [.command, .function], true),
                .key(.a, [.command, .function], true), .key(.a, [.command, .function], false),
                .key(.leftCommand, [.function], false),
            ]
        )
        try service.endFunctionPress(UUID())
        #expect(poster.events.count == 5)
        #expect(service.heldModifiers == [.function])
        try service.endFunctionPress(token)
        #expect(poster.events.last == .key(.function, [], false))
        #expect(service.heldModifiers.isEmpty)
        try service.endFunctionPress(token)
        #expect(poster.events.count == 6)
    }

    // MARK: - Fn Toggle
    @Test func functionToggleAndOneShotPerformShareTheSameHold() async throws {
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )
        let receipt = try service.toggleOneShotModifier(.function)
        #expect(receipt.method == .keyEvent)
        #expect(service.activeOneShotModifiers.isEmpty)
        #expect(service.heldModifiers == [.function])
        try await service.perform(.modifier(.function), behavior: .oneShot)
        #expect(
            poster.events == [
                .key(.function, [.function], true), .key(.function, [], false),
            ]
        )
        #expect(service.activeOneShotModifiers.isEmpty)
        #expect(service.heldModifiers.isEmpty)
    }

    // MARK: - Toggle Cleanup
    @Test func functionToggleSurvivesTypingAndCanRestartAfterCleanup() throws {
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )
        try service.toggleFunctionKey()
        try service.press(KeyStroke(.a), latchedModifiers: [])
        #expect(service.heldModifiers == [.function])
        service.releaseAllModifiers()
        #expect(service.heldModifiers.isEmpty)
        try service.toggleFunctionKey()
        try service.toggleFunctionKey()
        #expect(service.heldModifiers.isEmpty)
        #expect(
            poster.events == [
                .key(.function, [.function], true),
                .key(.a, [.function], true), .key(.a, [.function], false),
                .key(.function, [], false),
                .key(.function, [.function], true), .key(.function, [], false),
            ]
        )
    }

    // MARK: - Duplicate Fn
    @Test func duplicateFunctionPressDoesNotReleaseExistingHold() throws {
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )
        let token = try #require(try service.beginFunctionPress())
        #expect(try service.beginFunctionPress() == nil)
        #expect(poster.events == [.key(.function, [.function], true)])
        #expect(service.heldModifiers == [.function])
        try service.endFunctionPress(token)
        #expect(poster.events == [.key(.function, [.function], true), .key(.function, [], false)])
    }

    // MARK: - Physical Fn
    @Test func physicallyHeldFunctionIsNeitherDuplicatedNorReleasedByVirtualInput() async throws {
        let physical = PhysicalKeyboardState(
            readHardware: {
                PhysicalKeyboardSnapshot(pressedKeys: [.function], modifiers: [.function])
            },
            canObserve: { true }
        )
        physical.refresh()
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster,
            physicalKeyboard: physical
        )
        #expect(try service.beginFunctionPress() == nil)
        try service.toggleOneShotModifier(.function)
        try await service.perform(.modifier(.function), behavior: .oneShot)
        try service.endFunctionPress(UUID())
        service.releaseAllModifiers()
        #expect(poster.events.isEmpty)
        #expect(service.activeOneShotModifiers.isEmpty)
        #expect(service.heldModifiers == [.function])
        try await service.press(.a)
        #expect(poster.events == [.key(.a, [.function], true), .key(.a, [.function], false)])
    }

    // MARK: - Fn Lock Transition
    @Test func lockTransitionReleasesFunctionAndOldTokenCannotEndNewHold() throws {
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster,
            canPostEvents: { true }
        )
        let oldToken = try #require(try service.beginFunctionPress())
        service.setScreenLocked(true, allowsInput: true)
        #expect(service.heldModifiers.isEmpty)
        #expect(poster.events == [.key(.function, [.function], true), .key(.function, [], false)])
        let newToken = try #require(try service.beginFunctionPress())
        #expect(newToken != oldToken)
        try service.endFunctionPress(oldToken)
        #expect(service.heldModifiers == [.function])
        #expect(poster.events.count == 3)
        service.setScreenLocked(false, allowsInput: false)
        try service.endFunctionPress(newToken)
        #expect(service.heldModifiers.isEmpty)
        #expect(
            poster.events == [
                .key(.function, [.function], true), .key(.function, [], false),
                .key(.function, [.function], true), .key(.function, [], false),
            ]
        )
    }

    // MARK: - Modifier Cleanup
    @Test func cleanupReleasesTransferredStickyModifiersAndHeldFnOnlyOnce() throws {
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )
        try service.toggleOneShotModifier(.leftCommand)
        try service.toggleOneShotModifier(.leftShift)
        let token = try #require(try service.beginFunctionPress())
        #expect(service.consumeActiveOneShotModifiers() == [.leftCommand, .leftShift])
        service.releaseAllModifiers()
        #expect(service.activeOneShotModifiers.isEmpty)
        #expect(service.heldModifiers.isEmpty)
        #expect(
            poster.events == [
                .key(.leftCommand, [.command], true),
                .key(.leftShift, [.command, .shift], true),
                .key(.function, [.command, .shift, .function], true),
                .key(.leftShift, [.command, .function], false),
                .key(.leftCommand, [.function], false),
                .key(.function, [], false),
            ]
        )
        service.releaseAllModifiers()
        try service.endFunctionPress(token)
        #expect(poster.events.count == 6)
    }

    // MARK: - Fn Caps Lock Flags
    @Test func functionTransitionsPreservePhysicalCapsLockAndOtherHeldFlags() throws {
        let physical = PhysicalKeyboardState(
            readHardware: {
                PhysicalKeyboardSnapshot(
                    pressedKeys: [.rightOption],
                    modifiers: [.rightOption],
                    isCapsLockEnabled: true
                )
            },
            canObserve: { true }
        )
        physical.refresh()
        let poster = FakeKeyboardEventPoster()
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster,
            physicalKeyboard: physical
        )
        let token = try #require(try service.beginFunctionPress())
        try service.endFunctionPress(token)
        #expect(
            poster.events == [
                .key(.function, [.function, .option, .capsLock], true),
                .key(.function, [.option, .capsLock], false),
            ]
        )
        #expect(service.effectiveModifiers == [.rightOption])
        #expect(service.isCapsLockEnabled)
    }

    // MARK: - Fn Down Failure
    @Test func failedFunctionDownDoesNotCreateAHold() throws {
        let poster = FakeKeyboardEventPoster()
        poster.failingKeyPostAttempts = [1]
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )
        #expect(throws: KeyboardServiceError.eventCreationFailed) {
            try service.beginFunctionPress()
        }
        #expect(service.lastError == .eventCreationFailed)
        #expect(service.heldModifiers.isEmpty)
        #expect(poster.events.isEmpty)
        let token = try #require(try service.beginFunctionPress())
        try service.endFunctionPress(token)
        #expect(service.lastError == nil)
        #expect(poster.events == [.key(.function, [.function], true), .key(.function, [], false)])
    }

    // MARK: - Fn Up Failure
    @Test func failedFunctionUpKeepsTokenValidForRetry() throws {
        let poster = FakeKeyboardEventPoster()
        poster.failingKeyPostAttempts = [2]
        let service = KeyboardService(
            targetResolver: FakeKeyboardTargetResolver(),
            eventPoster: poster
        )
        let token = try #require(try service.beginFunctionPress())
        #expect(throws: KeyboardServiceError.eventCreationFailed) {
            try service.endFunctionPress(token)
        }
        #expect(service.lastError == .eventCreationFailed)
        #expect(service.heldModifiers == [.function])
        #expect(poster.events == [.key(.function, [.function], true)])
        try service.endFunctionPress(token)
        #expect(service.heldModifiers.isEmpty)
        #expect(service.lastError == nil)
        #expect(poster.events == [.key(.function, [.function], true), .key(.function, [], false)])
    }
}
