import CoreGraphics
import Foundation
import SwiftData

extension SchemaV1 {
    // MARK: - Keyboard
    @Model
    final class Keyboard {
        var id: UUID = UUID()
        var name: String = KeyboardLayoutDefaults.defaultName
        var baseWidth: CGFloat = KeyboardLayoutDefaults.baseSize.width
        var baseHeight: CGFloat = KeyboardLayoutDefaults.baseSize.height
        var gridColumns: Int = KeyboardLayoutDefaults.gridColumns
        var gridRows: Int = KeyboardLayoutDefaults.gridRows
        var sortIndex: Int = 0

        @Relationship(deleteRule: .cascade, inverse: \Key.keyboard)
        var keys: [Key] = []

        var baseSize: CGSize {
            get {
                CGSize(width: baseWidth, height: baseHeight)
            }
            set {
                baseWidth = newValue.width
                baseHeight = newValue.height
            }
        }

        // MARK: - Initialization
        init(
            id: UUID = UUID(),
            name: String = KeyboardLayoutDefaults.defaultName,
            baseSize: CGSize = KeyboardLayoutDefaults.baseSize,
            gridColumns: Int = KeyboardLayoutDefaults.gridColumns,
            gridRows: Int = KeyboardLayoutDefaults.gridRows,
            sortIndex: Int = 0,
            keys: [Key] = []
        ) {
            self.id = id
            self.name = name
            self.baseWidth = baseSize.width
            self.baseHeight = baseSize.height
            self.gridColumns = gridColumns
            self.gridRows = gridRows
            self.sortIndex = sortIndex
            self.keys = keys

            for key in keys {
                key.keyboard = self
            }
        }
    }
}
