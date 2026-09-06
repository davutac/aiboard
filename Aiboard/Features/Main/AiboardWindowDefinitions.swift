import CoreGraphics

// MARK: - Aiboard Window IDs
extension FloatingWindowID {
    static let main = FloatingWindowID("main")
    static let keyboardDebug = FloatingWindowID("keyboardDebug")
}

// MARK: - Aiboard Window Configurations
extension AlwaysOnTopWindowConfiguration {
    static var keyboardDebugWindow: AlwaysOnTopWindowConfiguration {
        AlwaysOnTopWindowConfiguration(
            size: CGSize(width: 430, height: 390),
            minSize: CGSize(width: 360, height: 300),
            allowsResizing: false,
            maintainsContentAspectRatio: false,
            storageKey: "keyboardDebug"
        )
    }
}
