import CoreGraphics
import SwiftData
import Testing

@testable import Aiboard

// MARK: - KeyboardLayoutSeederTests
@MainActor
struct KeyboardLayoutSeederTests {
    // MARK: - Seeding
    @Test func emptyDatabaseCreatesAnsiCompactKeyboard() throws {
        let context = try makeInMemoryContext()

        let seededKeyboard = try KeyboardLayoutSeeder.seedDefaultKeyboardIfNeeded(in: context)
        let keyboards = try fetchKeyboards(in: context)

        #expect(seededKeyboard != nil)
        #expect(keyboards.count == 1)
        #expect(keyboards.first?.name == KeyboardLayoutDefaults.defaultName)
        #expect(keyboards.first?.keys.isEmpty == false)
    }

    @Test func ansiCompactLanguageKeyCyclesKeyboardLanguage() throws {
        let keyboard = KeyboardLayoutSeeder.ansiCompactKeyboard()
        let languageKey = try #require(keyboard.keys.first { key in
            key.title == "Lang"
        })

        #expect(languageKey.leftClickAction == .cycleKeyboardLanguage)
        #expect(languageKey.rightClickAction == .none)
    }

    @Test func seedingDoesNotDuplicateExistingKeyboard() throws {
        let context = try makeInMemoryContext()

        let firstKeyboard = try KeyboardLayoutSeeder.seedDefaultKeyboardIfNeeded(in: context)
        let secondKeyboard = try KeyboardLayoutSeeder.seedDefaultKeyboardIfNeeded(in: context)
        let keyboards = try fetchKeyboards(in: context)

        #expect(firstKeyboard != nil)
        #expect(secondKeyboard == nil)
        #expect(keyboards.count == 1)
    }

    @Test func ansiCompactKeysStayInsideGridAndIncludeWideKeys() {
        let keyboard = KeyboardLayoutSeeder.ansiCompactKeyboard()
        let hasWideKey = keyboard.keys.contains { key in
            key.gridColumnSpan > 4
        }
        let hasSymbolLabels = keyboard.keys.contains { key in
            key.labelKind == .symbol && !key.labelSymbolName.isEmpty
        }
        let hasNavigationCluster = keyboard.keys.contains { key in
            key.gridColumn >= 66
        }
        let allKeysAreInBounds = keyboard.keys.allSatisfy { key in
            key.gridColumn >= 0
                && key.gridRow >= 0
                && key.gridColumnSpan >= 1
                && key.gridRowSpan >= 1
                && key.gridColumn + key.gridColumnSpan <= keyboard.gridColumns
                && key.gridRow + key.gridRowSpan <= keyboard.gridRows
        }

        #expect(keyboard.gridColumns == KeyboardLayoutDefaults.gridColumns)
        #expect(keyboard.gridRows == KeyboardLayoutDefaults.gridRows)
        #expect(hasWideKey)
        #expect(hasSymbolLabels)
        #expect(hasNavigationCluster)
        #expect(allKeysAreInBounds)
    }

    @Test func ansiCompactKeysUseFullDefaultGridWidth() {
        let keyboard = KeyboardLayoutSeeder.ansiCompactKeyboard()
        let rightEdge = keyboard.keys.map { key in
            key.gridColumn + key.gridColumnSpan
        }.max()

        #expect(rightEdge == keyboard.gridColumns)
    }

    @Test func ansiCompactKeysUseFullDefaultGridHeight() {
        let keyboard = KeyboardLayoutSeeder.ansiCompactKeyboard()
        let bottomEdge = keyboard.keys.map { key in
            key.gridRow + key.gridRowSpan
        }.max()

        #expect(bottomEdge == keyboard.gridRows)
    }

    @Test func seedingReplacesPreReleaseDefaultKeyboard() throws {
        let context = try makeInMemoryContext()
        let oldKeyboard = KeyboardModel(
            name: KeyboardLayoutDefaults.defaultName,
            gridColumns: 64,
            gridRows: KeyboardLayoutDefaults.gridRows,
            keys: [KeyModel(title: "POS1")]
        )

        context.insert(oldKeyboard)
        try context.save()

        let seededKeyboard = try KeyboardLayoutSeeder.seedDefaultKeyboardIfNeeded(in: context)
        let keyboards = try fetchKeyboards(in: context)
        let restoredDefaultKeyboard = keyboards.first { keyboard in
            keyboard.name == KeyboardLayoutDefaults.defaultName
        }
        let hasOldKey = keyboards.contains { keyboard in
            keyboard.keys.contains { key in
                key.title == "POS1"
            }
        }

        #expect(seededKeyboard != nil)
        #expect(keyboards.count == 1)
        #expect(restoredDefaultKeyboard?.gridColumns == KeyboardLayoutDefaults.gridColumns)
        #expect(!hasOldKey)
    }

    @Test func seedingPreservesEditedDefaultKeyboard() throws {
        let context = try makeInMemoryContext()
        let editedKeyboard = KeyboardModel(
            name: KeyboardLayoutDefaults.defaultName,
            baseSize: CGSize(width: 900, height: 260),
            gridColumns: 90,
            gridRows: 6,
            keys: [KeyModel(title: "Custom")]
        )

        context.insert(editedKeyboard)
        try context.save()

        let seededKeyboard = try KeyboardLayoutSeeder.seedDefaultKeyboardIfNeeded(in: context)
        let keyboards = try fetchKeyboards(in: context)
        let restoredEditedKeyboard = keyboards.first { keyboard in
            keyboard.name == KeyboardLayoutDefaults.defaultName
        }

        #expect(seededKeyboard == nil)
        #expect(keyboards.count == 1)
        #expect(restoredEditedKeyboard?.gridColumns == 90)
        #expect(restoredEditedKeyboard?.gridRows == 6)
        #expect(restoredEditedKeyboard?.baseSize == CGSize(width: 900, height: 260))
        #expect(restoredEditedKeyboard?.keys.first?.title == "Custom")
    }

    @Test func seedingPreservesExistingQwertzKeyboard() throws {
        let context = try makeInMemoryContext()
        let ansiKeyboard = KeyboardLayoutSeeder.ansiCompactKeyboard()
        let qwertzKeyboard = KeyboardModel(
            name: KeyboardLayoutDefaults.qwertzName,
            gridColumns: KeyboardLayoutDefaults.gridColumns,
            gridRows: KeyboardLayoutDefaults.gridRows,
            sortIndex: 1,
            keys: [KeyModel(title: "Edited QWERTZ")]
        )

        context.insert(ansiKeyboard)
        context.insert(qwertzKeyboard)
        try context.save()

        let seededKeyboard = try KeyboardLayoutSeeder.seedDefaultKeyboardIfNeeded(in: context)
        let keyboards = try fetchKeyboards(in: context)
        let restoredQwertzKeyboard = try #require(keyboards.first { keyboard in
            keyboard.name == KeyboardLayoutDefaults.qwertzName
        })

        #expect(seededKeyboard == nil)
        #expect(keyboards.count == 2)
        #expect(restoredQwertzKeyboard.keys.first?.title == "Edited QWERTZ")
        #expect(restoredQwertzKeyboard.sortIndex == 1)
    }

    @Test func seedingRestoresDefaultKeyboardSymbolLabels() throws {
        let context = try makeInMemoryContext()
        let keyboard = KeyboardLayoutSeeder.ansiCompactKeyboard()
        let languageKey = try #require(keyboard.keys.first { key in
            key.title == "Lang"
        })

        for key in keyboard.keys {
            key.labelKind = .text
            key.labelSymbolName = ""
        }
        languageKey.leftClickAction = .none

        context.insert(keyboard)
        try context.save()

        let seededKeyboard = try KeyboardLayoutSeeder.seedDefaultKeyboardIfNeeded(in: context)
        let keyboards = try fetchKeyboards(in: context)
        let restoredKeyboard = try #require(keyboards.first { keyboard in
            keyboard.name == KeyboardLayoutDefaults.defaultName
        })
        let deleteKey = try #require(restoredKeyboard.keys.first { key in
            key.title == "Delete"
        })
        let shiftKey = try #require(restoredKeyboard.keys.first { key in
            key.title == "Shift" && key.gridColumn == 0
        })
        let restoredLanguageKey = try #require(restoredKeyboard.keys.first { key in
            key.title == "Lang"
        })

        #expect(seededKeyboard == nil)
        #expect(keyboards.count == 1)
        #expect(deleteKey.labelKind == .symbol)
        #expect(deleteKey.labelSymbolName == "delete.left")
        #expect(shiftKey.labelKind == .symbol)
        #expect(shiftKey.labelSymbolName == "shift")
        #expect(restoredLanguageKey.leftClickAction == .cycleKeyboardLanguage)
    }

    // MARK: - Helpers
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: schema,
            migrationPlan: MigrationPlan.self,
            configurations: [configuration]
        )

        return ModelContext(container)
    }

    private func fetchKeyboards(in context: ModelContext) throws -> [KeyboardModel] {
        try context.fetch(FetchDescriptor<KeyboardModel>())
    }
}
