// MARK: - Key Display
extension Key {
    nonisolated var displayTitle: String {
        switch self {
        case .a:
            "A"
        case .s:
            "S"
        case .d:
            "D"
        case .f:
            "F"
        case .h:
            "H"
        case .g:
            "G"
        case .z:
            "Z"
        case .x:
            "X"
        case .c:
            "C"
        case .v:
            "V"
        case .isoSection:
            "ISO Section"
        case .b:
            "B"
        case .q:
            "Q"
        case .w:
            "W"
        case .e:
            "E"
        case .r:
            "R"
        case .y:
            "Y"
        case .t:
            "T"
        case .one:
            "1"
        case .two:
            "2"
        case .three:
            "3"
        case .four:
            "4"
        case .six:
            "6"
        case .five:
            "5"
        case .equal:
            "="
        case .nine:
            "9"
        case .seven:
            "7"
        case .minus:
            "-"
        case .eight:
            "8"
        case .zero:
            "0"
        case .rightBracket:
            "]"
        case .o:
            "O"
        case .u:
            "U"
        case .leftBracket:
            "["
        case .i:
            "I"
        case .p:
            "P"
        case .return:
            "Return"
        case .l:
            "L"
        case .j:
            "J"
        case .quote:
            "'"
        case .k:
            "K"
        case .semicolon:
            ";"
        case .backslash:
            "\\"
        case .comma:
            ","
        case .slash:
            "/"
        case .n:
            "N"
        case .m:
            "M"
        case .period:
            "."
        case .tab:
            "Tab"
        case .space:
            "Space"
        case .grave:
            "`"
        case .delete:
            "Delete"
        case .escape:
            "Escape"
        case .rightCommand:
            "Right Command"
        case .leftCommand:
            "Left Command"
        case .leftShift:
            "Left Shift"
        case .capsLock:
            "Caps Lock"
        case .leftOption:
            "Left Option"
        case .leftControl:
            "Left Control"
        case .rightShift:
            "Right Shift"
        case .rightOption:
            "Right Option"
        case .rightControl:
            "Right Control"
        case .function:
            "Function"
        case .f17:
            "F17"
        case .keypadDecimal:
            "Keypad Decimal"
        case .keypadMultiply:
            "Keypad *"
        case .keypadPlus:
            "Keypad +"
        case .keypadClear:
            "Keypad Clear"
        case .volumeUp:
            "Volume Up"
        case .volumeDown:
            "Volume Down"
        case .mute:
            "Mute"
        case .keypadDivide:
            "Keypad /"
        case .keypadEnter:
            "Keypad Enter"
        case .keypadMinus:
            "Keypad -"
        case .f18:
            "F18"
        case .f19:
            "F19"
        case .keypadEquals:
            "Keypad ="
        case .keypad0:
            "Keypad 0"
        case .keypad1:
            "Keypad 1"
        case .keypad2:
            "Keypad 2"
        case .keypad3:
            "Keypad 3"
        case .keypad4:
            "Keypad 4"
        case .keypad5:
            "Keypad 5"
        case .keypad6:
            "Keypad 6"
        case .keypad7:
            "Keypad 7"
        case .f20:
            "F20"
        case .keypad8:
            "Keypad 8"
        case .keypad9:
            "Keypad 9"
        case .jisYen:
            "JIS Yen"
        case .jisUnderscore:
            "JIS Underscore"
        case .jisKeypadComma:
            "JIS Keypad Comma"
        case .f5:
            "F5"
        case .f6:
            "F6"
        case .f7:
            "F7"
        case .f3:
            "F3"
        case .f8:
            "F8"
        case .f9:
            "F9"
        case .jisEisu:
            "JIS Eisu"
        case .f11:
            "F11"
        case .jisKana:
            "JIS Kana"
        case .f13:
            "F13"
        case .f16:
            "F16"
        case .f14:
            "F14"
        case .f10:
            "F10"
        case .contextualMenu:
            "Contextual Menu"
        case .f12:
            "F12"
        case .f15:
            "F15"
        case .help:
            "Help"
        case .home:
            "Home"
        case .pageUp:
            "Page Up"
        case .forwardDelete:
            "Forward Delete"
        case .f4:
            "F4"
        case .end:
            "End"
        case .f2:
            "F2"
        case .pageDown:
            "Page Down"
        case .f1:
            "F1"
        case .leftArrow:
            "Left Arrow"
        case .rightArrow:
            "Right Arrow"
        case .downArrow:
            "Down Arrow"
        case .upArrow:
            "Up Arrow"
        }
    }
}

// MARK: - ModifierKey Display
extension ModifierKey {
    nonisolated var displayTitle: String {
        switch self {
        case .leftShift:
            "Left Shift"
        case .rightShift:
            "Right Shift"
        case .leftCommand:
            "Left Command"
        case .rightCommand:
            "Right Command"
        case .leftOption:
            "Left Option"
        case .rightOption:
            "Right Option"
        case .leftControl:
            "Left Control"
        case .rightControl:
            "Right Control"
        case .function:
            "Function"
        }
    }
}
