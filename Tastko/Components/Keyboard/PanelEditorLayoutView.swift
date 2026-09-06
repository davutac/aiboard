import SwiftUI

// MARK: - PanelEditorLayoutView
struct PanelEditorLayoutView: View {
    @Environment(\.keyboardLanguageService) private var keyboardLanguageService

    let panel: PanelEditorPanel

    // MARK: - Body
    var body: some View {
        GeometryReader { proxy in
            let scale = layoutScale(in: proxy.size)
            let horizontalScale = panel.size.width > 0 ? proxy.size.width / panel.size.width : scale

            ZStack(alignment: .topLeading) {
                ForEach(panel.visibleButtons) { button in
                    PanelEditorButtonView(
                        button: button,
                        scale: scale,
                        languageContext: KeyboardLanguageContext(
                            language: keyboardLanguageService.selectedLanguage
                        )
                    )
                    .frame(
                        width: button.frame.width * horizontalScale,
                        height: button.frame.height * scale
                    )
                    .offset(
                        x: button.frame.minX * horizontalScale,
                        y: button.frame.minY * scale
                    )
                }
            }
            .frame(
                width: proxy.size.width,
                height: panel.size.height * scale,
                alignment: .topLeading
            )
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .onAppear {
            keyboardLanguageService.refreshSelectedLanguage()
        }
    }

    // MARK: - Metrics
    private func layoutScale(in availableSize: CGSize) -> CGFloat {
        guard
            availableSize.width.isFinite,
            availableSize.height.isFinite,
            availableSize.width > 0,
            availableSize.height > 0,
            panel.size.width > 0,
            panel.size.height > 0
        else {
            return 1
        }

        return min(
            availableSize.width / panel.size.width,
            availableSize.height / panel.size.height
        )
    }
}
