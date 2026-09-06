import SwiftUI
import Testing

@testable import Aiboard

// MARK: - KeyMouseEventViewTests
@MainActor
struct KeyMouseEventViewTests {
    // MARK: - Hit Testing
    @Test func hitTestingConvertsNonzeroFrameOrigin() {
        let parent = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 300))
        let view = KeyMouseEventNSView(frame: NSRect(x: 120, y: 80, width: 46, height: 77))
        view.hitRegion = .isoReturn
        parent.addSubview(view)

        let upperArm = view.convert(NSPoint(x: 4, y: 20), to: parent)
        let lowerStem = view.convert(NSPoint(x: 20, y: 60), to: parent)
        let cutout = view.convert(NSPoint(x: 4, y: 60), to: parent)

        #expect(view.hitTest(upperArm) === view)
        #expect(view.hitTest(lowerStem) === view)
        #expect(view.hitTest(cutout) == nil)
    }

    @Test func isoHitRegionRespectsBoundsOrigin() {
        let bounds = CGRect(x: 100, y: 200, width: 46, height: 77)
        #expect(KeyMouseHitRegion.isoReturn.contains(CGPoint(x: 104, y: 220), in: bounds))
        #expect(!KeyMouseHitRegion.isoReturn.contains(CGPoint(x: 104, y: 260), in: bounds))
        #expect(KeyMouseHitRegion.isoReturn.contains(CGPoint(x: 120, y: 260), in: bounds))
    }

    // MARK: - Drag Cancellation
    @Test(arguments: [KeyMouseButton.left, .right])
    func draggingOutsideCancelsTyping(button: KeyMouseButton) throws {
        let view = KeyMouseEventNSView(frame: NSRect(x: 0, y: 0, width: 46, height: 77))
        let recorder = KeyMouseEventRecorder()
        view.delegate = recorder
        let down = try mouseEvent(
            button == .left ? .leftMouseDown : .rightMouseDown,
            at: CGPoint(x: 20, y: 20),
            in: view
        )
        let drag = try mouseEvent(
            button == .left ? .leftMouseDragged : .rightMouseDragged,
            at: CGPoint(x: 60, y: 20),
            in: view
        )
        if button == .left {
            view.mouseDown(with: down)
            view.mouseDragged(with: drag)
            view.mouseDragged(with: drag)
        }
        else {
            view.rightMouseDown(with: down)
            view.rightMouseDragged(with: drag)
            view.rightMouseDragged(with: drag)
        }
        #expect(recorder.events == ["press", "cancel"])
    }

    @Test func draggingIntoReturnCutoutCancelsTyping() throws {
        let view = KeyMouseEventNSView(frame: NSRect(x: 0, y: 0, width: 46, height: 77))
        view.hitRegion = .isoReturn
        let recorder = KeyMouseEventRecorder()
        view.delegate = recorder
        view.mouseDown(with: try mouseEvent(.leftMouseDown, at: CGPoint(x: 4, y: 20), in: view))
        view.mouseDragged(
            with: try mouseEvent(.leftMouseDragged, at: CGPoint(x: 4, y: 60), in: view)
        )
        #expect(recorder.events == ["press", "cancel"])
    }

    @Test func editorDragContinuesOutsideKey() throws {
        let view = KeyMouseEventNSView(frame: NSRect(x: 0, y: 0, width: 46, height: 77))
        view.allowsDragTracking = true
        let recorder = KeyMouseEventRecorder()
        view.delegate = recorder
        view.mouseDown(with: try mouseEvent(.leftMouseDown, at: CGPoint(x: 20, y: 20), in: view))
        view.mouseDragged(
            with: try mouseEvent(.leftMouseDragged, at: CGPoint(x: 60, y: 20), in: view)
        )
        #expect(recorder.events == ["press", "drag"])
    }

    // MARK: - Fixtures
    private func mouseEvent(
        _ type: NSEvent.EventType,
        at point: CGPoint,
        in view: NSView
    ) throws -> NSEvent {
        try #require(
            NSEvent.mouseEvent(
                with: type,
                location: view.convert(point, to: nil),
                modifierFlags: [],
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                eventNumber: 0,
                clickCount: 1,
                pressure: 1
            )
        )
    }

    // MARK: - Coordinator
    @Test func coordinatorDispatchesMouseActionsSynchronously() {
        var pressedButton: KeyMouseButton?
        var releasedButton: KeyMouseButton?
        var actions: [String] = []
        let coordinator = KeyMouseEventView.Coordinator(
            pressedButton: Binding(
                get: { pressedButton },
                set: { pressedButton = $0 }
            ),
            releasedButton: Binding(
                get: { releasedButton },
                set: { releasedButton = $0 }
            ),
            allowsDragTracking: false,
            mousePressed: { actions.append("pressed:\($0)") },
            mouseReleasedInside: { actions.append("released:\($0)") },
            mouseCancelled: { actions.append("cancelled") },
            editingDragChanged: { _ in },
            editingDragEnded: { _ in }
        )
        let view = KeyMouseEventNSView()

        coordinator.keyMouseEventView(view, didPress: .left)
        coordinator.keyMouseEventView(view, didReleaseInside: .left)

        #expect(actions == ["pressed:left", "released:left"])
        #expect(pressedButton == nil)
        #expect(releasedButton == .left)
    }
}

// MARK: - KeyMouseEventRecorder
@MainActor
private final class KeyMouseEventRecorder: KeyMouseEventNSViewDelegate {
    var events: [String] = []

    // MARK: - Events
    func keyMouseEventView(_ view: KeyMouseEventNSView, didPress button: KeyMouseButton) {
        events.append("press")
    }
    func keyMouseEventView(_ view: KeyMouseEventNSView, didReleaseInside button: KeyMouseButton) {
        events.append("release")
    }
    func keyMouseEventViewDidCancel(_ view: KeyMouseEventNSView) {
        events.append("cancel")
    }
    func keyMouseEventView(_ view: KeyMouseEventNSView, didDrag translation: CGSize) {
        events.append("drag")
    }
    func keyMouseEventView(_ view: KeyMouseEventNSView, didEndDrag translation: CGSize) {
        events.append("endDrag")
    }
}
