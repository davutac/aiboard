import AppKit
import Observation
import SwiftUI

// MARK: - FloatingWindowID
nonisolated struct FloatingWindowID: Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - FloatingWindowActions
struct FloatingWindowActions {
    let hide: () -> Void
}

// MARK: - FloatingWindowManager
@Observable
@MainActor
final class FloatingWindowManager {
    static let shared = FloatingWindowManager()

    private struct WindowInstance {
        let controller: AlwaysOnTopWindowController
        var isVisible: Bool
    }

    private var windows: [FloatingWindowID: WindowInstance] = [:]
    private let geometryStore = FloatingWindowGeometryStore()

    private init() {}

    // MARK: - API
    func show<Content: View>(
        _ id: FloatingWindowID,
        configuration: AlwaysOnTopWindowConfiguration = .init(),
        preservingCurrentOrigin: Bool = false,
        @ViewBuilder content: @escaping (FloatingWindowActions) -> Content
    ) {
        let controller = controller(for: id)
        let configuration = configurationWithStorage(configuration)
        let actions = actions(for: id)

        controller.show(
            configuration: configuration,
            preservingCurrentOrigin: preservingCurrentOrigin
        ) {
            content(actions)
        }

        windows[id] = WindowInstance(controller: controller, isVisible: true)
    }

    // MARK: - Child Windows
    /// Reusing an ID updates the existing child. IDs are scoped to the parent.
    func showChild<Content: View>(
        _ id: ChildWindowID,
        attachedTo parentID: FloatingWindowID,
        configuration: ChildWindowConfiguration? = nil,
        @ViewBuilder content: () -> Content
    ) {
        let controller = controller(for: parentID)
        if windows[parentID] == nil {
            windows[parentID] = WindowInstance(controller: controller, isVisible: false)
        }
        controller.showChild(id, configuration: configuration, content: content)
    }

    func hideChild(_ id: ChildWindowID, attachedTo parentID: FloatingWindowID) {
        windows[parentID]?.controller.hideChild(id)
    }

    func removeChild(_ id: ChildWindowID, attachedTo parentID: FloatingWindowID) {
        windows[parentID]?.controller.removeChild(id)
    }

    func isChildVisible(_ id: ChildWindowID, attachedTo parentID: FloatingWindowID) -> Bool {
        windows[parentID]?.controller.isChildVisible(id) == true
    }

    func toggle<Content: View>(
        _ id: FloatingWindowID,
        configuration: AlwaysOnTopWindowConfiguration = .init(),
        @ViewBuilder content: @escaping (FloatingWindowActions) -> Content
    ) {
        if isVisible(id) {
            hide(id)
        }
        else {
            show(id, configuration: configuration, content: content)
        }
    }

    // MARK: - Geometry Updates
    func setPreventsHiding(_ preventsHiding: Bool, for id: FloatingWindowID) {
        windows[id]?.controller.setPreventsHiding(preventsHiding)
    }

    func setLockScreenDisplay(_ enabled: Bool, for id: FloatingWindowID) throws {
        guard let controller = windows[id]?.controller else {
            if enabled { throw PrivateDisplaySpace.Failure.unavailable("keyboard window") }
            return
        }
        try controller.setLockScreenDisplay(enabled)
    }

    func frame(_ id: FloatingWindowID) -> CGRect? {
        windows[id]?.controller.frame
    }

    func animateGeometry(
        _ id: FloatingWindowID,
        configuration: AlwaysOnTopWindowConfiguration,
        duration: TimeInterval,
        progress: @escaping (CGFloat) -> Void
    ) {
        windows[id]?.controller.animateGeometry(
            configuration: configurationWithStorage(configuration, restoring: false),
            duration: duration,
            progress: progress
        )
    }

    func hide(_ id: FloatingWindowID) {
        guard let instance = windows[id] else { return }
        guard !instance.controller.preventsHiding else { return }

        instance.controller.hide()
        windows[id]?.isVisible = false
    }

    func isVisible(_ id: FloatingWindowID) -> Bool {
        windows[id]?.isVisible ?? false
    }

    // MARK: - Helpers
    private func controller(for id: FloatingWindowID) -> AlwaysOnTopWindowController {
        if let instance = windows[id] {
            return instance.controller
        }

        return AlwaysOnTopWindowController()
    }

    private func actions(for id: FloatingWindowID) -> FloatingWindowActions {
        FloatingWindowActions(
            hide: { [weak self] in
                self?.hide(id)
            }
        )
    }

    private func configurationWithStorage(
        _ configuration: AlwaysOnTopWindowConfiguration,
        restoring: Bool = true
    ) -> AlwaysOnTopWindowConfiguration {
        guard let storageKey = configuration.storageKey else {
            return configuration
        }

        var configuration =
            restoring ? restoredConfiguration(configuration, storageKey: storageKey) : configuration
        let sizeDidChange = configuration.sizeDidChange
        let originDidChange = configuration.originDidChange
        let allowsResizing = configuration.allowsResizing
        let fallbackSize = configuration.size

        configuration.sizeDidChange = { [weak self] size in
            let sanitizedSize = size.validWindowConstraint(fallback: fallbackSize)

            if allowsResizing {
                self?.geometryStore.store(size: sanitizedSize, storageKey: storageKey)
            }

            sizeDidChange?(sanitizedSize)
        }
        configuration.originDidChange = { [weak self] origin in
            guard let sanitizedOrigin = FloatingWindowDefaults.sanitizedOrigin(origin) else {
                return
            }

            self?.geometryStore.store(origin: sanitizedOrigin, storageKey: storageKey)
            originDidChange?(sanitizedOrigin)
        }

        return configuration
    }

    private func restoredConfiguration(
        _ configuration: AlwaysOnTopWindowConfiguration,
        storageKey: String
    ) -> AlwaysOnTopWindowConfiguration {
        guard let frame = geometryStore.frame(storageKey: storageKey) else {
            return configuration
        }

        var configuration = configuration

        if configuration.allowsResizing {
            var restoredSize = frame.size
                .validWindowConstraint(fallback: configuration.size)
                .constrained(toAtLeast: configuration.minSize)
                .constrained(toAtMost: configuration.maxSize)

            if let contentHeightForWidth = configuration.contentHeightForWidth {
                restoredSize.height = contentHeightForWidth(restoredSize.width)
                    .clamped(
                        to: configuration.minSize.height...configuration.maxSize.height
                    )
            }

            configuration.size = restoredSize
        }

        if let origin = FloatingWindowDefaults.sanitizedOrigin(frame.origin) {
            configuration.origin = origin
        }

        return configuration
    }
}

// MARK: - FloatingWindowGeometryStore
@MainActor
private final class FloatingWindowGeometryStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func frame(storageKey: String) -> StoredFloatingWindowFrame? {
        guard let data = userDefaults.data(forKey: defaultsKey(storageKey)) else {
            return nil
        }

        return try? JSONDecoder().decode(StoredFloatingWindowFrame.self, from: data)
    }

    func store(size: CGSize, storageKey: String) {
        guard size.isValidWindowConstraint else { return }

        var frame = frame(storageKey: storageKey) ?? StoredFloatingWindowFrame()
        frame.size = size
        store(frame, storageKey: storageKey)
    }

    func store(origin: CGPoint, storageKey: String) {
        guard let origin = FloatingWindowDefaults.sanitizedOrigin(origin) else { return }

        var frame = frame(storageKey: storageKey) ?? StoredFloatingWindowFrame()
        frame.origin = origin
        store(frame, storageKey: storageKey)
    }

    private func store(_ frame: StoredFloatingWindowFrame, storageKey: String) {
        guard let data = try? JSONEncoder().encode(frame) else {
            return
        }

        userDefaults.set(data, forKey: defaultsKey(storageKey))
    }

    private func defaultsKey(_ storageKey: String) -> String {
        "floatingWindow.\(storageKey).frame"
    }
}

// MARK: - StoredFloatingWindowFrame
private nonisolated struct StoredFloatingWindowFrame: Codable {
    var width: CGFloat?
    var height: CGFloat?
    var x: CGFloat?
    var y: CGFloat?

    var size: CGSize {
        get {
            CGSize(width: width ?? 0, height: height ?? 0)
        }
        set {
            width = newValue.width
            height = newValue.height
        }
    }

    var origin: CGPoint? {
        get {
            guard let x, let y else { return nil }

            return CGPoint(x: x, y: y)
        }
        set {
            x = newValue?.x
            y = newValue?.y
        }
    }
}

extension CGSize {
    // MARK: - Constraint
    fileprivate func constrained(toAtMost maximumSize: CGSize) -> CGSize {
        CGSize(
            width: min(width, maximumSize.width),
            height: min(height, maximumSize.height)
        )
    }
}
