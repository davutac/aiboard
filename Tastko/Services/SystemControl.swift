import AppKit
import CoreGraphics
import IOKit

// MARK: - SystemControl
nonisolated enum SystemControl: String, CaseIterable, Hashable, Sendable {
    case brightnessDown, brightnessUp, missionControl, spotlight
    case previousTrack, playPause, nextTrack, mute, volumeDown, volumeUp

    // MARK: - System Key
    var keyType: Int? {
        switch self {
        case .brightnessDown: Int(NX_KEYTYPE_BRIGHTNESS_DOWN)
        case .brightnessUp: Int(NX_KEYTYPE_BRIGHTNESS_UP)
        case .previousTrack: Int(NX_KEYTYPE_REWIND)
        case .playPause: Int(NX_KEYTYPE_PLAY)
        case .nextTrack: Int(NX_KEYTYPE_FAST)
        case .mute: Int(NX_KEYTYPE_MUTE)
        case .volumeDown: Int(NX_KEYTYPE_SOUND_DOWN)
        case .volumeUp: Int(NX_KEYTYPE_SOUND_UP)
        case .missionControl, .spotlight: nil
        }
    }

    // MARK: - System Application
    var applicationURL: URL? {
        switch self {
        case .missionControl: URL(filePath: "/System/Applications/Mission Control.app")
        case .spotlight: URL(filePath: "/System/Library/CoreServices/Spotlight.app")
        default: nil
        }
    }
}

// MARK: - SystemControlPerforming
@MainActor
protocol SystemControlPerforming {
    func perform(_ control: SystemControl) async throws
}

// MARK: - MacOSSystemControlPerformer
nonisolated struct MacOSSystemControlPerformer: SystemControlPerforming {
    // MARK: - Execution
    @MainActor func perform(_ control: SystemControl) async throws {
        if let applicationURL = control.applicationURL {
            _ = try await NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }
        guard CGPreflightPostEventAccess() else {
            throw KeyboardServiceError.deliveryFailed(
                "Allow Accessibility access to use system controls."
            )
        }
        let down = try Self.event(for: control, keyDown: true)
        let up = try Self.event(for: control, keyDown: false)
        guard let downEvent = down.cgEvent, let upEvent = up.cgEvent else {
            throw KeyboardServiceError.eventCreationFailed
        }
        downEvent.post(tap: .cghidEventTap)
        upEvent.post(tap: .cghidEventTap)
    }

    // MARK: - Auxiliary Key Events
    @MainActor static func event(for control: SystemControl, keyDown: Bool) throws -> NSEvent {
        guard let keyType = control.keyType,
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS),
                data1: (keyType << 16) | (Int(keyDown ? NX_KEYDOWN : NX_KEYUP) << 8),
                data2: -1
            )
        else { throw KeyboardServiceError.eventCreationFailed }
        return event
    }
}
