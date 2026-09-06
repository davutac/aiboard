import CoreGraphics
import Foundation
import Observation

// MARK: - KeyboardTypingObserving
@MainActor
protocol KeyboardTypingObserving: AnyObject {
    func prepareForInput()
    func didPostText(_ text: String)
    func didPostKey(_ stroke: KeyStroke)
    func resetTypingSession()
}

// MARK: - KeyboardTargetResolving
@MainActor
protocol KeyboardTargetResolving {
    func focusedKeyboardTarget() throws -> FocusedKeyboardTarget
}

// MARK: - KeyboardEventPosting
@MainActor
protocol KeyboardEventPosting {
    func postText(_ text: String, to target: FocusedKeyboardTarget) throws
    func replacePrefix(_ count: Int, with text: String, to target: FocusedKeyboardTarget) throws
    func postTextToSystemFocus(_ text: String) throws
    func postKey(_ key: Key, modifiers: KeyModifiers, keyDown: Bool) throws
}

// MARK: - KeyboardDeliveryMethod
nonisolated enum KeyboardDeliveryMethod: Hashable, Sendable {
    case noOperation
    case modifierState
    case textEvent
    case keyEvent
}

// MARK: - KeyboardDeliveryReceipt
nonisolated struct KeyboardDeliveryReceipt: Hashable, Sendable {
    let method: KeyboardDeliveryMethod
    let route: AccessibilityFocusRoute?
    let processIdentifier: pid_t?
    let applicationName: String?
    let summary: String

    static func noOperation(summary: String) -> KeyboardDeliveryReceipt {
        KeyboardDeliveryReceipt(
            method: .noOperation,
            route: nil,
            processIdentifier: nil,
            applicationName: nil,
            summary: summary
        )
    }

    static func modifierState(summary: String) -> KeyboardDeliveryReceipt {
        KeyboardDeliveryReceipt(
            method: .modifierState,
            route: nil,
            processIdentifier: nil,
            applicationName: nil,
            summary: summary
        )
    }

    static func systemKeyEvent(summary: String) -> KeyboardDeliveryReceipt {
        KeyboardDeliveryReceipt(
            method: .keyEvent,
            route: nil,
            processIdentifier: nil,
            applicationName: nil,
            summary: summary
        )
    }
}

// MARK: - KeyboardServiceError
nonisolated enum KeyboardServiceError: Equatable, LocalizedError, Sendable {
    case accessibility(AccessibilityFocusError)
    case eventCreationFailed
    case deliveryFailed(String)

    var errorDescription: String? {
        switch self {
        case .accessibility(let error):
            error.localizedDescription
        case .eventCreationFailed:
            "A keyboard event could not be created."
        case .deliveryFailed(let message):
            message
        }
    }
}

// MARK: - KeyboardService
@Observable
@MainActor
final class KeyboardService {
    static let shared = KeyboardService()

    var inputDidChange: (() -> Void)?
    weak var typingObserver: (any KeyboardTypingObserving)?

    private let targetResolver: KeyboardTargetResolving
    private let eventPoster: KeyboardEventPosting
    private let systemControlPerformer: any SystemControlPerforming
    private let canPostEvents: () -> Bool
    private(set) var isScreenLocked = false
    private(set) var inputSession = UUID()
    private var lockScreenInputEnabled = false

    private(set) var lastError: KeyboardServiceError?
    private(set) var lastReceipt: KeyboardDeliveryReceipt?
    private(set) var activeOneShotModifiers: Set<ModifierKey> = []
    private(set) var isCapsLockEnabled = false
    private var activeOneShotModifierOrder: [ModifierKey] = []

    // MARK: - Initialization
    init() {
        self.targetResolver = AccessibilityService.shared
        self.eventPoster = CGKeyboardEventPoster()
        self.systemControlPerformer = MacOSSystemControlPerformer()
        self.canPostEvents = {
            (getuid() != 0 || LoginWindowSession.isActive) && CGPreflightPostEventAccess()
        }
    }

    init(
        targetResolver: KeyboardTargetResolving,
        eventPoster: KeyboardEventPosting,
        systemControlPerformer: any SystemControlPerforming = MacOSSystemControlPerformer(),
        canPostEvents: @escaping () -> Bool = { CGPreflightPostEventAccess() }
    ) {
        self.targetResolver = targetResolver
        self.eventPoster = eventPoster
        self.systemControlPerformer = systemControlPerformer
        self.canPostEvents = canPostEvents
    }

    // MARK: - Lock-Screen Input
    func setScreenLocked(_ locked: Bool, allowsInput: Bool) {
        guard isScreenLocked != locked || lockScreenInputEnabled != allowsInput else { return }
        isScreenLocked = locked
        lockScreenInputEnabled = allowsInput
        inputSession = UUID()
        typingObserver?.resetTypingSession()
        clearActiveOneShotModifiers()
        lastReceipt = nil
        lastError = nil
    }

    private func checkLockScreenInput() throws {
        guard isScreenLocked else { return }
        guard lockScreenInputEnabled else {
            throw KeyboardServiceError.deliveryFailed(
                "Lock-screen keyboard is disabled in Settings."
            )
        }
        guard canPostEvents() else {
            throw KeyboardServiceError.accessibility(.accessibilityNotAuthorized)
        }
    }

    // MARK: - Key Actions
    @discardableResult
    func perform(
        _ action: KeyAction,
        behavior: KeyPressBehavior = .pressAndRelease
    ) async throws -> KeyboardDeliveryReceipt {
        switch action {
        case .none:
            recordSuccess(.noOperation(summary: "key action none"))
        case .text(let text):
            try await type(text, consumesActiveOneShotModifiers: true)
        case .keyStroke(let stroke):
            try await press(stroke, consumesActiveOneShotModifiers: true)
        case .modifier(let modifier):
            try await perform(modifier, behavior: behavior)
        case .cycleKeyboardLanguage:
            recordSuccess(.noOperation(summary: "keyboard language cycle"))
        case .toggleFunctionToolbar:
            recordSuccess(.noOperation(summary: "function toolbar visibility handled by window"))
        }
    }

    // MARK: - Function Toolbar
    @discardableResult
    func pressFunctionToolbarKey(_ key: Key) async throws -> KeyboardDeliveryReceipt {
        let modifiers = consumeActiveOneShotModifiers().filter { $0 != .function }
        return try await press(KeyStroke(key), latchedModifiers: modifiers)
    }

    @discardableResult
    func performSystemControl(_ control: SystemControl) async throws -> KeyboardDeliveryReceipt {
        clearActiveOneShotModifiers()
        do {
            try await systemControlPerformer.perform(control)
            return recordSuccess(.systemKeyEvent(summary: "system control \(control.rawValue)"))
        }
        catch {
            throw recordFailure(error)
        }
    }

    @discardableResult
    private func perform(
        _ modifier: ModifierKey,
        behavior: KeyPressBehavior
    ) async throws -> KeyboardDeliveryReceipt {
        switch behavior {
        case .pressAndRelease:
            try await pressAndRelease(modifier)
        case .oneShot:
            toggleOneShotModifier(modifier)
        }
    }

    @discardableResult
    private func pressAndRelease(_ modifier: ModifierKey) async throws -> KeyboardDeliveryReceipt {
        do {
            try checkLockScreenInput()
            try eventPoster.postKey(
                modifier.key,
                modifiers: activeOneShotModifierFlags.union(modifier.modifiers),
                keyDown: true
            )
            try eventPoster.postKey(
                modifier.key,
                modifiers: activeOneShotModifierFlags,
                keyDown: false
            )

            return recordSuccess(
                .systemKeyEvent(
                    summary: "modifier(\(modifier))"
                )
            )
        }
        catch {
            throw recordFailure(error)
        }
    }

    @discardableResult
    func toggleOneShotModifier(_ modifier: ModifierKey) -> KeyboardDeliveryReceipt {
        if activeOneShotModifiers.contains(modifier) {
            activeOneShotModifiers.remove(modifier)
            activeOneShotModifierOrder.removeAll { $0 == modifier }

            return recordSuccess(
                .modifierState(
                    summary: "modifier(\(modifier) unlatched)"
                )
            )
        }

        activeOneShotModifiers.insert(modifier)
        activeOneShotModifierOrder.append(modifier)

        return recordSuccess(
            .modifierState(
                summary: "modifier(\(modifier) latched)"
            )
        )
    }

    // MARK: - Text Input
    @discardableResult
    func type(_ text: String) async throws -> KeyboardDeliveryReceipt {
        try await type(text, consumesActiveOneShotModifiers: false)
    }

    @discardableResult
    private func type(
        _ text: String,
        consumesActiveOneShotModifiers: Bool
    ) async throws -> KeyboardDeliveryReceipt {
        guard !text.isEmpty else {
            return recordSuccess(.noOperation(summary: "empty text"))
        }

        do {
            try checkLockScreenInput()
            if isScreenLocked {
                try eventPoster.postTextToSystemFocus(text)
                if consumesActiveOneShotModifiers { clearActiveOneShotModifiers() }
                return recordSuccess(.systemKeyEvent(summary: "Input submitted to system focus"))
            }
            let target = try targetResolver.focusedKeyboardTarget()

            typingObserver?.prepareForInput()
            try eventPoster.postText(text, to: target)
            typingObserver?.didPostText(text)

            if consumesActiveOneShotModifiers {
                clearActiveOneShotModifiers()
            }

            return recordSuccess(
                receipt(
                    method: .textEvent,
                    target: target,
                    summary: "text(\(text.count) characters)"
                )
            )
        }
        catch {
            throw recordFailure(error)
        }
    }

    // MARK: - Prediction Delivery
    @discardableResult
    func type(
        _ text: String,
        deletingBackward count: Int = 0,
        toValidatedTarget target: FocusedKeyboardTarget
    ) throws
        -> KeyboardDeliveryReceipt
    {
        do {
            guard !isScreenLocked else {
                throw KeyboardServiceError.deliveryFailed("Predictions are paused while locked.")
            }
            typingObserver?.prepareForInput()
            if count > 0 {
                typingObserver?.resetTypingSession()
                try eventPoster.replacePrefix(count, with: text, to: target)
            }
            else if !text.isEmpty {
                try eventPoster.postText(text, to: target)
                typingObserver?.didPostText(text)
            }
            return recordSuccess(
                receipt(
                    method: .textEvent,
                    target: target,
                    summary: "prediction(\(text.count) characters)"
                )
            )
        }
        catch {
            throw recordFailure(error)
        }
    }

    // MARK: - Keystroke Input
    @discardableResult
    func press(_ key: Key, modifiers: KeyModifiers = []) async throws -> KeyboardDeliveryReceipt {
        try await press(KeyStroke(key, modifiers: modifiers))
    }

    @discardableResult
    func press(_ stroke: KeyStroke) async throws -> KeyboardDeliveryReceipt {
        try await press(stroke, consumesActiveOneShotModifiers: false)
    }

    @discardableResult
    func releaseActiveOneShotModifiers() async throws -> KeyboardDeliveryReceipt {
        guard !activeOneShotModifiers.isEmpty else {
            return recordSuccess(.noOperation(summary: "no active one-shot modifiers"))
        }

        clearActiveOneShotModifiers()
        return recordSuccess(.modifierState(summary: "one-shot modifiers released"))
    }

    @discardableResult
    func consumeActiveOneShotModifiers(for action: KeyAction = .none) -> [ModifierKey] {
        let modifiers = activeOneShotModifierOrder
        clearActiveOneShotModifiers()
        guard case .keyStroke(let stroke) = action else { return modifiers }
        // The resolver may remove Shift to force lowercase on a Caps Lock right-click.
        return modifiers.filter { stroke.modifiers.isSuperset(of: $0.modifiers) }
    }

    // MARK: - Caps Lock
    @discardableResult
    func toggleCapsLock() -> KeyboardDeliveryReceipt {
        isCapsLockEnabled.toggle()
        return recordSuccess(
            .modifierState(
                summary: "caps lock \(isCapsLockEnabled ? "enabled" : "disabled")"
            )
        )
    }

    // MARK: - Keystroke Delivery
    @discardableResult
    private func press(
        _ stroke: KeyStroke,
        consumesActiveOneShotModifiers: Bool
    ) async throws -> KeyboardDeliveryReceipt {
        let latchedModifiers = activeOneShotModifierOrder

        if consumesActiveOneShotModifiers, stroke.key != .capsLock {
            clearActiveOneShotModifiers()
        }

        return try await press(stroke, latchedModifiers: latchedModifiers)
    }

    @discardableResult
    func press(
        _ stroke: KeyStroke,
        latchedModifiers: [ModifierKey]
    ) async throws -> KeyboardDeliveryReceipt {
        if stroke.key == .capsLock {
            return toggleCapsLock()
        }

        do {
            try checkLockScreenInput()
            let modifiers = stroke.modifiers.union(modifierFlags(for: Set(latchedModifiers)))

            if !isScreenLocked { typingObserver?.prepareForInput() }
            try postChord(
                stroke,
                modifiers: modifiers,
                latchedModifiers: latchedModifiers
            )
            if !isScreenLocked {
                typingObserver?.didPostKey(KeyStroke(stroke.key, modifiers: modifiers))
            }

            return recordSuccess(
                .systemKeyEvent(
                    summary: "key(\(stroke.key))"
                )
            )
        }
        catch {
            throw recordFailure(error)
        }
    }

    // MARK: - One-Shot Modifiers
    private var activeOneShotModifierFlags: KeyModifiers {
        modifierFlags(for: activeOneShotModifiers)
    }

    private func modifierFlags(for modifiers: Set<ModifierKey>) -> KeyModifiers {
        modifiers.reduce([]) { flags, modifier in
            flags.union(modifier.modifiers)
        }
    }

    private func clearActiveOneShotModifiers() {
        activeOneShotModifiers.removeAll()
        activeOneShotModifierOrder.removeAll()
    }

    // MARK: - Chord Events
    private func postChord(
        _ stroke: KeyStroke,
        modifiers: KeyModifiers,
        latchedModifiers: [ModifierKey]
    ) throws {
        var postedModifiers: [ModifierKey] = []
        var keyIsDown = false

        do {
            var pressedModifiers: Set<ModifierKey> = []

            for modifier in latchedModifiers {
                pressedModifiers.insert(modifier)
                try eventPoster.postKey(
                    modifier.key,
                    modifiers: modifierFlags(for: pressedModifiers),
                    keyDown: true
                )
                postedModifiers.append(modifier)
            }

            try eventPoster.postKey(
                stroke.key,
                modifiers: modifiers,
                keyDown: true
            )
            keyIsDown = true

            try eventPoster.postKey(
                stroke.key,
                modifiers: modifiers,
                keyDown: false
            )
            keyIsDown = false

            try postModifierUps(postedModifiers)
        }
        catch {
            if keyIsDown {
                try? eventPoster.postKey(
                    stroke.key,
                    modifiers: modifiers,
                    keyDown: false
                )
            }

            postModifierUpsBestEffort(postedModifiers)
            throw error
        }
    }

    private func postModifierUps(_ modifiers: [ModifierKey]) throws {
        var remainingModifiers = Set(modifiers)

        for modifier in modifiers.reversed() {
            remainingModifiers.remove(modifier)
            try eventPoster.postKey(
                modifier.key,
                modifiers: modifierFlags(for: remainingModifiers),
                keyDown: false
            )
        }
    }

    private func postModifierUpsBestEffort(_ modifiers: [ModifierKey]) {
        var remainingModifiers = Set(modifiers)

        for modifier in modifiers.reversed() {
            remainingModifiers.remove(modifier)
            try? eventPoster.postKey(
                modifier.key,
                modifiers: modifierFlags(for: remainingModifiers),
                keyDown: false
            )
        }
    }

    // MARK: - Receipts
    private func receipt(
        method: KeyboardDeliveryMethod,
        target: FocusedKeyboardTarget,
        summary: String
    ) -> KeyboardDeliveryReceipt {
        KeyboardDeliveryReceipt(
            method: method,
            route: target.route,
            processIdentifier: target.processIdentifier,
            applicationName: target.applicationName,
            summary: summary
        )
    }

    private func recordSuccess(_ receipt: KeyboardDeliveryReceipt) -> KeyboardDeliveryReceipt {
        lastError = nil
        if isScreenLocked {
            lastReceipt = nil
            return KeyboardDeliveryReceipt(
                method: receipt.method,
                route: nil,
                processIdentifier: nil,
                applicationName: nil,
                summary: "Lock-screen input; acceptance unverified"
            )
        }
        lastReceipt = receipt
        inputDidChange?()

        return receipt
    }

    private func recordFailure(_ error: any Error) -> KeyboardServiceError {
        typingObserver?.resetTypingSession()
        let serviceError = KeyboardServiceError(error)

        lastError = serviceError

        return serviceError
    }
}

// MARK: - AccessibilityService KeyboardTargetResolving
extension AccessibilityService: KeyboardTargetResolving {}

// MARK: - KeyboardServiceError Conversion
extension KeyboardServiceError {
    fileprivate init(_ error: any Error) {
        if let serviceError = error as? KeyboardServiceError {
            self = serviceError
        }
        else if let accessibilityError = error as? AccessibilityFocusError {
            self = .accessibility(accessibilityError)
        }
        else {
            self = .deliveryFailed(error.localizedDescription)
        }
    }
}
