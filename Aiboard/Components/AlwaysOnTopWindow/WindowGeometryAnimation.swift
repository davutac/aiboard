import AppKit
import QuartzCore

// MARK: - WindowGeometryAnimation
@MainActor
final class WindowGeometryAnimation: NSObject {
    private var displayLink: CADisplayLink?
    private var startedAt: CFTimeInterval?
    private let duration: TimeInterval
    private let update: (CGFloat) -> Void

    // MARK: - Initialization
    init(window: NSWindow, duration: TimeInterval, update: @escaping (CGFloat) -> Void) {
        self.duration = duration
        self.update = update
        super.init()
        let displayLink = window.displayLink(target: self, selector: #selector(step))
        self.displayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    // MARK: - Frames
    @objc private func step(_ displayLink: CADisplayLink) {
        let startedAt = startedAt ?? displayLink.timestamp
        self.startedAt = startedAt
        let fraction = min(1, max(0, (displayLink.targetTimestamp - startedAt) / duration))
        update(fraction * fraction * (3 - 2 * fraction))
        if fraction == 1 { cancel() }
    }

    func cancel() {
        displayLink?.invalidate()
        displayLink = nil
    }
}
