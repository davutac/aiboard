import Testing

@testable import Aiboard

// MARK: - KeyActionEditorTests
struct KeyActionEditorTests {
    // MARK: - Action Kind
    @Test func actionKindMatchesActionCase() {
        #expect(KeyAction.none.kind == .none)
        #expect(KeyAction.text("Hello").kind == .text)
        #expect(KeyAction.keyStroke(KeyStroke(.a)).kind == .keyStroke)
        #expect(KeyAction.modifier(.leftShift).kind == .modifier)
        #expect(KeyAction.cycleKeyboardLanguage.kind == .keyboardLanguage)
    }

    @Test func defaultActionsUseSafeEditorValues() {
        #expect(KeyActionKind.none.defaultAction == .none)
        #expect(KeyActionKind.text.defaultAction == .text(""))
        #expect(KeyActionKind.keyStroke.defaultAction == .keyStroke(KeyStroke(.a)))
        #expect(KeyActionKind.modifier.defaultAction == .modifier(.leftShift))
        #expect(KeyActionKind.keyboardLanguage.defaultAction == .cycleKeyboardLanguage)
    }

    @Test func keyPressBehaviorProvidesAllEditorChoices() {
        #expect(KeyPressBehavior.allCases == [.pressAndRelease, .oneShot])
    }
}
