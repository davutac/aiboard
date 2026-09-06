import AppKit

// MARK: - AlwaysOnTopWindowConfiguration
struct AlwaysOnTopWindowConfiguration {
    var size: CGSize
    var minSize: CGSize
    var maxSize: CGSize
    var origin: CGPoint?
    var level: NSWindow.Level
    var collectionBehavior: NSWindow.CollectionBehavior
    var hidesOnDeactivate: Bool
    var isMovableByWindowBackground: Bool
    var allowsResizing: Bool
    var maintainsContentAspectRatio: Bool
    var contentAspectRatio: CGSize?
    var contentHeightForWidth: (@MainActor (CGFloat) -> CGFloat)?
    var hasShadow: Bool
    var storageKey: String?
    var sizeDidChange: (@MainActor (CGSize) -> Void)?
    var originDidChange: (@MainActor (CGPoint) -> Void)?

    // MARK: - Initialization
    nonisolated init(
        size: CGSize = CGSize(width: 360, height: 240),
        minSize: CGSize = FloatingWindowDefaults.defaultMinimumSize,
        maxSize: CGSize = FloatingWindowDefaults.defaultMaximumSize,
        origin: CGPoint? = nil,
        level: NSWindow.Level = .floating,
        collectionBehavior: NSWindow.CollectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
        ],
        hidesOnDeactivate: Bool = false,
        isMovableByWindowBackground: Bool = true,
        allowsResizing: Bool = true,
        maintainsContentAspectRatio: Bool = true,
        contentAspectRatio: CGSize? = nil,
        contentHeightForWidth: (@MainActor (CGFloat) -> CGFloat)? = nil,
        hasShadow: Bool = true,
        storageKey: String? = nil,
        sizeDidChange: (@MainActor (CGSize) -> Void)? = nil,
        originDidChange: (@MainActor (CGPoint) -> Void)? = nil
    ) {
        self.size = size
        self.minSize = minSize
        self.maxSize = maxSize
        self.origin = origin
        self.level = level
        self.collectionBehavior = collectionBehavior
        self.hidesOnDeactivate = hidesOnDeactivate
        self.isMovableByWindowBackground = isMovableByWindowBackground
        self.allowsResizing = allowsResizing
        self.maintainsContentAspectRatio = maintainsContentAspectRatio
        self.contentAspectRatio = contentAspectRatio
        self.contentHeightForWidth = contentHeightForWidth
        self.hasShadow = hasShadow
        self.storageKey = storageKey
        self.sizeDidChange = sizeDidChange
        self.originDidChange = originDidChange
    }
}
