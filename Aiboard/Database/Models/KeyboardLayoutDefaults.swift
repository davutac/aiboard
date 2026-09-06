import CoreGraphics

// MARK: - KeyboardLayoutDefaults
enum KeyboardLayoutDefaults {
    nonisolated static let defaultName = "ANSI Compact"
    nonisolated static let qwertzName = "QWERTZ Compact"
    nonisolated static let gridColumns = 78
    nonisolated static let gridRows = 5
    nonisolated static let keyGap: CGFloat = 1
    nonisolated static let baseSize = CGSize(width: 780, height: 200)
}
