import SwiftUI

// MARK: - PanelEditorButtonView
struct PanelEditorButtonView: View {
    @Environment(\.keyboardService) private var keyboardService
    @Environment(\.soundService) private var soundService
    @Environment(\.floatingWindowController) private var floatingWindowController

    let button: PanelEditorButton
    let scale: CGFloat
    let languageContext: KeyboardLanguageContext

    @State private var pressedButton: KeyMouseButton?
    @State private var releasedButton: KeyMouseButton?
    @State private var isHovered = false
    @State private var repeatTask: Task<Void, Never>?

    // MARK: - Body
    var body: some View {
        ZStack {
            PanelEditorKeycap(
                button: button,
                presentation: resolvedPresentation,
                scale: scale,
                isPressed: pressedButton != nil,
                isHovered: isHovered,
                isActive: isModifierActive
            )

            KeyMouseEventView(
                pressedButton: $pressedButton,
                releasedButton: $releasedButton,
                allowsDragTracking: false,
                hitRegion: hitRegion,
                mousePressed: handleMousePress,
                mouseReleasedInside: handleMouseRelease,
                mouseCancelled: handleMouseCancellation,
                editingDragChanged: { _ in },
                editingDragEnded: { _ in }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
        }
        .contentShape(PanelEditorKeyShape(buttonShape: button.shape))
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(accessibilityTraits)
        .accessibilityHint(accessibilityHint)
        .accessibilityAction {
            perform(action(for: .left))
        }
        .accessibilityAction(
            named: keyboardService.isCapsLockEnabled ? "Lowercase key" : "Shifted key"
        ) {
            perform(action(for: .right))
        }
        .onDisappear {
            stopRepeatingAction()
        }
        .onChange(of: keyboardService.inputSession) {
            stopRepeatingAction()
            pressedButton = nil
            releasedButton = nil
        }
    }

    // MARK: - Presentation
    private var resolvedPresentation: ResolvedKeyPresentation {
        LanguageAwareKeyResolver.presentation(
            title: button.title,
            secondaryTitle: button.secondaryTitle ?? "",
            labelKind: .text,
            labelSymbolName: "",
            leftClickAction: button.primaryAction,
            rightClickAction: button.secondaryAction,
            languageContext: languageContext
        )
    }

    // MARK: - Accessibility
    private var accessibilityLabel: String {
        resolvedPresentation.title.isEmpty ? "Unavailable panel button" : resolvedPresentation.title
    }

    private var accessibilityHint: String {
        if button.primaryAction == .toggleFunctionToolbar {
            return "Shows or hides the system controls and function keys"
        }
        if button.primaryAction.isCapsLock {
            return "Toggles uppercase typing; right-click a letter to type lowercase"
        }

        guard modifierKey != nil else {
            if keyboardService.isCapsLockEnabled {
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

    private var isModifierActive: Bool {
        if button.primaryAction.isCapsLock {
            return keyboardService.isCapsLockEnabled
        }

        guard let modifierKey else {
            return false
        }

        return keyboardService.activeOneShotModifiers.contains(modifierKey)
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

        startRepeatingAction(action)
    }

    private func handleMouseRelease(_ mouseButton: KeyMouseButton) {
        stopRepeatingAction()
        releasedButton = nil
    }

    private func handleMouseCancellation() {
        stopRepeatingAction()
    }

    private func action(for mouseButton: KeyMouseButton) -> KeyAction {
        KeyActionResolver.action(
            for: mouseButton.actionTrigger,
            primaryAction: resolvedPresentation.leftClickAction,
            secondaryAction: resolvedPresentation.rightClickAction,
            activeOneShotModifiers: keyboardService.activeOneShotModifiers,
            isCapsLockEnabled: keyboardService.isCapsLockEnabled,
            primaryTitle: resolvedPresentation.title
        )
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
                    latchedModifiers: latchedModifiers
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

    private func startRepeatingAction(_ action: KeyAction) {
        guard action.isRepeatable else {
            return
        }

        stopRepeatingAction()
        let latchedModifiers = keyboardService.consumeActiveOneShotModifiers(for: action)

        let inputSession = keyboardService.inputSession
        repeatTask = Task {
            guard keyboardService.inputSession == inputSession, !Task.isCancelled else { return }
            await performRepeatingAction(action, latchedModifiers: latchedModifiers)

            guard !Task.isCancelled else {
                return
            }

            try? await Task.sleep(for: .milliseconds(350))

            while !Task.isCancelled, keyboardService.inputSession == inputSession {
                await performRepeatingAction(action, latchedModifiers: latchedModifiers)
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
                latchedModifiers: latchedModifiers
            )
        case .text(let text):
            _ = try? await keyboardService.type(text)
        }
    }
}
