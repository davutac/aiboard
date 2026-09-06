import AppKit
import Defaults
import Testing

@testable import Tastko

// MARK: - LockScreenDisplayTests
@MainActor
@Suite(.serialized)
struct LockScreenDisplayTests {
    // MARK: - Native Visibility Actions
    @Test func pinnedPanelRejectsNativeHideCloseAndMiniaturize() {
        let panel = AlwaysOnTopPanel(configuration: .init())
        panel.orderFrontRegardless()
        panel.preventsHiding = true
        panel.orderOut(nil)
        panel.miniaturize(nil)
        panel.close()
        #expect(panel.isVisible)
        #expect(!panel.isMiniaturized)
        #expect(!panel.canHide)
        panel.preventsHiding = false
        panel.orderOut(nil)
        #expect(!panel.isVisible)
        #expect(panel.canHide)
    }

    // MARK: - Private Window Lifecycle
    @Test func attachingAndDetachingOwnWindowPreservesItsFrameAndFocusPolicy() throws {
        let panel = AlwaysOnTopPanel(configuration: .init())
        panel.orderFrontRegardless()
        defer { panel.orderOut(nil) }
        let original = panel.frame
        for _ in 0..<3 {
            let space = try PrivateDisplaySpace()
            try space.attach(panel)
            #expect(panel.frame == original)
            #expect(!panel.canBecomeKey && !panel.canBecomeMain)
            space.detach()
            space.detach()
            #expect(panel.frame == original)
            #expect(panel.isVisible)
        }
    }

    // MARK: - Simulated Lock Notifications
    @Test func lockRestoresManualAndInactivityHidingWithoutChangingPreferences() {
        let controller = FloatingWindowController.shared
        let originalSetting = Defaults[.experimentalLockScreenDisplay]
        let originalPrediction = Defaults[.textPredictionEnabled]
        let originalAutoHide = Defaults[.pointerAutoHideEnabled]
        Defaults[.experimentalLockScreenDisplay] = true
        Defaults[.textPredictionEnabled] = false
        defer {
            controller.screenLockDidChange(false)
            controller.hide()
            Defaults[.experimentalLockScreenDisplay] = originalSetting
            Defaults[.textPredictionEnabled] = originalPrediction
        }

        for inactive in [false, true] {
            controller.show()
            if inactive {
                controller.handlePointerVisibility(.hideForInactivity)
            }
            else {
                controller.hide()
            }
            controller.screenLockDidChange(true)
            #expect(controller.isVisible)
            #expect(controller.presentationState == .expanded)
            #expect(!TextPredictionService.shared.isRunning)
            controller.handlePointerVisibility(.hideForInactivity)
            controller.handlePointerVisibility(.toggle)
            controller.hide()
            controller.minimize()
            controller.toggle()
            FloatingWindowManager.shared.hide(.main)
            #expect(controller.isVisible)
            #expect(controller.presentationState == .expanded)
            let toolbarWasVisible = controller.isFunctionToolbarVisible
            controller.toggleFunctionToolbar()
            #expect(controller.isFunctionToolbarVisible != toolbarWasVisible)
            controller.toggleFunctionToolbar()
            controller.screenLockDidChange(true)
            controller.screenLockDidChange(false)
            #expect(!controller.isVisible)
            #expect(controller.isHiddenForInactivity == inactive)
            #expect(Defaults[.pointerAutoHideEnabled] == originalAutoHide)
        }
    }

    @Test func unlockRestoresMinimizedPresentationAndNormalHideActions() {
        let controller = FloatingWindowController.shared
        let originalSetting = Defaults[.experimentalLockScreenDisplay]
        Defaults[.experimentalLockScreenDisplay] = true
        defer {
            controller.screenLockDidChange(false)
            controller.expand()
            controller.hide()
            Defaults[.experimentalLockScreenDisplay] = originalSetting
        }
        controller.minimize()
        controller.screenLockDidChange(true)
        controller.minimize()
        #expect(controller.isVisible)
        #expect(controller.presentationState == .expanded)
        controller.screenLockDidChange(false)
        #expect(controller.isVisible)
        #expect(controller.presentationState == .minimized)
        controller.hide()
        #expect(!controller.isVisible)
    }
}
