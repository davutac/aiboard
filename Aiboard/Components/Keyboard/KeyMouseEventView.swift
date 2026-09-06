import AppKit
import SwiftUI

// MARK: - KeyMouseButton
enum KeyMouseButton: Hashable {
    case left
    case right

    // MARK: - Action
    var actionTrigger: KeyActionTrigger {
        switch self {
        case .left:
            .leftClick
        case .right:
            .rightClick
        }
    }

    var actionSlot: KeyActionSlot {
        switch self {
        case .left:
            .leftClick
        case .right:
            .rightClick
        }
    }
}

// MARK: - KeyMouseHitRegion
enum KeyMouseHitRegion: Hashable {
    case rectangle
    case isoReturn

    // MARK: - Hit Testing
    func contains(_ point: CGPoint, in bounds: CGRect) -> Bool {
        guard bounds.contains(point) else {
            return false
        }

        switch self {
        case .rectangle:
            return true
        case .isoReturn:
            let upperSectionHeight = bounds.height * PanelEditorISOEnterMetrics.upperHeightFraction
            let lowerLeadingInset =
                bounds.width * PanelEditorISOEnterMetrics.lowerLeadingInsetFraction
            return point.y <= bounds.minY + upperSectionHeight
                || point.x >= bounds.minX + lowerLeadingInset
        }
    }
}

// MARK: - KeyMouseEventView
struct KeyMouseEventView: NSViewRepresentable {
    @Binding var pressedButton: KeyMouseButton?
    @Binding var releasedButton: KeyMouseButton?
    let allowsDragTracking: Bool
    var hitRegion: KeyMouseHitRegion = .rectangle
    let mousePressed: (KeyMouseButton) -> Void
    let mouseReleasedInside: (KeyMouseButton) -> Void
    let mouseCancelled: () -> Void
    let editingDragChanged: (CGSize) -> Void
    let editingDragEnded: (CGSize) -> Void

    // MARK: - Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(
            pressedButton: $pressedButton,
            releasedButton: $releasedButton,
            allowsDragTracking: allowsDragTracking,
            mousePressed: mousePressed,
            mouseReleasedInside: mouseReleasedInside,
            mouseCancelled: mouseCancelled,
            editingDragChanged: editingDragChanged,
            editingDragEnded: editingDragEnded
        )
    }

    // MARK: - NSView
    func makeNSView(context: Context) -> KeyMouseEventNSView {
        let view = KeyMouseEventNSView()

        view.delegate = context.coordinator
        view.allowsDragTracking = allowsDragTracking
        view.hitRegion = hitRegion

        return view
    }

    func updateNSView(_ nsView: KeyMouseEventNSView, context: Context) {
        context.coordinator.pressedButton = $pressedButton
        context.coordinator.releasedButton = $releasedButton
        context.coordinator.allowsDragTracking = allowsDragTracking
        context.coordinator.mousePressed = mousePressed
        context.coordinator.mouseReleasedInside = mouseReleasedInside
        context.coordinator.mouseCancelled = mouseCancelled
        context.coordinator.editingDragChanged = editingDragChanged
        context.coordinator.editingDragEnded = editingDragEnded
        nsView.delegate = context.coordinator
        nsView.allowsDragTracking = allowsDragTracking
        nsView.hitRegion = hitRegion
    }

    // MARK: - Coordinator
    @MainActor
    final class Coordinator: KeyMouseEventNSViewDelegate {
        var pressedButton: Binding<KeyMouseButton?>
        var releasedButton: Binding<KeyMouseButton?>
        var allowsDragTracking: Bool
        var mousePressed: (KeyMouseButton) -> Void
        var mouseReleasedInside: (KeyMouseButton) -> Void
        var mouseCancelled: () -> Void
        var editingDragChanged: (CGSize) -> Void
        var editingDragEnded: (CGSize) -> Void

        // MARK: - Initialization
        init(
            pressedButton: Binding<KeyMouseButton?>,
            releasedButton: Binding<KeyMouseButton?>,
            allowsDragTracking: Bool,
            mousePressed: @escaping (KeyMouseButton) -> Void,
            mouseReleasedInside: @escaping (KeyMouseButton) -> Void,
            mouseCancelled: @escaping () -> Void,
            editingDragChanged: @escaping (CGSize) -> Void,
            editingDragEnded: @escaping (CGSize) -> Void
        ) {
            self.pressedButton = pressedButton
            self.releasedButton = releasedButton
            self.allowsDragTracking = allowsDragTracking
            self.mousePressed = mousePressed
            self.mouseReleasedInside = mouseReleasedInside
            self.mouseCancelled = mouseCancelled
            self.editingDragChanged = editingDragChanged
            self.editingDragEnded = editingDragEnded
        }

        // MARK: - KeyMouseEventNSViewDelegate
        func keyMouseEventView(
            _ view: KeyMouseEventNSView,
            didPress button: KeyMouseButton
        ) {
            pressedButton.wrappedValue = button
            mousePressed(button)
        }

        func keyMouseEventView(
            _ view: KeyMouseEventNSView,
            didReleaseInside button: KeyMouseButton
        ) {
            pressedButton.wrappedValue = nil
            releasedButton.wrappedValue = button
            mouseReleasedInside(button)
        }

        func keyMouseEventViewDidCancel(_ view: KeyMouseEventNSView) {
            pressedButton.wrappedValue = nil
            mouseCancelled()
        }

        func keyMouseEventView(
            _ view: KeyMouseEventNSView,
            didDrag translation: CGSize
        ) {
            guard allowsDragTracking else {
                return
            }

            editingDragChanged(translation)
        }

        func keyMouseEventView(
            _ view: KeyMouseEventNSView,
            didEndDrag translation: CGSize
        ) {
            guard allowsDragTracking else {
                return
            }

            editingDragEnded(translation)
        }
    }
}

// MARK: - KeyMouseEventNSViewDelegate
@MainActor
protocol KeyMouseEventNSViewDelegate: AnyObject {
    func keyMouseEventView(_ view: KeyMouseEventNSView, didPress button: KeyMouseButton)
    func keyMouseEventView(_ view: KeyMouseEventNSView, didReleaseInside button: KeyMouseButton)
    func keyMouseEventViewDidCancel(_ view: KeyMouseEventNSView)
    func keyMouseEventView(_ view: KeyMouseEventNSView, didDrag translation: CGSize)
    func keyMouseEventView(_ view: KeyMouseEventNSView, didEndDrag translation: CGSize)
}

// MARK: - KeyMouseEventNSView
@MainActor
final class KeyMouseEventNSView: NSView {
    weak var delegate: (any KeyMouseEventNSViewDelegate)?
    var allowsDragTracking = false
    var hitRegion: KeyMouseHitRegion = .rectangle

    private var pressedButton: KeyMouseButton?
    private var trackingStartLocationInWindow: CGPoint?
    private var hasDragged = false

    override var isFlipped: Bool {
        true
    }

    // MARK: - Hit Testing
    override func hitTest(_ point: NSPoint) -> NSView? {
        let localPoint = convert(point, from: superview)
        guard hitRegion.contains(localPoint, in: bounds) else {
            return nil
        }

        return super.hitTest(point)
    }

    // MARK: - First Mouse
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        beginTracking(.left, with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        beginTracking(.right, with: event)
    }

    override func mouseDragged(with event: NSEvent) {
        updateDrag(.left, with: event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        updateDrag(.right, with: event)
    }

    override func mouseUp(with event: NSEvent) {
        endTracking(.left, with: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        endTracking(.right, with: event)
    }

    override func mouseExited(with event: NSEvent) {
        guard !allowsDragTracking || !hasDragged else {
            return
        }

        cancelTracking()
    }

    // MARK: - Tracking
    private func beginTracking(_ button: KeyMouseButton, with event: NSEvent) {
        pressedButton = button
        trackingStartLocationInWindow = event.locationInWindow
        hasDragged = false
        delegate?.keyMouseEventView(self, didPress: button)
    }

    private func endTracking(_ button: KeyMouseButton, with event: NSEvent) {
        guard pressedButton == button else {
            return
        }

        if allowsDragTracking, hasDragged {
            let translation = dragTranslation(for: event)

            clearTracking()
            delegate?.keyMouseEventView(self, didEndDrag: translation)
            delegate?.keyMouseEventViewDidCancel(self)
            return
        }

        clearTracking()
        let location = convert(event.locationInWindow, from: nil)

        if hitRegion.contains(location, in: bounds) {
            delegate?.keyMouseEventView(self, didReleaseInside: button)
        }
        else {
            delegate?.keyMouseEventViewDidCancel(self)
        }
    }

    private func cancelTracking() {
        guard pressedButton != nil else {
            return
        }

        clearTracking()
        delegate?.keyMouseEventViewDidCancel(self)
    }

    private func updateDrag(_ button: KeyMouseButton, with event: NSEvent) {
        guard pressedButton == button else {
            return
        }

        guard allowsDragTracking, button == .left else {
            let location = convert(event.locationInWindow, from: nil)
            if !hitRegion.contains(location, in: bounds) {
                cancelTracking()
            }
            return
        }

        let translation = dragTranslation(for: event)

        if !hasDragged {
            let distance = hypot(translation.width, translation.height)

            guard distance >= Self.dragThreshold else {
                return
            }

            hasDragged = true
        }

        delegate?.keyMouseEventView(self, didDrag: translation)
    }

    private func dragTranslation(for event: NSEvent) -> CGSize {
        guard let trackingStartLocationInWindow else {
            return .zero
        }

        let currentLocation = event.locationInWindow
        let translation = CGSize(
            width: currentLocation.x - trackingStartLocationInWindow.x,
            height: trackingStartLocationInWindow.y - currentLocation.y
        )

        guard translation.width.isFinite, translation.height.isFinite else {
            return .zero
        }

        return translation
    }

    private func clearTracking() {
        pressedButton = nil
        trackingStartLocationInWindow = nil
        hasDragged = false
    }

    private static let dragThreshold: CGFloat = 3
}
