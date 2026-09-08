import ApplicationServices
import Foundation

@testable import Tastko

// MARK: - Hardware Fixture
@MainActor
final class FakeHardwareState {
    var snapshot = PhysicalKeyboardSnapshot()
}

// MARK: - KeyboardService Test Helpers
@MainActor
final class FakeKeyboardTargetResolver: KeyboardTargetResolving {
    private var target: FocusedKeyboardTarget?
    private let error: (any Error)?

    private(set) var resolveCount = 0

    init(target: FocusedKeyboardTarget? = nil, error: (any Error)? = nil) {
        self.target = target
        self.error = error
    }

    func focusedKeyboardTarget() throws -> FocusedKeyboardTarget {
        resolveCount += 1

        if let error {
            throw error
        }

        guard let target else {
            throw AccessibilityFocusError.focusedApplicationUnavailable
        }

        return target
    }
}

@MainActor
final class FakeKeyboardEventPoster: KeyboardEventPosting {
    enum Event: Equatable {
        case text(String, pid_t, AccessibilityFocusRoute)
        case replacement(Int, String, pid_t)
        case systemText(String)
        case key(Key, KeyModifiers, Bool)
        case keyRepeat(Key, KeyModifiers)
    }

    private(set) var events: [Event] = []
    var failingKeyPostAttempts: Set<Int> = []
    private(set) var keyPostAttempts = 0

    func postTextToSystemFocus(_ text: String) throws {
        events.append(.systemText(text))
    }

    func postText(_ text: String, to target: FocusedKeyboardTarget) throws {
        events.append(.text(text, target.processIdentifier, target.route))
    }

    // MARK: - Replacement
    func replacePrefix(_ count: Int, with text: String, to target: FocusedKeyboardTarget) throws {
        events.append(.replacement(count, text, target.processIdentifier))
    }

    func postKey(
        _ key: Key,
        modifiers: KeyModifiers,
        keyDown: Bool
    ) throws {
        try postKeyEvent(.key(key, modifiers, keyDown))
    }

    // MARK: - Repeat Delivery
    func postKeyRepeat(_ key: Key, modifiers: KeyModifiers) throws {
        try postKeyEvent(.keyRepeat(key, modifiers))
    }

    // MARK: - Key Posting Failures
    private func postKeyEvent(_ event: Event) throws {
        keyPostAttempts += 1
        if failingKeyPostAttempts.contains(keyPostAttempts) {
            throw KeyboardServiceError.eventCreationFailed
        }
        events.append(event)
    }
}

@MainActor
func keyboardServiceTarget(
    processIdentifier: pid_t = 1234,
    applicationName: String = "Target App",
    route: AccessibilityFocusRoute = .textElement
) -> FocusedKeyboardTarget {
    let element = AXUIElementCreateSystemWide()
    let textElement = route == .textElement ? element : nil
    let window = route == .window ? element : nil

    return FocusedKeyboardTarget(
        processIdentifier: processIdentifier,
        applicationName: applicationName,
        applicationElement: element,
        focusedTextElement: textElement,
        focusedWindow: window,
        route: route
    )
}

// MARK: - FailingCapsLockState
@MainActor
final class FailingCapsLockState {
    var isEnabled = false
    var shouldFail = true

    // MARK: - Toggle
    func toggle() throws -> Bool {
        if shouldFail { throw KeyboardServiceError.deliveryFailed("Caps Lock unavailable") }
        isEnabled.toggle()
        return isEnabled
    }
}

// MARK: - FakeSystemControlPerformer
@MainActor
final class FakeSystemControlPerformer: SystemControlPerforming {
    var controls: [SystemControl] = []
    var shouldFail = false

    // MARK: - Execution
    func perform(_ control: SystemControl) async throws {
        if shouldFail { throw KeyboardServiceError.deliveryFailed("System control unavailable") }
        controls.append(control)
    }
}
