import CoreGraphics
import Foundation

// MARK: - LoginWindowKeyboard
nonisolated struct LoginWindowKeyboard: Codable {
    let panel: PanelEditorPanel
    let width: CGFloat

    // MARK: - Export
    @MainActor
    static func export(to url: URL) throws {
        let panels = PanelEditorProfileStore.shared.panels
        guard let home = panels.first(where: \.isDefaultHomePanel) ?? panels.first else {
            throw CocoaError(.fileNoSuchFile)
        }
        let snapshot = LoginWindowKeyboard(
            panel: sanitized(home),
            width: FloatingWindowDefaults.size.width
        )
        try snapshot.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: url, options: .atomic)
    }

    // MARK: - Loading
    static func load(from url: URL) throws -> Self {
        let keyboard = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try keyboard.validate()
        return keyboard
    }

    // MARK: - Validation
    func validate() throws {
        guard width.isFinite, (300...3000).contains(width),
            panel.size.width.isFinite, panel.size.height.isFinite,
            (100...5000).contains(panel.size.width), (50...3000).contains(panel.size.height),
            !panel.buttons.isEmpty, panel.buttons.count <= 300,
            Set(panel.buttons.map(\.id)).count == panel.buttons.count,
            panel.buttons.allSatisfy({ button in
                let frame = button.frame
                return frame.origin.x.isFinite && frame.origin.y.isFinite
                    && frame.width.isFinite && frame.height.isFinite
                    && frame.minX >= 0 && frame.minY >= 0
                    && frame.width > 0 && frame.height > 0
                    && frame.maxX <= panel.size.width + 1
                    && frame.maxY <= panel.size.height + 1
                    && button.fontSize.isFinite && button.fontSize > 0
                    && button.primaryAction == Self.loginAction(button.primaryAction)
                    && button.secondaryAction == Self.loginAction(button.secondaryAction)
            })
        else { throw CocoaError(.coderInvalidValue) }
        let keys = Set(
            panel.buttons.compactMap { button -> Key? in
                guard case .keyStroke(let stroke) = button.primaryAction else { return nil }
                return stroke.key
            }
        )
        guard keys.isSuperset(of: [.a, .z, .one, .zero, .space, .delete, .return, .tab]) else {
            throw CocoaError(.coderInvalidValue)
        }
    }

    // MARK: - Login Profile
    static func sanitized(_ panel: PanelEditorPanel) -> PanelEditorPanel {
        PanelEditorPanel(
            id: "login-keyboard",
            rawIdentifier: "login-keyboard",
            profileDisplayName: "Tastko",
            name: "Tastko",
            displayOrder: 0,
            size: panel.size,
            isDefaultHomePanel: true,
            associatedApplicationBundleIdentifiers: [],
            buttons: panel.visibleButtons.enumerated().map { index, button in
                let primary = loginAction(button.primaryAction)
                let secondary = loginAction(button.secondaryAction)
                let disabled = primary == .none && secondary == .none
                return PanelEditorButton(
                    id: "key-\(index)",
                    frame: button.frame,
                    title: disabled ? "" : button.title,
                    secondaryTitle: secondary == .none ? nil : button.secondaryTitle,
                    fontSize: button.fontSize,
                    backgroundColor: button.backgroundColor,
                    foregroundColor: button.foregroundColor,
                    shape: button.shape,
                    primaryAction: primary,
                    secondaryAction: secondary,
                    pressBehavior: button.pressBehavior
                )
            }
        )
    }

    private static func loginAction(_ action: KeyAction) -> KeyAction {
        switch action {
        case .text(let text): text.count == 1 ? action : .none
        case .toggleFunctionToolbar, .cycleKeyboardLanguage: .none
        case .none, .keyStroke, .modifier: action
        }
    }
}
