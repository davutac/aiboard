import AppKit
import ApplicationServices
import IOKit
import Observation

// MARK: - PhysicalKeyboardState
@Observable
@MainActor
final class PhysicalKeyboardState {
    static let shared = PhysicalKeyboardState()
    private(set) var snapshot = PhysicalKeyboardSnapshot()
    @ObservationIgnored private var localMonitor: Any?
    @ObservationIgnored private var globalMonitor: Any?
    @ObservationIgnored private var workspaceObservers: [NSObjectProtocol] = []
    @ObservationIgnored private var reconciliationTimer: Timer?
    @ObservationIgnored private var controlDates: [SystemControl: Date] = [:]
    @ObservationIgnored private let readHardware: () -> PhysicalKeyboardSnapshot
    @ObservationIgnored private let canObserve: () -> Bool
    @ObservationIgnored private var isRunning = false

    // MARK: - Initialization
    init(
        readHardware: @escaping () -> PhysicalKeyboardSnapshot = PhysicalKeyboardState
            .hardwareSnapshot,
        canObserve: @escaping () -> Bool = {
            AXIsProcessTrusted() || CGPreflightListenEventAccess()
        }
    ) {
        self.readHardware = readHardware
        self.canObserve = canObserve
    }

    // MARK: - Lifecycle
    func start() {
        guard !isRunning else {
            refresh()
            return
        }
        isRunning = true
        let events: NSEvent.EventTypeMask = [.keyDown, .keyUp, .flagsChanged, .systemDefined]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            MainActor.assumeIsolated { self?.receive(event) }
            return event
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didActivateApplicationNotification, NSWorkspace.didWakeNotification,
            NSWorkspace.sessionDidBecomeActiveNotification,
        ] {
            workspaceObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] _ in MainActor.assumeIsolated { self?.refresh() }
                }
            )
        }
        for name in [
            NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification,
        ] {
            workspaceObservers.append(
                center.addObserver(forName: name, object: nil, queue: .main) {
                    [weak self] _ in MainActor.assumeIsolated { self?.reset() }
                }
            )
        }
        // Recover missed releases and permission changes without retaining typed text.
        reconciliationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) {
            [weak self] _ in MainActor.assumeIsolated { self?.refresh() }
        }
        refresh()
    }

    func stop() {
        isRunning = false
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil
        globalMonitor = nil
        workspaceObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceObservers.removeAll()
        reconciliationTimer?.invalidate()
        reconciliationTimer = nil
        reset()
    }

    func reset() {
        snapshot = PhysicalKeyboardSnapshot()
        controlDates.removeAll()
    }

    func refresh() {
        guard canObserve() else {
            if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
            globalMonitor = nil
            reset()
            return
        }
        if isRunning, globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.keyDown, .keyUp, .flagsChanged, .systemDefined]
            ) { [weak self] event in
                MainActor.assumeIsolated { self?.receive(event) }
            }
        }
        var current = readHardware()
        controlDates = controlDates.filter { Date().timeIntervalSince($0.value) < 2 }
        current.pressedControls = Set(controlDates.keys)
        if current != snapshot { snapshot = current }
    }

    // MARK: - Events
    func receive(_ event: NSEvent) {
        guard
            event.cgEvent?.getIntegerValueField(.eventSourceUserData)
                != CGKeyboardEventPoster.predictionEventTag
        else { return }
        guard canObserve() else {
            reset()
            return
        }
        switch event.type {
        case .keyDown, .keyUp:
            guard let key = Key(rawValue: event.keyCode) else { return }
            snapshot.setKey(key, isDown: event.type == .keyDown)
        case .flagsChanged:
            let hardware = readHardware()
            snapshot.modifiers = hardware.modifiers
            snapshot.isCapsLockEnabled = hardware.isCapsLockEnabled
            for key in ModifierKey.allCases.map(\.key) + [.capsLock] {
                snapshot.setKey(key, isDown: hardware.pressedKeys.contains(key))
            }
        case .systemDefined:
            guard event.subtype.rawValue == Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS),
                let control = Self.control(for: (event.data1 >> 16) & 0xFFFF)
            else { return }
            let state = (event.data1 >> 8) & 0xFF
            if state == NX_KEYDOWN {
                snapshot.pressedControls.insert(control)
                controlDates[control] = Date()
            }
            else if state == NX_KEYUP {
                snapshot.pressedControls.remove(control)
                controlDates.removeValue(forKey: control)
            }
        default:
            break
        }
    }

    // MARK: - Hardware
    nonisolated static func hardwareSnapshot() -> PhysicalKeyboardSnapshot {
        var keys = Set(
            Key.allCases.filter {
                CGEventSource.keyState(.hidSystemState, key: $0.cgKeyCode)
            }
        )
        let flags = CGEventSource.flagsState(.hidSystemState)
        // Globe/Fn is exposed as a flag on keyboards that omit its key-state bit.
        if flags.contains(.maskSecondaryFn) { keys.insert(.function) }
        let modifiers = Set(ModifierKey.allCases.filter { keys.contains($0.key) })
        return PhysicalKeyboardSnapshot(
            pressedKeys: keys,
            modifiers: modifiers,
            isCapsLockEnabled: flags.contains(.maskAlphaShift)
        )
    }

    // MARK: - Media Keys
    nonisolated static func control(for keyType: Int) -> SystemControl? {
        switch Int32(keyType) {
        case NX_KEYTYPE_BRIGHTNESS_DOWN: .brightnessDown
        case NX_KEYTYPE_BRIGHTNESS_UP: .brightnessUp
        case NX_KEYTYPE_SOUND_DOWN: .volumeDown
        case NX_KEYTYPE_SOUND_UP: .volumeUp
        case NX_KEYTYPE_MUTE: .mute
        case NX_KEYTYPE_PLAY: .playPause
        case NX_KEYTYPE_PREVIOUS, NX_KEYTYPE_REWIND: .previousTrack
        case NX_KEYTYPE_NEXT, NX_KEYTYPE_FAST: .nextTrack
        default: nil
        }
    }
}
