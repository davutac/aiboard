import SwiftUI

// MARK: - AlwaysOnTopWindowController
@MainActor
final class AlwaysOnTopWindowController {
    private var panel: AlwaysOnTopPanel?
    private var hostingView: MouseInteractiveHostingView<AnyView>?
    private let windowDimensions = WindowDimensions()
    private var sizeDidChange: (@MainActor (CGSize) -> Void)?
    private var originDidChange: (@MainActor (CGPoint) -> Void)?
    private var isApplyingConfiguration = false
    private var geometryAnimation: WindowGeometryAnimation?
    private var finishGeometryAnimation: (() -> Void)?
    private var lockScreenSpace: PrivateDisplaySpace?

    var frame: CGRect? { panel?.frame }
    var preventsHiding: Bool { panel?.preventsHiding == true }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    // MARK: - Window Lifecycle
    func setPreventsHiding(_ preventsHiding: Bool) {
        panel?.preventsHiding = preventsHiding
    }

    func setLockScreenDisplay(_ enabled: Bool) throws {
        guard enabled else {
            lockScreenSpace?.detach()
            lockScreenSpace = nil
            return
        }
        guard lockScreenSpace == nil else { return }
        guard let panel else { throw PrivateDisplaySpace.Failure.unavailable("keyboard window") }
        let space = try PrivateDisplaySpace()
        try space.attach(panel)
        lockScreenSpace = space
    }

    func show<Content: View>(
        configuration: AlwaysOnTopWindowConfiguration = .init(),
        preservingCurrentOrigin: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        show(
            configuration: configuration,
            preservingCurrentOrigin: preservingCurrentOrigin,
            content: AnyView(content())
        )
    }

    func hide() {
        cancelGeometryAnimation()
        panel?.orderOut(nil)
    }

    func resizeContent(to size: CGSize) {
        guard let panel else {
            return
        }

        let currentSize = panel.contentSize(fallback: size)
        let constrainedSize = constrainedContentSize(size, for: panel, fallback: currentSize)

        guard constrainedSize.isMeaningfullyDifferent(from: currentSize) else {
            return
        }

        panel.setFittedContentSize(constrainedSize)
        publishWindowState(for: panel, fallback: constrainedSize)
        updateWindowDimensions(for: panel, fallback: constrainedSize)
    }

    // MARK: - Presentation
    private func show(
        configuration: AlwaysOnTopWindowConfiguration,
        preservingCurrentOrigin: Bool,
        content: AnyView
    ) {
        let panel = panel ?? makePanel(configuration: configuration, content: content)
        self.panel = panel
        hostingView?.rootView = contentWithWindowDimensions(content)
        applyGeometry(
            configuration: configuration,
            preservingCurrentOrigin: preservingCurrentOrigin
        )
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Geometry Animation
    func animateGeometry(
        configuration: AlwaysOnTopWindowConfiguration,
        duration: TimeInterval,
        progress: @escaping (CGFloat) -> Void
    ) {
        cancelGeometryAnimation()
        guard let panel, duration > 0 else {
            progress(1)
            updateGeometry(configuration: configuration)
            return
        }
        let initialFrame = panel.frame
        let contentSize = panel.contentSize(fallback: configuration.size)
        let targetFrame = CGRect(
            origin: configuration.origin ?? initialFrame.origin,
            size: CGSize(
                width: initialFrame.width + configuration.size.width - contentSize.width,
                height: initialFrame.height + configuration.size.height - contentSize.height
            )
        )
        isApplyingConfiguration = true
        // Allow the transition's full range; restore the width-driven limits at completion.
        panel.contentMinSize = CGSize(
            width: min(panel.contentMinSize.width, configuration.minSize.width),
            height: min(panel.contentMinSize.height, configuration.minSize.height)
        )
        panel.contentMaxSize = CGSize(
            width: max(panel.contentMaxSize.width, configuration.maxSize.width),
            height: max(panel.contentMaxSize.height, configuration.maxSize.height)
        )
        finishGeometryAnimation = { [weak self] in
            progress(1)
            self?.updateGeometry(configuration: configuration)
        }
        geometryAnimation = WindowGeometryAnimation(window: panel, duration: duration) {
            [weak self, weak panel] fraction in
            guard let self, let panel else { return }
            let frame = CGRect(
                x: initialFrame.minX + (targetFrame.minX - initialFrame.minX) * fraction,
                y: initialFrame.minY + (targetFrame.minY - initialFrame.minY) * fraction,
                width: initialFrame.width + (targetFrame.width - initialFrame.width) * fraction,
                height: initialFrame.height + (targetFrame.height - initialFrame.height) * fraction
            )
            panel.setFrame(frame, display: false)
            progress(fraction)
            if fraction == 1 {
                self.updateGeometry(configuration: configuration)
            }
        }
    }

    private func cancelGeometryAnimation() {
        geometryAnimation?.cancel()
        geometryAnimation = nil
        finishGeometryAnimation = nil
        isApplyingConfiguration = false
    }

    // MARK: - Geometry Updates
    func updateGeometry(configuration: AlwaysOnTopWindowConfiguration) {
        applyGeometry(configuration: configuration, preservingCurrentOrigin: false)
    }

    private func applyGeometry(
        configuration: AlwaysOnTopWindowConfiguration,
        preservingCurrentOrigin: Bool
    ) {
        cancelGeometryAnimation()
        guard let panel else { return }
        sizeDidChange = configuration.sizeDidChange
        originDidChange = configuration.originDidChange
        let preservedOrigin =
            preservingCurrentOrigin && panel.isVisible
            ? panel.frame.origin
            : nil
        var configuration = configuration
        configuration.origin = preservedOrigin ?? configuration.origin

        isApplyingConfiguration = true
        panel.apply(configuration)
        hostingView?.layoutSubtreeIfNeeded()
        panel.applyContentSizeConstraints(
            configuration: configuration,
            contentMinimumSize: hostingView?.fittingSize ?? .zero
        )
        if let preservedOrigin {
            panel.setFrameOrigin(preservedOrigin)
        }
        isApplyingConfiguration = false
        publishWindowState(for: panel, fallback: configuration.size)
        updateWindowDimensions(for: panel, fallback: configuration.size)
    }

    private func makePanel(
        configuration: AlwaysOnTopWindowConfiguration,
        content: AnyView
    ) -> AlwaysOnTopPanel {
        let panel = AlwaysOnTopPanel(configuration: configuration)
        let hostingView = MouseInteractiveHostingView(
            rootView: contentWithWindowDimensions(content)
        )
        hostingView.frame = NSRect(origin: .zero, size: configuration.size)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.sizingOptions = []
        hostingView.safeAreaRegions = []

        // The panel owns sizing; a host used directly as contentView can resize its window.
        let contentView = NSView(frame: hostingView.frame)
        contentView.addSubview(hostingView)
        panel.contentView = contentView
        panel.sizeDidChange = { [weak self, weak panel] size in
            guard let self, let panel else { return }
            guard !self.isApplyingConfiguration else { return }

            self.sizeDidChange?(size)
            self.updateWindowDimensions(for: panel, fallback: size)
        }
        panel.liveResizeDidChange = { [weak self] isLiveResizing in
            if isLiveResizing { self?.finishGeometryAnimation?() }
            self?.windowDimensions.updateLiveResizing(isLiveResizing)
        }
        panel.contentSizeDidChangeDuringLiveResize = { [weak self, weak panel] size in
            guard let self, let panel else { return }
            guard !self.isApplyingConfiguration else { return }

            self.updateWindowDimensions(for: panel, fallback: size)
        }
        panel.originDidChange = { [weak self] origin in
            guard let self else { return }
            guard !self.isApplyingConfiguration else { return }

            self.originDidChange?(origin)
        }
        self.hostingView = hostingView

        return panel
    }

    private func contentWithWindowDimensions(_ content: AnyView) -> AnyView {
        AnyView(
            content
                .environment(\.windowDimensions, windowDimensions)
        )
    }

    private func updateWindowDimensions(for panel: AlwaysOnTopPanel, fallback: CGSize) {
        windowDimensions.update(
            size: panel.contentSize(fallback: fallback),
            minSize: panel.contentMinSize,
            maxSize: panel.contentMaxSize
        )
    }

    private func publishWindowState(for panel: AlwaysOnTopPanel, fallback: CGSize) {
        sizeDidChange?(panel.contentSize(fallback: fallback))
        originDidChange?(panel.frame.origin)
    }

    private func constrainedContentSize(
        _ size: CGSize,
        for panel: AlwaysOnTopPanel,
        fallback: CGSize
    ) -> CGSize {
        let validSize = size.validWindowConstraint(fallback: fallback)
        let minimumSize = panel.contentMinSize.validWindowConstraint(fallback: fallback)
        let maximumSize = panel.contentMaxSize.validWindowConstraint(
            fallback: FloatingWindowDefaults.defaultMaximumSize
        )

        return CGSize(
            width: min(max(validSize.width, minimumSize.width), maximumSize.width),
            height: min(max(validSize.height, minimumSize.height), maximumSize.height)
        )
    }
}

extension CGSize {
    // MARK: - Comparison
    fileprivate func isMeaningfullyDifferent(from other: CGSize) -> Bool {
        abs(width - other.width) > 0.5 || abs(height - other.height) > 0.5
    }
}
