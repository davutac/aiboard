import SwiftUI

// MARK: - KeyboardDesignPreview
private struct KeyboardDesignPreview: View {
    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: KeyboardDesign.Metrics.rowSpacing) {
            Text("Aiboard")
                .font(KeyboardDesign.Typography.title)
            HStack(spacing: KeyboardDesign.Metrics.rowSpacing) {
                ForEach(["morning", "afternoon", "evening"], id: \.self) { word in
                    Button(word) {}
                        .buttonStyle(.keycap)
                }
            }
            HStack(spacing: KeyboardDesign.Metrics.rowSpacing) {
                key("A")
                key("Hover", isHovered: true)
                key("Press", isPressed: true)
                key("⇧", isActive: true)
            }
            HStack(spacing: KeyboardDesign.Metrics.rowSpacing) {
                key("esc", fill: .red)
                key("NEW", fill: .green)
                key("FILE", fill: .blue)
                key("DICT", fill: .yellow)
            }
        }
        .foregroundStyle(KeyboardDesign.Palette.label)
        .padding(KeyboardDesign.Metrics.rowInset)
        .background(KeyboardDesign.Palette.chassis)
        .frame(width: 440)
    }

    // MARK: - Key States
    private func key(
        _ title: String,
        fill: Color = KeyboardDesign.Palette.keyFill,
        isHovered: Bool = false,
        isPressed: Bool = false,
        isActive: Bool = false
    ) -> some View {
        Text(title)
            .font(KeyboardDesign.Typography.key(size: 22))
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background {
                KeycapSurface(
                    shape: RoundedRectangle(cornerRadius: KeyboardDesign.Metrics.keyRadius),
                    fill: fill,
                    isPressed: isPressed,
                    isHovered: isHovered,
                    isActive: isActive
                )
            }
    }
}

#Preview("Light") {
    KeyboardDesignPreview()
        .environment(\.colorScheme, .light)
}

#Preview("Dark") {
    KeyboardDesignPreview()
        .environment(\.colorScheme, .dark)
}
