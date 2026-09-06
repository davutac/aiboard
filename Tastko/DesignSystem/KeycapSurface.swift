import SwiftUI

// MARK: - KeycapSurface
struct KeycapSurface<KeyShape: Shape>: View {
    let shape: KeyShape
    var fill: Color = KeyboardDesign.Palette.keyFill
    var isPressed = false
    var isHovered = false
    var isActive = false
    @Environment(\.colorSchemeContrast) private var contrast

    // MARK: - Body
    var body: some View {
        shape
            .fill(fill)
            .opacity(isHovered ? 0.86 : 1)
            .overlay {
                shape.stroke(borderColor, lineWidth: borderWidth)
            }
            .allowsHitTesting(false)
    }

    // MARK: - Interaction
    private var borderColor: Color {
        if isActive { return KeyboardDesign.Palette.active }
        if isHovered { return KeyboardDesign.Palette.label.opacity(0.28) }
        return KeyboardDesign.Palette.border
    }

    private var borderWidth: CGFloat {
        contrast == .increased || isActive || isPressed ? 2 : 1
    }
}
