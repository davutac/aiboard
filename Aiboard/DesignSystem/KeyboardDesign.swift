import SwiftUI

// MARK: - KeyboardDesign
enum KeyboardDesign {
    enum Palette {
        static let error = Color("KeyboardError")
        static let chassis = Color("KeyboardChassis")
        static let chrome = Color("KeyboardChrome")
        static let keyFill = Color("KeyboardKeyFill")
        static let label = Color("KeyboardLabel")
        static let secondaryLabel = Color("KeyboardSecondaryLabel")
        static let border = Color("KeyboardBorder")
        static let separator = Color("KeyboardSeparator")
        static let active = Color("KeyboardActive")

        // MARK: - Imported Key Colors
        static func imported(_ components: PanelEditorColorComponents?, fallback: Color) -> Color {
            guard let components else { return fallback }
            return Color(
                .sRGB,
                red: components.red,
                green: components.green,
                blue: components.blue,
                opacity: components.alpha
            )
        }
    }

    nonisolated enum Metrics {
        static let windowRadius: CGFloat = 16
        static let keyRadius: CGFloat = 6
        static let keyInset: CGFloat = 2
        static let panelInset: CGFloat = 5
        static let rowSpacing: CGFloat = 8
        static let rowInset: CGFloat = 12
        static let functionToolbarVerticalInset: CGFloat = 2
        static let suggestionHeight: CGFloat = 32
        static let suggestionTopInset: CGFloat = 7
        static let suggestionBottomInset: CGFloat = 2
        static let suggestionInset: CGFloat = 16
    }

    enum Typography {
        static let title = Font.system(size: 13, weight: .semibold)
        static let toolbar = Font.system(size: 12, weight: .medium)
        static let suggestion = Font.system(size: 15, weight: .medium)
        static let suggestionPrefix = suggestion.weight(.regular)
        static let suggestionCompletion = suggestion.weight(.bold)

        // MARK: - Scaled Key Labels
        static func key(size: CGFloat) -> Font {
            .system(size: max(10, size * 0.92), weight: .regular)
        }

        // MARK: - Secondary Key Labels
        static func secondaryKey(scale: CGFloat) -> Font {
            .system(size: max(8, 9 * scale), weight: .medium)
        }
    }
}
