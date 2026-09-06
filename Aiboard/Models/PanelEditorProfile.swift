import CoreGraphics
import Foundation

// MARK: - PanelEditorColorComponents
nonisolated struct PanelEditorColorComponents: Codable, Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double
}

// MARK: - PanelEditorButtonShape
nonisolated enum PanelEditorButtonShape: Codable, Equatable, Hashable, Sendable {
    case rectangle
    case isoReturn
}

// MARK: - PanelEditorButton
nonisolated struct PanelEditorButton: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let frame: CGRect
    let title: String
    let secondaryTitle: String?
    let fontSize: CGFloat
    let backgroundColor: PanelEditorColorComponents?
    let foregroundColor: PanelEditorColorComponents?
    let shape: PanelEditorButtonShape
    let primaryAction: KeyAction
    let secondaryAction: KeyAction
    let pressBehavior: KeyPressBehavior
}

// MARK: - PanelEditorPanel
nonisolated struct PanelEditorPanel: Codable, Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let rawIdentifier: String
    let profileDisplayName: String
    let name: String
    let displayOrder: Int
    let size: CGSize
    let isDefaultHomePanel: Bool
    let associatedApplicationBundleIdentifiers: [String]
    let buttons: [PanelEditorButton]

    var visibleButtons: [PanelEditorButton] {
        buttons.filter {
            $0.primaryAction != .toggleFunctionToolbar
                && $0.secondaryAction != .toggleFunctionToolbar
        }
    }
}

// MARK: - PanelEditorProfile
nonisolated struct PanelEditorProfile: Identifiable, Equatable, Hashable, Sendable {
    let id: String
    let displayName: String
    let sourceURL: URL
    let panels: [PanelEditorPanel]
}
