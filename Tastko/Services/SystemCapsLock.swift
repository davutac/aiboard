import Darwin
import IOKit
import IOKit.hidsystem

// MARK: - SystemCapsLock
@MainActor
enum SystemCapsLock {
    // MARK: - Read
    nonisolated static func currentState() -> Bool? {
        try? withConnection { connection in
            var state = false
            let result = IOHIDGetModifierLockState(connection, Int32(kIOHIDCapsLockState), &state)
            guard result == KERN_SUCCESS else {
                throw KeyboardServiceError.deliveryFailed(
                    "Could not read Caps Lock state (IOKit status \(result))."
                )
            }
            return state
        }
    }

    // MARK: - Toggle
    static func toggle() throws -> Bool {
        try withConnection { connection in
            let selector = Int32(kIOHIDCapsLockState)
            var currentState = false
            let getResult = IOHIDGetModifierLockState(connection, selector, &currentState)
            guard getResult == KERN_SUCCESS else {
                throw KeyboardServiceError.deliveryFailed(
                    "Could not read Caps Lock state (IOKit status \(getResult))."
                )
            }

            let requestedState = !currentState
            let setResult = IOHIDSetModifierLockState(connection, selector, requestedState)
            guard setResult == KERN_SUCCESS else {
                throw KeyboardServiceError.deliveryFailed(
                    "Could not set Caps Lock state (IOKit status \(setResult))."
                )
            }

            var verifiedState = false
            let verifyResult = IOHIDGetModifierLockState(connection, selector, &verifiedState)
            guard verifyResult == KERN_SUCCESS else {
                throw KeyboardServiceError.deliveryFailed(
                    "Could not verify Caps Lock state (IOKit status \(verifyResult))."
                )
            }
            guard verifiedState == requestedState else {
                throw KeyboardServiceError.deliveryFailed(
                    "Caps Lock did not change to the requested state."
                )
            }
            return verifiedState
        }
    }

    // MARK: - IOHID Connection
    nonisolated private static func withConnection(
        _ body: (io_connect_t) throws -> Bool
    ) throws -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOHIDSystem")
        )
        guard service != IO_OBJECT_NULL else {
            throw KeyboardServiceError.deliveryFailed("IOHIDSystem is unavailable.")
        }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = IO_OBJECT_NULL
        let openResult = IOServiceOpen(
            service,
            mach_task_self_,
            UInt32(kIOHIDParamConnectType),
            &connection
        )
        guard openResult == KERN_SUCCESS else {
            throw KeyboardServiceError.deliveryFailed(
                "Could not open IOHIDSystem (IOKit status \(openResult))."
            )
        }
        defer { IOServiceClose(connection) }
        return try body(connection)
    }
}
