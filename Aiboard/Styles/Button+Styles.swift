import SwiftUI

// MARK: - SubtleIconButtonStyle
struct SubtleIconButtonStyle: ButtonStyle {
    // MARK: - Body
    func makeBody(configuration: Configuration) -> some View {
        SubtleIconButtonContent(configuration: configuration)
    }
}

// MARK: - SubtleIconButtonContent
private struct SubtleIconButtonContent: View {
    let configuration: ButtonStyleConfiguration
    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    // MARK: - Body
    var body: some View {
        configuration.label
            .foregroundStyle(KeyboardDesign.Palette.label)
            .frame(width: 20, height: 20)
            .background {
                RoundedRectangle(cornerRadius: KeyboardDesign.Metrics.keyRadius)
                    .fill(KeyboardDesign.Palette.keyFill)
                    .opacity(isEnabled && isHovered ? 1 : 0)
            }
            .opacity(configuration.isPressed ? 0.65 : 1)
            .contentShape(.rect)
            .onHover { isHovered = $0 }
    }
}

// MARK: - TitlebarButtonStyle
struct TitlebarButtonStyle: ButtonStyle {
    // MARK: - Body
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .buttonStyle(.plain)
            .frame(height: AppConstants.titlebarHeight)
            .padding(.horizontal, 8)
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - ScaledIconButtonStyle
struct ScaledIconButtonStyle: ButtonStyle {
    let size: CGSize
    let symbolScaleFactor: CGFloat
    let minimumSymbolSize: CGFloat

    // MARK: - Initialization
    init(
        size: CGSize,
        symbolScaleFactor: CGFloat,
        minimumSymbolSize: CGFloat = 24
    ) {
        self.size = size
        self.symbolScaleFactor = symbolScaleFactor
        self.minimumSymbolSize = minimumSymbolSize
    }

    // MARK: - Body
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: size.width, height: size.height)
            .background(KeyboardDesign.Palette.keyFill, in: .rect(cornerRadius: cornerRadius))
            .contentShape(.rect(cornerRadius: cornerRadius))
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }

    // MARK: - Metrics
    private var symbolSize: CGFloat {
        max(minimumSymbolSize, min(size.width, size.height) * symbolScaleFactor)
    }

    private var cornerRadius: CGFloat {
        max(12, min(size.width, size.height) * 0.24)
    }
}

// MARK: - KeyViewVisualState
struct KeyViewVisualState: Hashable {
    let isPressed: Bool
    let isHovered: Bool
    let isEditing: Bool
    let isLatched: Bool

    // MARK: - Initialization
    init(
        isPressed: Bool = false,
        isHovered: Bool = false,
        isEditing: Bool = false,
        isLatched: Bool = false
    ) {
        self.isPressed = isPressed
        self.isHovered = isHovered
        self.isEditing = isEditing
        self.isLatched = isLatched
    }
}

// MARK: - KeyViewButtonStyle
struct KeyViewButtonStyle: ButtonStyle {
    let state: KeyViewVisualState
    let scale: CGFloat

    // MARK: - Body
    func makeBody(configuration: Configuration) -> some View {
        VStack {
            configuration.label
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundShape)
        .overlay {
            Rectangle()
                .strokeBorder(
                    Color.accentColor.opacity(isHighlighted ? 0.65 : 0),
                    lineWidth: max(1, scale)
                )
        }
        .contentShape(.rect)
        .scaleEffect(isActive(configuration) ? 0.97 : 1)
        .animation(.smooth(duration: 0.12), value: state)
        .animation(.smooth(duration: 0.12), value: configuration.isPressed)
        .animation(.smooth(duration: 0.12), value: scale)
    }

    // MARK: - Styling
    private var backgroundShape: some View {
        Rectangle()
            .fill(backgroundColor)
    }

    private var backgroundColor: Color {
        if isHighlighted {
            return Color.accentColor.opacity(state.isHovered ? 0.24 : 0.18)
        }

        return Color.primary.opacity(state.isHovered ? 0.16 : 0.1)
    }

    private var isHighlighted: Bool {
        state.isEditing || state.isLatched
    }

    // MARK: - State
    private func isActive(_ configuration: Configuration) -> Bool {
        state.isPressed || configuration.isPressed
    }
}

// MARK: - ButtonStyle Extension
extension ButtonStyle where Self == TitlebarButtonStyle {
    static var titlebar: TitlebarButtonStyle {
        TitlebarButtonStyle()
    }
}

extension ButtonStyle where Self == ScaledIconButtonStyle {
    static func scaledIcon(
        size: CGSize,
        symbolScaleFactor: CGFloat,
        minimumSymbolSize: CGFloat = 24
    ) -> ScaledIconButtonStyle {
        ScaledIconButtonStyle(
            size: size,
            symbolScaleFactor: symbolScaleFactor,
            minimumSymbolSize: minimumSymbolSize
        )
    }
}

extension ButtonStyle where Self == KeyViewButtonStyle {
    static func keyView(
        state: KeyViewVisualState = KeyViewVisualState(),
        scale: CGFloat = 1
    ) -> KeyViewButtonStyle {
        KeyViewButtonStyle(
            state: state,
            scale: scale
        )
    }
}
