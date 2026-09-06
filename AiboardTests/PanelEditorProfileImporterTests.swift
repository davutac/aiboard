import CoreGraphics
import SwiftUI
import Testing

@testable import Aiboard

// MARK: - PanelEditorProfileImporterTests
struct PanelEditorProfileImporterTests {
    // MARK: - Function Toolbar Action
    @Test func importsTheSavedFunctionToolbarToggleAction() throws {
        var object = keyButton(id: "TOOLBAR", rect: "{{0, 0}, {30, 20}}", usbKeyCode: 4)
        object["Actions"] = [
            [
                "ActionType": "ActionToolbarVisibility",
                "ActionParam": [
                    "PanelID": "ACSH.systemPanel.dynamic.bestFunctionKeys",
                    "ToolbarVisibilityChangeMode": 3,
                ],
            ]
        ]
        let panels = try PanelEditorProfileImporter.panels(
            from: definitions(panelObjects: [object]),
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )
        let button = try #require(panels.first?.buttons.first)
        #expect(button.primaryAction == .toggleFunctionToolbar)
        #expect(button.secondaryAction == .none)
        #expect(!button.primaryAction.isRepeatable)
        #expect(panels.first?.visibleButtons.isEmpty == true)
    }

    @Test(arguments: ["ACSH.systemPanel.dynamic.bestSuggestions", "unrecognized.toolbar"])
    func doesNotTreatOtherToolbarsAsFunctionKeys(_ panelID: String) throws {
        var object = keyButton(id: "TOOLBAR", rect: "{{0, 0}, {30, 20}}", usbKeyCode: 4)
        object["Actions"] = [
            [
                "ActionType": "ActionToolbarVisibility",
                "ActionParam": ["PanelID": panelID, "ToolbarVisibilityChangeMode": 3],
            ]
        ]
        let panels = try PanelEditorProfileImporter.panels(
            from: definitions(panelObjects: [object]),
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )
        #expect(panels.first?.buttons.first?.primaryAction == KeyAction.none)
    }

    // MARK: - Profile Colors
    @Test func importsBackgroundAndFontColors() throws {
        var object = keyButton(
            id: "COLOR",
            rect: "{{0, 0}, {30, 20}}",
            usbKeyCode: 4,
            displayColor: "0.120 0.520 0.900 1.000"
        )
        object["FontColor"] = "0.100 0.200 0.300 0.750"
        let panels = try PanelEditorProfileImporter.panels(
            from: definitions(panelObjects: [object]),
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )
        let button = try #require(panels.first?.buttons.first)

        #expect(
            button.backgroundColor
                == PanelEditorColorComponents(red: 0.12, green: 0.52, blue: 0.9, alpha: 1)
        )
        #expect(
            button.foregroundColor
                == PanelEditorColorComponents(red: 0.1, green: 0.2, blue: 0.3, alpha: 0.75)
        )
    }

    @Test func importsNestedButtonGeometryAndShiftedSecondaryAction() throws {
        let panels = try PanelEditorProfileImporter.panels(
            from: definitions(
                panelObjects: [
                    group(
                        rect: "{{10, 20}, {100, 50}}",
                        objects: [
                            keyButton(
                                id: "A",
                                rect: "{{3, 4}, {30, 20}}",
                                usbKeyCode: 4,
                                displayColor: "0.120 0.520 0.900 1.000"
                            )
                        ]
                    )
                ]
            ),
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )

        let panel = try #require(panels.first)
        let button = try #require(panel.buttons.first)

        #expect(panel.id == "PROFILE::USER.PANEL")
        #expect(panel.size == CGSize(width: 200, height: 100))
        #expect(button.frame == CGRect(x: 13, y: 24, width: 30, height: 20))
        #expect(button.title == "A")
        #expect(button.primaryAction == .keyStroke(KeyStroke(.a)))
        #expect(button.secondaryAction == .keyStroke(KeyStroke(.a, modifiers: [.shift])))
        #expect(button.shape == .rectangle)
        #expect(
            button.backgroundColor
                == PanelEditorColorComponents(red: 0.12, green: 0.52, blue: 0.9, alpha: 1)
        )
    }

    @Test func importsTallReturnKeyAsISOShape() throws {
        let panels = try PanelEditorProfileImporter.panels(
            from: definitions(
                panelObjects: [
                    keyButton(
                        id: "RETURN",
                        rect: "{{0, 0}, {46, 77}}",
                        usbKeyCode: 40
                    )
                ]
            ),
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )

        let button = try #require(panels.first?.buttons.first)
        let bounds = CGRect(x: 0, y: 0, width: 46, height: 77)
        let path = PanelEditorKeyShape(buttonShape: button.shape).path(in: bounds)

        #expect(button.shape == .isoReturn)
        #expect(path.contains(CGPoint(x: 4, y: 20)))
        #expect(!path.contains(CGPoint(x: 4, y: 60)))
        #expect(path.contains(CGPoint(x: 20, y: 60)))
        #expect(KeyMouseHitRegion.isoReturn.contains(CGPoint(x: 20, y: 60), in: bounds))
        #expect(!KeyMouseHitRegion.isoReturn.contains(CGPoint(x: 4, y: 60), in: bounds))
    }

    @Test func preservesImportedMacModifiersAndAddsShiftForRightClick() throws {
        let panels = try PanelEditorProfileImporter.panels(
            from: definitions(
                panelObjects: [
                    macKeyButton(
                        id: "UNDO",
                        rect: "{{0, 0}, {55, 35}}",
                        title: "UNDO",
                        macKeyCode: Key.z.rawValue,
                        modifiers: CGEventFlags.maskCommand.rawValue
                    )
                ]
            ),
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )

        let button = try #require(panels.first?.buttons.first)

        #expect(
            button.primaryAction
                == .keyStroke(KeyStroke(.z, modifiers: [.command]))
        )
        #expect(
            button.secondaryAction
                == .keyStroke(KeyStroke(.z, modifiers: [.command, .shift]))
        )
    }

    @Test func importsModifierUsagesAsOneShotActions() throws {
        let panels = try PanelEditorProfileImporter.panels(
            from: definitions(
                panelObjects: [
                    keyButton(
                        id: "SHIFT",
                        rect: "{{0, 0}, {60, 35}}",
                        usbKeyCode: 225
                    )
                ]
            ),
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )

        let button = try #require(panels.first?.buttons.first)

        #expect(button.title == "⇧")
        #expect(button.primaryAction == .modifier(.leftShift))
        #expect(button.secondaryAction == .none)
        #expect(button.pressBehavior == .oneShot)
    }

    @Test func importsFunctionUsageAsToggleModifier() throws {
        let panels = try PanelEditorProfileImporter.panels(
            from: definitions(
                panelObjects: [
                    keyButton(
                        id: "FUNCTION",
                        rect: "{{0, 0}, {38, 35}}",
                        usbKeyCode: 232
                    )
                ]
            ),
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )

        let button = try #require(panels.first?.buttons.first)

        #expect(button.title == "fn")
        #expect(button.primaryAction == .modifier(.function))
        #expect(button.secondaryAction == .none)
        #expect(button.pressBehavior == .oneShot)
    }

    @Test func sortsPanelsByPanelEditorDisplayOrder() throws {
        var root = definitions(panelObjects: [])
        let second = try #require((root["Panels"] as? [String: Any])?["USER.PANEL"])
        var panels = root["Panels"] as? [String: Any] ?? [:]
        var first = second as? [String: Any] ?? [:]
        first["Name"] = "First"
        first["DisplayOrder"] = 1
        panels["USER.FIRST"] = first
        root["Panels"] = panels

        let importedPanels = try PanelEditorProfileImporter.panels(
            from: root,
            profileIdentifier: "PROFILE",
            profileDisplayName: "Fixture"
        )

        #expect(importedPanels.map(\.name) == ["First", "Fixture Panel"])
    }

    @Test func importsApplicationAssociationsAndDefaultHomePanel() throws {
        var root = definitions(panelObjects: [])
        var panels = root["Panels"] as? [String: Any] ?? [:]
        var panel = panels["USER.PANEL"] as? [String: Any] ?? [:]
        panel["ShowPanelLocationString"] = "DefaultHomePanel"
        panel["AssociatedApplications"] = [
            ["ApplicationBundleID": " com.example.Editor "],
            ["ApplicationBundleID": ""],
        ]
        panels["USER.PANEL"] = panel
        root["Panels"] = panels

        let importedPanel = try #require(
            PanelEditorProfileImporter.panels(
                from: root,
                profileIdentifier: "PROFILE",
                profileDisplayName: "Fixture"
            ).first
        )

        #expect(importedPanel.isDefaultHomePanel)
        #expect(importedPanel.associatedApplicationBundleIdentifiers == ["com.example.Editor"])
    }

    @Test func preferredPanelMatchesAssociatedApplicationCaseInsensitively() throws {
        let profile = try selectionProfile()

        let panel = PanelEditorProfileStore.preferredPanel(
            in: [profile],
            forApplicationBundleIdentifier: "COM.EXAMPLE.EDITOR",
            currentPanelIdentifier: nil
        )

        #expect(panel?.name == "Editor")
    }

    @Test func preferredPanelFallsBackToDefaultHomePanel() throws {
        let profile = try selectionProfile()

        let panel = PanelEditorProfileStore.preferredPanel(
            in: [profile],
            forApplicationBundleIdentifier: "com.example.Unassigned",
            currentPanelIdentifier: nil
        )

        #expect(panel?.name == "Default")
    }

    @Test func windowMetricsUsePanelWidthWithoutHorizontalPadding() {
        let size = PanelEditorWindowMetrics.contentSize(
            for: CGSize(width: 708, height: 237)
        )

        #expect(size.width == 708)
        #expect(
            size.height
                == 237 + AppConstants.titlebarHeight + PanelEditorWindowMetrics.statusBarHeight
        )
    }

    @Test func windowMetricsScaleOnlyTheKeyboardHeight() {
        let height = PanelEditorWindowMetrics.contentHeight(
            for: CGSize(width: 708, height: 237),
            width: 1_416
        )

        #expect(
            height
                == PanelEditorWindowMetrics.fixedChromeHeight + 474
        )
    }

    @Test func minimumScaleProducesAnExactKeyboardSizedWindow() {
        let size = PanelEditorWindowMetrics.contentSize(
            for: CGSize(width: 708, height: 237),
            scale: 0.5
        )

        #expect(size.width == 354)
        #expect(size.height == PanelEditorWindowMetrics.fixedChromeHeight + 118.5)
        #expect(
            size.height
                == PanelEditorWindowMetrics.contentHeight(
                    for: CGSize(width: 708, height: 237),
                    width: size.width
                )
        )
    }

    // MARK: - Fixtures
    private func definitions(panelObjects: [[String: Any]]) -> [String: Any] {
        [
            "Panels": [
                "USER.PANEL": [
                    "ID": "USER.PANEL",
                    "Name": "Fixture Panel",
                    "DisplayOrder": 2,
                    "Rect": "{{0, 0}, {200, 100}}",
                    "PanelObjects": panelObjects,
                ]
            ]
        ]
    }

    private func selectionProfile() throws -> PanelEditorProfile {
        var root = definitions(panelObjects: [])
        let fixturePanel = try #require(
            (root["Panels"] as? [String: Any])?["USER.PANEL"] as? [String: Any]
        )
        var defaultPanel = fixturePanel
        defaultPanel["Name"] = "Default"
        defaultPanel["DisplayOrder"] = 1
        defaultPanel["ShowPanelLocationString"] = "DefaultHomePanel"

        var editorPanel = fixturePanel
        editorPanel["Name"] = "Editor"
        editorPanel["DisplayOrder"] = 2
        editorPanel["AssociatedApplications"] = [
            ["ApplicationBundleID": "com.example.Editor"]
        ]

        root["Panels"] = [
            "USER.DEFAULT": defaultPanel,
            "USER.EDITOR": editorPanel,
        ]

        return PanelEditorProfile(
            id: "PROFILE",
            displayName: "Fixture",
            sourceURL: URL(filePath: "/Fixture.ascconfig"),
            panels: try PanelEditorProfileImporter.panels(
                from: root,
                profileIdentifier: "PROFILE",
                profileDisplayName: "Fixture"
            )
        )
    }

    private func group(rect: String, objects: [[String: Any]]) -> [String: Any] {
        [
            "ID": "GROUP",
            "PanelObjectType": "Group",
            "Rect": rect,
            "PanelObjects": objects,
        ]
    }

    private func keyButton(
        id: String,
        rect: String,
        usbKeyCode: Int,
        displayColor: String? = nil
    ) -> [String: Any] {
        var button: [String: Any] = [
            "ID": id,
            "PanelObjectType": "Button",
            "Rect": rect,
            "DisplayText": "",
            "FontSize": 22,
            "Actions": [
                keyMacro(
                    parameters: [
                        "UsesMacKeyCode": false,
                        "USBKeyCode": usbKeyCode,
                    ]
                )
            ],
        ]

        button["DisplayColor"] = displayColor
        return button
    }

    private func macKeyButton(
        id: String,
        rect: String,
        title: String,
        macKeyCode: UInt16,
        modifiers: UInt64
    ) -> [String: Any] {
        [
            "ID": id,
            "PanelObjectType": "Button",
            "Rect": rect,
            "DisplayText": title,
            "FontSize": 15,
            "Actions": [
                keyMacro(
                    parameters: [
                        "UsesMacKeyCode": true,
                        "MacKeyCode": macKeyCode,
                        "Modifiers": modifiers,
                    ]
                )
            ],
        ]
    }

    private func keyMacro(parameters: [String: Any]) -> [String: Any] {
        [
            "ActionType": "ActionPerformKeyMacro",
            "ActionParam": [
                "Events": [
                    [
                        "ActionType": "ActionPressKeyCode",
                        "ActionParam": parameters,
                    ]
                ]
            ],
        ]
    }
}
