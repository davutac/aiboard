import CoreGraphics
import SwiftData

extension SchemaV1 {
    // MARK: - Key
    @Model
    final class Key {
        static let defaultSize = FloatingWindowDefaults.defaultKeySize

        var keyboard: Keyboard?
        var title: String = "Key"
        var secondaryTitle: String = ""
        var labelKindRawValue: String = KeyLabelKind.text.rawValue
        var labelSymbolName: String = ""
        var width: CGFloat = defaultSize.width
        var height: CGFloat = defaultSize.height
        var gridColumn: Int = 0
        var gridRow: Int = 0
        var gridColumnSpan: Int = 1
        var gridRowSpan: Int = 1
        var sortIndex: Int = 0
        var leftClickAction: KeyAction = KeyAction.none
        var rightClickAction: KeyAction = KeyAction.none
        var pressBehavior: KeyPressBehavior = KeyPressBehavior.pressAndRelease

        var size: CGSize {
            get {
                CGSize(width: width, height: height)
            }
            set {
                width = newValue.width
                height = newValue.height
            }
        }

        var labelKind: KeyLabelKind {
            get {
                KeyLabelKind(rawValue: labelKindRawValue) ?? .text
            }
            set {
                labelKindRawValue = newValue.rawValue
            }
        }

        // MARK: - Initialization
        init(
            keyboard: Keyboard? = nil,
            title: String = "Key",
            secondaryTitle: String? = nil,
            labelKind: KeyLabelKind = KeyLabelKind.text,
            labelSymbolName: String = "",
            size: CGSize = Key.defaultSize,
            gridColumn: Int = 0,
            gridRow: Int = 0,
            gridColumnSpan: Int = 1,
            gridRowSpan: Int = 1,
            sortIndex: Int = 0,
            leftClickAction: KeyAction = KeyAction.none,
            rightClickAction: KeyAction = KeyAction.none,
            pressBehavior: KeyPressBehavior = KeyPressBehavior.pressAndRelease
        ) {
            self.keyboard = keyboard
            self.title = title
            self.secondaryTitle = secondaryTitle ?? ""
            self.labelKindRawValue = labelKind.rawValue
            self.labelSymbolName = labelSymbolName
            self.width = size.width
            self.height = size.height
            self.gridColumn = gridColumn
            self.gridRow = gridRow
            self.gridColumnSpan = gridColumnSpan
            self.gridRowSpan = gridRowSpan
            self.sortIndex = sortIndex
            self.leftClickAction = leftClickAction
            self.rightClickAction = rightClickAction
            self.pressBehavior = pressBehavior
        }
    }
}
