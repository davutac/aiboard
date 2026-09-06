import CoreGraphics
import SwiftUI
import Testing

@testable import Aiboard

// MARK: - FloatingWindowDefaultsTests
struct FloatingWindowDefaultsTests {
    // MARK: - Key Model
    @MainActor
    @Test func keyModelDefaultsUseNoOpActions() {
        let key = KeyModel()

        #expect(key.title == "Key")
        #expect(key.secondaryTitle.isEmpty)
        #expect(key.labelKind == .text)
        #expect(key.labelSymbolName.isEmpty)
        #expect(key.size == KeyModel.defaultSize)
        #expect(key.width == KeyModel.defaultSize.width)
        #expect(key.height == KeyModel.defaultSize.height)
        #expect(key.gridColumn == 0)
        #expect(key.gridRow == 0)
        #expect(key.gridColumnSpan == 1)
        #expect(key.gridRowSpan == 1)
        #expect(key.sortIndex == 0)
        #expect(key.leftClickAction == .none)
        #expect(key.rightClickAction == .none)
        #expect(key.pressBehavior == .pressAndRelease)
    }

    @MainActor
    @Test func keyModelStoresConfiguredActions() {
        let key = KeyModel(
            title: "A",
            secondaryTitle: "!",
            labelKind: .symbol,
            labelSymbolName: "command",
            size: CGSize(width: 72, height: 36),
            gridColumn: 3,
            gridRow: 2,
            gridColumnSpan: 5,
            gridRowSpan: 1,
            sortIndex: 7,
            leftClickAction: .text("a"),
            rightClickAction: .keyStroke(KeyStroke(.a, modifiers: [.shift])),
            pressBehavior: .oneShot
        )

        #expect(key.title == "A")
        #expect(key.secondaryTitle == "!")
        #expect(key.labelKind == .symbol)
        #expect(key.labelSymbolName == "command")
        #expect(key.size == CGSize(width: 72, height: 36))
        #expect(key.width == 72)
        #expect(key.height == 36)
        #expect(key.gridColumn == 3)
        #expect(key.gridRow == 2)
        #expect(key.gridColumnSpan == 5)
        #expect(key.gridRowSpan == 1)
        #expect(key.sortIndex == 7)
        #expect(key.leftClickAction == .text("a"))
        #expect(key.rightClickAction == .keyStroke(KeyStroke(.a, modifiers: [.shift])))
        #expect(key.pressBehavior == .oneShot)
    }

    @MainActor
    @Test func keyboardModelDefaultsUseAnsiCompactGrid() {
        let keyboard = KeyboardModel()

        #expect(keyboard.name == KeyboardLayoutDefaults.defaultName)
        #expect(keyboard.baseSize == KeyboardLayoutDefaults.baseSize)
        #expect(keyboard.gridColumns == KeyboardLayoutDefaults.gridColumns)
        #expect(keyboard.gridRows == KeyboardLayoutDefaults.gridRows)
        #expect(keyboard.sortIndex == 0)
        #expect(keyboard.keys.isEmpty)
    }

    @Test func defaultKeySizeFitsSeventeenButtonsAtOnePointSpacing() {
        let totalButtonWidth =
            KeyModel.defaultSize.width
            * CGFloat(FloatingWindowDefaults.defaultRowButtonCount)
        let totalSpacing =
            FloatingWindowDefaults.defaultRowSpacing
            * CGFloat(FloatingWindowDefaults.defaultRowButtonCount - 1)
        let totalContentPadding = FloatingWindowDefaults.defaultContentPadding * 2
        let totalRowWidth = totalButtonWidth + totalSpacing
        let totalContentWidth = totalRowWidth + totalContentPadding

        #expect(KeyModel.defaultSize.width == KeyModel.defaultSize.height)
        #expect(abs(totalRowWidth - FloatingWindowDefaults.defaultRowWidth) < 0.0001)
        #expect(abs(totalContentWidth - FloatingWindowDefaults.defaultMinimumSize.width) < 0.0001)
    }

    // MARK: - Mini Size
    @Test func sanitizedMiniSizeLocksToSquare() {
        let size = FloatingWindowDefaults.sanitizedMiniSize(
            CGSize(width: 80, height: 120)
        )

        #expect(size == CGSize(width: 120, height: 120))
    }

    @Test func sanitizedMiniSizeClampsToAllowedRange() {
        let undersized = FloatingWindowDefaults.sanitizedMiniSize(
            CGSize(width: 20, height: 20)
        )
        let oversized = FloatingWindowDefaults.sanitizedMiniSize(
            CGSize(width: 400, height: 400)
        )

        #expect(undersized == FloatingWindowDefaults.minimumMiniSize)
        #expect(oversized == FloatingWindowDefaults.maximumMiniSize)
    }

    @Test func minimumMiniSizeMatchesButtonAndPadding() {
        let sideLength =
            FloatingWindowDefaults.miniButtonSideLength
            + (FloatingWindowDefaults.miniContentPadding * 2)

        #expect(
            FloatingWindowDefaults.minimumMiniSize
                == CGSize(
                    width: sideLength,
                    height: sideLength
                )
        )
    }

    @Test func sanitizedMiniSizeFallsBackForInvalidValues() {
        let size = FloatingWindowDefaults.sanitizedMiniSize(
            CGSize(width: CGFloat.nan, height: CGFloat.infinity)
        )

        #expect(size == FloatingWindowDefaults.defaultMiniSize)
    }

    // MARK: - Environment
    @Test func keyboardEditingEnvironmentDefaultsToFalse() {
        let environmentValues = EnvironmentValues()

        #expect(environmentValues.isKeyboardEditing == false)
    }
}
