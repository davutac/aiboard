import AppKit
import Observation
import SwiftUI

@Observable
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let persistence = AppPersistence()
    @ObservationIgnored lazy var aiService = AIProviderService(persistence: persistence)
    let updateService = AppUpdateService.shared
    let accessibilityService = AccessibilityService.shared
    let floatingWindowController = FloatingWindowController.shared
    let floatingWindowManager = FloatingWindowManager.shared
    private let pointerVisibilityMonitor = PointerVisibilityMonitor {
        if $0 == .toggle { SoundService.shared.play(.keyPress) }
        FloatingWindowController.shared.handlePointerVisibility($0)
    }

    var isFloatingWindowVisible: Bool {
        floatingWindowController.isVisible
    }

    var isKeyboardDebugWindowVisible: Bool {
        floatingWindowManager.isVisible(.keyboardDebug)
    }

    // MARK: - Application Lifecycle
    func applicationDidFinishLaunching(_ notification: Notification) {
        aiService.start()
        PhysicalKeyboardState.shared.start()
        startObservingActiveApplication()
        if let frontmostApplication = NSWorkspace.shared.frontmostApplication {
            floatingWindowController.applicationDidActivate(frontmostApplication)
        }

        accessibilityService.requestAuthorization()
        floatingWindowController.show()
        floatingWindowController.updateLockScreenDisplay()
        startObservingScreenLock()
        pointerVisibilityMonitor.start()
        updateService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        KeyboardService.shared.releaseAllModifiers()
        PhysicalKeyboardState.shared.stop()
        pointerVisibilityMonitor.stop()
        DistributedNotificationCenter.default().removeObserver(self)
        floatingWindowController.stopLockScreenDisplay()
        TextPredictionService.shared.stop()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    // MARK: - Provider Shutdown
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await aiService.shutdown()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        floatingWindowController.show()
        return false
    }

    // MARK: - Active Application
    private func startObservingScreenLock() {
        for name in [
            NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification,
        ] {
            NSWorkspace.shared.notificationCenter.addObserver(
                self,
                selector: #selector(releaseKeyboardInput),
                name: name,
                object: nil
            )
        }
        let center = DistributedNotificationCenter.default()
        center.addObserver(
            self,
            selector: #selector(screenLocked),
            name: .init("com.apple.screenIsLocked"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
        center.addObserver(
            self,
            selector: #selector(screenUnlocked),
            name: .init("com.apple.screenIsUnlocked"),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    // MARK: - Suspended Input
    @objc private func releaseKeyboardInput() {
        KeyboardService.shared.releaseAllModifiers()
    }

    @objc private func screenLocked() {
        pointerVisibilityMonitor.stop()
        floatingWindowController.screenLockDidChange(true)
    }

    @objc private func screenUnlocked() {
        floatingWindowController.screenLockDidChange(false)
        PhysicalKeyboardState.shared.refresh()
        pointerVisibilityMonitor.start()
    }

    private func startObservingActiveApplication() {
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeApplicationDidChange(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
    }

    @objc private func activeApplicationDidChange(_ notification: Notification) {
        guard
            let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication
        else {
            return
        }

        floatingWindowController.applicationDidActivate(application)
    }

    // MARK: - Floating Window
    func toggleFloatingWindow() {
        floatingWindowController.toggle()
    }

    // MARK: - Keyboard Debug Window
    func toggleKeyboardDebugWindow() {
        floatingWindowManager.toggle(
            .keyboardDebug,
            configuration: .keyboardDebugWindow
        ) { actions in
            KeyboardDebugWindowContent(hide: actions.hide)
        }
    }
}
