import CoreGraphics

// MARK: - PanelEditorWindowMetrics
enum PanelEditorWindowMetrics {
    nonisolated static let statusBarHeight =
        KeyboardDesign.Metrics.suggestionHeight
        + KeyboardDesign.Metrics.suggestionTopInset
        + KeyboardDesign.Metrics.suggestionBottomInset
    nonisolated static let fixedChromeHeight = AppConstants.titlebarHeight + statusBarHeight
    nonisolated static let functionToolbarBaseHeight =
        KeyboardDesign.Metrics.suggestionHeight + 2
        * KeyboardDesign.Metrics.functionToolbarVerticalInset

    // MARK: - Shared Window Geometry
    @MainActor
    static func expandedConfiguration(
        size: CGSize,
        origin: CGPoint?,
        minimumScale: CGFloat,
        panelSize: CGSize?,
        functionToolbarProgress: CGFloat = 0
    ) -> AlwaysOnTopWindowConfiguration {
        let scale =
            minimumScale.isFinite
            ? minimumScale.clamped(to: FloatingWindowDefaults.allowedMinimumKeyboardScaleRange)
            : FloatingWindowDefaults.defaultMinimumKeyboardScale
        let keyboardSize =
            panelSize
            ?? CGSize(
                width: FloatingWindowDefaults.defaultSize.width,
                height: FloatingWindowDefaults.defaultSize.height - fixedChromeHeight
            )
        let minimumSize = contentSize(
            for: keyboardSize,
            scale: scale,
            functionToolbarProgress: functionToolbarProgress
        )
        let maximumWidthForHeight =
            (FloatingWindowDefaults.defaultMaximumSize.height - fixedChromeHeight)
            * keyboardSize.width / keyboardSize.height
        let maximumWidth = max(
            minimumSize.width,
            min(FloatingWindowDefaults.defaultMaximumSize.width, maximumWidthForHeight)
        )
        let width = size.validWindowConstraint(fallback: FloatingWindowDefaults.defaultSize)
            .width.clamped(to: minimumSize.width...maximumWidth)

        return AlwaysOnTopWindowConfiguration(
            size: CGSize(
                width: width,
                height: contentHeight(
                    for: keyboardSize,
                    width: width,
                    functionToolbarProgress: functionToolbarProgress
                )
            ),
            minSize: minimumSize,
            maxSize: CGSize(
                width: maximumWidth,
                height: contentHeight(
                    for: keyboardSize,
                    width: maximumWidth,
                    functionToolbarProgress: functionToolbarProgress
                )
            ),
            origin: FloatingWindowDefaults.sanitizedOrigin(origin),
            maintainsContentAspectRatio: false,
            contentHeightForWidth: { width in
                contentHeight(
                    for: keyboardSize,
                    width: width,
                    functionToolbarProgress: functionToolbarProgress
                )
            },
            storageKey: "mainPanelEditorShared"
        )
    }

    // MARK: - Size
    nonisolated static func contentSize(for panelSize: CGSize) -> CGSize {
        contentSize(for: panelSize, scale: 1)
    }

    nonisolated static func contentSize(
        for panelSize: CGSize,
        scale: CGFloat,
        functionToolbarProgress: CGFloat = 0
    ) -> CGSize {
        let validScale = max(0, scale)

        return CGSize(
            width: panelSize.width * validScale,
            height: fixedChromeHeight
                + ((panelSize.height + functionToolbarBaseHeight
                    * min(1, max(0, functionToolbarProgress))) * validScale)
        )
    }

    nonisolated static func contentHeight(
        for panelSize: CGSize,
        width: CGFloat,
        functionToolbarProgress: CGFloat = 0
    ) -> CGFloat {
        guard panelSize.width > 0 else {
            return fixedChromeHeight
        }

        return contentSize(
            for: panelSize,
            scale: width / panelSize.width,
            functionToolbarProgress: functionToolbarProgress
        ).height
    }

    // MARK: - Screen Bounds
    nonisolated static func fittedOrigin(_ origin: CGPoint, size: CGSize, in visibleFrame: CGRect)
        -> CGPoint
    {
        CGPoint(
            x: min(
                max(origin.x, visibleFrame.minX),
                max(visibleFrame.minX, visibleFrame.maxX - size.width)
            ),
            y: min(
                max(origin.y, visibleFrame.minY),
                max(visibleFrame.minY, visibleFrame.maxY - size.height)
            )
        )
    }
}
