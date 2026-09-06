import SwiftUI

// MARK: - KeyActionEditor
struct KeyActionEditor: View {
    @Binding var action: KeyAction
    let languageContext: KeyboardLanguageContext

    // MARK: - Body
    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 10) {
            editorRow("Type") {
                Picker("Type", selection: actionKind) {
                    ForEach(KeyActionKind.allCases, id: \.self) { kind in
                        Text(kind.displayTitle).tag(kind)
                    }
                }
                .labelsHidden()
            }

            actionValueEditor
        }
        .controlSize(.large)
    }

    // MARK: - Kind
    private var actionKind: Binding<KeyActionKind> {
        Binding {
            action.kind
        } set: { kind in
            guard kind != action.kind else {
                return
            }

            action = kind.defaultAction
        }
    }

    // MARK: - Value Editor
    @ViewBuilder
    private var actionValueEditor: some View {
        switch action {
        case .none, .cycleKeyboardLanguage, .toggleFunctionToolbar:
            EmptyView()
        case .text:
            editorRow("Output") {
                TextField("Text", text: textBinding)
                    .textFieldStyle(.roundedBorder)
            }
        case .keyStroke:
            keyStrokeEditor
        case .modifier:
            modifierEditor
        }
    }

    // MARK: - Key Stroke Editor
    private var keyStrokeEditor: some View {
        Group {
            editorRow("Key") {
                Picker("Key", selection: keyBinding) {
                    ForEach(Key.allCases, id: \.self) { key in
                        Text(
                            LanguageAwareKeyResolver.displayTitle(
                                for: key,
                                languageContext: languageContext
                            )
                        )
                        .tag(key)
                    }
                }
                .labelsHidden()
            }

            editorRow("Modifiers") {
                modifierGrid
            }
        }
    }

    // MARK: - Modifier Editor
    private var modifierEditor: some View {
        editorRow("Modifier") {
            Picker("Modifier", selection: modifierKeyBinding) {
                ForEach(ModifierKey.allCases, id: \.self) { modifier in
                    Text(modifier.displayTitle).tag(modifier)
                }
            }
            .labelsHidden()
        }
    }

    // MARK: - Modifier Grid
    private var modifierGrid: some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 7) {
            GridRow {
                Toggle("Command", isOn: modifierBinding(.command))
                Toggle("Shift", isOn: modifierBinding(.shift))
            }

            GridRow {
                Toggle("Option", isOn: modifierBinding(.option))
                Toggle("Control", isOn: modifierBinding(.control))
            }
        }
        .toggleStyle(.checkbox)
    }

    // MARK: - Styling
    private func editorRow<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        GridRow(alignment: .center) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: Self.rowLabelWidth, alignment: .leading)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Metrics
    private static let rowLabelWidth: CGFloat = 82

    // MARK: - Bindings
    private var textBinding: Binding<String> {
        Binding {
            guard case .text(let text) = action else {
                return ""
            }

            return text
        } set: { text in
            action = .text(text)
        }
    }

    private var keyBinding: Binding<Key> {
        Binding {
            guard case .keyStroke(let stroke) = action else {
                return .a
            }

            return stroke.key
        } set: { key in
            action = .keyStroke(KeyStroke(key, modifiers: keyStrokeModifiers))
        }
    }

    private var modifierKeyBinding: Binding<ModifierKey> {
        Binding {
            guard case .modifier(let modifier) = action else {
                return .leftShift
            }

            return modifier
        } set: { modifier in
            action = .modifier(modifier)
        }
    }

    private func modifierBinding(_ modifier: KeyModifiers) -> Binding<Bool> {
        Binding {
            keyStrokeModifiers.contains(modifier)
        } set: { isOn in
            var modifiers = keyStrokeModifiers

            if isOn {
                modifiers.insert(modifier)
            }
            else {
                modifiers.remove(modifier)
            }

            action = .keyStroke(KeyStroke(keyStrokeKey, modifiers: modifiers))
        }
    }

    private var keyStrokeKey: Key {
        guard case .keyStroke(let stroke) = action else {
            return .a
        }

        return stroke.key
    }

    private var keyStrokeModifiers: KeyModifiers {
        guard case .keyStroke(let stroke) = action else {
            return []
        }

        return stroke.modifiers
    }
}

// MARK: - KeyActionKind
nonisolated enum KeyActionKind: String, CaseIterable, Hashable, Sendable {
    case none
    case text
    case keyStroke
    case modifier
    case keyboardLanguage
    case functionToolbar

    // MARK: - Display
    var displayTitle: String {
        switch self {
        case .none:
            "None"
        case .text:
            "Text"
        case .keyStroke:
            "Keystroke"
        case .modifier:
            "Modifier"
        case .keyboardLanguage:
            "Language"
        case .functionToolbar:
            "Function toolbar"
        }
    }

    // MARK: - Action
    var defaultAction: KeyAction {
        switch self {
        case .none:
            .none
        case .text:
            .text("")
        case .keyStroke:
            .keyStroke(KeyStroke(.a))
        case .modifier:
            .modifier(.leftShift)
        case .keyboardLanguage:
            .cycleKeyboardLanguage
        case .functionToolbar:
            .toggleFunctionToolbar
        }
    }
}

// MARK: - KeyAction Kind
extension KeyAction {
    nonisolated var kind: KeyActionKind {
        switch self {
        case .none:
            .none
        case .text:
            .text
        case .keyStroke:
            .keyStroke
        case .modifier:
            .modifier
        case .cycleKeyboardLanguage:
            .keyboardLanguage
        case .toggleFunctionToolbar:
            .functionToolbar
        }
    }
}
