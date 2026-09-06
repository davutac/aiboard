import AppKit
import Darwin

// MARK: - Display Brightness
@MainActor
enum DisplayBrightness {
    private typealias GetBrightness = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness = @convention(c) (UInt32, Float) -> Int32

    // MARK: - Adjustment
    static func adjust(by amount: Float) throws {
        // Brightness key events can be ignored by macOS. Resolve private DisplayServices
        // symbols at runtime to adjust the display directly.
        guard
            let handle = dlopen(
                "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
                RTLD_NOW | RTLD_LOCAL
            )
        else {
            throw KeyboardServiceError.deliveryFailed(
                "Display brightness controls are unavailable."
            )
        }
        defer { dlclose(handle) }
        guard let getSymbol = dlsym(handle, "DisplayServicesGetBrightness"),
            let setSymbol = dlsym(handle, "DisplayServicesSetBrightness")
        else {
            throw KeyboardServiceError.deliveryFailed(
                "Display brightness controls are unavailable."
            )
        }
        let getBrightness = unsafeBitCast(getSymbol, to: GetBrightness.self)
        let setBrightness = unsafeBitCast(setSymbol, to: SetBrightness.self)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
        let display =
            (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value ?? CGMainDisplayID()
        var current: Float = 0
        let readStatus = getBrightness(display, &current)
        guard readStatus == 0, current.isFinite else {
            throw KeyboardServiceError.deliveryFailed(
                "Cannot read brightness for this display (\(readStatus))."
            )
        }
        let target = min(1, max(0, current + amount))
        let writeStatus = setBrightness(display, target)
        guard writeStatus == 0 else {
            throw KeyboardServiceError.deliveryFailed(
                "Cannot change brightness for this display (\(writeStatus))."
            )
        }
    }
}
