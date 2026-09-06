import AppKit
import Testing

@testable import Aiboard

// MARK: - LoginWindowKeyboardTests
@MainActor
struct LoginWindowKeyboardTests {
    // MARK: - Profile Isolation
    @Test func snapshotPreservesKeysAndGeometryButExcludesMacrosAndApplicationMetadata() throws {
        let original = panel(extraAction: .text("private macro"))
        let snapshot = LoginWindowKeyboard(
            panel: LoginWindowKeyboard.sanitized(original),
            width: 820
        )
        try snapshot.validate()
        let restored = try JSONDecoder().decode(
            LoginWindowKeyboard.self,
            from: JSONEncoder().encode(snapshot)
        )
        #expect(restored.panel.size == original.size)
        #expect(restored.panel.buttons.map(\.frame) == original.buttons.map(\.frame))
        #expect(
            restored.panel.buttons.first?.primaryAction == original.buttons.first?.primaryAction
        )
        #expect(restored.panel.buttons.last?.primaryAction == KeyAction.none)
        #expect(restored.panel.buttons.last?.title == "")
        #expect(restored.panel.associatedApplicationBundleIdentifiers.isEmpty)
        #expect(restored.panel.profileDisplayName == "Aiboard")
        #expect(
            !String(decoding: try JSONEncoder().encode(restored), as: UTF8.self).contains("private")
        )
    }

    @Test func rejectsIncompleteKeyboardAndUnsanitizedMacros() {
        #expect(throws: (any Error).self) {
            try LoginWindowKeyboard(panel: panel(extraAction: .text("private macro")), width: 820)
                .validate()
        }
        #expect(throws: (any Error).self) {
            try LoginWindowKeyboard(panel: panel(keys: [.a]), width: 820).validate()
        }
        #expect(throws: (any Error).self) {
            try LoginWindowKeyboard(panel: panel(), width: .infinity).validate()
        }
    }

    // MARK: - Session Boundaries
    @Test func onlyTheRootPreloginSessionCanPostInput() {
        #expect(LoginWindowSession.allowsInput(userID: 0, loginDone: false))
        #expect(!LoginWindowSession.allowsInput(userID: 0, loginDone: true))
        #expect(!LoginWindowSession.allowsInput(userID: 0, loginDone: nil))
        #expect(!LoginWindowSession.allowsInput(userID: 501, loginDone: false))
        #expect(!LoginWindowSession.allowsInput(userID: 501, loginDone: true))
    }

    // MARK: - Fixtures
    private func panel(
        keys: [Key] = [.a, .z, .one, .zero, .space, .delete, .return, .tab],
        extraAction: KeyAction = .text("é")
    ) -> PanelEditorPanel {
        let actions = keys.map { KeyAction.keyStroke(KeyStroke($0)) } + [extraAction]
        return PanelEditorPanel(
            id: "private-profile",
            rawIdentifier: "private-panel",
            profileDisplayName: "private name",
            name: "private name",
            displayOrder: 1,
            size: CGSize(width: 900, height: 100),
            isDefaultHomePanel: true,
            associatedApplicationBundleIdentifiers: ["private.app"],
            buttons: actions.enumerated().map { index, action in
                PanelEditorButton(
                    id: "private-\(index)",
                    frame: CGRect(x: index * 90, y: 0, width: 85, height: 90),
                    title: index == keys.count ? "private macro" : "Key",
                    secondaryTitle: nil,
                    fontSize: 18,
                    backgroundColor: nil,
                    foregroundColor: nil,
                    shape: .rectangle,
                    primaryAction: action,
                    secondaryAction: .none,
                    pressBehavior: .pressAndRelease
                )
            }
        )
    }
}
