import Foundation

// MARK: - KeyAction
nonisolated enum KeyAction: Codable, Hashable, Sendable {
    case none
    case text(String)
    case keyStroke(KeyStroke)
    case modifier(ModifierKey)
    case cycleKeyboardLanguage
    case toggleFunctionToolbar
}

// MARK: - KeyPressBehavior
nonisolated enum KeyPressBehavior: String, CaseIterable, Codable, Hashable, Sendable {
    case pressAndRelease
    case oneShot
}
