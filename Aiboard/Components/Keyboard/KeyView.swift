import SwiftUI

// MARK: - KeyView
struct KeyView: View {
    @Environment(\.keyboardService) private var keyboardService
    @Environment(\.keyboardLanguageService) private var keyboardLanguageService
    @Environment(\.isKeyboardEditing) private var isKeyboardEditing
    @Environment(\.soundService) private var soundService

    let key: KeyModel
    let languageContext: KeyboardLanguageContext
    let editingDragChanged: (CGSize) -> Void
    let editingDragEnded: (CGSize) -> Void

    @State private var pressedButton: KeyMouseButton?
    @State private var releasedButton: KeyMouseButton?
    @State private var isHovered = false
    @State private var repeatTask: Task<Void, Never>?
    @State private var isEditorPresented = false
    @State private var editorActionSlot = KeyActionSlot.leftClick

    // MARK: - Initialization
    init(
        key: KeyModel,
        languageContext: KeyboardLanguageContext = KeyboardLanguageContext(),
        editingDragChanged: @escaping (CGSize) -> Void = { _ in },
        editingDragEnded: @escaping (CGSize) -> Void = { _ in }
    ) {
        self.key = key
        self.languageContext = languageContext
        self.editingDragChanged = editingDragChanged
        self.editingDragEnded = editingDragEnded
    }

    // MARK: - Body
    var body: some View {
        GeometryReader { proxy in
            let scale = keyScale(for: proxy.size)

            ZStack {
                keySurface(scale: scale)

                KeyMouseEventView(
                    pressedButton: $pressedButton,
                    releasedButton: $releasedButton,
                    allowsDragTracking: isKeyboardEditing,
                    mousePressed: handleMousePress,
                    mouseReleasedInside: handleMouseRelease,
                    mouseCancelled: handleMouseCancellation,
                    editingDragChanged: editingDragChanged,
                    editingDragEnded: editingDragEnded
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)
            }
        }
        .onHover { isHovered in
            self.isHovered = isHovered
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isKeyboardEditing ? "Opens key settings" : "Performs key action")
        .accessibilityAction {
            if isKeyboardEditing {
                presentEditor(for: .left)
            }
            else {
                performAction(for: .left)
            }
        }
        .accessibilityAction(named: "Edit key") {
            guard isKeyboardEditing else {
                return
            }

            presentEditor(for: .left)
        }
        .popover(
            isPresented: $isEditorPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            KeyEditorPopover(
                key: key,
                selectedActionSlot: $editorActionSlot,
                languageContext: languageContext
            )
        }
        .onChange(of: isKeyboardEditing) {
            pressedButton = nil
            releasedButton = nil
            stopRepeatingAction()

            guard !isKeyboardEditing else {
                return
            }

            isEditorPresented = false
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

    // MARK: - Surface
    private func keySurface(scale: CGFloat) -> some View {
        Button {
        } label: {
            keyLabel(scale: scale)
        }
        .buttonStyle(
            .keyView(
                state: visualState,
                scale: scale
            )
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func keyLabel(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            primaryLabel(scale: scale)

            if let secondaryTitle {
                Text(secondaryTitle)
                    .font(
                        .system(
                            size: 8 * scale,
                            weight: .medium,
                            design: .rounded
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(isHighlighted ? Color.accentColor : Color.secondary)
                    .padding(2 * scale)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func primaryLabel(scale: CGFloat) -> some View {
        switch resolvedKey.labelKind {
        case .text:
            Text(resolvedKey.title)
                .font(.system(size: 18 * scale, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .foregroundStyle(primaryLabelColor)
                .padding(4 * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        case .symbol:
            Image(systemName: symbolName)
                .font(.system(size: 18 * scale, weight: .semibold, design: .rounded))
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(primaryLabelColor)
                .padding(4 * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private var visualState: KeyViewVisualState {
        KeyViewVisualState(
            isPressed: pressedButton != nil,
            isHovered: isHovered,
            isEditing: isKeyboardEditing,
            isLatched: isLatched
        )
    }

    private var secondaryTitle: String? {
        resolvedKey.secondaryTitle
    }

    private var symbolName: String {
        guard !resolvedKey.labelSymbolName.isEmpty else {
            return "questionmark"
        }

        return resolvedKey.labelSymbolName
    }

    private var accessibilityLabel: String {
        guard !resolvedKey.title.isEmpty else {
            return resolvedKey.labelKind == .symbol ? symbolName : "Key"
        }

        return resolvedKey.title
    }

    private var primaryLabelColor: Color {
        isHighlighted ? Color.accentColor : Color.primary
    }

    private var isHighlighted: Bool {
        visualState.isEditing || visualState.isLatched
    }

    private var isLatched: Bool {
        isLatched(action: resolvedKey.leftClickAction)
            || isLatched(action: resolvedKey.rightClickAction)
    }

    private var resolvedKey: ResolvedKeyPresentation {
        LanguageAwareKeyResolver.presentation(
            title: key.title,
            secondaryTitle: key.secondaryTitle,
            labelKind: key.labelKind,
            labelSymbolName: key.labelSymbolName,
            leftClickAction: key.leftClickAction,
            rightClickAction: key.rightClickAction,
            languageContext: languageContext
        )
    }

    // MARK: - Metrics
    private func keyScale(for size: CGSize) -> CGFloat {
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0 else {
            return 1
        }

        let widthScale = size.width / KeyModel.defaultSize.width
        let heightScale = size.height / KeyModel.defaultSize.height
        let scale = min(widthScale, heightScale)

        guard scale.isFinite else {
            return 1
        }

        return max(0.75, scale)
    }

    // MARK: - Actions
    private func handleMousePress(_ button: KeyMouseButton) {
        guard !isKeyboardEditing else {
            stopRepeatingAction()
            return
        }

        soundService.play(.keyPress)

        let action = action(for: button)

        if !action.isRepeatable {
            performAction(for: button)
            return
        }

        startRepeatingAction(action)
    }

    private func handleMouseRelease(_ button: KeyMouseButton) {
        stopRepeatingAction()

        guard !isKeyboardEditing else {
            presentEditor(for: button)
            releasedButton = nil
            return
        }

        releasedButton = nil
    }

    private func handleMouseCancellation() {
        stopRepeatingAction()
    }

    private func performAction(for button: KeyMouseButton) {
        let inputSession = keyboardService.inputSession
        guard !isKeyboardEditing else { return }

        let action = action(for: button)

        if action == .toggleFunctionToolbar {
            FloatingWindowController.shared.toggleFunctionToolbar()
            return
        }

        if action.isCapsLock {
            keyboardService.toggleCapsLock()
            return
        }

        guard action != .cycleKeyboardLanguage else {
            keyboardLanguageService.selectNextLanguage()
            return
        }

        if case .modifier(let modifier) = action, key.pressBehavior == .oneShot {
            keyboardService.toggleOneShotModifier(modifier)
            return
        }

        if case .keyStroke(let stroke) = action {
            let modifiers = keyboardService.consumeActiveOneShotModifiers(for: action)
            Task {
                guard keyboardService.inputSession == inputSession else { return }
                _ = try? await keyboardService.press(stroke, latchedModifiers: modifiers)
            }
        }
        else {
            Task {
                guard keyboardService.inputSession == inputSession else { return }
                _ = try? await keyboardService.perform(action, behavior: key.pressBehavior)
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

            try? await Task.sleep(nanoseconds: Self.keyRepeatInitialDelay)

            while !Task.isCancelled, keyboardService.inputSession == inputSession {
                await performRepeatingAction(action, latchedModifiers: latchedModifiers)
                try? await Task.sleep(nanoseconds: Self.keyRepeatInterval)
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

    private func action(for button: KeyMouseButton) -> KeyAction {
        KeyActionResolver.action(
            for: button.actionTrigger,
            primaryAction: resolvedKey.leftClickAction,
            secondaryAction: resolvedKey.rightClickAction,
            activeOneShotModifiers: keyboardService.activeOneShotModifiers,
            isCapsLockEnabled: keyboardService.isCapsLockEnabled,
            primaryTitle: resolvedKey.title
        )
    }

    private func isLatched(action: KeyAction) -> Bool {
        if action.isCapsLock {
            return keyboardService.isCapsLockEnabled
        }

        guard case .modifier(let modifier) = action else {
            return false
        }

        return keyboardService.activeOneShotModifiers.contains(modifier)
    }

    // MARK: - Editing
    private func presentEditor(for button: KeyMouseButton) {
        stopRepeatingAction()
        editorActionSlot = button.actionSlot
        isEditorPresented = true
    }

    private static let keyRepeatInitialDelay: UInt64 = 350_000_000
    private static let keyRepeatInterval: UInt64 = 60_000_000
}
