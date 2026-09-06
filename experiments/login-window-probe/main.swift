import AppKit
import ApplicationServices
import Carbon.HIToolbox
import OSLog

// MARK: - Probe Events
enum ProbeEvents {
    static let keyCodes: [CGKeyCode] = [CGKeyCode(kVK_ANSI_X), CGKeyCode(kVK_Delete)]

    // MARK: - Event Construction
    static func pair(for keyCode: CGKeyCode) throws -> (CGEvent, CGEvent) {
        guard keyCodes.contains(keyCode),
            let source = CGEventSource(stateID: .combinedSessionState),
            let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
            let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        else { throw NSError(domain: "AiboardLoginProbe", code: 1) }
        down.flags = []
        up.flags = []
        return (down, up)
    }
}

// MARK: - Nonactivating Probe UI
final class ProbePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class ProbeButton: NSButton {
    // MARK: - First Mouse
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

// MARK: - Probe Delegate
final class ProbeDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.davutcaliskan.AiboardLoginProbe", category: "Probe")
    private let permissionLabel = NSTextField(labelWithString: "")
    private let resultLabel = NSTextField(labelWithString: "No input attempted.")
    private var panel: ProbePanel?
    private var terminationSignal: DispatchSourceSignal?
    private var timeout: Timer?

    // MARK: - Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = nil
        showPanel()
        refreshPermission()
        signal(SIGTERM, SIG_IGN)
        let terminationSignal = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        terminationSignal.setEventHandler { NSApp.terminate(nil) }
        terminationSignal.resume()
        self.terminationSignal = terminationSignal
        timeout = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { _ in
            MainActor.assumeIsolated { NSApp.terminate(nil) }
        }
        logger.notice("Probe started; uid=\(geteuid()); expires in 300 seconds")
    }

    func applicationWillTerminate(_ notification: Notification) {
        timeout?.invalidate()
        logger.notice("Probe stopped")
    }

    // MARK: - Window
    private func showPanel() {
        let panel = ProbePanel(
            contentRect: CGRect(x: 0, y: 0, width: 490, height: 205),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.canBecomeVisibleWithoutLogin = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .windowBackgroundColor

        let title = NSTextField(labelWithString: "Aiboard visibility / input probe")
        title.font = .boldSystemFont(ofSize: 16)
        let instructions = NSTextField(
            wrappingLabelWithString:
                "Select an empty test field outside this window. Send one test x, observe it, then delete it. This helper never submits a login."
        )
        instructions.font = .systemFont(ofSize: 12)
        let content = NSView(frame: CGRect(x: 0, y: 0, width: 490, height: 205))
        title.frame = CGRect(x: 16, y: 173, width: 458, height: 22)
        instructions.frame = CGRect(x: 16, y: 129, width: 458, height: 36)
        permissionLabel.frame = CGRect(x: 16, y: 105, width: 458, height: 18)
        resultLabel.frame = CGRect(x: 16, y: 81, width: 458, height: 18)
        for label in [title, instructions, permissionLabel, resultLabel] {
            content.addSubview(label)
        }
        let actions: [(String, Selector, CGFloat)] = [
            ("Send one x", #selector(sendTestKey), 90),
            ("Delete one character", #selector(deleteTestKey), 150),
            ("Refresh status", #selector(refreshPermission), 115),
            ("Quit probe", #selector(quit), 95),
        ]
        var x: CGFloat = 12
        for (title, action, width) in actions {
            let button = button(title, action: action)
            button.frame = CGRect(x: x, y: 44, width: width, height: 28)
            content.addSubview(button)
            x += width + 3
        }
        if geteuid() != 0 {
            let request = button("Request input permission…", action: #selector(requestPermission))
            request.frame = CGRect(x: 12, y: 8, width: 220, height: 28)
            content.addSubview(request)
        }
        panel.contentView = content
        if let screen = NSScreen.main {
            panel.setFrameOrigin(
                CGPoint(x: screen.visibleFrame.minX + 24, y: screen.visibleFrame.minY + 24)
            )
        }
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = ProbeButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.setButtonType(.momentaryPushIn)
        return button
    }

    // MARK: - Input Attempts
    @objc private func sendTestKey() { post(CGKeyCode(kVK_ANSI_X)) }
    @objc private func deleteTestKey() { post(CGKeyCode(kVK_Delete)) }

    private func post(_ keyCode: CGKeyCode) {
        refreshPermission()
        guard CGPreflightPostEventAccess() else {
            resultLabel.stringValue = "Posting denied. No event was sent."
            logger.notice("Input attempt blocked by posting permission")
            return
        }
        do {
            let (down, up) = try ProbeEvents.pair(for: keyCode)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
            resultLabel.stringValue = "Event submitted; actual delivery needs visual confirmation."
            logger.notice("Fixed test event submitted; delivery unverified")
        }
        catch {
            resultLabel.stringValue = "Could not construct the test event."
        }
    }

    // MARK: - Permissions and Exit
    @objc private func refreshPermission() {
        permissionLabel.stringValue =
            "Event posting: \(CGPreflightPostEventAccess() ? "allowed" : "denied") · Accessibility: \(AXIsProcessTrusted() ? "trusted" : "untrusted")"
    }

    @objc private func requestPermission() {
        guard geteuid() != 0 else { return }
        _ = CGRequestPostEventAccess()
        refreshPermission()
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - Entry Point
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
if CommandLine.arguments.contains("--self-test") {
    for keyCode in ProbeEvents.keyCodes {
        let (down, up) = try ProbeEvents.pair(for: keyCode)
        precondition(down.type == .keyDown && up.type == .keyUp)
        precondition(down.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode))
        precondition(up.getIntegerValueField(.keyboardEventKeycode) == Int64(keyCode))
    }
    let panel = ProbePanel()
    panel.canBecomeVisibleWithoutLogin = true
    precondition(panel.canBecomeVisibleWithoutLogin && !panel.canBecomeKey)
    print(
        "PASS: event construction and nonactivating window configuration; no events posted, no login test performed"
    )
}
else {
    let delegate = ProbeDelegate()
    application.delegate = delegate
    withExtendedLifetime(delegate) { application.run() }
}
