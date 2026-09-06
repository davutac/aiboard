import Foundation
import SwiftData

// MARK: - KeyboardLayoutSeeder
@MainActor
enum KeyboardLayoutSeeder {
    // MARK: - Seed
    @discardableResult
    static func seedDefaultKeyboardIfNeeded(in context: ModelContext) throws -> KeyboardModel? {
        let descriptor = FetchDescriptor<KeyboardModel>(
            sortBy: [SortDescriptor(\KeyboardModel.sortIndex), SortDescriptor(\KeyboardModel.name)]
        )
        let keyboards = try context.fetch(descriptor)

        if let existingKeyboard = keyboards.first(where: { $0.name == KeyboardLayoutDefaults.defaultName }) {
            guard shouldReplacePreReleaseDefault(existingKeyboard) else {
                try restoreDefaultKeyboardBuiltIns(in: existingKeyboard, context: context)
                return nil
            }

            context.delete(existingKeyboard)
        }
        else if !keyboards.isEmpty {
            return nil
        }

        let keyboard = ansiCompactKeyboard()

        context.insert(keyboard)
        try context.save()

        return keyboard
    }

    static func ansiCompactKeyboard() -> KeyboardModel {
        KeyboardModel(
            name: KeyboardLayoutDefaults.defaultName,
            baseSize: KeyboardLayoutDefaults.baseSize,
            gridColumns: KeyboardLayoutDefaults.gridColumns,
            gridRows: KeyboardLayoutDefaults.gridRows,
            sortIndex: 0,
            keys: ansiCompactKeys()
        )
    }

    // MARK: - Replacement
    private static func shouldReplacePreReleaseDefault(_ keyboard: KeyboardModel) -> Bool {
        keyboard.name == KeyboardLayoutDefaults.defaultName
            && (
                keyboard.keys.isEmpty
                    || keyboard.keys.contains(where: isPreReleaseReferenceLabel)
            )
    }

    private static func isPreReleaseReferenceLabel(_ key: KeyModel) -> Bool {
        key.title == "POS1"
            || key.title == "LNGS"
            || key.title == "q"
    }

    private static func restoreDefaultKeyboardBuiltIns(
        in keyboard: KeyboardModel,
        context: ModelContext
    ) throws {
        guard keyboard.name == KeyboardLayoutDefaults.defaultName else {
            return
        }

        let expectedKeys = ansiCompactKeyboard().keys.filter { key in
            key.labelKind == .symbol && !key.labelSymbolName.isEmpty
        }
        var didRestoreBuiltIns = false

        for expectedKey in expectedKeys {
            guard let key = keyboard.keys.first(where: { key in
                key.gridColumn == expectedKey.gridColumn
                    && key.gridRow == expectedKey.gridRow
                    && key.gridColumnSpan == expectedKey.gridColumnSpan
                    && key.gridRowSpan == expectedKey.gridRowSpan
            }) else {
                continue
            }

            guard key.labelKind != .symbol || key.labelSymbolName != expectedKey.labelSymbolName else {
                continue
            }

            key.labelKind = .symbol
            key.labelSymbolName = expectedKey.labelSymbolName
            didRestoreBuiltIns = true
        }

        didRestoreBuiltIns = restoreDefaultLanguageKeyAction(in: keyboard) || didRestoreBuiltIns

        guard didRestoreBuiltIns else {
            return
        }

        try context.save()
    }

    private static func restoreDefaultLanguageKeyAction(in keyboard: KeyboardModel) -> Bool {
        guard
            let languageKey = keyboard.keys.first(where: isDefaultLanguageKey),
            languageKey.leftClickAction == .none,
            languageKey.rightClickAction == .none
        else {
            return false
        }

        languageKey.leftClickAction = .cycleKeyboardLanguage
        return true
    }

    private static func isDefaultLanguageKey(_ key: KeyModel) -> Bool {
        key.gridColumn == 74
            && key.gridRow == 0
            && key.gridColumnSpan == 4
            && key.gridRowSpan == 1
    }

    // MARK: - Keys
    private static func ansiCompactKeys() -> [KeyModel] {
        var placements: [SeedKeyPlacement] = []

        appendNumberRow(to: &placements)
        appendTopLetterRow(to: &placements)
        appendHomeRow(to: &placements)
        appendShiftRow(to: &placements)
        appendModifierRow(to: &placements)
        appendNavigationCluster(to: &placements)

        return placements.enumerated().map { sortIndex, placement in
            KeyModel(
                title: placement.definition.title,
                secondaryTitle: placement.definition.secondaryTitle,
                labelKind: placement.definition.labelKind,
                labelSymbolName: placement.definition.labelSymbolName,
                gridColumn: placement.column,
                gridRow: placement.row,
                gridColumnSpan: placement.definition.columnSpan,
                gridRowSpan: placement.rowSpan,
                sortIndex: sortIndex,
                leftClickAction: placement.definition.leftClickAction,
                rightClickAction: placement.definition.rightClickAction,
                pressBehavior: placement.definition.pressBehavior
            )
        }
    }

    private static func appendNumberRow(to placements: inout [SeedKeyPlacement]) {
        var column = 0

        append(key("§", secondaryTitle: "±", span: 4, key: .isoSection), to: &placements, column: &column, row: 0)
        append(key("1", secondaryTitle: "!", span: 4, key: .one), to: &placements, column: &column, row: 0)
        append(key("2", secondaryTitle: "@", span: 4, key: .two), to: &placements, column: &column, row: 0)
        append(key("3", secondaryTitle: "#", span: 4, key: .three), to: &placements, column: &column, row: 0)
        append(key("4", secondaryTitle: "$", span: 4, key: .four), to: &placements, column: &column, row: 0)
        append(key("5", secondaryTitle: "%", span: 4, key: .five), to: &placements, column: &column, row: 0)
        append(key("6", secondaryTitle: "^", span: 4, key: .six), to: &placements, column: &column, row: 0)
        append(key("7", secondaryTitle: "&", span: 4, key: .seven), to: &placements, column: &column, row: 0)
        append(key("8", secondaryTitle: "*", span: 4, key: .eight), to: &placements, column: &column, row: 0)
        append(key("9", secondaryTitle: "(", span: 4, key: .nine), to: &placements, column: &column, row: 0)
        append(key("0", secondaryTitle: ")", span: 4, key: .zero), to: &placements, column: &column, row: 0)
        append(key("-", secondaryTitle: "_", span: 4, key: .minus), to: &placements, column: &column, row: 0)
        append(key("=", secondaryTitle: "+", span: 4, key: .equal), to: &placements, column: &column, row: 0)
        append(symbolKey("Delete", symbolName: "delete.left", span: 12, key: .delete), to: &placements, column: &column, row: 0)

        assert(column == 64)
    }

    private static func appendTopLetterRow(to placements: inout [SeedKeyPlacement]) {
        var column = 0

        append(symbolKey("Tab", symbolName: "arrow.right.to.line", span: 6, key: .tab), to: &placements, column: &column, row: 1)
        append(letter("Q", span: 4, key: .q), to: &placements, column: &column, row: 1)
        append(letter("W", span: 4, key: .w), to: &placements, column: &column, row: 1)
        append(letter("E", span: 4, key: .e), to: &placements, column: &column, row: 1)
        append(letter("R", span: 4, key: .r), to: &placements, column: &column, row: 1)
        append(letter("T", span: 4, key: .t), to: &placements, column: &column, row: 1)
        append(letter("Y", span: 4, key: .y), to: &placements, column: &column, row: 1)
        append(letter("U", span: 4, key: .u), to: &placements, column: &column, row: 1)
        append(letter("I", span: 4, key: .i), to: &placements, column: &column, row: 1)
        append(letter("O", span: 4, key: .o), to: &placements, column: &column, row: 1)
        append(letter("P", span: 4, key: .p), to: &placements, column: &column, row: 1)
        append(key("[", secondaryTitle: "{", span: 4, key: .leftBracket), to: &placements, column: &column, row: 1)
        append(key("]", secondaryTitle: "}", span: 4, key: .rightBracket), to: &placements, column: &column, row: 1)
        column += 4
        appendAt(symbolKey("Return", symbolName: "return.left", span: 6, key: .return), column: column, row: 1, rowSpan: 2, to: &placements)
        column += 6

        assert(column == 64)
    }

    private static func appendHomeRow(to placements: inout [SeedKeyPlacement]) {
        var column = 0

        append(symbolKey("Caps Lock", symbolName: "capslock", span: 7, key: .capsLock), to: &placements, column: &column, row: 2)
        append(letter("A", span: 4, key: .a), to: &placements, column: &column, row: 2)
        append(letter("S", span: 4, key: .s), to: &placements, column: &column, row: 2)
        append(letter("D", span: 4, key: .d), to: &placements, column: &column, row: 2)
        append(letter("F", span: 4, key: .f), to: &placements, column: &column, row: 2)
        append(letter("G", span: 4, key: .g), to: &placements, column: &column, row: 2)
        append(letter("H", span: 4, key: .h), to: &placements, column: &column, row: 2)
        append(letter("J", span: 4, key: .j), to: &placements, column: &column, row: 2)
        append(letter("K", span: 4, key: .k), to: &placements, column: &column, row: 2)
        append(letter("L", span: 4, key: .l), to: &placements, column: &column, row: 2)
        append(key(";", secondaryTitle: ":", span: 4, key: .semicolon), to: &placements, column: &column, row: 2)
        append(key("'", secondaryTitle: "\"", span: 4, key: .quote), to: &placements, column: &column, row: 2)
        append(key("\\", secondaryTitle: "|", span: 7, key: .backslash), to: &placements, column: &column, row: 2)

        assert(column == 58)
    }

    private static func appendShiftRow(to placements: inout [SeedKeyPlacement]) {
        var column = 0

        append(modifier("Shift", symbolName: "shift", span: 6, modifier: .leftShift), to: &placements, column: &column, row: 3)
        append(key("`", secondaryTitle: "~", span: 4, key: .grave), to: &placements, column: &column, row: 3)
        append(letter("Z", span: 4, key: .z), to: &placements, column: &column, row: 3)
        append(letter("X", span: 4, key: .x), to: &placements, column: &column, row: 3)
        append(letter("C", span: 4, key: .c), to: &placements, column: &column, row: 3)
        append(letter("V", span: 4, key: .v), to: &placements, column: &column, row: 3)
        append(letter("B", span: 4, key: .b), to: &placements, column: &column, row: 3)
        append(letter("N", span: 4, key: .n), to: &placements, column: &column, row: 3)
        append(letter("M", span: 4, key: .m), to: &placements, column: &column, row: 3)
        append(key(",", secondaryTitle: "<", span: 4, key: .comma), to: &placements, column: &column, row: 3)
        append(key(".", secondaryTitle: ">", span: 4, key: .period), to: &placements, column: &column, row: 3)
        append(key("/", secondaryTitle: "?", span: 4, key: .slash), to: &placements, column: &column, row: 3)
        append(modifier("Shift", symbolName: "shift", span: 14, modifier: .rightShift), to: &placements, column: &column, row: 3)

        assert(column == 64)
    }

    private static func appendModifierRow(to placements: inout [SeedKeyPlacement]) {
        var column = 0

        append(modifier("Control", symbolName: "control", span: 6, modifier: .leftControl), to: &placements, column: &column, row: 4)
        append(modifier("Option", symbolName: "option", span: 5, modifier: .leftOption), to: &placements, column: &column, row: 4)
        append(modifier("Command", symbolName: "command", span: 7, modifier: .leftCommand), to: &placements, column: &column, row: 4)
        append(key("Space", span: 27, key: .space), to: &placements, column: &column, row: 4)
        append(modifier("Command", symbolName: "command", span: 7, modifier: .rightCommand), to: &placements, column: &column, row: 4)
        append(modifier("Option", symbolName: "option", span: 5, modifier: .rightOption), to: &placements, column: &column, row: 4)
        append(modifier("Control", symbolName: "control", span: 7, modifier: .rightControl), to: &placements, column: &column, row: 4)

        assert(column == 64)
    }

    private static func appendNavigationCluster(to placements: inout [SeedKeyPlacement]) {
        appendAt(key("Home", span: 4, key: .home), column: 66, row: 0, to: &placements)
        appendAt(key("End", span: 4, key: .end), column: 70, row: 0, to: &placements)
        appendAt(actionOnly("Lang", span: 4), column: 74, row: 0, to: &placements)
        appendAt(key("fn", span: 4, key: .function), column: 66, row: 1, to: &placements)
        appendAt(symbolKey("Home", symbolName: "arrow.up.left", span: 4, key: .home), column: 70, row: 1, to: &placements)
        appendAt(symbolKey("Page Up", symbolName: "arrow.up.to.line", span: 4, key: .pageUp), column: 74, row: 1, to: &placements)
        appendAt(symbolKey("Forward Delete", symbolName: "delete.right", span: 4, key: .forwardDelete), column: 66, row: 2, to: &placements)
        appendAt(symbolKey("End", symbolName: "arrow.down.right", span: 4, key: .end), column: 70, row: 2, to: &placements)
        appendAt(symbolKey("Page Down", symbolName: "arrow.down.to.line", span: 4, key: .pageDown), column: 74, row: 2, to: &placements)
        appendAt(symbolKey("Up", symbolName: "arrowtriangle.up.fill", span: 4, key: .upArrow), column: 70, row: 3, to: &placements)
        appendAt(symbolKey("Left", symbolName: "arrowtriangle.left.fill", span: 4, key: .leftArrow), column: 66, row: 4, to: &placements)
        appendAt(symbolKey("Down", symbolName: "arrowtriangle.down.fill", span: 4, key: .downArrow), column: 70, row: 4, to: &placements)
        appendAt(symbolKey("Right", symbolName: "arrowtriangle.right.fill", span: 4, key: .rightArrow), column: 74, row: 4, to: &placements)
    }

    // MARK: - Placement
    private static func append(
        _ definition: SeedKeyDefinition,
        to placements: inout [SeedKeyPlacement],
        column: inout Int,
        row: Int,
        rowSpan: Int = 1
    ) {
        appendAt(
            definition,
            column: column,
            row: row,
            rowSpan: rowSpan,
            to: &placements
        )
        column += definition.columnSpan
    }

    private static func appendAt(
        _ definition: SeedKeyDefinition,
        column: Int,
        row: Int,
        rowSpan: Int = 1,
        to placements: inout [SeedKeyPlacement]
    ) {
        placements.append(
            SeedKeyPlacement(
                definition: definition,
                column: column,
                row: row,
                rowSpan: rowSpan
            )
        )
    }

    // MARK: - Definitions
    private static func letter(
        _ title: String,
        span: Int,
        key: Key
    ) -> SeedKeyDefinition {
        SeedKeyDefinition(
            title: title,
            secondaryTitle: nil,
            labelKind: .text,
            labelSymbolName: "",
            columnSpan: span,
            leftClickAction: stroke(key),
            rightClickAction: shiftedStroke(key),
            pressBehavior: .pressAndRelease
        )
    }

    private static func key(
        _ title: String,
        secondaryTitle: String? = nil,
        span: Int,
        key: Key
    ) -> SeedKeyDefinition {
        SeedKeyDefinition(
            title: title,
            secondaryTitle: secondaryTitle,
            labelKind: .text,
            labelSymbolName: "",
            columnSpan: span,
            leftClickAction: stroke(key),
            rightClickAction: secondaryTitle == nil ? .none : shiftedStroke(key),
            pressBehavior: .pressAndRelease
        )
    }

    private static func symbolKey(
        _ title: String,
        symbolName: String,
        span: Int,
        key: Key
    ) -> SeedKeyDefinition {
        SeedKeyDefinition(
            title: title,
            secondaryTitle: nil,
            labelKind: .symbol,
            labelSymbolName: symbolName,
            columnSpan: span,
            leftClickAction: stroke(key),
            rightClickAction: .none,
            pressBehavior: .pressAndRelease
        )
    }

    private static func modifier(
        _ title: String,
        symbolName: String,
        span: Int,
        modifier: ModifierKey
    ) -> SeedKeyDefinition {
        SeedKeyDefinition(
            title: title,
            secondaryTitle: nil,
            labelKind: .symbol,
            labelSymbolName: symbolName,
            columnSpan: span,
            leftClickAction: .modifier(modifier),
            rightClickAction: .none,
            pressBehavior: .oneShot
        )
    }

    private static func actionOnly(
        _ title: String,
        span: Int
    ) -> SeedKeyDefinition {
        SeedKeyDefinition(
            title: title,
            secondaryTitle: nil,
            labelKind: .text,
            labelSymbolName: "",
            columnSpan: span,
            leftClickAction: .cycleKeyboardLanguage,
            rightClickAction: .none,
            pressBehavior: .pressAndRelease
        )
    }

    private static func stroke(_ key: Key) -> KeyAction {
        .keyStroke(KeyStroke(key))
    }

    private static func shiftedStroke(_ key: Key) -> KeyAction {
        .keyStroke(KeyStroke(key, modifiers: [.shift]))
    }
}

// MARK: - SeedKeyPlacement
private struct SeedKeyPlacement {
    let definition: SeedKeyDefinition
    let column: Int
    let row: Int
    let rowSpan: Int
}

// MARK: - SeedKeyDefinition
private struct SeedKeyDefinition {
    let title: String
    let secondaryTitle: String?
    let labelKind: KeyLabelKind
    let labelSymbolName: String
    let columnSpan: Int
    let leftClickAction: KeyAction
    let rightClickAction: KeyAction
    let pressBehavior: KeyPressBehavior
}
