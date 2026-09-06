import AppKit
import CoreGraphics
import Foundation

// MARK: - PanelEditorProfileLoadResult
nonisolated struct PanelEditorProfileLoadResult: Sendable {
    let profiles: [PanelEditorProfile]
    let issues: [String]
}

// MARK: - PanelEditorProfileImportError
nonisolated enum PanelEditorProfileImportError: LocalizedError, Sendable {
    case invalidPropertyList(URL)
    case missingPanelDefinitions(URL)
    case invalidPanel(String)

    var errorDescription: String? {
        switch self {
        case .invalidPropertyList(let url):
            "The Panel Editor property list could not be read at \(url.path)."
        case .missingPanelDefinitions(let url):
            "The profile has no PanelDefinitions.plist at \(url.path)."
        case .invalidPanel(let identifier):
            "Panel \(identifier) has invalid geometry."
        }
    }
}

// MARK: - PanelEditorProfileImporter
/// Read-only compatibility boundary for Panel Editor's undocumented `.ascconfig` schema.
nonisolated enum PanelEditorProfileImporter {
    // MARK: - Profiles
    static func loadProfiles(in directoryURL: URL) throws -> PanelEditorProfileLoadResult {
        let packageURLs = try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.caseInsensitiveCompare("ascconfig") == .orderedSame }
        .sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        var profiles: [PanelEditorProfile] = []
        var issues: [String] = []

        for packageURL in packageURLs {
            do {
                profiles.append(try loadProfile(at: packageURL))
            }
            catch {
                issues.append("\(packageURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        return PanelEditorProfileLoadResult(profiles: profiles, issues: issues)
    }

    static func loadProfile(at packageURL: URL) throws -> PanelEditorProfile {
        let infoURL = packageURL.appending(path: "Contents/Info.plist")
        let definitionsURL = packageURL.appending(
            path: "Contents/Resources/PanelDefinitions.plist"
        )

        guard FileManager.default.fileExists(atPath: definitionsURL.path) else {
            throw PanelEditorProfileImportError.missingPanelDefinitions(packageURL)
        }

        let info = try propertyListDictionary(at: infoURL)
        let definitions = try propertyListDictionary(at: definitionsURL)
        let profileIdentifier =
            info["ASCConfigurationIdentifier"] as? String
            ?? packageURL.deletingPathExtension().lastPathComponent
        let displayName =
            info["ASCConfigurationDisplayName"] as? String
            ?? packageURL.deletingPathExtension().lastPathComponent

        return PanelEditorProfile(
            id: profileIdentifier,
            displayName: displayName,
            panels: try panels(
                from: definitions,
                profileIdentifier: profileIdentifier,
                profileDisplayName: displayName
            )
        )
    }

    static func panels(
        from definitions: [String: Any],
        profileIdentifier: String,
        profileDisplayName: String
    ) throws -> [PanelEditorPanel] {
        guard let rawPanels = definitions["Panels"] as? [String: Any] else {
            return []
        }

        return try rawPanels.compactMap { rawIdentifier, rawValue in
            guard let dictionary = rawValue as? [String: Any] else {
                return nil
            }

            return try panel(
                from: dictionary,
                rawIdentifier: rawIdentifier,
                profileIdentifier: profileIdentifier,
                profileDisplayName: profileDisplayName
            )
        }
        .sorted { first, second in
            if first.displayOrder != second.displayOrder {
                return first.displayOrder < second.displayOrder
            }

            return first.name.localizedStandardCompare(second.name) == .orderedAscending
        }
    }

    private static func panel(
        from dictionary: [String: Any],
        rawIdentifier: String,
        profileIdentifier: String,
        profileDisplayName: String
    ) throws -> PanelEditorPanel {
        guard let panelRect = rect(from: dictionary["Rect"] as? String) else {
            throw PanelEditorProfileImportError.invalidPanel(rawIdentifier)
        }

        let panelIdentifier = "\(profileIdentifier)::\(rawIdentifier)"
        var buttons: [PanelEditorButton] = []
        appendButtons(
            from: dictionary["PanelObjects"] as? [[String: Any]] ?? [],
            parentOrigin: .zero,
            panelIdentifier: panelIdentifier,
            to: &buttons
        )

        let associatedApplicationBundleIdentifiers =
            (dictionary["AssociatedApplications"] as? [[String: Any]] ?? [])
            .compactMap { application in
                (application["ApplicationBundleID"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }

        return PanelEditorPanel(
            id: panelIdentifier,
            rawIdentifier: rawIdentifier,
            profileDisplayName: profileDisplayName,
            name: dictionary["Name"] as? String ?? "Panel",
            displayOrder: (dictionary["DisplayOrder"] as? NSNumber)?.intValue ?? .max,
            size: panelRect.size,
            isDefaultHomePanel:
                dictionary["ShowPanelLocationString"] as? String == "DefaultHomePanel",
            associatedApplicationBundleIdentifiers: associatedApplicationBundleIdentifiers,
            buttons: buttons
        )
    }

    // MARK: - Objects
    private static func appendButtons(
        from objects: [[String: Any]],
        parentOrigin: CGPoint,
        panelIdentifier: String,
        to buttons: inout [PanelEditorButton]
    ) {
        for object in objects {
            guard let localRect = rect(from: object["Rect"] as? String) else {
                continue
            }

            let absoluteRect = localRect.offsetBy(
                dx: parentOrigin.x,
                dy: parentOrigin.y
            )

            switch object["PanelObjectType"] as? String {
            case "Button":
                buttons.append(
                    button(
                        from: object,
                        frame: absoluteRect,
                        panelIdentifier: panelIdentifier
                    )
                )

            case "Group":
                appendButtons(
                    from: object["PanelObjects"] as? [[String: Any]] ?? [],
                    parentOrigin: absoluteRect.origin,
                    panelIdentifier: panelIdentifier,
                    to: &buttons
                )

            default:
                continue
            }
        }
    }

    private static func button(
        from dictionary: [String: Any],
        frame: CGRect,
        panelIdentifier: String
    ) -> PanelEditorButton {
        let importedAction = importedAction(from: dictionary)
        let explicitTitle = (dictionary["DisplayText"] as? String)?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let title =
            explicitTitle?.isEmpty == false
            ? explicitTitle!
            : importedAction.action == .toggleFunctionToolbar
                ? "Toolbar" : importedAction.key?.panelEditorDisplayTitle ?? ""
        let secondaryTitle =
            explicitTitle?.isEmpty == false
            ? nil
            : importedAction.key?.panelEditorShiftedTitle
        let rawIdentifier = dictionary["ID"] as? String ?? UUID().uuidString

        return PanelEditorButton(
            id: "\(panelIdentifier)::\(rawIdentifier)",
            frame: frame,
            title: title,
            secondaryTitle: secondaryTitle,
            fontSize: CGFloat((dictionary["FontSize"] as? NSNumber)?.doubleValue ?? 16),
            backgroundColor: color(from: dictionary["DisplayColor"] as? String),
            foregroundColor: color(from: dictionary["FontColor"] as? String),
            shape: buttonShape(for: importedAction.key, frame: frame),
            primaryAction: importedAction.action,
            secondaryAction: importedAction.action.addingShiftModifier,
            pressBehavior: importedAction.pressBehavior
        )
    }

    private static func buttonShape(for key: Key?, frame: CGRect) -> PanelEditorButtonShape {
        guard key == .return, frame.height > frame.width else {
            return .rectangle
        }

        return .isoReturn
    }

    // MARK: - Actions
    private static func importedAction(from button: [String: Any]) -> ImportedAction {
        if let actions = button["Actions"] as? [[String: Any]],
            actions.count == 1,
            actions[0]["ActionType"] as? String == "ActionToolbarVisibility",
            let parameters = actions[0]["ActionParam"] as? [String: Any],
            parameters["PanelID"] as? String == "ACSH.systemPanel.dynamic.bestFunctionKeys",
            (parameters["ToolbarVisibilityChangeMode"] as? NSNumber)?.intValue == 3
        {
            return ImportedAction(
                action: .toggleFunctionToolbar,
                key: nil,
                pressBehavior: .pressAndRelease
            )
        }

        guard
            let actions = button["Actions"] as? [[String: Any]],
            actions.count == 1,
            actions[0]["ActionType"] as? String == "ActionPerformKeyMacro",
            let actionParameters = actions[0]["ActionParam"] as? [String: Any],
            let events = actionParameters["Events"] as? [[String: Any]],
            events.count == 1,
            events[0]["ActionType"] as? String == "ActionPressKeyCode",
            let eventParameters = events[0]["ActionParam"] as? [String: Any],
            let key = key(from: eventParameters)
        else {
            return ImportedAction(action: .none, key: nil, pressBehavior: .pressAndRelease)
        }

        let modifiers = modifiers(from: eventParameters["Modifiers"] as? NSNumber)

        if modifiers.isEmpty, let modifier = key.modifierKey {
            return ImportedAction(
                action: .modifier(modifier),
                key: key,
                pressBehavior: .oneShot
            )
        }

        return ImportedAction(
            action: .keyStroke(KeyStroke(key, modifiers: modifiers)),
            key: key,
            pressBehavior: .pressAndRelease
        )
    }

    private static func key(from parameters: [String: Any]) -> Key? {
        let usesMacKeyCode = (parameters["UsesMacKeyCode"] as? NSNumber)?.boolValue ?? false

        if usesMacKeyCode,
            let rawValue = (parameters["MacKeyCode"] as? NSNumber)?.uint16Value
        {
            return Key(rawValue: rawValue)
        }

        guard let usage = (parameters["USBKeyCode"] as? NSNumber)?.intValue else {
            return nil
        }

        return USBKeyCodeMap.key(for: usage)
    }

    private static func modifiers(from number: NSNumber?) -> KeyModifiers {
        guard let number else {
            return []
        }

        let flags = CGEventFlags(rawValue: number.uint64Value)
        var modifiers: KeyModifiers = []

        if flags.contains(.maskCommand) { modifiers.insert(.command) }
        if flags.contains(.maskShift) { modifiers.insert(.shift) }
        if flags.contains(.maskAlternate) { modifiers.insert(.option) }
        if flags.contains(.maskControl) { modifiers.insert(.control) }
        if flags.contains(.maskAlphaShift) { modifiers.insert(.capsLock) }
        if flags.contains(.maskSecondaryFn) { modifiers.insert(.function) }
        if flags.contains(.maskNumericPad) { modifiers.insert(.numericPad) }
        if flags.contains(.maskHelp) { modifiers.insert(.help) }

        return modifiers
    }

    // MARK: - Values
    private static func propertyListDictionary(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let value = try PropertyListSerialization.propertyList(from: data, format: nil)

        guard let dictionary = value as? [String: Any] else {
            throw PanelEditorProfileImportError.invalidPropertyList(url)
        }

        return dictionary
    }

    private static func rect(from string: String?) -> CGRect? {
        guard let string else {
            return nil
        }

        let rect = NSRectFromString(string)

        guard
            rect.origin.x.isFinite,
            rect.origin.y.isFinite,
            rect.width.isFinite,
            rect.height.isFinite,
            rect.width > 0,
            rect.height > 0
        else {
            return nil
        }

        return rect
    }

    private static func color(from string: String?) -> PanelEditorColorComponents? {
        guard let string else {
            return nil
        }

        let components = string.split(whereSeparator: \Character.isWhitespace).compactMap {
            Double($0)
        }

        guard components.count == 4 else {
            return nil
        }

        return PanelEditorColorComponents(
            red: components[0].clampedToUnitInterval,
            green: components[1].clampedToUnitInterval,
            blue: components[2].clampedToUnitInterval,
            alpha: components[3].clampedToUnitInterval
        )
    }
}

// MARK: - ImportedAction
private nonisolated struct ImportedAction {
    let action: KeyAction
    let key: Key?
    let pressBehavior: KeyPressBehavior
}

// MARK: - USBKeyCodeMap
private nonisolated enum USBKeyCodeMap {
    private static let keys: [Int: Key] = [
        4: .a, 5: .b, 6: .c, 7: .d, 8: .e, 9: .f, 10: .g, 11: .h,
        12: .i, 13: .j, 14: .k, 15: .l, 16: .m, 17: .n, 18: .o, 19: .p,
        20: .q, 21: .r, 22: .s, 23: .t, 24: .u, 25: .v, 26: .w, 27: .x,
        28: .y, 29: .z,
        30: .one, 31: .two, 32: .three, 33: .four, 34: .five,
        35: .six, 36: .seven, 37: .eight, 38: .nine, 39: .zero,
        40: .return, 41: .escape, 42: .delete, 43: .tab, 44: .space,
        45: .minus, 46: .equal, 47: .leftBracket, 48: .rightBracket,
        49: .backslash, 50: .backslash, 51: .semicolon, 52: .quote,
        53: .grave, 54: .comma, 55: .period, 56: .slash, 57: .capsLock,
        58: .f1, 59: .f2, 60: .f3, 61: .f4, 62: .f5, 63: .f6,
        64: .f7, 65: .f8, 66: .f9, 67: .f10, 68: .f11, 69: .f12,
        74: .home, 75: .pageUp, 76: .forwardDelete, 77: .end, 78: .pageDown,
        79: .rightArrow, 80: .leftArrow, 81: .downArrow, 82: .upArrow,
        84: .keypadDivide, 85: .keypadMultiply, 86: .keypadMinus, 87: .keypadPlus,
        88: .keypadEnter, 89: .keypad1, 90: .keypad2, 91: .keypad3,
        92: .keypad4, 93: .keypad5, 94: .keypad6, 95: .keypad7,
        96: .keypad8, 97: .keypad9, 98: .keypad0, 99: .keypadDecimal,
        100: .isoSection,
        224: .leftControl, 225: .leftShift, 226: .leftOption, 227: .leftCommand,
        228: .rightControl, 229: .rightShift, 230: .rightOption, 231: .rightCommand,
        232: .function,
    ]

    // MARK: - Lookup
    static func key(for usage: Int) -> Key? {
        keys[usage]
    }
}

// MARK: - Key Panel Editor Presentation
extension Key {
    fileprivate nonisolated var panelEditorDisplayTitle: String {
        switch self {
        case .return, .keypadEnter:
            "↩"
        case .delete:
            "⌫"
        case .forwardDelete:
            "⌦"
        case .tab:
            "⇥"
        case .space:
            "Space"
        case .capsLock:
            "⇪"
        case .leftShift, .rightShift:
            "⇧"
        case .leftControl, .rightControl:
            "⌃"
        case .leftOption, .rightOption:
            "⌥"
        case .leftCommand, .rightCommand:
            "⌘"
        case .function:
            "fn"
        case .leftArrow:
            "←"
        case .rightArrow:
            "→"
        case .downArrow:
            "↓"
        case .upArrow:
            "↑"
        default:
            displayTitle
        }
    }

    fileprivate nonisolated var panelEditorShiftedTitle: String? {
        switch self {
        case .isoSection: "±"
        case .one: "!"
        case .two: "@"
        case .three: "#"
        case .four: "$"
        case .five: "%"
        case .six: "^"
        case .seven: "&"
        case .eight: "*"
        case .nine: "("
        case .zero: ")"
        case .minus: "_"
        case .equal: "+"
        case .leftBracket: "{"
        case .rightBracket: "}"
        case .semicolon: ":"
        case .quote: "\""
        case .backslash: "|"
        case .grave: "~"
        case .comma: "<"
        case .period: ">"
        case .slash: "?"
        default: nil
        }
    }

    fileprivate nonisolated var modifierKey: ModifierKey? {
        switch self {
        case .leftShift: .leftShift
        case .rightShift: .rightShift
        case .leftCommand: .leftCommand
        case .rightCommand: .rightCommand
        case .leftOption: .leftOption
        case .rightOption: .rightOption
        case .leftControl: .leftControl
        case .rightControl: .rightControl
        case .function: .function
        default: nil
        }
    }
}

// MARK: - KeyAction Shift
extension KeyAction {
    fileprivate nonisolated var addingShiftModifier: KeyAction {
        guard case .keyStroke(let stroke) = self else {
            return .none
        }

        return .keyStroke(
            KeyStroke(
                stroke.key,
                modifiers: stroke.modifiers.union(.shift)
            )
        )
    }
}

// MARK: - Double Clamp
extension Double {
    fileprivate nonisolated var clampedToUnitInterval: Double {
        min(max(self, 0), 1)
    }
}
