import AppKit

// MARK: - Interactive Window Region
@MainActor
protocol WindowMouseInteractiveRegion: AnyObject {}

// MARK: - Empty Area Mouse Passthrough
@MainActor
final class WindowMousePassthrough {
    private let panel: NSWindow
    private let content: NSView
    private var globalMonitor: Any?
    private var localMonitor: Any?

    // MARK: - Initialization
    init(panel: NSWindow, content: NSView) {
        self.panel = panel
        self.content = content
        panel.acceptsMouseMovedEvents = true
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            MainActor.assumeIsolated { self?.update() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            MainActor.assumeIsolated { self?.update() }
            return event
        }
        update()
    }

    isolated deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }

    // MARK: - Hit Testing
    func update(at screenPoint: NSPoint = NSEvent.mouseLocation) {
        let point = panel.convertPoint(fromScreen: screenPoint)
        panel.ignoresMouseEvents = !containsInteractiveRegion(content, at: point)
    }

    private func containsInteractiveRegion(_ view: NSView, at point: NSPoint) -> Bool {
        guard !view.isHiddenOrHasHiddenAncestor else { return false }
        if view is any WindowMouseInteractiveRegion,
            let parent = view.superview,
            view.hitTest(parent.convert(point, from: nil)) != nil
        {
            return true
        }
        return view.subviews.contains { containsInteractiveRegion($0, at: point) }
    }
}
