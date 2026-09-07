import SwiftUI

// MARK: - PanelEditorButtonView
struct PanelEditorButtonView: View {
    @Environment(\.keyboardService) private var keyboardService
    @Environment(\.keyboardLanguageService) private var languageService
    @Environment(\.soundService) private var soundService
    @Environment(\.floatingWindowController) private var floatingWindowController

    let button: PanelEditorButton
    let scale: CGFloat
    let languageContext: KeyboardLanguageContext

    @State private var pressedButton: KeyMouseButton?
    @State private var isHovered = false
    @State private var repeatTask: Task<Void, Never>?

    // MARK: - Body
    var body: some View {
        ZStack {
            PanelEditorKeycap(
                button: button,
                presentation: resolvedPresentation,
                scale: scale,
                isPressed: isPressed,
                isHovered: isHovered,
                isActive: isModifierActive
            )

            KeyMouseEventView(
                pressedButton: $pressedButton,
                hitRegion: hitRegion,
                mousePressed: handleMousePress,
                mouseReleasedInside: handleMouseRelease,
                mouseCancelled: handleMouseCancellation
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
        .contentShape(PanelEditorKeyShape(buttonShape: button.shape))
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isPressed ? "Pressed" : "")
        .accessibilityAddTraits(accessibilityTraits)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction {
            perform(action(for: .left))
        }
        .accessibilityAction(
            named: keyboardService.effectiveCapsLockEnabled ? "Lowercase key" : "Shifted key"
        ) {
            perform(action(for: .right))
        }
        .onDisappear {
            stopRepeatingAction()
        }
        .onChange(of: keyboardService.inputSession) {
            stopRepeatingAction()
            pressedButton = nil
        }
    }

    // MARK: - Presentation
    private var resolvedPresentation: ResolvedKeyPresentation {
        presentation(modifiers: keyboardService.activeOneShotModifiers)
    }

    // MARK: - Layout Labels
    private func presentation(modifiers: Set<ModifierKey>) -> ResolvedKeyPresentation {
        let base = LanguageAwareKeyResolver.presentation(
            title: button.title,
            secondaryTitle: button.secondaryTitle ?? "",
            leftClickAction: button.primaryAction,
            rightClickAction: button.secondaryAction,
            languageContext: languageContext
        )
        return ModifierAwareKeyResolver.presentation(
            from: base,
            translator: languageService.keyLabels,
            activeOneShotModifiers: modifiers,
            physicalModifiers: keyboardService.physicalKeyboard.snapshot.modifiers,
            isCapsLockEnabled: keyboardService.effectiveCapsLockEnabled
        )
    }

    // MARK: - Accessibility
    private var accessibilityLabel: String {
        let title =
            resolvedPresentation.title.isEmpty
            ? "Unavailable panel button" : resolvedPresentation.title
        return resolvedPresentation.isDeadKey ? "\(title), accent dead key" : title
    }

    private var accessibilityHint: String {
        if resolvedPresentation.isDeadKey {
            return "Combines an accent with the next character"
        }
        if button.primaryAction == .toggleFunctionToolbar {
            return "Shows or hides the system controls and function keys"
        }
        if button.primaryAction.isCapsLock {
            return "Toggles uppercase typing; right-click a letter to type lowercase"
        }

        guard modifierKey != nil else {
            if keyboardService.effectiveCapsLockEnabled {
                return "Left-click types uppercase; right-click types a letter in lowercase"
            }
            return "Left-click types the key; right-click types it with Shift"
        }

        return "Toggles this modifier for the next key; multiple modifiers can be combined"
    }

    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = [.isButton]

        if isModifierActive {
            _ = traits.insert(.isSelected)
        }

        return traits
    }

    private var modifierKey: ModifierKey? {
        guard case .modifier(let modifier) = button.primaryAction else {
            return nil
        }

        return modifier
    }

    private var isPressed: Bool {
        pressedButton != nil
            || keyboardService.physicalKeyboard.snapshot.isPressed(button.primaryAction)
    }

    private var isModifierActive: Bool {
        if button.primaryAction.isCapsLock {
            return keyboardService.effectiveCapsLockEnabled
        }

        guard let modifierKey else {
            return false
        }

        return keyboardService.effectiveModifiers.contains(modifierKey)
    }

    private var hitRegion: KeyMouseHitRegion {
        switch button.shape {
        case .rectangle:
            .rectangle
        case .isoReturn:
            .isoReturn
        }
    }

    // MARK: - Actions
    private func handleMousePress(_ mouseButton: KeyMouseButton) {
        soundService.play(.keyPress)

        let action = action(for: mouseButton)

        if !action.isRepeatable {
            perform(action)
            return
        }

        startRepeatingAction(action, for: mouseButton)
    }

    private func handleMouseRelease(_ mouseButton: KeyMouseButton) {
        stopRepeatingAction()
    }

    private func handleMouseCancellation() {
        stopRepeatingAction()
    }

    private func action(for mouseButton: KeyMouseButton, modifiers: Set<ModifierKey>? = nil)
        -> KeyAction
    {
        let modifiers = modifiers ?? keyboardService.activeOneShotModifiers
        let presentation = presentation(modifiers: modifiers)
        return switch mouseButton {
        case .left: presentation.leftClickAction
        case .right: presentation.rightClickAction
        }
    }

    private func perform(_ action: KeyAction) {
        let inputSession = keyboardService.inputSession
        if action == .toggleFunctionToolbar {
            floatingWindowController.toggleFunctionToolbar()
            return
        }
        guard !action.isNone else {
            return
        }

        if action.isCapsLock {
            keyboardService.toggleCapsLock()
            return
        }

        if case .modifier(let modifier) = action, button.pressBehavior == .oneShot {
            keyboardService.toggleOneShotModifier(modifier)
            return
        }

        switch action {
        case .keyStroke(let stroke):
            let latchedModifiers = keyboardService.consumeActiveOneShotModifiers(for: action)

            Task {
                guard keyboardService.inputSession == inputSession else { return }
                _ = try? await keyboardService.press(
                    stroke,
                    latchedModifiers: latchedModifiers,
                    modifiersAreResolved: true
                )
            }
        case .text(let text):
            keyboardService.consumeActiveOneShotModifiers()

            Task {
                guard keyboardService.inputSession == inputSession else { return }
                _ = try? await keyboardService.type(text)
            }
        case .none, .modifier(_), .cycleKeyboardLanguage, .toggleFunctionToolbar:
            Task {
                guard keyboardService.inputSession == inputSession else { return }
                _ = try? await keyboardService.perform(action, behavior: button.pressBehavior)
            }
        }
    }

    // MARK: - Key Repeat
    private func startRepeatingAction(_ initialAction: KeyAction, for mouseButton: KeyMouseButton) {
        stopRepeatingAction()
        let capturedModifiers = keyboardService.activeOneShotModifiers
        let latchedModifiers = keyboardService.consumeActiveOneShotModifiers(for: initialAction)
        let inputSession = keyboardService.inputSession
        repeatTask = Task {
            guard keyboardService.inputSession == inputSession, !Task.isCancelled else { return }
            await performRepeatingAction(initialAction, latchedModifiers: latchedModifiers)
            try? await Task.sleep(for: .milliseconds(350))
            while !Task.isCancelled, keyboardService.inputSession == inputSession {
                let currentAction = action(for: mouseButton, modifiers: capturedModifiers)
                let currentLatches = latchedModifiers.filter { modifier in
                    guard case .keyStroke(let stroke) = currentAction else { return true }
                    return stroke.modifiers.isSuperset(of: modifier.modifiers)
                }
                await performRepeatingAction(currentAction, latchedModifiers: currentLatches)
                try? await Task.sleep(for: .milliseconds(60))
            }
        }
    }

    private func stopRepeatingAction() {
        repeatTask?.cancel()
        repeatTask = nil
    }

    private func performRepeatingAction(_ action: KeyAction, latchedModifiers: [ModifierKey]) async
    {
        switch action {
        case .none, .modifier(_), .cycleKeyboardLanguage, .toggleFunctionToolbar:
            return
        case .keyStroke(let stroke):
            _ = try? await keyboardService.press(
                stroke,
                latchedModifiers: latchedModifiers,
                modifiersAreResolved: true
            )
        case .text(let text):
            _ = try? await keyboardService.type(text)
        }
    }
}
