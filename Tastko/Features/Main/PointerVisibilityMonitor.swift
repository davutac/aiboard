import AppKit
import Defaults

// MARK: - PointerVisibilityMonitor
@MainActor
final class PointerVisibilityMonitor {
    private var timer: Timer?
    private var policy = PointerVisibilityPolicy()
    private let cornerIndicator = HotCornerIndicatorController()
    private let perform: (PointerVisibilityAction) -> Void

    // MARK: - Initialization
    init(perform: @escaping (PointerVisibilityAction) -> Void) {
        self.perform = perform
    }

    // MARK: - Lifecycle
    func start() {
        guard timer == nil else { return }
        policy = PointerVisibilityPolicy()
        samplePointer()
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.samplePointer() }
        }
        timer.tolerance = 0.02
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cornerIndicator.update(nil)
    }

    // MARK: - Sampling
    private func samplePointer() {
        if let action = policy.update(
            location: NSEvent.mouseLocation,
            screenFrames: NSScreen.screens.map(\.frame),
            mouseButtonIsDown: NSEvent.pressedMouseButtons != 0,
            time: ProcessInfo.processInfo.systemUptime,
            inactivityDelay: inactivityDelay,
            cornerDwell: Defaults[.hotCornerDwellDuration]
        ) {
            perform(action)
        }
        cornerIndicator.update(policy.cornerProgress)
    }

    // MARK: - Settings
    private var inactivityDelay: TimeInterval? {
        guard Defaults[.pointerAutoHideEnabled] else { return nil }
        let duration = Defaults[.pointerAutoHideDelay]
        guard duration.isFinite else { return PointerVisibilityPolicy.defaultInactivityDelay }
        return min(
            max(duration, PointerVisibilityPolicy.inactivityDelayRange.lowerBound),
            PointerVisibilityPolicy.inactivityDelayRange.upperBound
        )
    }
}
