import SwiftUI

// MARK: - KeycapButtonStyle
struct KeycapButtonStyle: ButtonStyle {
    var scale: CGFloat = 1
    var fillsWidth = false
    // MARK: - Body
    func makeBody(configuration: Configuration) -> some View {
        KeycapButtonContent(configuration: configuration, scale: scale, fillsWidth: fillsWidth)
    }
}

// MARK: - ButtonStyle Extension
extension ButtonStyle where Self == KeycapButtonStyle {
    static var keycap: KeycapButtonStyle {
        KeycapButtonStyle()
    }

    // MARK: - Configured Keycap Style
    static func keycap(scale: CGFloat = 1, fillsWidth: Bool = false) -> KeycapButtonStyle {
        KeycapButtonStyle(scale: scale, fillsWidth: fillsWidth)
    }
}

// MARK: - KeycapButtonContent
private struct KeycapButtonContent: View {
    let configuration: ButtonStyleConfiguration
    let scale: CGFloat
    let fillsWidth: Bool
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body
    var body: some View {
        configuration.label
            .font(.system(size: 15 * scale, weight: .medium))
            .foregroundStyle(KeyboardDesign.Palette.label)
            .padding(.horizontal, fillsWidth ? 0 : KeyboardDesign.Metrics.suggestionInset)
            .frame(maxWidth: fillsWidth ? .infinity : nil)
            .frame(height: KeyboardDesign.Metrics.suggestionHeight * scale)
            .background {
                KeycapSurface(
                    shape: RoundedRectangle(cornerRadius: KeyboardDesign.Metrics.keyRadius * scale),
                    isPressed: configuration.isPressed,
                    isHovered: isHovered
                )
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? nil : .smooth(duration: 0.1), value: configuration.isPressed)
            .contentShape(.rect)
            .onHover { isHovered = $0 }
    }
}
