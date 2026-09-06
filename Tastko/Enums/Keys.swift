import CoreGraphics

// MARK: - Key
nonisolated enum Key: UInt16, CaseIterable, Codable, Hashable, Sendable {
    case a = 0x00
    case s = 0x01
    case d = 0x02
    case f = 0x03
    case h = 0x04
    case g = 0x05
    case z = 0x06
    case x = 0x07
    case c = 0x08
    case v = 0x09
    case isoSection = 0x0A
    case b = 0x0B
    case q = 0x0C
    case w = 0x0D
    case e = 0x0E
    case r = 0x0F
    case y = 0x10
    case t = 0x11
    case one = 0x12
    case two = 0x13
    case three = 0x14
    case four = 0x15
    case six = 0x16
    case five = 0x17
    case equal = 0x18
    case nine = 0x19
    case seven = 0x1A
    case minus = 0x1B
    case eight = 0x1C
    case zero = 0x1D
    case rightBracket = 0x1E
    case o = 0x1F
    case u = 0x20
    case leftBracket = 0x21
    case i = 0x22
    case p = 0x23
    case `return` = 0x24
    case l = 0x25
    case j = 0x26
    case quote = 0x27
    case k = 0x28
    case semicolon = 0x29
    case backslash = 0x2A
    case comma = 0x2B
    case slash = 0x2C
    case n = 0x2D
    case m = 0x2E
    case period = 0x2F
    case tab = 0x30
    case space = 0x31
    case grave = 0x32
    case delete = 0x33
    case escape = 0x35
    case rightCommand = 0x36
    case leftCommand = 0x37
    case leftShift = 0x38
    case capsLock = 0x39
    case leftOption = 0x3A
    case leftControl = 0x3B
    case rightShift = 0x3C
    case rightOption = 0x3D
    case rightControl = 0x3E
    case function = 0x3F
    case f17 = 0x40
    case keypadDecimal = 0x41
    case keypadMultiply = 0x43
    case keypadPlus = 0x45
    case keypadClear = 0x47
    case volumeUp = 0x48
    case volumeDown = 0x49
    case mute = 0x4A
    case keypadDivide = 0x4B
    case keypadEnter = 0x4C
    case keypadMinus = 0x4E
    case f18 = 0x4F
    case f19 = 0x50
    case keypadEquals = 0x51
    case keypad0 = 0x52
    case keypad1 = 0x53
    case keypad2 = 0x54
    case keypad3 = 0x55
    case keypad4 = 0x56
    case keypad5 = 0x57
    case keypad6 = 0x58
    case keypad7 = 0x59
    case f20 = 0x5A
    case keypad8 = 0x5B
    case keypad9 = 0x5C
    case jisYen = 0x5D
    case jisUnderscore = 0x5E
    case jisKeypadComma = 0x5F
    case f5 = 0x60
    case f6 = 0x61
    case f7 = 0x62
    case f3 = 0x63
    case f8 = 0x64
    case f9 = 0x65
    case jisEisu = 0x66
    case f11 = 0x67
    case jisKana = 0x68
    case f13 = 0x69
    case f16 = 0x6A
    case f14 = 0x6B
    case f10 = 0x6D
    case contextualMenu = 0x6E
    case f12 = 0x6F
    case f15 = 0x71
    case help = 0x72
    case home = 0x73
    case pageUp = 0x74
    case forwardDelete = 0x75
    case f4 = 0x76
    case end = 0x77
    case f2 = 0x78
    case pageDown = 0x79
    case f1 = 0x7A
    case leftArrow = 0x7B
    case rightArrow = 0x7C
    case downArrow = 0x7D
    case upArrow = 0x7E

    // MARK: - Core Graphics
    var cgKeyCode: CGKeyCode {
        rawValue
    }
}

// MARK: - ModifierKey
nonisolated enum ModifierKey: String, CaseIterable, Codable, Hashable, Sendable {
    case leftShift
    case rightShift
    case leftCommand
    case rightCommand
    case leftOption
    case rightOption
    case leftControl
    case rightControl
    case function

    // MARK: - Key
    var key: Key {
        switch self {
        case .leftShift:
            .leftShift
        case .rightShift:
            .rightShift
        case .leftCommand:
            .leftCommand
        case .rightCommand:
            .rightCommand
        case .leftOption:
            .leftOption
        case .rightOption:
            .rightOption
        case .leftControl:
            .leftControl
        case .rightControl:
            .rightControl
        case .function:
            .function
        }
    }

    // MARK: - Modifiers
    var modifiers: KeyModifiers {
        switch self {
        case .leftShift, .rightShift:
            .shift
        case .leftCommand, .rightCommand:
            .command
        case .leftOption, .rightOption:
            .option
        case .leftControl, .rightControl:
            .control
        case .function:
            .function
        }
    }
}

// MARK: - KeyModifiers
nonisolated struct KeyModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt

    static let command = Self(rawValue: 1 << 0)
    static let shift = Self(rawValue: 1 << 1)
    static let option = Self(rawValue: 1 << 2)
    static let control = Self(rawValue: 1 << 3)
    static let capsLock = Self(rawValue: 1 << 4)
    static let function = Self(rawValue: 1 << 5)
    static let numericPad = Self(rawValue: 1 << 6)
    static let help = Self(rawValue: 1 << 7)

    init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    // MARK: - Core Graphics
    var cgEventFlags: CGEventFlags {
        var flags: CGEventFlags = []

        if contains(.command) {
            flags.insert(.maskCommand)
        }

        if contains(.shift) {
            flags.insert(.maskShift)
        }

        if contains(.option) {
            flags.insert(.maskAlternate)
        }

        if contains(.control) {
            flags.insert(.maskControl)
        }

        if contains(.capsLock) {
            flags.insert(.maskAlphaShift)
        }

        if contains(.function) {
            flags.insert(.maskSecondaryFn)
        }

        if contains(.numericPad) {
            flags.insert(.maskNumericPad)
        }

        if contains(.help) {
            flags.insert(.maskHelp)
        }

        return flags
    }
}

// MARK: - KeyStroke
nonisolated struct KeyStroke: Codable, Hashable, Sendable {
    let key: Key
    let modifiers: KeyModifiers

    init(_ key: Key, modifiers: KeyModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }
}
