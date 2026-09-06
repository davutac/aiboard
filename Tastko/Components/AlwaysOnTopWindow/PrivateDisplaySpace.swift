import AppKit
import Darwin

// Adapted from SkyLightWindow, copyright (c) 2025 Lakr Aream (MIT).
// See Resources/SkyLightWindow-LICENSE.txt and docs/lock-screen-display.md.

// MARK: - Private Display Space
final class PrivateDisplaySpace {
    private typealias Connection = @convention(c) () -> Int32
    private typealias Create = @convention(c) (Int32, Int32, Int32) -> UInt64
    private typealias SetLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias SetVisible = @convention(c) (Int32, CFArray) -> Void
    private typealias AddWindow = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void
    private typealias CopySpaces = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias WindowsInSpaces = @convention(c) (Int32, CFArray, CFArray) -> Void
    private typealias Destroy = @convention(c) (Int32, UInt64) -> Void
    private typealias ActiveSpace = @convention(c) (Int32) -> UInt64

    private let handle: UnsafeMutableRawPointer
    private let create: Create
    private let setLevel: SetLevel
    private let show: SetVisible
    private let hide: SetVisible
    private let addWindow: AddWindow
    private let copySpaces: CopySpaces
    private let restoreWindows: WindowsInSpaces
    private let removeWindows: WindowsInSpaces
    private let destroy: Destroy
    private let activeSpace: ActiveSpace
    private let connection: Int32
    private var space: UInt64?
    private var windowNumber: Int?
    private var originalSpaces: CFArray?

    enum Failure: Error, CustomStringConvertible {
        case unavailable(String)
        case rejected(String, Int32)

        var description: String {
            switch self {
            case .unavailable(let name): "Missing \(name)"
            case .rejected(let name, let code): "\(name): \(code)"
            }
        }
    }

    // MARK: - Runtime Loading
    init() throws {
        guard
            let handle = dlopen(
                "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight",
                RTLD_NOW | RTLD_LOCAL
            )
        else { throw Failure.unavailable("SkyLight") }

        do {
            let mainConnection: Connection = try Self.load("SLSMainConnectionID", from: handle)
            create = try Self.load("SLSSpaceCreate", from: handle)
            setLevel = try Self.load("SLSSpaceSetAbsoluteLevel", from: handle)
            show = try Self.load("SLSShowSpaces", from: handle)
            hide = try Self.load("SLSHideSpaces", from: handle)
            addWindow = try Self.load("SLSSpaceAddWindowsAndRemoveFromSpaces", from: handle)
            copySpaces = try Self.load("SLSCopySpacesForWindows", from: handle)
            restoreWindows = try Self.load("SLSAddWindowsToSpaces", from: handle)
            removeWindows = try Self.load("SLSRemoveWindowsFromSpaces", from: handle)
            destroy = try Self.load("SLSSpaceDestroy", from: handle)
            activeSpace = try Self.load("SLSGetActiveSpace", from: handle)
            connection = mainConnection()
            guard connection != 0 else { throw Failure.rejected("Connection", connection) }
            self.handle = handle
        }
        catch {
            dlclose(handle)
            throw error
        }
    }

    private static func load<T>(_ name: String, from handle: UnsafeMutableRawPointer) throws -> T {
        guard let symbol = dlsym(handle, name) else { throw Failure.unavailable(name) }
        return unsafeBitCast(symbol, to: T.self)
    }

    // MARK: - Window Attachment
    func attach(_ window: NSWindow) throws {
        precondition(space == nil)
        let windows = [window.windowNumber] as CFArray
        if let originals = copySpaces(connection, 0x7, windows)?.takeRetainedValue(),
            CFArrayGetCount(originals) > 0
        {
            originalSpaces = originals
        }
        else {
            let active = activeSpace(connection)
            guard active != 0 else { throw Failure.unavailable("original window spaces") }
            originalSpaces = [active] as CFArray
        }
        windowNumber = window.windowNumber
        let created = create(connection, 1, 0)
        guard created > 0 else { throw Failure.rejected("Create space", 0) }
        space = created
        // Upstream identifies level 400 as Notification Center at screen lock.
        try check(setLevel(connection, created, 400), operation: "Set level")
        show(connection, [created] as CFArray)
        addWindow(connection, created, windows, 7)
        // The window-space query omits this special space on macOS 27.
        // These void operations require a separate visual visibility check.
    }

    private func check(_ code: Int32, operation: String) throws {
        guard code == 0 else { throw Failure.rejected(operation, code) }
    }

    // MARK: - Teardown
    func detach() {
        guard let space else { return }
        if let windowNumber, let originalSpaces {
            let windows = [windowNumber] as CFArray
            restoreWindows(connection, windows, originalSpaces)
            removeWindows(connection, windows, [space] as CFArray)
        }
        hide(connection, [space] as CFArray)
        destroy(connection, space)
        self.space = nil
        windowNumber = nil
        originalSpaces = nil
    }

    isolated deinit {
        detach()
        dlclose(handle)
    }
}
